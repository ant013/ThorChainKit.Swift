import BigInt
import Foundation

/// A transfer represented by one side of a Midgard action. Addresses and assets
/// stay strings because an action may include an external-chain asset/address.
public struct CoinTransfer: Equatable, Sendable {
    public let address: String
    public let asset: String
    public let amount: BigUInt

    public init(address: String, asset: String, amount: BigUInt) {
        self.address = address
        self.asset = asset
        self.amount = amount
    }
}

/// A normalized THORChain transaction for history. It represents either a
/// locally broadcast send or a Midgard action that confirms the same hash.
/// `PendingTransaction` separately keeps the send retry lifecycle.
public struct Transaction: Equatable, Sendable {
    public let transactionId: TransactionID
    public let blockHeight: Int64
    public let timestamp: Date
    /// Raw Midgard timestamp. `Date` is for presentation; this value preserves
    /// the provider ordering used by the history cursor.
    let timestampNanoseconds: Int64
    public let type: String
    public let status: String
    public let memo: String?
    public let incoming: [CoinTransfer]
    public let outgoing: [CoinTransfer]
    /// Network fee in RUNE base units. Always RUNE whatever asset was sent, so it
    /// needs no denomination of its own. Nil when the provider did not report one.
    public let fee: BigUInt?

    public var isPending: Bool { status == "pending" }
    /// Midgard currently documents `success` and `refund` as finalized action
    /// statuses. An unknown future status remains visible but never proves that
    /// a locally broadcast transaction can be removed.
    var isTerminal: Bool { ["success", "refund"].contains(status) }

    public init(
        transactionId: TransactionID,
        blockHeight: Int64,
        timestamp: Date,
        timestampNanoseconds: Int64? = nil,
        type: String,
        status: String,
        memo: String?,
        incoming: [CoinTransfer],
        outgoing: [CoinTransfer],
        fee: BigUInt? = nil
    ) {
        self.transactionId = transactionId
        self.blockHeight = blockHeight
        self.timestamp = timestamp
        self.timestampNanoseconds = timestampNanoseconds ?? Int64(timestamp.timeIntervalSince1970 * 1_000_000_000)
        self.type = type
        self.status = status
        self.memo = memo
        self.incoming = incoming
        self.outgoing = outgoing
        self.fee = fee
    }
}

public enum TransactionSyncError: Equatable, Sendable {
    case notStarted
    case storageUnavailable
    case providerUnavailable
    case invalidResponse
}

public enum TransactionSyncState: Equatable, Sendable {
    case notSynced(error: TransactionSyncError)
    case syncing
    case synced
}
