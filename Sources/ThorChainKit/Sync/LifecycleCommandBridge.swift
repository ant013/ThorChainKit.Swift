import Foundation

@preconcurrency final class LifecycleCommandBarrier {
    private let semaphore = DispatchSemaphore(value: 0)
    private var signalled = false
    private var succeeded = true
    private let lock = NSLock()

    func signal(success: Bool = true) {
        lock.lock()
        guard !signalled else { lock.unlock(); return }
        succeeded = success
        signalled = true
        lock.unlock()
        semaphore.signal()
    }

    func wait() -> Bool {
        semaphore.wait()
        lock.lock(); defer { lock.unlock() }
        return succeeded
    }

    var isSuccessful: Bool {
        lock.lock(); defer { lock.unlock() }
        return succeeded
    }
}

final class LifecycleCommandBridge: KitLifecycle {
    private let syncer: any AccountSyncing
    private let gate: LifecycleGate
    private var tail: Task<Void, Never>?

    init(syncer: any AccountSyncing, gate: LifecycleGate) {
        self.syncer = syncer
        self.gate = gate
    }

    func start(sequence: UInt64) -> LifecycleCommandBarrier {
        _ = sequence
        guard let generation = gate.start() else { return completedBarrier(success: false) }
        return enqueue { [syncer] in await syncer.start(generation: generation) }
    }

    func stop(sequence: UInt64) -> LifecycleCommandBarrier {
        _ = sequence
        tail?.cancel()
        let cancellation = Task { [syncer] in await syncer.cancelRefresh() }
        switch gate.close() {
        case let .success(generation):
            return enqueue { [syncer] in
                await cancellation.value
                await syncer.stop(generation: generation)
            }
        case .failure:
            return enqueue { [syncer, gate] in
                await cancellation.value
                await syncer.cancelStop()
                gate.publishStopFailureIfCurrent()
            }
        }
    }

    func cancelStop() -> LifecycleCommandBarrier {
        enqueue { [syncer] in await syncer.cancelStop() }
    }

    func refresh(sequence: UInt64) -> LifecycleCommandBarrier {
        _ = sequence
        return enqueue { [syncer] in await syncer.refresh() }
    }

    private func completedBarrier(success: Bool = true) -> LifecycleCommandBarrier {
        let barrier = LifecycleCommandBarrier()
        barrier.signal(success: success)
        return barrier
    }

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) -> LifecycleCommandBarrier {
        let barrier = LifecycleCommandBarrier()
        let previous = tail
        tail = Task {
            _ = await previous?.value
            guard !Task.isCancelled else {
                barrier.signal()
                return
            }
            await operation()
            barrier.signal()
        }
        return barrier
    }
}
