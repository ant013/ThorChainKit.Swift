import BigInt
import Combine
import Foundation

/// TronKit-shaped lifecycle owner with the Midgard pagination semantics used by
/// the Android THOR kit. It never signs or mutates the local send journal.
final class TransactionSyncer: @unchecked Sendable {
    private static let pageLimit = 50
    private static let maximumPageCount = 20
    private static let pendingRefreshLimit = 10

    private let provider: any MidgardActionProviding
    private let repository: TransactionRepository
    private let transactionManager: TransactionManager
    private let address: Address
    private let dispatcher = DispatchQueue(label: "io.horizontalsystems.thorchain-kit.transaction-syncer")
    private let dispatcherKey = DispatchSpecificKey<UInt8>()
    private let stateSubject = CurrentValueSubject<TransactionSyncState, Never>(.notSynced)
    private var task: Task<Void, Never>?
    private var syncing = false
    private var syncID: UUID?

    init(provider: any MidgardActionProviding, repository: TransactionRepository, transactionManager: TransactionManager, address: Address) {
        self.provider = provider
        self.repository = repository
        self.transactionManager = transactionManager
        self.address = address
        dispatcher.setSpecific(key: dispatcherKey, value: 1)
    }

    var state: TransactionSyncState { withDispatcher { stateSubject.value } }
    var statePublisher: AnyPublisher<TransactionSyncState, Never> { stateSubject.eraseToAnyPublisher() }

    func sync() {
        dispatcher.async { [weak self] in self?.syncOnDispatcher() }
    }

    func stop() {
        withDispatcher { stopOnDispatcher() }
    }

    private func syncOnDispatcher() {
        guard !syncing else { return }
        syncing = true
        let activeSyncID = UUID()
        syncID = activeSyncID
        stateSubject.send(.syncing)
        guard syncing, syncID == activeSyncID else { return }
        task = Task { [weak self, provider, repository, transactionManager, address] in
            do {
                let cursor = try repository.cursor()
                let recent = try await Self.syncRecent(
                    provider: provider,
                    repository: repository,
                    transactionManager: transactionManager,
                    address: address,
                    cursor: cursor
                )
                try Task.checkCancellation()
                transactionManager.process(transactions: recent.transactions, initial: cursor.lastTimestamp == 0)
                let backfill = try await Self.syncBackfill(
                    provider: provider,
                    repository: repository,
                    transactionManager: transactionManager,
                    address: address
                )
                try Task.checkCancellation()
                transactionManager.process(transactions: backfill, initial: false)
                let pending = try await Self.refreshPending(
                    provider: provider,
                    repository: repository,
                    transactionManager: transactionManager,
                    address: address,
                    recentHashes: recent.hashes
                )
                try Task.checkCancellation()
                transactionManager.process(transactions: pending, initial: false)
                self?.finish(.synced, syncID: activeSyncID)
            } catch is CancellationError {
                self?.finish(.notSynced, syncID: activeSyncID)
            } catch {
                self?.finish(.failed, syncID: activeSyncID)
            }
        }
    }

    private static func syncRecent(
        provider: any MidgardActionProviding,
        repository: TransactionRepository,
        transactionManager: TransactionManager,
        address: Address,
        cursor: TransactionSyncCursor
    ) async throws -> (transactions: [Transaction], hashes: Set<String>) {
        var updated = [Transaction]()
        var nextPageToken: String?
        var reachedWatermark = false
        var exhausted = false

        for _ in 0 ..< maximumPageCount {
            try Task.checkCancellation()
            let page = try await provider.fetchActions(
                address: address.raw,
                limit: pageLimit,
                nextPageToken: nextPageToken,
                transactionID: nil
            )
            try Task.checkCancellation()
            let transactions = try page.actions.compactMap(transaction)
            updated.append(contentsOf: transactions)
            reachedWatermark = transactions.contains { !$0.isPending && Int64($0.timestamp.timeIntervalSince1970) <= cursor.lastTimestamp }
            nextPageToken = page.nextPageToken
            exhausted = page.nextPageToken == nil || page.actions.isEmpty
            if reachedWatermark || exhausted { break }
        }

        // Store actions before advancing either cursor. This must be written before
        // the timestamp watermark. A crash
        // can then only repeat reads, never omit the older history segment.
        if !updated.isEmpty {
            try Task.checkCancellation()
            try transactionManager.save(transactions: updated)
        }
        if !reachedWatermark, !exhausted, let nextPageToken {
            try repository.save(backfillPageToken: nextPageToken)
        }
        if let newest = updated.lazy.filter({ !$0.isPending }).map({ Int64($0.timestamp.timeIntervalSince1970) }).max(), newest > cursor.lastTimestamp {
            try repository.save(lastTimestamp: newest)
        }
        return (updated, Set(updated.map { $0.transactionId.hash }))
    }

    private static func syncBackfill(
        provider: any MidgardActionProviding,
        repository: TransactionRepository,
        transactionManager: TransactionManager,
        address: Address
    ) async throws -> [Transaction] {
        var token = try repository.cursor().backfillPageToken
        guard token != nil else { return [] }
        var updated = [Transaction]()

        for _ in 0 ..< maximumPageCount {
            try Task.checkCancellation()
            let page = try await provider.fetchActions(
                address: address.raw,
                limit: pageLimit,
                nextPageToken: token,
                transactionID: nil
            )
            try Task.checkCancellation()
            updated.append(contentsOf: try page.actions.compactMap(transaction))
            token = page.nextPageToken
            if token == nil || page.actions.isEmpty {
                token = nil
                break
            }
        }
        if !updated.isEmpty {
            try Task.checkCancellation()
            try transactionManager.save(transactions: updated)
        }
        try repository.save(backfillPageToken: token)
        return updated
    }

    private static func refreshPending(
        provider: any MidgardActionProviding,
        repository: TransactionRepository,
        transactionManager: TransactionManager,
        address: Address,
        recentHashes: Set<String>
    ) async throws -> [Transaction] {
        let stale = try repository.pendingTransactions()
            .filter { !recentHashes.contains($0.transactionId.hash) }
            .prefix(pendingRefreshLimit)
        var refreshed = [Transaction]()
        for pending in stale {
            try Task.checkCancellation()
            let page = try await provider.fetchActions(
                address: address.raw,
                limit: 10,
                nextPageToken: nil,
                transactionID: pending.transactionId
            )
            try Task.checkCancellation()
            for transaction in try page.actions.compactMap(transaction) where transaction.transactionId == pending.transactionId {
                refreshed.append(transaction)
            }
        }
        if !refreshed.isEmpty {
            try Task.checkCancellation()
            try transactionManager.save(transactions: refreshed)
        }
        return refreshed
    }

    private static func transaction(_ action: MidgardAction) throws -> Transaction? {
        guard let incoming = action.incoming, let outgoing = action.outgoing else {
            throw MidgardProviderError.invalidResponse
        }
        guard let hash = (incoming + outgoing).compactMap(\.transactionHash).first(where: { !$0.isEmpty }) else {
            return nil
        }
        guard let transactionId = TransactionID(hash: hash.uppercased()),
              let height = action.height, height >= 0,
              let nanoseconds = action.date, nanoseconds >= 0,
              let type = action.type, !type.isEmpty,
              let status = action.status, !status.isEmpty
        else {
            throw MidgardProviderError.invalidResponse
        }
        return Transaction(
            transactionId: transactionId,
            blockHeight: height,
            timestamp: Date(timeIntervalSince1970: TimeInterval(nanoseconds / 1_000_000_000)),
            type: type,
            status: status,
            memo: memo(action.metadata),
            incoming: try transfers(incoming),
            outgoing: try transfers(outgoing)
        )
    }

    private static func transfers(_ transactions: [MidgardActionTransaction]) throws -> [CoinTransfer] {
        try transactions.flatMap { transaction in
            guard let address = transaction.address, !address.isEmpty else {
                throw MidgardProviderError.invalidResponse
            }
            return try (transaction.coins ?? []).map { coin in
                guard let asset = coin.asset, !asset.isEmpty,
                      let amountString = coin.amount, let amount = BigUInt(amountString)
                else {
                    throw MidgardProviderError.invalidResponse
                }
                return CoinTransfer(address: address, asset: asset, amount: amount)
            }
        }
    }

    private static func memo(_ metadata: MidgardJSONValue?) -> String? {
        metadata?.object?.values.compactMap { $0.object?["memo"]?.string }.first
    }

    private func stopOnDispatcher() {
        task?.cancel()
        task = nil
        syncID = nil
        syncing = false
        stateSubject.send(.notSynced)
    }

    private func finish(_ state: TransactionSyncState, syncID: UUID) {
        dispatcher.async { [weak self] in
            guard let self else { return }
            guard self.syncID == syncID else { return }
            task = nil
            self.syncID = nil
            syncing = false
            stateSubject.send(state)
        }
    }

    private func withDispatcher<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: dispatcherKey) == 1 { return body() }
        return dispatcher.sync(execute: body)
    }
}
