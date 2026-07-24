import Foundation
import XCTest
@testable import ThorChainKit

final class SendJournalOrderingTests: XCTestCase {
    func testReservationLinkCommitsAtomically() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: path) }
        let database = try DatabaseRuntime.open(path: path.path)
        let namespace = "journal-test"
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let owner = Data([1, 2, 3])
        let key = SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 7)
        let reservations = SequenceReservationStore(writer: database.pool)
        XCTAssertTrue(try reservations.acquire(key, ownerToken: owner))

        let raw = Data([0x01, 0x02, 0x03])
        let transaction = SignedTransaction(txRaw: raw, transactionID: DirectSignCodec.transactionId(txRaw: raw))
        let journal = SendJournal(writer: database.pool, persistenceNamespace: namespace)
        try journal.insertBroadcasting(
            transaction: transaction,
            senderPayload: sender.payload,
            recipientPayload: recipient.payload,
            sender: sender.raw,
            recipient: recipient.raw,
            amount: Data([5]),
            quotedNativeFee: Data([1]),
            memo: nil,
            accountNumber: 1,
            sequence: 7,
            providerFamilyID: "fixture",
            quoteHeight: 12,
            reservationOwnerToken: owner
        )

        let record = try XCTUnwrap(journal.record(for: transaction.transactionID))
        XCTAssertEqual(record.state, .broadcasting)
        XCTAssertEqual(record.signedTxRaw, raw)
        let linkedHash: String? = try database.pool.read { db in
            try String.fetchOne(db, sql: "SELECT local_hash FROM send_sequence_reservations WHERE persistence_namespace = ? AND sequence = ?", arguments: [namespace, 7])
        }
        XCTAssertEqual(linkedHash, transaction.transactionID.hash)
    }

    func testFailedReservationLinkRollsBackJournalInsert() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("journal-(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: path) }
        let database = try DatabaseRuntime.open(path: path.path)
        let namespace = "journal-rollback-test"
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let reservationOwner = Data([1])
        let wrongOwner = Data([2])
        let reservations = SequenceReservationStore(writer: database.pool)
        let key = SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 8)
        XCTAssertTrue(try reservations.acquire(key, ownerToken: reservationOwner))

        let transaction = SignedTransaction(txRaw: Data([4, 5, 6]), transactionID: DirectSignCodec.transactionId(txRaw: Data([4, 5, 6])))
        let journal = SendJournal(writer: database.pool, persistenceNamespace: namespace)
        XCTAssertThrowsError(try journal.insertBroadcasting(
            transaction: transaction,
            senderPayload: sender.payload,
            recipientPayload: recipient.payload,
            sender: sender.raw,
            recipient: recipient.raw,
            amount: Data([5]),
            quotedNativeFee: Data([1]),
            memo: nil,
            accountNumber: 1,
            sequence: 8,
            providerFamilyID: "fixture",
            quoteHeight: 12,
            reservationOwnerToken: wrongOwner
        ))
        XCTAssertNil(try journal.record(for: transaction.transactionID))
    }
}
