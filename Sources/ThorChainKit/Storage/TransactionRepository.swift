import BigInt
import Foundation
import GRDB

struct TransactionSyncCursor: Equatable, Sendable {
    let lastTimestamp: Int64
    let backfillPageToken: String?
}

/// The persisted source for the Midgard transaction projection and its cursor.
/// Keeping the watermark and continuation token in this repository prevents one
/// write from accidentally discarding the other.
final class TransactionRepository: @unchecked Sendable {
    private let storage: TransactionStorage
    private let persistenceNamespace: String

    init(storage: TransactionStorage, persistenceNamespace: String) {
        self.storage = storage
        self.persistenceNamespace = persistenceNamespace
    }

    func transactions(hash: String? = nil, descending: Bool = true, limit: Int? = nil) throws -> [Transaction] {
        guard limit.map({ $0 > 0 }) ?? true else { return [] }
        return try storage.read { db in
            var sql = "SELECT tx_hash, block_height, timestamp, type, status, memo, incoming, outgoing FROM transactions WHERE persistence_namespace = ?"
            var arguments: [any DatabaseValueConvertible] = [persistenceNamespace]
            if let hash {
                sql += " AND tx_hash = ?"
                arguments.append(hash)
            }
            let order = descending ? "DESC" : "ASC"
            sql += " ORDER BY timestamp \(order), tx_hash \(order)"
            if let limit {
                sql += " LIMIT \(limit)"
            }
            return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments)).map(Self.transaction)
        }
    }

    func pendingTransactions() throws -> [Transaction] {
        try storage.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT tx_hash, block_height, timestamp, type, status, memo, incoming, outgoing FROM transactions WHERE persistence_namespace = ? AND status = ? ORDER BY timestamp DESC, tx_hash DESC",
                arguments: [persistenceNamespace, "pending"]
            ).map(Self.transaction)
        }
    }

    func save(_ transactions: [Transaction]) throws {
        guard !transactions.isEmpty else { return }
        try storage.write { db in
            try save(transactions, in: db)
        }
    }

    func save(_ transactions: [Transaction], in db: Database) throws {
        for transaction in transactions {
            try db.execute(
                    sql: """
                    INSERT INTO transactions
                    (persistence_namespace, tx_hash, block_height, timestamp, type, status, memo, incoming, outgoing)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(persistence_namespace, tx_hash) DO UPDATE SET
                        block_height = excluded.block_height,
                        timestamp = excluded.timestamp,
                        type = excluded.type,
                        status = excluded.status,
                        memo = excluded.memo,
                        incoming = excluded.incoming,
                        outgoing = excluded.outgoing
                    """,
                    arguments: [
                        persistenceNamespace,
                        transaction.transactionId.hash,
                        transaction.blockHeight,
                        Int64(transaction.timestamp.timeIntervalSince1970),
                        transaction.type,
                        transaction.status,
                        transaction.memo,
                        try Self.transferData(transaction.incoming),
                        try Self.transferData(transaction.outgoing),
                    ]
            )
        }
    }

    func cursor() throws -> TransactionSyncCursor {
        try storage.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT last_timestamp, backfill_page_token FROM transaction_sync_state WHERE persistence_namespace = ?",
                arguments: [persistenceNamespace]
            ) else {
                return TransactionSyncCursor(lastTimestamp: 0, backfillPageToken: nil)
            }
            guard let timestamp: Int64 = row["last_timestamp"], timestamp >= 0 else { throw StorageError.invalid }
            return TransactionSyncCursor(lastTimestamp: timestamp, backfillPageToken: row["backfill_page_token"])
        }
    }

    func save(lastTimestamp: Int64) throws {
        guard lastTimestamp >= 0 else { throw StorageError.invalid }
        try storage.write { db in
            let current = try Self.cursor(db: db, namespace: persistenceNamespace)
            try db.execute(
                sql: "INSERT OR REPLACE INTO transaction_sync_state (persistence_namespace, last_timestamp, backfill_page_token) VALUES (?, ?, ?)",
                arguments: [persistenceNamespace, lastTimestamp, current.backfillPageToken]
            )
        }
    }

    func save(backfillPageToken: String?) throws {
        try storage.write { db in
            let current = try Self.cursor(db: db, namespace: persistenceNamespace)
            try db.execute(
                sql: "INSERT OR REPLACE INTO transaction_sync_state (persistence_namespace, last_timestamp, backfill_page_token) VALUES (?, ?, ?)",
                arguments: [persistenceNamespace, current.lastTimestamp, backfillPageToken]
            )
        }
    }

    private static func cursor(db: Database, namespace: String) throws -> TransactionSyncCursor {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT last_timestamp, backfill_page_token FROM transaction_sync_state WHERE persistence_namespace = ?",
            arguments: [namespace]
        ) else {
            return TransactionSyncCursor(lastTimestamp: 0, backfillPageToken: nil)
        }
        guard let timestamp: Int64 = row["last_timestamp"], timestamp >= 0 else { throw StorageError.invalid }
        return TransactionSyncCursor(lastTimestamp: timestamp, backfillPageToken: row["backfill_page_token"])
    }

    private static func transaction(_ row: Row) throws -> Transaction {
        guard let hash: String = row["tx_hash"], let transactionId = TransactionID(hash: hash),
              let height: Int64 = row["block_height"], height >= 0,
              let timestamp: Int64 = row["timestamp"], timestamp >= 0,
              let type: String = row["type"], !type.isEmpty,
              let status: String = row["status"], !status.isEmpty,
              let incoming: Data = row["incoming"],
              let outgoing: Data = row["outgoing"]
        else {
            throw StorageError.invalid
        }
        return Transaction(
            transactionId: transactionId,
            blockHeight: height,
            timestamp: Date(timeIntervalSince1970: TimeInterval(timestamp)),
            type: type,
            status: status,
            memo: row["memo"],
            incoming: try transfers(incoming),
            outgoing: try transfers(outgoing)
        )
    }

    private static func transferData(_ transfers: [CoinTransfer]) throws -> Data {
        try JSONEncoder().encode(transfers.map(PersistedTransfer.init))
    }

    private static func transfers(_ data: Data) throws -> [CoinTransfer] {
        try JSONDecoder().decode([PersistedTransfer].self, from: data).map { transfer in
            guard let amount = BigUInt(transfer.amount), !transfer.address.isEmpty, !transfer.asset.isEmpty else {
                throw StorageError.invalid
            }
            return CoinTransfer(address: transfer.address, asset: transfer.asset, amount: amount)
        }
    }
}

private struct PersistedTransfer: Codable {
    let address: String
    let asset: String
    let amount: String

    init(_ transfer: CoinTransfer) {
        address = transfer.address
        asset = transfer.asset
        amount = transfer.amount.description
    }
}
