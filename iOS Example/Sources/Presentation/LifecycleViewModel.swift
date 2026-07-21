import Combine
import Foundation
import ThorChainKit

@MainActor
final class LifecycleViewModel: ObservableObject {
    @Published private(set) var syncDescription = "idle(cached: false)"
    @Published private(set) var requestCount = 0
    @Published private(set) var offline = false
    @Published private(set) var pending = false
    @Published private(set) var runeBalance = "0"
    @Published private(set) var acceptedHeight = "nil"
    @Published private(set) var lastBlockHeight = "nil"

    let runtime: ExampleRuntime
    private var cancellables = Set<AnyCancellable>()
    private let commandQueue = DispatchQueue(label: "ThorChainKitExample.LifecycleCommandQueue")

    init(runtime: ExampleRuntime) {
        self.runtime = runtime
        Task {
            pending = await runtime.fixturePending()
            offline = UserDefaults.standard.bool(forKey: Configuration.fixtureOfflineKey)
            updateRequestCount()
        }
        runtime.kit.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.syncDescription = Self.describe(state)
                if case .synced = state {
                    self?.updateRequestCount()
                } else if case .notSynced = state {
                    self?.updateRequestCount()
                }
                self?.writeEvidence()
            }
            .store(in: &cancellables)
        runtime.kit.lastBlockHeightPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height in
                self?.lastBlockHeight = height.map(String.init) ?? "nil"
                self?.writeEvidence()
            }
            .store(in: &cancellables)
        runtime.kit.accountStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.runeBalance = state?.balances[.rune]?.description ?? "0"
                self?.acceptedHeight = state.map { String($0.acceptedHeight) } ?? "nil"
                self?.writeEvidence()
            }
            .store(in: &cancellables)
        updateRequestCount()
    }

    func start() { runtime.kit.start(); updateRequestCount() }
    func stop() { runtime.kit.stop(); updateRequestCount() }
    func refresh() {
        let kit = runtime.kit
        commandQueue.async {
            _ = kit.refresh()
        }
        updateRequestCount()
    }

    func toggleOffline() {
        let value = !offline
        Task {
            await runtime.setFixtureOffline(value)
            offline = value
            updateRequestCount()
        }
    }

    func togglePending() {
        let value = !pending
        Task {
            await runtime.setFixturePending(value)
            pending = value
            updateRequestCount()
        }
    }

    func releasePending() {
        Task {
            await runtime.releaseFixturePending()
            pending = false
            updateRequestCount()
        }
    }

    private func updateRequestCount() {
        Task {
            requestCount = await runtime.fixtureRequestCount()
            writeEvidence()
        }
    }

    private func writeEvidence() {
        let parsedAcceptedHeight = Int64(acceptedHeight)
        let parsedLastBlockHeight = Int64(lastBlockHeight)
        runtime.writeFixtureEvidence(
            syncState: syncDescription,
            acceptedHeight: parsedAcceptedHeight,
            lastBlockHeight: parsedLastBlockHeight,
            rune: runeBalance,
            requestCount: requestCount
        )
    }

    private static func describe(_ state: SyncState) -> String {
        switch state {
        case let .idle(cached): "idle(cached: \(cached))"
        case let .syncing(previous): "syncing(previous: \(previous == nil ? "nil" : "present"))"
        case .synced: "synced"
        case let .notSynced(error, cached): "notSynced(\(error), cached: \(cached == nil ? "nil" : "present"))"
        }
    }
}
