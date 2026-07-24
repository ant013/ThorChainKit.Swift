protocol KitLifecycle: AnyObject {
    func start(sequence: UInt64) -> LifecycleCommandBarrier
    func stop(sequence: UInt64) -> LifecycleCommandBarrier
    func cancelStop() -> LifecycleCommandBarrier
    func refresh(sequence: UInt64) -> LifecycleCommandBarrier
}

struct KitDependencies {
    let lifecycle: any KitLifecycle
    let sendRuntime: SendRuntime
    let preflight: SendPreflightCoordinator?
    let pendingRepository: PendingTransactionRepository?

    init(
        lifecycle: any KitLifecycle,
        sendRuntime: SendRuntime = SendRuntime(),
        preflight: SendPreflightCoordinator? = nil,
        pendingRepository: PendingTransactionRepository? = nil
    ) {
        self.lifecycle = lifecycle; self.sendRuntime = sendRuntime; self.preflight = preflight; self.pendingRepository = pendingRepository
    }
}

final class NoOpLifecycle: KitLifecycle {
    func start(sequence: UInt64) -> LifecycleCommandBarrier { completedBarrier() }
    func stop(sequence: UInt64) -> LifecycleCommandBarrier { completedBarrier() }
    func cancelStop() -> LifecycleCommandBarrier { completedBarrier() }
    func refresh(sequence: UInt64) -> LifecycleCommandBarrier { completedBarrier() }

    private func completedBarrier() -> LifecycleCommandBarrier {
        let barrier = LifecycleCommandBarrier()
        barrier.signal()
        return barrier
    }
}
