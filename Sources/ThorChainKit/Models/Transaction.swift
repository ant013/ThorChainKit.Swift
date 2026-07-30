import BigInt
import Foundation

/// A transfer represented by one side of a Midgard action. Addresses and assets
/// stay strings because an action may include an external-chain asset/address.
public struct CoinTransfer: Equatable, Sendable {
    public let address: String
    public let asset: String
    public let amount: BigUInt

    init(address: String, asset: String, amount: BigUInt) {
        self.address = address
        self.asset = asset
        self.amount = amount
    }
}

/// A normalized THORChain action returned by Midgard. Local broadcast state
/// remains exposed separately as `PendingTransaction` until this action proves
/// inclusion of the same hash.
public struct Transaction: Equatable, Sendable {
    public let transactionId: TransactionID
    public let blockHeight: Int64
    public let timestamp: Date
    public let type: String
    public let status: String
    public let memo: String?
    public let incoming: [CoinTransfer]
    public let outgoing: [CoinTransfer]

    public var isPending: Bool { status == "pending" }
    /// Midgard currently documents `success` and `refund` as finalized action
    /// statuses. An unknown future status remains visible but never proves that
    /// a locally broadcast transaction can be removed.
    var isTerminal: Bool { ["success", "refund"].contains(status) }

    init(
        transactionId: TransactionID,
        blockHeight: Int64,
        timestamp: Date,
        type: String,
        status: String,
        memo: String?,
        incoming: [CoinTransfer],
        outgoing: [CoinTransfer]
    ) {
        self.transactionId = transactionId
        self.blockHeight = blockHeight
        self.timestamp = timestamp
        self.type = type
        self.status = status
        self.memo = memo
        self.incoming = incoming
        self.outgoing = outgoing
    }
}

public enum TransactionSyncState: Equatable, Sendable {
    case notSynced
    case syncing
    case synced
    case failed
}
