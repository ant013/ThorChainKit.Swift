import Foundation
import XCTest
@testable import ThorChainKit

final class PendingTransactionRepositoryTests: XCTestCase {
    func testUnknownJournalProjectsAsAvailableAndTerminalAcceptedIsNotApplicable() throws {
        let fixture = try makeJournal()
        let repository = PendingTransactionRepository(journal: fixture.journal)
        guard case .ready = repository.refresh() else {
            return XCTFail("valid journal must publish a ready snapshot")
        }
        XCTAssertEqual(repository.snapshot.count, 1)
        guard case .available = repository.snapshot[0].retryAvailability else {
            return XCTFail("unknown journal rows must be retryable")
        }

        XCTAssertTrue(try fixture.journal.transition(
            transactionID: fixture.transaction.transactionID,
            from: .unknown,
            expectedGeneration: 0,
            to: .checkTxAccepted,
            generation: 1
        ))
        guard case .ready = repository.refresh() else {
            return XCTFail("accepted journal must publish a ready snapshot")
        }
        guard case .notApplicable = repository.snapshot[0].retryAvailability else {
            return XCTFail("accepted rows must not be retryable")
        }
    }

    func testRefreshFailurePreservesLastSnapshotAsDegraded() throws {
        let fixture = try makeJournal()
        let repository = PendingTransactionRepository(journal: fixture.journal)
        XCTAssertEqual(repository.refresh(), .ready)
        try fixture.database.pool.write { db in
            try db.execute(sql: "DROP TABLE send_journal")
        }

        guard case .degraded = repository.refresh() else {
            return XCTFail("observation failure must install degraded status")
        }
        XCTAssertEqual(repository.snapshot.count, 1)
    }

    private func makeJournal() throws -> RepositoryFixture {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("pending-\(UUID().uuidString).sqlite")
        let database = try DatabaseRuntime.open(path: path.path)
        let namespace = "pending-\(UUID().uuidString)"
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let owner = Data([2, 3, 4])
        let reservations = SequenceReservationStore(writer: database.pool)
        XCTAssertTrue(try reservations.acquire(
            SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 3),
            ownerToken: owner
        ))
        let raw = Data([0x31, 0x32])
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
            sequence: 3,
            providerFamilyID: "fixture",
            quoteHeight: 12,
            reservationOwnerToken: owner
        )
        XCTAssertTrue(try journal.transition(
            transactionID: transaction.transactionID,
            from: .broadcasting,
            expectedGeneration: 1,
            to: .unknown,
            generation: 0
        ))
        return RepositoryFixture(database: database, journal: journal, transaction: transaction)
    }
}

private struct RepositoryFixture {
    let database: DatabaseRuntime
    let journal: SendJournal
    let transaction: SignedTransaction
}
