import Combine
import Foundation
import XCTest
@testable import ThorChainKit

final class TransactionHistoryTests: XCTestCase {
    func testMidgardProviderDecodesActionStringsAndIgnoresAdditiveJSON() async throws {
        let address = try sendTestAddress()
        let hash = String(repeating: "A", count: 64)
        let response = try httpResponse(body: """
        {
          "actions": [{
            "date": "1785408389116780091", "height": "27220171",
            "type": "send", "status": "success", "ignored": {"future": true},
            "in": [{"address": "\(address.raw)", "txID": "\(hash)", "coins": [{"asset": "THOR.RUNE", "amount": "42"}]}],
            "out": [{"address": "thor1g2tj3e6a76unm26cy8x2jpxz0wysnaerasq74p", "txID": "\(hash)", "coins": [{"asset": "THOR.RUNE", "amount": "42"}]}],
            "metadata": {"send": {"memo": "memo", "future": [1, 2]}}
          }],
          "meta": {"nextPageToken": "cursor", "ignored": true}
        }
        """)
        let transport = HistoryTransport(result: response)
        let provider = MidgardProvider(
            baseURLs: [URL(string: "https://midgard.example/base/")!],
            requestTimeout: 5,
            clientId: "fixture",
            transport: transport
        )

        let page = try await provider.fetchActions(address: address.raw, limit: 50, nextPageToken: "previous", transactionID: nil)
        XCTAssertEqual(page.actions.count, 1)
        XCTAssertEqual(page.nextPageToken, "cursor")
        XCTAssertEqual(page.actions.first?.height, 27_220_171)
        XCTAssertEqual(page.actions.first?.date, 1_785_408_389_116_780_091)

        let request = await transport.request
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request?.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/base/v2/actions")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "address" })?.value, address.raw)
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "limit" })?.value, "50")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "nextPageToken" })?.value, "previous")
    }

    func testRepositoryPreservesBackfillTokenWhenWatermarkChanges() throws {
        let repository = try repository(namespace: "cursor")
        try repository.save(backfillPageToken: "older")
        try repository.save(lastTimestamp: 100)
        XCTAssertEqual(try repository.cursor(), TransactionSyncCursor(lastTimestamp: 100, backfillPageToken: "older"))

        try repository.save(backfillPageToken: nil)
        XCTAssertEqual(try repository.cursor(), TransactionSyncCursor(lastTimestamp: 100, backfillPageToken: nil))
    }

    func testTerminalActionClearsJournalButPendingActionDoesNot() throws {
        let fixture = try journalFixture()
        let pending = PendingTransactionManager(journal: fixture.journal)
        let repository = TransactionRepository(storage: fixture.storage, persistenceNamespace: fixture.namespace)
        let manager = TransactionManager(storage: fixture.storage, repository: repository, journal: fixture.journal, pendingTransactionManager: pending)

        try manager.save(transactions: [transaction(id: fixture.transactionID, status: "pending")])
        XCTAssertEqual(try fixture.journal.pendingRecords().count, 1)

        try manager.save(transactions: [transaction(id: fixture.transactionID, status: "success")])
        XCTAssertTrue(try fixture.journal.pendingRecords().isEmpty)
        XCTAssertEqual(manager.transactions().first?.status, "success")
    }

    func testUnknownActionDoesNotClearJournal() throws {
        let fixture = try journalFixture()
        let pending = PendingTransactionManager(journal: fixture.journal)
        let repository = TransactionRepository(storage: fixture.storage, persistenceNamespace: fixture.namespace)
        let manager = TransactionManager(storage: fixture.storage, repository: repository, journal: fixture.journal, pendingTransactionManager: pending)

        try manager.save(transactions: [transaction(id: fixture.transactionID, status: "unknown")])

        XCTAssertEqual(try fixture.journal.pendingRecords().count, 1)
        XCTAssertEqual(manager.transactions().first?.status, "unknown")
    }

    func testTransactionManagerPublishesOnlySuppliedDelta() throws {
        let fixture = try historyFixture()
        let first = transaction(id: try transactionID(1), status: "success")
        let second = transaction(id: try transactionID(2), status: "success")
        var emissions = [([Transaction], Bool)]()
        let cancellable = fixture.manager.allTransactionsPublisher.sink { emissions.append($0) }

        fixture.manager.process(transactions: [first], initial: true)
        fixture.manager.process(transactions: [second], initial: false)

        XCTAssertEqual(emissions.count, 2)
        XCTAssertEqual(emissions[0].0, [first])
        XCTAssertTrue(emissions[0].1)
        XCTAssertEqual(emissions[1].0, [second])
        XCTAssertFalse(emissions[1].1)
        withExtendedLifetime(cancellable) {}
    }

    func testTerminalHistoryAndJournalReconciliationRollBackTogether() throws {
        let fixture = try journalFixture()
        let pending = PendingTransactionManager(journal: fixture.journal)
        let repository = TransactionRepository(storage: fixture.storage, persistenceNamespace: fixture.namespace)
        let manager = TransactionManager(storage: fixture.storage, repository: repository, journal: fixture.journal, pendingTransactionManager: pending)
        try fixture.storage.write { db in
            try db.execute(sql: "CREATE TRIGGER prevent_history_reconciliation BEFORE DELETE ON send_journal BEGIN SELECT RAISE(ABORT, 'test'); END")
        }

        XCTAssertThrowsError(try manager.save(transactions: [transaction(id: fixture.transactionID, status: "success")]))
        XCTAssertTrue(try repository.transactions().isEmpty)
        XCTAssertEqual(try fixture.journal.pendingRecords().count, 1)
    }

    func testSyncerRechecksPendingHashOutsideRecentPage() throws {
        let fixture = try journalFixture()
        let pending = PendingTransactionManager(journal: fixture.journal)
        let repository = TransactionRepository(storage: fixture.storage, persistenceNamespace: fixture.namespace)
        let manager = TransactionManager(storage: fixture.storage, repository: repository, journal: fixture.journal, pendingTransactionManager: pending)
        let provider = HistoryProvider(
            pending: action(id: fixture.transactionID, status: "pending"),
            confirmed: action(id: fixture.transactionID, status: "success")
        )
        let syncer = TransactionSyncer(provider: provider, repository: repository, transactionManager: manager, address: try sendTestAddress())
        let first = expectation(description: "first sync")
        let second = expectation(description: "second sync")
        var syncedCount = 0
        let cancellable = syncer.statePublisher.sink { state in
            guard state == .synced else { return }
            syncedCount += 1
            if syncedCount == 1 { first.fulfill() }
            if syncedCount == 2 { second.fulfill() }
        }

        syncer.sync()
        wait(for: [first], timeout: 2)
        XCTAssertEqual(manager.transactions().first?.status, "pending")
        XCTAssertEqual(try fixture.journal.pendingRecords().count, 1)

        syncer.sync()
        wait(for: [second], timeout: 2)
        XCTAssertEqual(manager.transactions().first?.status, "success")
        XCTAssertTrue(try fixture.journal.pendingRecords().isEmpty)
        _ = cancellable
    }

    func testSyncerStopsRecentPagingAtTerminalWatermark() async throws {
        let fixture = try historyFixture()
        let repository = fixture.repository
        try repository.save(lastTimestamp: 123)
        let provider = ScriptedHistoryProvider { request in
            XCTAssertNil(request.transactionID)
            return MidgardActionPage(
                actions: [self.action(id: try self.transactionID(3), status: "success")],
                nextPageToken: "must-not-be-requested"
            )
        }
        let syncer = TransactionSyncer(provider: provider, repository: repository, transactionManager: fixture.manager, address: try sendTestAddress())

        await waitForState(.synced, syncer: syncer)

        let requests = await provider.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testSyncerDoesNotRecheckPendingActionSeenInRecentPage() async throws {
        let fixture = try historyFixture()
        let pending = transaction(id: try transactionID(4), status: "pending")
        let provider = ScriptedHistoryProvider { request in
            XCTAssertNil(request.transactionID)
            return MidgardActionPage(actions: [self.action(id: pending.transactionId, status: "pending")], nextPageToken: nil)
        }
        let syncer = TransactionSyncer(provider: provider, repository: fixture.repository, transactionManager: fixture.manager, address: try sendTestAddress())

        await waitForState(.synced, syncer: syncer)

        let requests = await provider.requests()
        XCTAssertFalse(requests.contains { $0.transactionID != nil })
    }

    func testSyncerLimitsStalePendingRechecksToTen() async throws {
        let fixture = try historyFixture()
        try fixture.repository.save((1 ... 11).map { transaction(id: try! transactionID($0 + 10), status: "pending") })
        let provider = ScriptedHistoryProvider { _ in MidgardActionPage(actions: [], nextPageToken: nil) }
        let syncer = TransactionSyncer(provider: provider, repository: fixture.repository, transactionManager: fixture.manager, address: try sendTestAddress())

        await waitForState(.synced, syncer: syncer)

        let requests = await provider.requests()
        XCTAssertEqual(requests.filter { $0.transactionID == nil }.count, 1)
        XCTAssertEqual(requests.filter { $0.transactionID != nil }.count, 10)
    }

    func testPageCapPersistsBackfillTokenBeforeBackfillFailure() async throws {
        let fixture = try historyFixture()
        let provider = PageCapHistoryProvider(action: try action(id: transactionID(42), status: "success"))
        let syncer = TransactionSyncer(provider: provider, repository: fixture.repository, transactionManager: fixture.manager, address: try sendTestAddress())

        await waitForState(.failed, syncer: syncer)

        XCTAssertEqual(try fixture.repository.cursor().backfillPageToken, "backfill")
        let requests = await provider.requests()
        XCTAssertEqual(requests.count, 21)
    }

    func testReentrantStopFromStateSubscriberDoesNotStartHistoryRequest() async throws {
        let fixture = try historyFixture()
        let provider = ScriptedHistoryProvider { _ in MidgardActionPage(actions: [], nextPageToken: nil) }
        let syncer = TransactionSyncer(provider: provider, repository: fixture.repository, transactionManager: fixture.manager, address: try sendTestAddress())
        let stopped = expectation(description: "reentrant stop")
        let cancellable = syncer.statePublisher.sink { state in
            guard state == .syncing else { return }
            syncer.stop()
            stopped.fulfill()
        }

        syncer.sync()
        await fulfillment(of: [stopped], timeout: 2)

        XCTAssertEqual(syncer.state, .notSynced)
        let requests = await provider.requests()
        XCTAssertTrue(requests.isEmpty)
        withExtendedLifetime(cancellable) {}
    }

    func testCancelledOldSyncCannotOverwriteNewSyncState() async throws {
        let fixture = try historyFixture()
        let provider = GateHistoryProvider()
        let syncer = TransactionSyncer(provider: provider, repository: fixture.repository, transactionManager: fixture.manager, address: try sendTestAddress())
        let newSyncCompleted = expectation(description: "new sync completed")
        let obsoleteCompletion = expectation(description: "old sync changed state")
        obsoleteCompletion.isInverted = true
        let gate = StateEventGate()
        let cancellable = syncer.statePublisher.sink { state in
            if state == .synced { newSyncCompleted.fulfill() }
            if state == .notSynced, gate.isArmed { obsoleteCompletion.fulfill() }
        }

        syncer.sync()
        await provider.waitForFirstRequest()
        syncer.stop()
        syncer.sync()
        await fulfillment(of: [newSyncCompleted], timeout: 2)

        gate.arm()
        await provider.releaseFirstRequest()
        await fulfillment(of: [obsoleteCompletion], timeout: 0.2)
        XCTAssertEqual(syncer.state, .synced)
        withExtendedLifetime(cancellable) {}
    }

    func testSecondSenderDoesNotRepeatJournalRecoveryForSameDatabase() throws {
        let fixture = try journalFixture(insertJournal: false)
        _ = TransactionSender(
            address: try sendTestAddress(),
            persistenceNamespace: fixture.namespace,
            journal: fixture.journal,
            reservationStore: SequenceReservationStore(storage: fixture.storage)
        )
        try fixture.insertBroadcasting()

        _ = TransactionSender(
            address: try sendTestAddress(),
            persistenceNamespace: fixture.namespace,
            journal: fixture.journal,
            reservationStore: SequenceReservationStore(storage: fixture.storage)
        )

        XCTAssertEqual(try fixture.journal.record(for: fixture.transactionID)?.state, .broadcasting)
    }

    private func repository(namespace: String) throws -> TransactionRepository {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).sqlite").path
        let storage = try TransactionStorage(path: path)
        return TransactionRepository(storage: storage, persistenceNamespace: namespace)
    }

    private func historyFixture() throws -> HistoryFixture {
        let journal = try journalFixture(insertJournal: false)
        let pending = PendingTransactionManager(journal: journal.journal)
        let repository = TransactionRepository(storage: journal.storage, persistenceNamespace: journal.namespace)
        let manager = TransactionManager(storage: journal.storage, repository: repository, journal: journal.journal, pendingTransactionManager: pending)
        return HistoryFixture(repository: repository, manager: manager)
    }

    private func journalFixture(insertJournal: Bool = true) throws -> JournalFixture {
        let storage = try TransactionStorage(path: FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).sqlite").path)
        let namespace = "history"
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let transactionID = try XCTUnwrap(TransactionID(hash: String(repeating: "B", count: 64)))
        let owner = Data([1])
        let journal = SendJournal(storage: storage, persistenceNamespace: namespace)
        let fixture = JournalFixture(storage: storage, namespace: namespace, journal: journal, transactionID: transactionID, sender: sender, recipient: recipient, owner: owner)
        if insertJournal { try fixture.insertBroadcasting() }
        return fixture
    }

    private func transaction(id: TransactionID, status: String) -> Transaction {
        Transaction(
            transactionId: id,
            blockHeight: 123,
            timestamp: Date(timeIntervalSince1970: 123),
            type: "send",
            status: status,
            memo: "memo",
            incoming: [CoinTransfer(address: "sender", asset: "THOR.RUNE", amount: 42)],
            outgoing: [CoinTransfer(address: "recipient", asset: "THOR.RUNE", amount: 42)]
        )
    }

    private func action(id: TransactionID, status: String) -> MidgardAction {
        try! JSONDecoder().decode(MidgardAction.self, from: Data("""
        {"date":"123000000000","height":"123","type":"send","status":"\(status)","in":[{"address":"sender","txID":"\(id.hash)","coins":[{"asset":"THOR.RUNE","amount":"42"}]}],"out":[{"address":"recipient","txID":"\(id.hash)","coins":[{"asset":"THOR.RUNE","amount":"42"}]}]}
        """.utf8))
    }

    private func transactionID(_ value: Int) throws -> TransactionID {
        try XCTUnwrap(TransactionID(hash: String(format: "%064X", value)))
    }

    private func waitForState(_ expected: TransactionSyncState, syncer: TransactionSyncer) async {
        let fulfilled = expectation(description: "transaction sync \(expected)")
        let cancellable = syncer.statePublisher.sink { state in
            if state == expected { fulfilled.fulfill() }
        }
        syncer.sync()
        await fulfillment(of: [fulfilled], timeout: 2)
        withExtendedLifetime(cancellable) {}
    }

    private func httpResponse(body: String) throws -> (Data, HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "https://midgard.example/base/v2/actions"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
        return (Data(body.utf8), response)
    }
}

private struct JournalFixture {
    let storage: TransactionStorage
    let namespace: String
    let journal: SendJournal
    let transactionID: TransactionID
    let sender: Address
    let recipient: Address
    let owner: Data

    func insertBroadcasting() throws {
        let reservations = SequenceReservationStore(storage: storage)
        XCTAssertTrue(try reservations.acquire(SequenceReservationKey(persistenceNamespace: namespace, senderPayload: sender.payload, sequence: 7), ownerToken: owner))
        try journal.insertBroadcasting(
            transaction: SignedTransaction(txRaw: Data([1, 2]), transactionID: transactionID),
            senderPayload: sender.payload,
            recipientPayload: recipient.payload,
            sender: sender.raw,
            recipient: recipient.raw,
            amount: Data([42]),
            quotedNativeFee: Data(),
            memo: "memo",
            accountNumber: 1,
            sequence: 7,
            providerFamilyID: "fixture",
            quoteHeight: 123,
            reservationOwnerToken: owner
        )
    }
}

private struct HistoryFixture {
    let repository: TransactionRepository
    let manager: TransactionManager
}

private struct HistoryRequest: Sendable {
    let nextPageToken: String?
    let transactionID: TransactionID?
}

private actor ScriptedHistoryProvider: MidgardActionProviding {
    private let response: @Sendable (HistoryRequest) throws -> MidgardActionPage
    private var recordedRequests = [HistoryRequest]()

    init(response: @escaping @Sendable (HistoryRequest) throws -> MidgardActionPage) {
        self.response = response
    }

    func fetchActions(address: String, limit: Int, nextPageToken: String?, transactionID: TransactionID?) async throws -> MidgardActionPage {
        let request = HistoryRequest(nextPageToken: nextPageToken, transactionID: transactionID)
        recordedRequests.append(request)
        return try response(request)
    }

    func requests() -> [HistoryRequest] { recordedRequests }
}

private actor PageCapHistoryProvider: MidgardActionProviding {
    private let action: MidgardAction
    private var recordedRequests = [HistoryRequest]()

    init(action: MidgardAction) {
        self.action = action
    }

    func fetchActions(address: String, limit: Int, nextPageToken: String?, transactionID: TransactionID?) async throws -> MidgardActionPage {
        let request = HistoryRequest(nextPageToken: nextPageToken, transactionID: transactionID)
        recordedRequests.append(request)
        if nextPageToken == "backfill" { throw MidgardProviderError.unavailable }
        let next = recordedRequests.count == 20 ? "backfill" : "recent-\(recordedRequests.count)"
        return MidgardActionPage(actions: [action], nextPageToken: next)
    }

    func requests() -> [HistoryRequest] { recordedRequests }
}

private actor GateHistoryProvider: MidgardActionProviding {
    private var firstRequestStarted = false
    private var firstRequestWaiter: CheckedContinuation<Void, Never>?
    private var firstRequestRelease: CheckedContinuation<Void, Never>?

    func fetchActions(address: String, limit: Int, nextPageToken: String?, transactionID: TransactionID?) async throws -> MidgardActionPage {
        guard !firstRequestStarted else { return MidgardActionPage(actions: [], nextPageToken: nil) }
        firstRequestStarted = true
        firstRequestWaiter?.resume()
        firstRequestWaiter = nil
        await withCheckedContinuation { firstRequestRelease = $0 }
        return MidgardActionPage(actions: [], nextPageToken: nil)
    }

    func waitForFirstRequest() async {
        guard !firstRequestStarted else { return }
        await withCheckedContinuation { firstRequestWaiter = $0 }
    }

    func releaseFirstRequest() {
        firstRequestRelease?.resume()
        firstRequestRelease = nil
    }
}

private final class StateEventGate: @unchecked Sendable {
    private let lock = NSLock()
    private var armed = false

    var isArmed: Bool {
        lock.lock(); defer { lock.unlock() }
        return armed
    }

    func arm() {
        lock.lock()
        armed = true
        lock.unlock()
    }
}

private actor HistoryTransport: HTTPTransporting {
    let result: (Data, HTTPURLResponse)
    private(set) var request: URLRequest?

    init(result: (Data, HTTPURLResponse)) { self.result = result }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        return result
    }
}

private actor HistoryProvider: MidgardActionProviding {
    private let pending: MidgardAction
    private let confirmed: MidgardAction
    private var recentRequests = 0

    init(pending: MidgardAction, confirmed: MidgardAction) {
        self.pending = pending
        self.confirmed = confirmed
    }

    func fetchActions(address: String, limit: Int, nextPageToken: String?, transactionID: TransactionID?) async throws -> MidgardActionPage {
        if transactionID != nil {
            return MidgardActionPage(actions: [confirmed], nextPageToken: nil)
        }
        recentRequests += 1
        return MidgardActionPage(actions: recentRequests == 1 ? [pending] : [], nextPageToken: nil)
    }
}
