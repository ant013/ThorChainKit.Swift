import Foundation
import XCTest
@testable import ThorChainKit

final class SendJournalRestartTests: XCTestCase {
    func testSeedBroadcastingForRestart() throws {
        let path = restartPath()
        let database = try DatabaseRuntime.open(path: path)
        let namespace = "restart-process"
        let journal = SendJournal(writer: database.pool, persistenceNamespace: namespace)
        try seedBroadcasting(
            journal: journal,
            reservations: SequenceReservationStore(writer: database.pool),
            namespace: namespace
        )
        guard let state = try journal.pendingRecords().first?.state else {
            return XCTFail("seed journal row is missing")
        }
        guard case .broadcasting = state else {
            return XCTFail("seed journal row must be broadcasting")
        }
    }

    func testSeparateProcessRecoversBroadcastingAsUnknown() throws {
        let path = restartPath()
        let database = try DatabaseRuntime.open(path: path)
        let namespace = "restart-process"
        if try SendJournal(writer: database.pool, persistenceNamespace: namespace).pendingRecords().isEmpty {
            try seedBroadcasting(
                journal: SendJournal(writer: database.pool, persistenceNamespace: namespace),
                reservations: SequenceReservationStore(writer: database.pool),
                namespace: namespace
            )
        }
        let sender = try sendTestAddress()
        let runtime = SendRuntime(
            address: sender,
            persistenceNamespace: namespace,
            runtimeIdentifier: "restart-process-runtime",
            databaseWriter: database.pool
        )
        _ = runtime
        let records = try SendJournal(writer: database.pool, persistenceNamespace: namespace).pendingRecords()
        XCTAssertEqual(records.count, 1)
        guard case .unknown = records[0].state else {
            return XCTFail("restart must normalize broadcasting to unknown")
        }
        XCTAssertEqual(records[0].transactionID.hash.count, 64)
    }

    private func restartPath() -> String {
        if let configured = ProcessInfo.processInfo.environment["THR_S205_RESTART_DB"], !configured.isEmpty {
            return configured
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("restart-\(UUID().uuidString).sqlite").path
    }

    private func seedBroadcasting(
        journal: SendJournal,
        reservations: SequenceReservationStore,
        namespace: String
    ) throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let owner = Data([4, 5, 6])
        XCTAssertTrue(try reservations.acquire(
            SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 5),
            ownerToken: owner
        ))
        let raw = Data([0x51, 0x52])
        let transaction = SignedTransaction(txRaw: raw, transactionID: DirectSignCodec.transactionId(txRaw: raw))
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
            sequence: 5,
            providerFamilyID: "fixture",
            quoteHeight: 12,
            reservationOwnerToken: owner
        )
    }
}
