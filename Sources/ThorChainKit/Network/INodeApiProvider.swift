import Foundation

protocol INodeApiProvider: Sendable {
    func account(address: Address, using lease: EndpointLease) async throws -> AccountTransport?
    func balances(address: Address, using lease: EndpointLease) async throws -> [BalanceTransport]
}
