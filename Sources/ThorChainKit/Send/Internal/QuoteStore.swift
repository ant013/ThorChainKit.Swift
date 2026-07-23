import Foundation

protocol SendMonotonicClock: Sendable {
    var now: UInt64 { get }
}

struct SystemSendMonotonicClock: SendMonotonicClock {
    var now: UInt64 { DispatchTime.now().uptimeNanoseconds }
}

final class QuoteStore: @unchecked Sendable {
    private enum State: Equatable { case active, consumed, invalidated }
    let clientID: UUID
    private let clock: any SendMonotonicClock
    private var records = [QuoteAuthorityRecord: State]()
    private let lock = NSLock()

    init(clientID: UUID = UUID(), clock: any SendMonotonicClock = SystemSendMonotonicClock()) {
        self.clientID = clientID
        self.clock = clock
    }

    func issue(
        recipient: Address,
        amountMagnitude: Data,
        isMaximum: Bool,
        nativeFeeMagnitude: Data,
        totalDebitMagnitude: Data,
        memo: String?,
        acceptedHeight: Int64,
        expiresAt: Date,
        generation: UInt64,
        accountNumber: UInt64 = 0,
        sequence: UInt64 = 0,
        providerFamilyID: String = "contract"
    ) throws -> SendQuote {
        var random = SystemRandomNumberGenerator()
        lock.lock(); defer { lock.unlock() }
        purgeExpiredLocked()
        let (deadline, overflow) = clock.now.addingReportingOverflow(10_000_000_000)
        guard !overflow else { throw SendError.operationUnavailable }
        for _ in 0..<8 {
            let token = Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &random) })
            let record = QuoteAuthorityRecord(
                envelope: QuoteAuthorityEnvelope(
                    clientID: clientID,
                    generation: generation,
                    deadline: deadline,
                    token: token
                ),
                snapshot: QuoteReviewSnapshot(
                    sender: "",
                    recipient: recipient.raw,
                    requestedAmountIsMaximum: isMaximum,
                    amountMagnitude: amountMagnitude,
                    nativeFeeMagnitude: nativeFeeMagnitude,
                    totalDebitMagnitude: totalDebitMagnitude,
                    memo: memo,
                    acceptedHeight: acceptedHeight,
                    accountNumber: accountNumber,
                    sequence: sequence,
                    providerFamilyID: providerFamilyID
                )
            )
            guard records[record] == nil else { continue }
            records[record] = .active
            return SendQuote(
                recipient: recipient,
                amountMagnitude: amountMagnitude,
                isMaximum: isMaximum,
                nativeFeeMagnitude: nativeFeeMagnitude,
                totalDebitMagnitude: totalDebitMagnitude,
                memo: memo,
                acceptedHeight: acceptedHeight,
                expiresAt: expiresAt,
                authorityRecord: record
            )
        }
        throw SendError.operationUnavailable
    }

    func insert(_ quote: SendQuote) throws {
        let record = quote.internalAuthorityRecord
        lock.lock(); defer { lock.unlock() }
        purgeExpiredLocked()
        guard record.envelope.clientID == clientID,
              record.envelope.token.count == 32,
              quote.hasConsistentAuthorityProjection,
              records[record] == nil
        else { throw SendError.operationUnavailable }
        records[record] = .active
    }

    func consume(_ quote: SendQuote, activeGeneration: UInt64) throws -> QuoteAuthorityRecord {
        let record = quote.internalAuthorityRecord
        lock.lock(); defer { lock.unlock() }
        purgeExpiredLocked()
        guard record.envelope.clientID == clientID else { throw SendError.quoteOwnershipMismatch }
        guard record.envelope.generation == activeGeneration else { throw SendError.quoteGenerationInvalidated }
        if clock.now >= record.envelope.deadline {
            records[record] = .invalidated
            throw SendError.quoteExpired
        }
        guard quote.hasConsistentAuthorityProjection else { throw SendError.operationUnavailable }
        guard let state = records[record] else { throw SendError.operationUnavailable }
        switch state {
        case .active:
            records[record] = .consumed
            return record
        case .consumed:
            throw SendError.quoteAlreadyConsumed
        case .invalidated:
            throw SendError.quoteGenerationInvalidated
        }
    }

    func invalidate(generation: UInt64) {
        lock.lock(); defer { lock.unlock() }
        purgeExpiredLocked()
        for record in records.keys where record.envelope.generation == generation {
            if records[record] == .active { records[record] = .invalidated }
        }
    }

    func isEmpty() -> Bool {
        lock.lock(); defer { lock.unlock() }
        purgeExpiredLocked()
        return records.isEmpty
    }

    private func purgeExpiredLocked() {
        let now = clock.now
        records = records.filter { record, _ in now < record.envelope.deadline }
    }
}
