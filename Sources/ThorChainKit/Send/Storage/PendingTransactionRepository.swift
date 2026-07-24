import Combine
import Foundation
import GRDB

final class PendingTransactionRepository: @unchecked Sendable {
    private let journal: SendJournal
    private let network: Network
    private let stateQueue = DispatchQueue(label: "ThorChainKit.Send.Pending")
    private let subject = CurrentValueSubject<[PendingTransaction], Never>([])
    private let statusSubject = CurrentValueSubject<PendingTransactionsStatus, Never>(.degraded)
    private var lastSnapshot = [PendingTransaction]()
    private var observation: AnyDatabaseCancellable?
    private var observationGeneration = 0

    init(journal: SendJournal, network: Network = .mainnet) {
        self.journal = journal
        self.network = network
        installObservation()
    }

    var snapshot: [PendingTransaction] { stateQueue.sync { subject.value } }
    var status: PendingTransactionsStatus { stateQueue.sync { statusSubject.value } }
    var publisher: AnyPublisher<[PendingTransaction], Never> { subject.eraseToAnyPublisher() }
    var statusPublisher: AnyPublisher<PendingTransactionsStatus, Never> { statusSubject.eraseToAnyPublisher() }

    @discardableResult
    func refresh() -> PendingTransactionsStatus {
        stateQueue.sync {
            do {
                let next = try journal.pendingRecords().compactMap { Self.project($0, network: network) }
                lastSnapshot = next
                subject.send(next)
                statusSubject.send(.ready)
                if observation == nil { installObservation() }
            } catch {
                subject.send(lastSnapshot)
                statusSubject.send(.degraded)
            }
            return statusSubject.value
        }
    }

    private func installObservation() {
        observationGeneration += 1
        let generation = observationGeneration
        observation?.cancel()
        let observation = ValueObservation.tracking { [journal] db in
            try journal.pendingRecords(in: db)
        }
        self.observation = observation.start(
            in: journal.databaseWriter,
            scheduling: .async(onQueue: stateQueue),
            onError: { [weak self] _ in
                self?.stateQueue.async {
                    guard let self, self.observationGeneration == generation else { return }
                    self.observation = nil
                    self.statusSubject.send(.degraded)
                }
            },
            onChange: { [weak self] records in
                self?.stateQueue.async {
                    guard let self, self.observationGeneration == generation else { return }
                    self.lastSnapshot = records.compactMap { Self.project($0, network: self.network) }
                    self.subject.send(self.lastSnapshot)
                    self.statusSubject.send(.ready)
                }
            }
        )
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

    func publish(transactionID: TransactionID, generation: UInt64) {
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

    func fail(transactionID: TransactionID, generation: UInt64) {
        let key = key(transactionID, generation)
        let waiting: [CheckedContinuation<Bool, Never>]
        lock.lock()
        failedPublications.insert(key)
        waiting = waiters.removeValue(forKey: key) ?? []
        lock.unlock()
        waiting.forEach { $0.resume(returning: false) }
    }

    func acknowledge(transactionID: TransactionID, generation: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return acknowledgements.contains(key(transactionID, generation))
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
