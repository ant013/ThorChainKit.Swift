protocol KitLifecycle: AnyObject {
    func start(sequence: UInt64) -> LifecycleCommandBarrier
    func stop(sequence: UInt64) -> LifecycleCommandBarrier
    func cancelStop() -> LifecycleCommandBarrier
    func refresh(sequence: UInt64) -> LifecycleCommandBarrier
}

struct KitDependencies {
    let lifecycle: any KitLifecycle

    init(lifecycle: any KitLifecycle) {
        self.lifecycle = lifecycle
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
