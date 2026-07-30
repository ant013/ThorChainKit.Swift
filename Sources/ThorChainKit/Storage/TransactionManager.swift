import Combine
import Foundation

final class TransactionManager: @unchecked Sendable {
    private let journal: SendJournal
    private let network: Network
    private let publicationBarrier: PendingPublicationBarrier?
    private let stateQueue = DispatchQueue(label: "ThorChainKit.Send.Pending")
    private let subject = CurrentValueSubject<[PendingTransaction], Never>([])
    private let statusSubject = CurrentValueSubject<PendingTransactionsStatus, Never>(.degraded)
    private var lastSnapshot = [PendingTransaction]()
    private var lastRecords = [SendJournalRecord]()

    init(
        journal: SendJournal,
        network: Network = .mainnet,
        publicationBarrier: PendingPublicationBarrier? = nil
    ) {
        self.journal = journal
        self.network = network
        self.publicationBarrier = publicationBarrier
        _ = refresh()
    }

    var snapshot: [PendingTransaction] { stateQueue.sync { subject.value } }
    var status: PendingTransactionsStatus { stateQueue.sync { statusSubject.value } }
    var publisher: AnyPublisher<[PendingTransaction], Never> { subject.eraseToAnyPublisher() }
    var statusPublisher: AnyPublisher<PendingTransactionsStatus, Never> { statusSubject.eraseToAnyPublisher() }

    @discardableResult
    func refresh() -> PendingTransactionsStatus {
        stateQueue.sync { refreshLocked() }
    }

    private func refreshLocked() -> PendingTransactionsStatus {
        do {
            let records = try journal.pendingRecords()
            lastRecords = records
            records.filter { $0.state == .broadcasting }.forEach {
                publicationBarrier?.acknowledge(transactionID: $0.transactionID, generation: $0.broadcastGeneration)
            }
            lastSnapshot = records.compactMap { Self.project($0, network: network) }
            subject.send(lastSnapshot)
            statusSubject.send(.ready)
        } catch {
            lastRecords.filter { $0.state == .broadcasting }.forEach {
                publicationBarrier?.fail(transactionID: $0.transactionID, generation: $0.broadcastGeneration)
            }
            publicationBarrier?.failAll()
            subject.send(lastSnapshot)
            statusSubject.send(.degraded)
        }
        return statusSubject.value
    }

    private static func project(_ record: SendJournalRecord, network: Network) -> PendingTransaction? {
        guard let transactionID = TransactionID(hash: record.transactionID.hash),
              let recipient = try? Address(record.recipient, network: network) else { return nil }
        let state: PendingTransaction.State = record.state == .checkTxAccepted ? .checkTxAccepted : .unknown
        let availability: PendingTransaction.RetryAvailability
        switch record.state {
        case .broadcasting: availability = .inFlight
        case .checkTxAccepted: availability = .notApplicable
        case .unknown:
            switch record.retryBlockedReason {
            case .sequenceAdvanced: availability = .sequenceAdvanced
            case .providerInconsistent: availability = .providerInconsistent
            case nil: availability = .available
            }
        case .rejected: return nil
        }
        return PendingTransaction(
            transactionId: transactionID,
            recipient: recipient,
            amountMagnitude: record.amount,
            nativeFeeMagnitude: record.quotedNativeFee,
            memo: record.memo,
            state: state,
            retryAvailability: availability,
            createdAt: record.createdAt
        )
    }
}

final class PendingPublicationBarrier: @unchecked Sendable {
    private let lock = NSLock()
    private var acknowledgements = Set<String>()
    private var waiters = [String: [CheckedContinuation<Bool, Never>]]()
    private var failedPublications = Set<String>()

    func acknowledge(transactionID: TransactionID, generation: UInt64) {
        let key = key(transactionID, generation)
        let waiting: [CheckedContinuation<Bool, Never>]
        lock.lock()
        guard !failedPublications.contains(key) else {
            waiting = waiters.removeValue(forKey: key) ?? []
            lock.unlock()
            waiting.forEach { $0.resume(returning: false) }
            return
        }
        acknowledgements.insert(key)
        waiting = waiters.removeValue(forKey: key) ?? []
        lock.unlock()
        waiting.forEach { $0.resume(returning: true) }
    }

    func publish(transactionID: TransactionID, generation: UInt64) {
        acknowledge(transactionID: transactionID, generation: generation)
    }

    func fail(transactionID: TransactionID, generation: UInt64) {
        let key = key(transactionID, generation)
        let waiting: [CheckedContinuation<Bool, Never>]
        lock.lock()
        failedPublications.insert(key)
        waiting = waiters.removeValue(forKey: key) ?? []
        lock.unlock()
        waiting.forEach { $0.resume(returning: false) }
    }

    func isAcknowledged(transactionID: TransactionID, generation: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return acknowledgements.contains(key(transactionID, generation))
    }

    func failAll() {
        let waiting: [CheckedContinuation<Bool, Never>]
        lock.lock()
        let keys = waiters.keys
        failedPublications.formUnion(keys)
        waiting = waiters.values.flatMap { $0 }
        waiters.removeAll()
        lock.unlock()
        waiting.forEach { $0.resume(returning: false) }
    }

    func wait(transactionID: TransactionID, generation: UInt64) async -> Bool {
        let key = key(transactionID, generation)
        return await withCheckedContinuation { continuation in
            lock.lock()
            if failedPublications.contains(key) {
                lock.unlock()
                continuation.resume(returning: false)
                return
            }
            if acknowledgements.contains(key) {
                lock.unlock()
                continuation.resume(returning: true)
            } else {
                waiters[key, default: []].append(continuation)
                lock.unlock()
            }
        }
    }

    func reset() {
        lock.lock()
        acknowledgements.removeAll()
        failedPublications.removeAll()
        lock.unlock()
    }

    private func key(_ transactionID: TransactionID, _ generation: UInt64) -> String {
        "\(transactionID.hash):\(generation)"
    }
}
