import GRDB

enum ThorChainMigrations {
    static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "sync_control") { table in
                table.column("storage_key", .text).primaryKey()
                table.column("generation", .integer).notNull()
            }
            try db.create(table: "account_state") { table in
                table.column("storage_key", .text).primaryKey()
                table.column("network_chain_id", .text).notNull()
                table.column("address", .text).notNull()
                table.column("account_exists", .boolean).notNull()
                table.column("account_number", .integer)
                table.column("sequence", .integer)
                table.column("accepted_height", .integer).notNull()
                table.column("fetched_at", .datetime).notNull()
                table.column("provider_family_id", .text).notNull()
            }
            try db.create(table: "balances") { table in
                table.column("storage_key", .text).notNull()
                table.column("denom", .text).notNull()
                table.column("amount_decimal_string", .text).notNull()
                table.primaryKey(["storage_key", "denom"])
            }
        }
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
