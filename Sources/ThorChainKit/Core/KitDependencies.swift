protocol KitLifecycle: AnyObject {
    func start(sequence: UInt64) -> LifecycleCommandBarrier
    func stop(sequence: UInt64) -> LifecycleCommandBarrier
    func cancelStop() -> LifecycleCommandBarrier
    func refresh(sequence: UInt64) -> LifecycleCommandBarrier
}

struct KitDependencies {
    let lifecycle: any KitLifecycle
    let sendRuntime: SendRuntime

    init(lifecycle: any KitLifecycle, sendRuntime: SendRuntime = SendRuntime()) {
        self.lifecycle = lifecycle
        self.sendRuntime = sendRuntime
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
