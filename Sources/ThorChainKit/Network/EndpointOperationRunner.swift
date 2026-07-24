import Foundation

enum EndpointOperationError: Error, Equatable, Sendable { case deadlineExceeded, cancelled, orphanCapReached }

final class EndpointOperationRunner: @unchecked Sendable {
    private let deadline: TimeInterval
    private let orphanCounter: OrphanCounter

    init(deadline: TimeInterval = 15, maximumOrphanedOperations: Int = 8) {
        self.deadline = deadline
        orphanCounter = OrphanCounter(maximum: maximumOrphanedOperations)
    }

    func run<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        guard orphanCounter.admit() else { throw EndpointOperationError.orphanCapReached }
        let deadline = self.deadline
        let cancellation = CancellationSignal()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
                let gate = CompletionGate<T>(continuation)
                cancellation.install { gate.finish(.failure(EndpointOperationError.cancelled)) }
                Task.detached {
                    do { gate.finish(.success(try await operation())) }
                    catch { gate.finish(.failure(error)) }
                    self.orphanCounter.complete()
                }
                Task.detached {
                    let ns = UInt64(max(0, deadline) * 1_000_000_000)
                    do { try await Task.sleep(nanoseconds: ns) } catch { return }
                    gate.finish(.failure(EndpointOperationError.deadlineExceeded))
                }
                if Task.isCancelled { gate.finish(.failure(EndpointOperationError.cancelled)) }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}

private final class CancellationSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var callback: (() -> Void)?

    func install(_ callback: @escaping () -> Void) {
        lock.lock(); defer { lock.unlock() }
        if cancelled { callback() } else { self.callback = callback }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let callback = self.callback
        self.callback = nil
        lock.unlock()
        callback?()
    }
}

private final class OrphanCounter: @unchecked Sendable {
    private let lock = NSLock()
    private let maximum: Int
    private var count = 0

    init(maximum: Int) { self.maximum = max(0, maximum) }

    func admit() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard count < maximum else { return false }
        count += 1
        return true
    }

    func complete() {
        lock.lock(); defer { lock.unlock() }
        count = max(0, count - 1)
    }
}

private final class CompletionGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let continuation: CheckedContinuation<T, Error>

    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }

    func finish(_ result: Result<T, Error>) {
        lock.lock(); defer { lock.unlock() }
        guard !completed else { return }
        completed = true
        continuation.resume(with: result)
    }
}
