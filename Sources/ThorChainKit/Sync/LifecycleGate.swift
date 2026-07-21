import Foundation

@preconcurrency final class LifecycleGate {
    private let dispatcher: DispatchQueue
    private let address: Address
    private let key: StorageKey
    private let storage: any AccountStateStorage
    private let publishing: StatePublishing
    private let dispatcherKey = DispatchSpecificKey<UInt8>()
    private var generation: UInt64?
    private var closed = true
    private var pendingStopFailureGeneration: UInt64?

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
        dispatcher.setSpecific(key: dispatcherKey, value: 1)
    }

    func start() -> UInt64? {
        withDispatcher {
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
    }

    func close() -> Result<UInt64, Error> {
        withDispatcher {
            guard let oldGeneration = generation else {
                return .failure(StorageRecordError.invalid)
            }
            closed = true
            pendingStopFailureGeneration = oldGeneration
            do {
                let next = try storage.advanceGeneration(key: key)
                generation = next
                pendingStopFailureGeneration = nil
                publish(.idle(cached: publishing.snapshot.accountState != nil))
                return .success(oldGeneration)
            } catch {
                return .failure(error)
            }
        }
    }

    func publishSyncingIfCurrent(generation: UInt64) {
        withDispatcher { [self] in
            guard !closed, self.generation == generation else { return }
            publish(.syncing(previous: publishing.snapshot.accountState))
        }
    }

    func acceptCachedIfCurrent(generation: UInt64, record: StorageRecord) {
        withDispatcher { [self] in
            guard !closed, self.generation == generation else { return }
            guard isIdentityCurrent(record) else {
                publish(.notSynced(.storageUnavailable, cached: nil))
                return
            }
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
        withDispatcher { [self] in
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
        withDispatcher { [self] in
            guard !closed,
                  self.generation == failure.generation,
                  failure.address == address.raw,
                  failure.networkChainId == address.network.expectedChainId
            else { return }
            publish(.notSynced(failure.error, cached: publishing.snapshot.accountState))
        }
    }

    func publishStopFailureIfCurrent() {
        withDispatcher { [self] in
            guard let generation = pendingStopFailureGeneration,
                  closed,
                  self.generation == generation
            else { return }
            pendingStopFailureGeneration = nil
            publish(.notSynced(.storageUnavailable, cached: publishing.snapshot.accountState))
        }
    }

    private func withDispatcher<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: dispatcherKey) == 1 {
            return body()
        }
        return dispatcher.sync(execute: body)
    }

    private func isCurrent(_ generation: UInt64, record: StorageRecord) -> Bool {
        !closed
            && self.generation == generation
            && record.storageKey == key
            && isIdentityCurrent(record)
    }

    private func isIdentityCurrent(_ record: StorageRecord) -> Bool {
        record.storageKey == key
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
