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

    func wait() { semaphore.wait() }

    var isSuccessful: Bool {
        lock.lock(); defer { lock.unlock() }
        return succeeded
    }
}

final class LifecycleCommandBridge: KitLifecycle {
    private let syncer: any AccountSyncing
    private let gate: LifecycleGate
    private let sendRuntime: SendRuntime
    private var activeGeneration: UInt64?
    private var tail: Task<Void, Never>?

    init(syncer: any AccountSyncing, gate: LifecycleGate, sendRuntime: SendRuntime = SendRuntime()) {
        self.syncer = syncer
        self.gate = gate
        self.sendRuntime = sendRuntime
    }

    func start(sequence: UInt64) -> LifecycleCommandBarrier {
        _ = sequence
        guard let generation = gate.start() else { return completedBarrier(success: false) }
        activeGeneration = generation
        return enqueue { [syncer, sendRuntime] in
            await sendRuntime.activate(generation: generation)
            await syncer.start(generation: generation)
        }
    }

    func stop(sequence: UInt64) -> LifecycleCommandBarrier {
        _ = sequence
        tail?.cancel()
        let invalidatedGeneration = activeGeneration
        activeGeneration = nil
        switch gate.close() {
        case let .success(generation):
            return enqueue { [syncer, sendRuntime] in
                if let invalidatedGeneration {
                    await sendRuntime.invalidate(generation: invalidatedGeneration)
                }
                let cancellation = Task { await syncer.cancelRefresh() }
                await cancellation.value
                await syncer.stop(generation: generation)
            }
        case .failure:
            return enqueue { [syncer, gate, sendRuntime] in
                if let invalidatedGeneration {
                    await sendRuntime.invalidate(generation: invalidatedGeneration)
                }
                let cancellation = Task { await syncer.cancelRefresh() }
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
