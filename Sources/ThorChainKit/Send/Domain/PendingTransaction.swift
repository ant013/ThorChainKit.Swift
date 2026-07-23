import BigInt
import Foundation

public struct PendingTransaction: Sendable, CustomDebugStringConvertible, CustomReflectable {
    public enum State: Sendable { case checkTxAccepted, unknown }
    public enum RetryAvailability: Sendable { case available, inFlight, sequenceAdvanced, providerInconsistent, notApplicable }

    public let transactionId: TransactionID
    public let recipient: Address
    public var amount: BigUInt { magnitude(amountMagnitude) }
    public var nativeFee: BigUInt { magnitude(nativeFeeMagnitude) }
    public let memo: String?
    public let state: State
    public let retryAvailability: RetryAvailability
    public let createdAt: Date

    private let amountMagnitude: Data
    private let nativeFeeMagnitude: Data

    internal init(
        transactionId: TransactionID,
        recipient: Address,
        amountMagnitude: Data,
        nativeFeeMagnitude: Data,
        memo: String?,
        state: State,
        retryAvailability: RetryAvailability,
        createdAt: Date
    ) {
        self.transactionId = transactionId
        self.recipient = recipient
        self.amountMagnitude = amountMagnitude
        self.nativeFeeMagnitude = nativeFeeMagnitude
        self.memo = memo
        self.state = state
        self.retryAvailability = retryAvailability
        self.createdAt = createdAt
    }

    public var debugDescription: String {
        "PendingTransaction(transactionId: \(transactionId.hash), recipient: \(recipient.raw), amount: \(amount), nativeFee: \(nativeFee), memo: \(memo ?? "nil"), createdAt: \(createdAt.timeIntervalSince1970))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "transactionId": transactionId.hash,
            "recipient": recipient.raw,
            "amount": amount,
            "nativeFee": nativeFee,
            "memo": memo as Any,
            "state": state,
            "retryAvailability": retryAvailability,
            "createdAt": createdAt
        ], displayStyle: .struct)
    }
}

public enum PendingTransactionsStatus: Sendable { case ready, degraded }

private func magnitude(_ data: Data) -> BigUInt {
    data.isEmpty ? 0 : BigUInt(data)
}
