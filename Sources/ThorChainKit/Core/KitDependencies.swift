protocol KitLifecycle: AnyObject {
    func start(sequence: UInt64)
    func stop(sequence: UInt64)
    func refresh(sequence: UInt64)
}

struct KitDependencies {
    let lifecycle: any KitLifecycle
}

final class NoOpLifecycle: KitLifecycle {
    func start(sequence: UInt64) {}
    func stop(sequence: UInt64) {}
    func refresh(sequence: UInt64) {}
}
