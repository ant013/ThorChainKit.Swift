import Foundation
import GRDB

final class TransactionStorage {
    private let dbPool: DatabasePool

    convenience init(databaseDirectoryUrl: URL, databaseFileName: String) throws {
        let databaseURL = databaseDirectoryUrl.appendingPathComponent("\(databaseFileName).sqlite")
        try self.init(path: databaseURL.path)
    }

    init(path: String) throws {
        dbPool = try DatabasePool(path: path)
        try migrator.migrate(dbPool)
    }

    func read<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbPool.read(updates)
    }

    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbPool.write(updates)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v2-send-reservations") { db in
            try db.create(table: "send_sequence_reservations") { table in
                table.column("persistence_namespace", .text).notNull()
                table.column("sender_payload", .blob).notNull()
                table.column("sequence", .integer).notNull()
                table.column("owner_token", .blob).notNull()
                table.primaryKey(["persistence_namespace", "sender_payload", "sequence"])
            }
        }

        migrator.registerMigration("v3-send-journal") { db in
            try db.alter(table: "send_sequence_reservations") { table in
                table.add(column: "local_hash", .text)
            }
            try db.create(table: "send_journal") { table in
                table.column("persistence_namespace", .text).notNull()
                table.column("local_hash", .text).notNull()
                table.column("signed_tx_raw", .blob).notNull()
                table.column("sender_payload", .blob).notNull()
                table.column("recipient_payload", .blob).notNull()
                table.column("sender", .text).notNull()
                table.column("recipient", .text).notNull()
                table.column("amount", .text).notNull()
                table.column("quoted_native_fee", .text).notNull()
                table.column("memo", .text)
                table.column("account_number", .text).notNull()
                table.column("sequence", .text).notNull()
                table.column("provider_family_id", .text).notNull()
                table.column("quote_height", .text).notNull()
                table.column("state", .text).notNull()
                table.column("broadcast_generation", .integer).notNull()
                table.column("retry_blocked_reason", .text)
                table.column("check_tx_code", .integer)
                table.column("codespace", .text)
                table.column("sanitized_log", .text)
                table.column("created_at", .datetime).notNull()
                table.column("updated_at", .datetime).notNull()
                table.primaryKey(["persistence_namespace", "local_hash"])
            }
        }

        return migrator
    }
}
