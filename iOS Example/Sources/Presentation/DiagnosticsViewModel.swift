import Combine
import Foundation
import ThorChainKit

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    @Published private(set) var lastBlockHeight: Int64?
    @Published private(set) var syncState: SyncState = .idle(cached: false)
    @Published private(set) var accountState: AccountState?

    let runtime: ExampleRuntime
    private var cancellables = Set<AnyCancellable>()

    init(runtime: ExampleRuntime) {
        self.runtime = runtime

        runtime.kit.lastBlockHeightPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastBlockHeight = $0 }
            .store(in: &cancellables)
        runtime.kit.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.syncState = $0 }
            .store(in: &cancellables)
        runtime.kit.accountStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.accountState = $0 }
            .store(in: &cancellables)
    }

    var network: String {
        "\(runtime.kit.network.environment.rawValue) · \(runtime.kit.network.expectedChainId)"
    }

    var address: String { runtime.kit.address.raw }
    var runeBalance: String { accountState?.balances[.rune].description ?? "0" }
    var accountExists: String { String(accountState?.exists ?? false) }
    var accountStateDescription: String { accountState == nil ? "nil" : "present" }

    var syncDescription: String {
        switch syncState {
        case let .idle(cached):
            return "idle(cached: \(cached))"
        case let .syncing(previous):
            return "syncing(previous: \(previous == nil ? "nil" : "present"))"
        case .synced:
            return "synced"
        case let .notSynced(error, cached):
            return "notSynced(\(error), cached: \(cached == nil ? "nil" : "present"))"
        }
    }
}
