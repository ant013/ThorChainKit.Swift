import Foundation

struct AccountTransport: Equatable, Sendable {
    let accountNumber: UInt64
    let sequence: UInt64
}

struct BalanceTransport: Equatable, Sendable {
    let denom: Denom
    let amountDecimal: String
}

struct AccountReadTransport: Equatable, Sendable {
    let acceptedHeight: Int64
    let account: AccountTransport?
    let balances: [BalanceTransport]
    let familyId: String
    let observedAt: Date

    init(
        acceptedHeight: Int64,
        account: AccountTransport?,
        balances: [BalanceTransport],
        familyId: String,
        observedAt: Date
    ) throws {
        guard acceptedHeight > 0, account != nil || balances.isEmpty else {
            throw ThorNodeReadError.invalidAccount
        }
        let denominations = balances.map { $0.denom.rawValue }
        guard Set(denominations).count == denominations.count else {
            throw ThorNodeReadError.duplicateDenom(denominations.first ?? "")
        }
        self.acceptedHeight = acceptedHeight
        self.account = account
        self.balances = balances
        self.familyId = familyId
        self.observedAt = observedAt
    }
}

protocol AccountReading: Sendable {
    func read(address: Address) async throws -> AccountReadTransport
}
