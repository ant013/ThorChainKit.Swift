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
        return migrator
    }
}
