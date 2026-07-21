import Foundation
import XCTest
@testable import ThorChainKit

final class AccountSyncerTests: XCTestCase {
    func testRefreshUsesOneCompleteReadAndPublishesOneSnapshot() async throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "d", count: 64))
        let storage = TestSyncStorage()
        let publishing = StatePublishing()
        let queue = DispatchQueue(label: "s1-05-sync-test")
        let gate = LifecycleGate(dispatcher: queue, address: address, key: key, storage: storage, publishing: publishing)
        let reader = TestAccountReader()
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: reader,
            storage: storage,
            gate: gate,
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )
        let generation = try XCTUnwrap(gate.start())

        await syncer.start(generation: generation)
        for _ in 0..<20 {
            if case .synced = publishing.snapshot.syncState { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        await syncer.stop(generation: generation)

        let readCount = await reader.readCount
        XCTAssertEqual(readCount, 1)
        guard case let .synced(account) = publishing.snapshot.syncState else {
            return XCTFail("Expected one complete synced snapshot")
        }
        XCTAssertEqual(account.balances[.rune], 7)
        XCTAssertEqual(publishing.snapshot.lastBlockHeight, 100)
    }

    func testSaveFailurePublishesStorageUnavailable() async throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "c", count: 64))
        let publishing = StatePublishing()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-sync-save-failure-test"),
            address: address,
            key: key,
            storage: FailingSaveStorage(),
            publishing: publishing
        )
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: TestAccountReader(),
            storage: FailingSaveStorage(),
            gate: gate,
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )
        let generation = try XCTUnwrap(gate.start())

        await syncer.start(generation: generation)
        for _ in 0..<20 {
            if case .notSynced(.storageUnavailable, cached: nil) = publishing.snapshot.syncState { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        await syncer.stop(generation: generation)

        guard case let .notSynced(error, cached: nil) = publishing.snapshot.syncState else {
            return XCTFail("Expected storage failure without a synced snapshot")
        }
        XCTAssertEqual(error, .storageUnavailable)
    }

    func testStopRacingSaveEstablishesGenerationAndPublicationBarrier() async throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "e", count: 64))
        let storage = TestSyncStorage()
        let publishing = StatePublishing()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-stop-race-test"),
            address: address,
            key: key,
            storage: storage,
            publishing: publishing
        )
        let generation = try XCTUnwrap(gate.start())
        let record = try StorageRecord(
            storageKey: key,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            accountExists: true,
            accountNumber: 1,
            sequence: 2,
            acceptedHeight: 100,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            balances: [StoredBalance(denom: "rune", amountDecimalString: "7")]
        )

        guard case let .success(stoppedGeneration) = gate.close() else {
            return XCTFail("Expected durable stop generation")
        }
        XCTAssertEqual(stoppedGeneration, generation)
        let saved = try await storage.saveIfCurrent(record, key: key, expectedGeneration: generation)
        XCTAssertFalse(saved)
        XCTAssertFalse(publishing.snapshot.syncState.isSynced)

        let pendingKey = StorageKey(persistenceNamespace: String(repeating: "p", count: 64))
        let pendingRecord = try StorageRecord(
            storageKey: pendingKey,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            accountExists: true,
            accountNumber: 1,
            sequence: 2,
            acceptedHeight: 9,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            balances: [StoredBalance(denom: "rune", amountDecimalString: "7")]
        )
        let pendingReader = PendingAccountReader()
        let pendingStorage = TestSyncStorage(record: pendingRecord)
        let pendingPublishing = StatePublishing()
        let pendingGate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-pending-stop-gate"),
            address: address,
            key: pendingKey,
            storage: pendingStorage,
            publishing: pendingPublishing
        )
        let pendingSyncer = AccountSyncer(
            address: address,
            storageKey: pendingKey,
            reader: pendingReader,
            storage: pendingStorage,
            gate: pendingGate,
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )
        let pendingKit = Kit(
            address: address,
            dependencies: KitDependencies(
                lifecycle: LifecycleCommandBridge(syncer: pendingSyncer, gate: pendingGate)
            ),
            persistenceNamespace: String(repeating: "p", count: 64),
            facadeDispatcher: DispatchQueue(label: "s1-05-pending-stop-facade"),
            publishing: pendingPublishing
        )
        let pendingKitBox = SendableKit(pendingKit)
        var syncedPublicationCount = 0
        let cancellable = pendingKit.syncStatePublisher.sink { state in
            if case .synced = state { syncedPublicationCount += 1 }
        }

        pendingKit.start()
        for _ in 0..<100 {
            if await pendingReader.didStart { break }
            await Task.yield()
        }
        let didStart = await pendingReader.didStart
        XCTAssertTrue(didStart)

        let refreshReturned = expectation(description: "pending refresh returns")
        DispatchQueue.global().async {
            pendingKitBox.kit.refresh()
            refreshReturned.fulfill()
        }
        let stopReturned = expectation(description: "pending stop returns")
        DispatchQueue.global().async {
            pendingKitBox.kit.stop()
            stopReturned.fulfill()
        }
        await fulfillment(of: [refreshReturned, stopReturned], timeout: 2)
        guard case let .idle(cached) = pendingKit.syncState else {
            cancellable.cancel()
            return XCTFail("Expected idle cached state after pending stop")
        }
        XCTAssertTrue(cached)
        XCTAssertEqual(pendingKit.lastBlockHeight, 9)
        XCTAssertEqual(syncedPublicationCount, 0)
        cancellable.cancel()
    }

    func testStopControlFailureFailsClosedAndDrainsOldGeneration() throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "1", count: 64))
        let publishing = StatePublishing()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-stop-failure-test"),
            address: address,
            key: key,
            storage: FailingGenerationStorage(),
            publishing: publishing
        )
        let generation = try XCTUnwrap(gate.start())
        guard case .failure = gate.close() else {
            return XCTFail("Expected control transaction failure")
        }
        gate.publishStopFailureIfCurrent()

        XCTAssertEqual(generation, 1)
        guard case let .notSynced(error, cached: nil) = publishing.snapshot.syncState else {
            return XCTFail("Expected failed stop to remain closed")
        }
        XCTAssertEqual(error, .storageUnavailable)
    }

    func testReentrantStopDoesNotWaitOnFacadeDispatcher() throws {
        let publishing = StatePublishing()
        let kit = Kit(
            address: try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet),
            dependencies: KitDependencies(lifecycle: NoOpLifecycle()),
            persistenceNamespace: String(repeating: "f", count: 64),
            facadeDispatcher: DispatchQueue(label: "s1-05-reentrant-stop-test"),
            publishing: publishing
        )
        kit.start()
        var callbackReturned = false
        let cancellable = kit.syncStatePublisher.sink { _ in
            kit.stop()
            callbackReturned = true
        }
        publishing.apply(StateSnapshot(accountState: nil, syncState: .idle(cached: false), lastBlockHeight: nil))
        XCTAssertTrue(callbackReturned)
        cancellable.cancel()
    }
}

private actor TestAccountReader: AccountReading {
    private(set) var readCount = 0

    func read(address: Address) async throws -> AccountReadTransport {
        readCount += 1
        return try AccountReadTransport(
            acceptedHeight: 100,
            account: AccountTransport(accountNumber: 1, sequence: 2),
            balances: [BalanceTransport(denom: .rune, amountDecimal: "7")],
            familyId: "primary",
            observedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private final class TestSyncStorage: AccountStateStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var record: StorageRecord?

    init(record: StorageRecord? = nil) {
        self.record = record
    }

    func load(key: StorageKey) async throws -> StorageRecord? {
        withLock { record }
    }

    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        withLock {
            generation += 1
            return generation
        }
    }

    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        withLock {
            guard generation == expectedGeneration else { return false }
            self.record = record
            return true
        }
    }

    func clear(key: StorageKey) async throws {}

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }
}

private actor PendingAccountReader: AccountReading {
    private(set) var didStart = false
    private var continuation: CheckedContinuation<AccountReadTransport, Error>?

    func read(address: Address) async throws -> AccountReadTransport {
        _ = address
        didStart = true
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        }, onCancel: {
            Task { await self.cancel() }
        })
    }

    private func cancel() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

private final class SendableKit: @unchecked Sendable {
    let kit: Kit

    init(_ kit: Kit) {
        self.kit = kit
    }
}

private final class FailingGenerationStorage: AccountStateStorage, @unchecked Sendable {
    private var advances = 0

    func load(key: StorageKey) async throws -> StorageRecord? { nil }

    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        advances += 1
        if advances == 2 { throw StorageRecordError.invalid }
        return UInt64(advances)
    }

    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        false
    }

    func clear(key: StorageKey) async throws {}
}

private struct FailingSaveStorage: AccountStateStorage {
    func load(key: StorageKey) async throws -> StorageRecord? { nil }
    func advanceGeneration(key: StorageKey) throws -> UInt64 { 1 }
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        throw StorageRecordError.invalid
    }
    func clear(key: StorageKey) async throws {}
}

private extension SyncState {
    var isSynced: Bool {
        if case .synced = self { return true }
        return false
    }
}
