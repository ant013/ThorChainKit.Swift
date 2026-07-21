import Combine
import Foundation

@MainActor
final class AccountReadViewModel: ObservableObject {
    @Published private(set) var result: AccountReadFixtureResult?

    private let runtime: ExampleRuntime
    private var operation: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(runtime: ExampleRuntime) {
        self.runtime = runtime
    }

    deinit {
        operation?.cancel()
    }

    func load() {
        operation?.cancel()
        generation &+= 1
        let requestGeneration = generation
        operation = Task { [weak self, runtime] in
            let result = try? await runtime.accountFixture()
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard generation == requestGeneration else { return }
            self.result = result
            operation = nil
        }
    }

    func cancel() {
        generation &+= 1
        operation?.cancel()
        operation = nil
    }
}
