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

    func save(transactions: [Transaction]) throws {
        try storage.write { db in
            try repository.save(transactions, in: db)
            try journal.removeIncluded(transactionIDs: transactions.filter(\.isTerminal).map(\.transactionId), in: db)
        }
        _ = pendingTransactionManager.refresh()
    }

    func process(transactions: [Transaction], initial: Bool) {
        guard !transactions.isEmpty else { return }
        allTransactionsSubject.send((transactions, initial))
        transactionsSubject.send(transactions)
    }
}
