import Foundation

struct SendAttemptHandoff: Sendable {
    let transaction: SignedTransaction
    let accountGate: AccountGate
    let sender: String
    // Empty and nil for a deposit, which has no recipient.
    let recipient: String
    let recipientPayload: Data?
    let amount: Data
    // Carried from the snapshot so the journal records what was actually sent.
    let denom: Denom
    let quotedNativeFee: Data
    let memo: String?
    let accountNumber: UInt64
    let providerFamilyID: String
    let quoteHeight: Int64
    let persistenceNamespace: String
    let sequence: UInt64
    let reservationOwnerToken: Data
    let operationHold: OperationHold
    let runtime: TransactionSender
}

struct OperationHold: Sendable, Equatable {
    let id: UUID
    let accountGate: AccountGate
}

struct AccountGate: Sendable, Equatable {
    let persistenceNamespace: String
    let sender: String
}
