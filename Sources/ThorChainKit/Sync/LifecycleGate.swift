import Foundation

@preconcurrency final class LifecycleGate {
    private let dispatcher: DispatchQueue
    private let address: Address
    private let key: StorageKey
    private let storage: any AccountStateStorage
    private let publishing: StatePublishing
    private var generation: UInt64?
    private var closed = true

    init(
        dispatcher: DispatchQueue,
        address: Address,
        key: StorageKey,
        storage: any AccountStateStorage,
        publishing: StatePublishing
    ) {
        self.dispatcher = dispatcher
        self.address = address
        self.key = key
        self.storage = storage
        self.publishing = publishing
    }

    func start() -> UInt64? {
        do {
            let next = try storage.advanceGeneration(key: key)
            generation = next
            closed = false
            return next
        } catch {
            publish(.notSynced(.storageUnavailable, cached: publishing.snapshot.accountState))
            return nil
        }
    }

    func close() -> Result<UInt64, Error> {
        closed = true
        do {
            let next = try storage.advanceGeneration(key: key)
            generation = next
            return .success(next)
        } catch {
            publish(.notSynced(.storageUnavailable, cached: publishing.snapshot.accountState))
            return .failure(error)
        }
    }

    func publishSyncingIfCurrent(generation: UInt64) {
        dispatcher.sync { [self] in
            guard !closed, self.generation == generation else { return }
            publish(.syncing(previous: publishing.snapshot.accountState))
        }
    }

    func acceptCachedIfCurrent(generation: UInt64, record: StorageRecord) {
        dispatcher.sync { [self] in
            guard isCurrent(generation, record: record) else { return }
            do {
                let account = try record.accountState()
                publishing.apply(StateSnapshot(
                    accountState: account,
                    syncState: .idle(cached: true),
                    lastBlockHeight: account.acceptedHeight
                ))
            } catch {
                publish(.notSynced(.storageUnavailable, cached: publishing.snapshot.accountState))
            }
        }
    }

    func acceptIfCurrent(generation: UInt64, record: StorageRecord) {
        dispatcher.sync { [self] in
            guard isCurrent(generation, record: record) else { return }
            do {
                let account = try record.accountState()
                publishing.apply(StateSnapshot(
                    accountState: account,
                    syncState: .synced(account),
                    lastBlockHeight: account.acceptedHeight
                ))
            } catch {
                publish(.notSynced(.storageUnavailable, cached: publishing.snapshot.accountState))
            }
        }
    }

    func publishFailureIfCurrent(_ failure: SyncFailure) {
        dispatcher.sync { [self] in
            guard !closed,
                  self.generation == failure.generation,
                  failure.address == address.raw,
                  failure.networkChainId == address.network.expectedChainId
            else { return }
            publish(.notSynced(failure.error, cached: publishing.snapshot.accountState))
        }
    }

    private func isCurrent(_ generation: UInt64, record: StorageRecord) -> Bool {
        !closed
            && self.generation == generation
            && record.storageKey == key
            && record.address == address.raw
            && record.networkChainId == address.network.expectedChainId
    }

    private func publish(_ state: SyncState) {
        let account: AccountState?
        let height: Int64?
        switch state {
        case let .synced(value):
            account = value
            height = value.acceptedHeight
        case .idle, .syncing, .notSynced:
            account = publishing.snapshot.accountState
            height = publishing.snapshot.lastBlockHeight
        }
        publishing.apply(StateSnapshot(
            accountState: account,
            syncState: state,
            lastBlockHeight: height
        ))
    }
}

struct SyncFailure: Equatable, Sendable {
    let generation: UInt64
    let address: String
    let networkChainId: String
    let error: SyncError
}
