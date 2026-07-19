import BigInt
import Foundation

public struct AccountState: Equatable {
    public let accountNumber: UInt64?
    public let sequence: UInt64?
    public let balances: [Denom: BigUInt]
    public let acceptedHeight: Int64
    public let fetchedAt: Date
    public let providerFamilyId: String
    public let exists: Bool

    init(
        accountNumber: UInt64?,
        sequence: UInt64?,
        balances: [Denom: BigUInt],
        acceptedHeight: Int64,
        fetchedAt: Date,
        providerFamilyId: String,
        exists: Bool
    ) throws {
        guard (accountNumber != nil) == exists,
              (sequence != nil) == exists,
              exists || balances.isEmpty
        else {
            throw AccountStateError.invalidExistence
        }
        self.accountNumber = accountNumber
        self.sequence = sequence
        self.balances = balances
        self.acceptedHeight = acceptedHeight
        self.fetchedAt = fetchedAt
        self.providerFamilyId = providerFamilyId
        self.exists = exists
    }
}

enum AccountStateError: Error {
    case invalidExistence
}
