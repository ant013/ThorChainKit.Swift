import Foundation

enum SendCoordinatorResult: Sendable {
    case handoff(SendAttemptHandoff)
    case failure(SendError)
    case repairPending(RepairIntent)
}

struct RepairIntent: Sendable, Equatable {
    let accountGate: AccountGate
    let persistenceNamespace: String
    let sequence: UInt64
    let reservationOwnerToken: Data
    let operationHold: OperationHold
}
