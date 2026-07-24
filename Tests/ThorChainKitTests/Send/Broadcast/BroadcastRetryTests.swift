import Foundation
import XCTest
@testable import ThorChainKit

final class BroadcastRetryTests: XCTestCase {
    func testRetryUsesByteIdenticalTxRawWithoutSignerOrCodec() async throws {
        let fixture = try makeUnknownRecord(namespace: "retry-bytes-\(UUID().uuidString)")
        let capture = RetryCapture()
        let events = RetryEvents()
        let runtime = SendRuntime(
            address: fixture.sender,
            persistenceNamespace: fixture.namespace,
            runtimeIdentifier: fixture.namespace,
            databaseWriter: fixture.database.pool,
            broadcastOperation: { transaction in
                capture.append(transaction.txRaw)
                return BroadcastResponse(txHash: transaction.transactionID.hash, code: 0, codespace: nil, sanitizedLog: nil)
            },
            lookupOperation: { _ in .notFound },
            retryObservability: SendRetryObservability { events.append($0) }
        )
        await runtime.activate(generation: 1)

        let submission = try await runtime.retryBroadcast(transactionId: fixture.transaction.transactionID, acceptingNativeFee: Data([1]))

        guard case .checkTxAccepted = submission.state else {
            return XCTFail("matching CheckTx response must terminalize as accepted")
        }
        XCTAssertEqual(capture.raws, [fixture.raw])
        XCTAssertEqual(events.values, [.operationHoldAcquired, .journalRead, .retryCAS, .publicationWait, .lookup, .broadcast, .operationHoldReleased])
    }

    func testSequenceAdvancedBlocksBeforeAnyIOAndSurvivesRestart() async throws {
        let fixture = try makeUnknownRecord(namespace: "retry-sequence-\(UUID().uuidString)")
        XCTAssertTrue(try fixture.journal.transition(
            transactionID: fixture.transaction.transactionID,
            from: .unknown,
            expectedGeneration: 0,
            to: .unknown,
            generation: 0,
            blockedReason: .sequenceAdvanced
        ))

        let firstCapture = RetryCapture()
        let firstEvents = RetryEvents()
        let firstRuntime = SendRuntime(
            address: fixture.sender,
            persistenceNamespace: fixture.namespace,
            runtimeIdentifier: fixture.namespace,
            databaseWriter: fixture.database.pool,
            broadcastOperation: { transaction in
                firstCapture.append(transaction.txRaw)
                return BroadcastResponse(txHash: transaction.transactionID.hash, code: 0, codespace: nil, sanitizedLog: nil)
            },
            lookupOperation: { _ in
                firstCapture.lookupCalls += 1
                return .notFound
            },
            retryObservability: SendRetryObservability { firstEvents.append($0) }
        )
        await firstRuntime.activate(generation: 1)
        do {
            _ = try await firstRuntime.retryBroadcast(transactionId: fixture.transaction.transactionID, acceptingNativeFee: Data([1]))
            XCTFail("sequence-advanced retry must be blocked")
        } catch let error as SendError {
            XCTAssertEqual(error, .retryBlocked(.sequenceAdvanced))
        }
        XCTAssertEqual(firstCapture.lookupCalls, 0)
        XCTAssertEqual(firstCapture.raws, [])
        XCTAssertEqual(firstEvents.values, [.operationHoldAcquired, .journalRead, .operationHoldReleased])

        let secondCapture = RetryCapture()
        let secondEvents = RetryEvents()
        let secondRuntime = SendRuntime(
            address: fixture.sender,
            persistenceNamespace: fixture.namespace,
            runtimeIdentifier: fixture.namespace,
            databaseWriter: fixture.database.pool,
            broadcastOperation: { transaction in
                secondCapture.append(transaction.txRaw)
                return BroadcastResponse(txHash: transaction.transactionID.hash, code: 0, codespace: nil, sanitizedLog: nil)
            },
            lookupOperation: { _ in
                secondCapture.lookupCalls += 1
                return .notFound
            },
            retryObservability: SendRetryObservability { secondEvents.append($0) }
        )
        await secondRuntime.activate(generation: 1)
        do {
            _ = try await secondRuntime.retryBroadcast(transactionId: fixture.transaction.transactionID, acceptingNativeFee: Data([1]))
            XCTFail("persisted sequence-advanced retry must remain blocked")
        } catch let error as SendError {
            XCTAssertEqual(error, .retryBlocked(.sequenceAdvanced))
        }
        XCTAssertEqual(secondCapture.lookupCalls, 0)
        XCTAssertEqual(secondCapture.raws, [])
        XCTAssertEqual(secondEvents.values, [.operationHoldAcquired, .journalRead, .operationHoldReleased])
        XCTAssertEqual(try fixture.journal.record(for: fixture.transaction.transactionID)?.retryBlockedReason, .sequenceAdvanced)
    }

    func testUnapprovedProductionFamilyIsUnavailableWithoutIO() async throws {
        let fixture = try makeUnknownRecord(namespace: "retry-unavailable-\(UUID().uuidString)")
        let capture = RetryCapture()
        let events = RetryEvents()
        let runtime = SendRuntime(
            address: fixture.sender,
            persistenceNamespace: fixture.namespace,
            runtimeIdentifier: fixture.namespace,
            databaseWriter: fixture.database.pool,
            retryObservability: SendRetryObservability { events.append($0) }
        )
        await runtime.activate(generation: 1)

        do {
            _ = try await runtime.retryBroadcast(transactionId: fixture.transaction.transactionID, acceptingNativeFee: Data([1]))
            XCTFail("unapproved production retry must be unavailable")
        } catch let error as SendError {
            XCTAssertEqual(error, .operationUnavailable)
        }
        XCTAssertEqual(capture.lookupCalls, 0)
        XCTAssertEqual(capture.raws, [])
        XCTAssertEqual(events.values, [.operationHoldAcquired, .journalRead, .operationHoldReleased])
    }

    func testPublicationFailureNormalizesBeforeAnyEndpointIO() async throws {
        let fixture = try makeUnknownRecord(namespace: "retry-publication-\(UUID().uuidString)")
        let barrier = PendingPublicationBarrier()
        barrier.fail(transactionID: fixture.transaction.transactionID, generation: 1)
        let capture = RetryCapture()
        let runtime = SendRuntime(
            address: fixture.sender,
            persistenceNamespace: fixture.namespace,
            runtimeIdentifier: fixture.namespace,
            databaseWriter: fixture.database.pool,
            publicationBarrier: barrier,
            broadcastOperation: { transaction in
                capture.append(transaction.txRaw)
                return BroadcastResponse(txHash: transaction.transactionID.hash, code: 0, codespace: nil, sanitizedLog: nil)
            },
            lookupOperation: { _ in
                capture.lookupCalls += 1
                return .notFound
            }
        )
        await runtime.activate(generation: 1)

        let submission = try await runtime.retryBroadcast(transactionId: fixture.transaction.transactionID, acceptingNativeFee: Data([1]))

        guard case .unknown = submission.state else {
            return XCTFail("failed publication must remain unknown")
        }
        XCTAssertEqual(capture.lookupCalls, 0)
        XCTAssertEqual(capture.raws, [])
        XCTAssertEqual(try fixture.journal.record(for: fixture.transaction.transactionID)?.state, .unknown)
    }

    func testLateGenerationCannotOverwriteTerminalState() throws {
        let fixture = try makeUnknownRecord(namespace: "retry-generation-\(UUID().uuidString)")
        XCTAssertTrue(try fixture.journal.transition(
            transactionID: fixture.transaction.transactionID,
            from: .unknown,
            expectedGeneration: 0,
            to: .broadcasting,
            generation: 1
        ))
        XCTAssertTrue(try fixture.journal.transition(
            transactionID: fixture.transaction.transactionID,
            from: .broadcasting,
            expectedGeneration: 1,
            to: .checkTxAccepted,
            generation: 1
        ))
        XCTAssertFalse(try fixture.journal.transition(
            transactionID: fixture.transaction.transactionID,
            from: .broadcasting,
            expectedGeneration: 1,
            to: .unknown,
            generation: 1
        ))
        guard case .checkTxAccepted = try XCTUnwrap(fixture.journal.record(for: fixture.transaction.transactionID)?.state) else {
            return XCTFail("late generation must not downgrade a terminal row")
        }
    }

    private func makeUnknownRecord(namespace: String) throws -> RetryFixture {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(namespace).sqlite")
        let database = try DatabaseRuntime.open(path: path.path)
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let owner = Data([7, 8, 9])
        let reservations = SequenceReservationStore(writer: database.pool)
        let key = SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 4)
        XCTAssertTrue(try reservations.acquire(key, ownerToken: owner))
        let raw = Data([0x01, 0x02, 0x03, 0x04])
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
            sequence: 4,
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
        return RetryFixture(database: database, journal: journal, namespace: namespace, sender: sender, transaction: transaction, raw: raw)
    }
}

private struct RetryFixture {
    let database: DatabaseRuntime
    let journal: SendJournal
    let namespace: String
    let sender: Address
    let transaction: SignedTransaction
    let raw: Data
}

private final class RetryCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRaws = [Data]()
    private var storedLookupCalls = 0

    var raws: [Data] {
        lock.lock(); defer { lock.unlock() }
        return storedRaws
    }

    var lookupCalls: Int {
        get {
            lock.lock(); defer { lock.unlock() }
            return storedLookupCalls
        }
        set {
            lock.lock(); storedLookupCalls = newValue; lock.unlock()
        }
    }

    func append(_ raw: Data) {
        lock.lock(); storedRaws.append(raw); lock.unlock()
    }
}

private final class RetryEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues = [SendRetryEvent]()

    var values: [SendRetryEvent] {
        lock.lock(); defer { lock.unlock() }
        return storedValues
    }

    func append(_ event: SendRetryEvent) {
        lock.lock(); storedValues.append(event); lock.unlock()
    }
}
