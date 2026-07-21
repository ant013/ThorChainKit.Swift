import Foundation
import GRDB

final class GrdbAccountStateStorage: AccountStateStorage {
    private let pool: DatabasePool

    init(path: String) throws {
        pool = try DatabasePool(path: path)
        try ThorChainMigrations.migrator().migrate(pool)
    }

    init(pool: DatabasePool) throws {
        self.pool = pool
        try ThorChainMigrations.migrator().migrate(pool)
    }

    func load(key: StorageKey) async throws -> StorageRecord? {
        try await pool.read { db -> StorageRecord? in
            guard try Row.fetchOne(
                db,
                sql: "SELECT generation FROM sync_control WHERE storage_key = ?",
                arguments: [key.rawValue]
            ) != nil else {
                return nil
            }
            guard let state = try Row.fetchOne(db, sql: "SELECT * FROM account_state WHERE storage_key = ?", arguments: [key.rawValue]) else {
                return nil
            }
            let rows = try Row.fetchAll(db, sql: "SELECT denom, amount_decimal_string FROM balances WHERE storage_key = ? ORDER BY denom", arguments: [key.rawValue])
            let balances = rows.map { StoredBalance(denom: $0["denom"], amountDecimalString: $0["amount_decimal_string"]) }
            let accountNumber = try Self.optionalUInt64(state["account_number"])
            let sequence = try Self.optionalUInt64(state["sequence"])
            return try StorageRecord(
                storageKey: key,
                address: state["address"],
                networkChainId: state["network_chain_id"],
                accountExists: state["account_exists"],
                accountNumber: accountNumber,
                sequence: sequence,
                acceptedHeight: state["accepted_height"],
                fetchedAt: state["fetched_at"],
                providerFamilyId: state["provider_family_id"],
                balances: balances
            )
        }
    }

    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        var next: UInt64 = 0
        try pool.writeInTransaction { db in
            let old: Int64 = try Row.fetchOne(db, sql: "SELECT generation FROM sync_control WHERE storage_key = ?", arguments: [key.rawValue])?["generation"] ?? 0
            guard old >= 0 else { throw StorageRecordError.invalid }
            next = UInt64(old) &+ 1
            try db.execute(sql: "INSERT INTO sync_control (storage_key, generation) VALUES (?, ?) ON CONFLICT(storage_key) DO UPDATE SET generation = excluded.generation", arguments: [key.rawValue, Int64(next)])
            return .commit
        }
        return next
    }

    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        try record.validate()
        guard record.storageKey == key else { throw StorageRecordError.invalid }
        var committed = false
        try pool.writeInTransaction { db in
            let current: Int64? = try Row.fetchOne(db, sql: "SELECT generation FROM sync_control WHERE storage_key = ?", arguments: [key.rawValue])?["generation"]
            guard current == Int64(exactly: expectedGeneration) else { return .rollback }
            try db.execute(sql: "INSERT OR REPLACE INTO account_state (storage_key, network_chain_id, address, account_exists, account_number, sequence, accepted_height, fetched_at, provider_family_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", arguments: [key.rawValue, record.networkChainId, record.address, record.accountExists, record.accountNumber.map(String.init), record.sequence.map(String.init), record.acceptedHeight, record.fetchedAt, record.providerFamilyId])
            try db.execute(sql: "DELETE FROM balances WHERE storage_key = ?", arguments: [key.rawValue])
            for balance in record.balances {
                try db.execute(sql: "INSERT INTO balances (storage_key, denom, amount_decimal_string) VALUES (?, ?, ?)", arguments: [key.rawValue, balance.denom, balance.amountDecimalString])
            }
            committed = true
            return .commit
        }
        return committed
    }

    func clear(key: StorageKey) async throws {
        try pool.writeInTransaction { db in
            try db.execute(sql: "DELETE FROM balances WHERE storage_key = ?", arguments: [key.rawValue])
            try db.execute(sql: "DELETE FROM account_state WHERE storage_key = ?", arguments: [key.rawValue])
            return .commit
        }
    }

    private static func optionalUInt64(_ value: DatabaseValue) throws -> UInt64? {
        switch value.storage {
        case .null:
            return nil
        case let .int64(value):
            guard value >= 0 else { throw StorageRecordError.invalid }
            return UInt64(value)
        case let .string(value):
            guard let result = UInt64(value), String(result) == value else {
                throw StorageRecordError.invalid
            }
            return result
        default:
            throw StorageRecordError.invalid
        }
    }
}
