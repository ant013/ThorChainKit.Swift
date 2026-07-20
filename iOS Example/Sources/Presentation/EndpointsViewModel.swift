import Combine
import Foundation

@MainActor
final class EndpointsViewModel: ObservableObject {
    @Published private(set) var snapshot: EndpointPolicySnapshot?

    private let runtime: ExampleRuntime
    private var operation: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(runtime: ExampleRuntime) {
        self.runtime = runtime
    }

    deinit {
        operation?.cancel()
    }

    func load(_ scenario: EndpointScenario) {
        operation?.cancel()
        generation &+= 1
        let requestGeneration = generation
        operation = Task { [weak self, runtime] in
            let snapshot = await runtime.endpointSnapshot(scenario: scenario)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard generation == requestGeneration else { return }
            self.snapshot = snapshot
            operation = nil
        }
    }

    func cancel() {
        generation &+= 1
        operation?.cancel()
        operation = nil
    }
}
