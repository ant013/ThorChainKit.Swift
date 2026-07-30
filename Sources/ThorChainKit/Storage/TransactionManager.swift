import BigInt
import Combine
import Foundation

/// Historical counterpart of TronKit.TransactionManager. It owns the normalized
/// cache and its publication; it never owns a signer or a Cosmos sequence.
final class TransactionManager: @unchecked Sendable {
    private let storage: TransactionStorage
    private let repository: TransactionRepository
    private let journal: SendJournal
    private let pendingTransactionManager: PendingTransactionManager
    private let allTransactionsSubject = PassthroughSubject<([Transaction], Bool), Never>()
    private let transactionsSubject = PassthroughSubject<[Transaction], Never>()

    init(storage: TransactionStorage, repository: TransactionRepository, journal: SendJournal, pendingTransactionManager: PendingTransactionManager) {
        self.storage = storage
        self.repository = repository
        self.journal = journal
        self.pendingTransactionManager = pendingTransactionManager
    }

    var allTransactionsPublisher: AnyPublisher<([Transaction], Bool), Never> {
        allTransactionsSubject.eraseToAnyPublisher()
    }

    var transactionsPublisher: AnyPublisher<[Transaction], Never> {
        transactionsSubject.eraseToAnyPublisher()
    }

    func transactions(hash: String? = nil, descending: Bool = true, limit: Int? = nil) -> [Transaction] {
        (try? repository.transactions(hash: hash, descending: descending, limit: limit)) ?? []
    }

    @discardableResult
    func save(transactions: [Transaction]) throws -> [Transaction] {
        let changed = try storage.write { db in
            let changed = try repository.save(transactions, in: db)
            try journal.removeIncluded(transactionIDs: transactions.filter(\.isTerminal).map(\.transactionId), in: db)
            return changed
        }
        _ = pendingTransactionManager.refresh()
        return changed
    }

    func process(initial: Bool) {
        let transactions: [Transaction]
        do {
            transactions = try storage.write { db in
                let transactions = try repository.unprocessedTransactions(in: db)
                try repository.markProcessed(in: db)
                return transactions
            }
        } catch {
            return
        }
        guard !transactions.isEmpty else { return }
        allTransactionsSubject.send((transactions, initial))
        transactionsSubject.send(transactions)
    }

    func reconcileLocalTransactions() throws {
        let records = try journal.records()
        let pending = records.compactMap(Self.localTransaction)
        let rejected = Set(records.filter { $0.state == .rejected }.map(\.transactionID))

        let changed = try storage.write { db -> Bool in
            var changed = !(try repository.saveLocal(pending, in: db)).isEmpty
            for transaction in try repository.localTransactions(in: db) where rejected.contains(transaction.transactionId) && transaction.status != "failed" {
                let failed = Transaction(
                    transactionId: transaction.transactionId,
                    blockHeight: transaction.blockHeight,
                    timestamp: transaction.timestamp,
                    timestampNanoseconds: transaction.timestampNanoseconds,
                    type: transaction.type,
                    status: "failed",
                    memo: transaction.memo,
                    incoming: transaction.incoming,
                    outgoing: transaction.outgoing
                )
                changed = !(try repository.save([failed], isLocal: true, in: db)).isEmpty || changed
            }
            return changed
        }
        _ = pendingTransactionManager.refresh()
        if changed { process(initial: false) }
    }

    private static func localTransaction(_ record: SendJournalRecord) -> Transaction? {
        let amount = BigUInt(record.amount)
        guard record.state != .rejected, amount > 0 else { return nil }
        let nanoseconds = Int64(record.createdAt.timeIntervalSince1970 * 1_000_000_000)
        return Transaction(
            transactionId: record.transactionID,
            blockHeight: 0,
            timestamp: record.createdAt,
            timestampNanoseconds: nanoseconds,
            type: "send",
            status: "pending",
            memo: record.memo,
            incoming: [CoinTransfer(address: record.sender, asset: "THOR.RUNE", amount: amount)],
            outgoing: [CoinTransfer(address: record.recipient, asset: "THOR.RUNE", amount: amount)]
        )
    }
}
