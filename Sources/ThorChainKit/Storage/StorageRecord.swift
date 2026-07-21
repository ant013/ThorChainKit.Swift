import BigInt
import Foundation

struct StorageKey: Hashable, Sendable {
    let rawValue: String

    init(persistenceNamespace: String) {
        rawValue = persistenceNamespace
    }
}

struct StoredBalance: Equatable, Sendable {
    let denom: String
    let amountDecimalString: String
}

struct StorageRecord: Equatable, Sendable {
    let storageKey: StorageKey
    let address: String
    let networkChainId: String
    let accountExists: Bool
    let accountNumber: UInt64?
    let sequence: UInt64?
    let acceptedHeight: Int64
    let fetchedAt: Date
    let providerFamilyId: String
    let balances: [StoredBalance]

    init(
        storageKey: StorageKey,
        address: String,
        networkChainId: String,
        accountExists: Bool,
        accountNumber: UInt64?,
        sequence: UInt64?,
        acceptedHeight: Int64,
        fetchedAt: Date,
        providerFamilyId: String,
        balances: [StoredBalance]
    ) throws {
        guard !address.isEmpty, !networkChainId.isEmpty,
              acceptedHeight > 0, !providerFamilyId.isEmpty,
              (accountNumber != nil) == accountExists,
              (sequence != nil) == accountExists,
              accountExists || balances.isEmpty,
              Set(balances.map(\.denom)).count == balances.count
        else { throw StorageRecordError.invalid }

        for balance in balances {
            guard (try? Denom(rawValue: balance.denom)) != nil,
                  let amount = BigUInt(balance.amountDecimalString, radix: 10),
                  amount < (BigUInt(1) << 256),
                  String(amount) == balance.amountDecimalString
            else { throw StorageRecordError.invalid }
        }
        self.storageKey = storageKey
        self.address = address
        self.networkChainId = networkChainId
        self.accountExists = accountExists
        self.accountNumber = accountNumber
        self.sequence = sequence
        self.acceptedHeight = acceptedHeight
        self.fetchedAt = fetchedAt
        self.providerFamilyId = providerFamilyId
        self.balances = balances
    }

    init(read: AccountReadTransport, address: Address, storageKey: StorageKey) throws {
        try self.init(
            storageKey: storageKey,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            accountExists: read.account != nil,
            accountNumber: read.account?.accountNumber,
            sequence: read.account?.sequence,
            acceptedHeight: read.acceptedHeight,
            fetchedAt: read.observedAt,
            providerFamilyId: read.familyId,
            balances: read.balances.map {
                StoredBalance(denom: $0.denom.rawValue, amountDecimalString: $0.amountDecimal)
            }
        )
    }

    func accountState() throws -> AccountState {
        var values = [Denom: BigUInt]()
        for balance in balances {
            values[try Denom(rawValue: balance.denom)] = BigUInt(balance.amountDecimalString, radix: 10)!
        }
        return try AccountState(
            accountNumber: accountNumber,
            sequence: sequence,
            balances: values,
            acceptedHeight: acceptedHeight,
            fetchedAt: fetchedAt,
            providerFamilyId: providerFamilyId,
            exists: accountExists
        )
    }

    func validate() throws {
        _ = try StorageRecord(
            storageKey: storageKey,
            address: address,
            networkChainId: networkChainId,
            accountExists: accountExists,
            accountNumber: accountNumber,
            sequence: sequence,
            acceptedHeight: acceptedHeight,
            fetchedAt: fetchedAt,
            providerFamilyId: providerFamilyId,
            balances: balances
        )
    }
}

enum StorageRecordError: Error, Equatable {
    case invalid
    case identityMismatch
}
