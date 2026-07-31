import Foundation
import GRDB

struct SequenceReservationKey: Hashable, Sendable {
    let persistenceNamespace: String
    let senderPayload: Data
    let sequence: UInt64
}

protocol ISequenceReservationManager: Sendable {
    func acquire(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool
    func release(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool
}

final class SequenceReservationStore: ISequenceReservationManager, @unchecked Sendable {
    private let storage: TransactionStorage

    init(storage: TransactionStorage) {
        self.storage = storage
    }

    func acquire(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool {
        guard !ownerToken.isEmpty, key.sequence <= UInt64(Int64.max) else { return false }
        do {
            try storage.write { db in
                try db.execute(
                    sql: "INSERT INTO send_sequence_reservations (persistence_namespace, sender_payload, sequence, owner_token) VALUES (?, ?, ?, ?)",
                    arguments: [key.persistenceNamespace, key.senderPayload, Int64(key.sequence), ownerToken]
                )
            }
            return true
        } catch {
            return false
        }
    }

    func release(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool {
        var released = false
        try storage.write { db in
            try db.execute(
                sql: "DELETE FROM send_sequence_reservations WHERE persistence_namespace = ? AND sender_payload = ? AND sequence = ? AND owner_token = ?",
                arguments: [key.persistenceNamespace, key.senderPayload, Int64(key.sequence), ownerToken]
            )
            released = db.changesCount > 0
        }
        return released
    }
}
