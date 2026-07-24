import Foundation

struct SendAttemptHandoff: Sendable {
    let transaction: SignedTransaction
    let accountGate: AccountGate
    let persistenceNamespace: String
    let sequence: UInt64
    let reservationOwnerToken: Data
    let operationHold: OperationHold
    let runtime: SendRuntime
}

struct OperationHold: Sendable, Equatable {
    let id: UUID
    let accountGate: AccountGate
}

struct AccountGate: Sendable, Equatable {
    let persistenceNamespace: String
    let sender: String
}
