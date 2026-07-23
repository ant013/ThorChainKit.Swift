import BigInt
import Foundation

struct QuoteAuthorityEnvelope: Equatable, Hashable, Sendable {
    let clientID: UUID
    let generation: UInt64
    let deadline: UInt64
    let token: Data
}

struct QuoteReviewSnapshot: Equatable, Hashable, Sendable {
    let sender: String
    let recipient: String
    let requestedAmountIsMaximum: Bool
    let amountMagnitude: Data
    let nativeFeeMagnitude: Data
    let totalDebitMagnitude: Data
    let memo: String?
    let acceptedHeight: Int64
    let accountNumber: UInt64
    let sequence: UInt64
    let providerFamilyID: String
}

struct QuoteAuthorityRecord: Equatable, Hashable, Sendable {
    let envelope: QuoteAuthorityEnvelope
    let snapshot: QuoteReviewSnapshot
}

public struct SendQuote: Sendable, CustomDebugStringConvertible, CustomReflectable {
    public let recipient: Address
    public var amount: BigUInt { magnitude(amountMagnitude) }
    public let isMaximum: Bool
    public var nativeFee: BigUInt { magnitude(nativeFeeMagnitude) }
    public var totalDebit: BigUInt { magnitude(totalDebitMagnitude) }
    public let memo: String?
    public let acceptedHeight: Int64
    public let expiresAt: Date

    private let amountMagnitude: Data
    private let nativeFeeMagnitude: Data
    private let totalDebitMagnitude: Data
    private let authorityRecord: QuoteAuthorityRecord

    internal init(
        recipient: Address,
        amountMagnitude: Data,
        isMaximum: Bool,
        nativeFeeMagnitude: Data,
        totalDebitMagnitude: Data,
        memo: String?,
        acceptedHeight: Int64,
        expiresAt: Date,
        authorityRecord: QuoteAuthorityRecord
    ) {
        self.recipient = recipient
        self.amountMagnitude = amountMagnitude
        self.isMaximum = isMaximum
        self.nativeFeeMagnitude = nativeFeeMagnitude
        self.totalDebitMagnitude = totalDebitMagnitude
        self.memo = memo
        self.acceptedHeight = acceptedHeight
        self.expiresAt = expiresAt
        self.authorityRecord = authorityRecord
    }

    internal var internalAuthorityRecord: QuoteAuthorityRecord { authorityRecord }

    internal var hasConsistentAuthorityProjection: Bool {
        let snapshot = authorityRecord.snapshot
        return snapshot.recipient == recipient.raw
            && snapshot.requestedAmountIsMaximum == isMaximum
            && snapshot.amountMagnitude == amountMagnitude
            && snapshot.nativeFeeMagnitude == nativeFeeMagnitude
            && snapshot.totalDebitMagnitude == totalDebitMagnitude
            && snapshot.memo == memo
            && snapshot.acceptedHeight == acceptedHeight
    }

    public var debugDescription: String {
        "SendQuote(recipient: \(recipient.raw), amount: \(amount), isMaximum: \(isMaximum), nativeFee: \(nativeFee), totalDebit: \(totalDebit), memo: \(memo ?? "nil"), acceptedHeight: \(acceptedHeight), expiresAt: \(expiresAt.timeIntervalSince1970))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "recipient": recipient.raw,
            "amount": amount,
            "isMaximum": isMaximum,
            "nativeFee": nativeFee,
            "totalDebit": totalDebit,
            "memo": memo as Any,
            "acceptedHeight": acceptedHeight,
            "expiresAt": expiresAt
        ], displayStyle: .struct)
    }
}

private func magnitude(_ data: Data) -> BigUInt {
    data.isEmpty ? 0 : BigUInt(data)
}
