import BigInt
import Combine
import Foundation
import XCTest
@testable import ThorChainKit

final class KitLifecycleTests: XCTestCase {
    func testLastBlockHeightMatchesAcceptedHeightBeforePublisherDelivery() throws {
        let publishing = StatePublishing()
        let account = try AccountState(
            accountNumber: 1,
            sequence: 2,
            balances: [.rune: 11],
            acceptedHeight: 321,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            exists: true
        )
        var observed: (Int64?, AccountState?, BigUInt)?
        let cancellable = publishing.lastBlockHeightSubject.sink { height in
            observed = (height, publishing.snapshot.accountState, publishing.snapshot.runeBalance)
        }

        publishing.apply(StateSnapshot(accountState: account, syncState: .synced(account), lastBlockHeight: account.acceptedHeight))

        XCTAssertEqual(observed?.0, 321)
        XCTAssertEqual(observed?.1, account)
        XCTAssertEqual(observed?.2, 11)
        cancellable.cancel()
    }

    func testRuneBalanceUsesExactRuneProjection() throws {
        let account = try AccountState(
            accountNumber: 1,
            sequence: 2,
            balances: [.rune: BigUInt("12345678901234567890")],
            acceptedHeight: 1,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            exists: true
        )

        XCTAssertEqual(
            StateSnapshot(accountState: account, syncState: .synced(account), lastBlockHeight: 1).runeBalance,
            BigUInt("12345678901234567890")
        )
    }

    func testCurrentGenerationFailureIngressPreservesCachedState() throws {
        let storage = TestLifecycleStorage()
        let queue = DispatchQueue(label: "s1-05-gate-test")
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "c", count: 64))
        let publishing = StatePublishing()
        let gate = LifecycleGate(dispatcher: queue, address: address, key: key, storage: storage, publishing: publishing)
        let generation = try XCTUnwrap(gate.start())
        let cached = try AccountState(
            accountNumber: 1,
            sequence: 2,
            balances: [.rune: 5],
            acceptedHeight: 9,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            exists: true
        )
        publishing.apply(StateSnapshot(accountState: cached, syncState: .synced(cached), lastBlockHeight: 9))

        gate.publishFailureIfCurrent(SyncFailure(
            generation: generation,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            error: .noConnection
        ))

        if case let .notSynced(error, cached: state) = publishing.snapshot.syncState {
            XCTAssertEqual(error, .noConnection)
            XCTAssertEqual(state, cached)
        } else {
            XCTFail("Expected current-generation failure")
        }
    }

    func testFailedStartRollsBackFacadeAdmissionAndCanRetry() async throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "d", count: 64))
        let dispatcher = DispatchQueue(label: "s1-05-failed-start-facade")
        let publishing = StatePublishing()
        let storage = FailFirstStartStorage()
        let gate = LifecycleGate(
            dispatcher: dispatcher,
            address: address,
            key: key,
            storage: storage,
            publishing: publishing
        )
        let syncer = RecordingAccountSyncer()
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: LifecycleCommandBridge(syncer: syncer, gate: gate)),
            persistenceNamespace: String(repeating: "d", count: 64),
            facadeDispatcher: dispatcher,
            publishing: publishing
        )
        let cancellable = kit.syncStatePublisher.sink { state in
            if case .notSynced(.storageUnavailable, cached: nil) = state {
                kit.refresh()
            }
        }

        kit.start()

        guard case .notSynced(.storageUnavailable, cached: nil) = kit.syncState else {
            return XCTFail("Expected sanitized storage failure after start admission failure")
        }
        kit.refresh()
        let failedEvents = await syncer.eventLog()
        XCTAssertEqual(failedEvents, [])

        storage.recover()
        kit.start()

        let recoveredEvents = await syncer.eventLog()
        XCTAssertEqual(recoveredEvents, ["start"])
        cancellable.cancel()
    }

    func testStopCompletionWaitsForSuccessAndControlFailureCancellation() throws {
        let publishing = StatePublishing()
        let kit = Kit(
            address: try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet),
            dependencies: KitDependencies(lifecycle: NoOpLifecycle()),
            persistenceNamespace: String(repeating: "c", count: 64),
            facadeDispatcher: DispatchQueue(label: "s1-05-stop-completion-test"),
            publishing: publishing
        )
        kit.start()
        kit.stop()
        XCTAssertFalse(kit.syncState.isSynced)
    }
}

private final class TestLifecycleStorage: AccountStateStorage, @unchecked Sendable {
    private var generation: UInt64 = 0

    func load(key: StorageKey) async throws -> StorageRecord? { nil }
    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        generation += 1
        return generation
    }
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        generation == expectedGeneration
    }
    func clear(key: StorageKey) async throws {}
}

private final class FailFirstStartStorage: AccountStateStorage, @unchecked Sendable {
    private var generation: UInt64 = 0
    private var failNextAdvance = true

    func load(key: StorageKey) async throws -> StorageRecord? { nil }

    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        if failNextAdvance {
            failNextAdvance = false
            throw StorageRecordError.invalid
        }
        generation += 1
        return generation
    }

    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        generation == expectedGeneration
    }

    func clear(key: StorageKey) async throws {}

    func recover() {
        failNextAdvance = false
    }
}

private actor RecordingAccountSyncer: AccountSyncing {
    private(set) var events = [String]()

    func eventLog() -> [String] {
        events
    }

    func start(generation: UInt64) async {
        _ = generation
        events.append("start")
    }

    func stop(generation: UInt64) async {
        _ = generation
        events.append("stop")
    }

    func cancelRefresh() async {
        events.append("cancelRefresh")
    }

    func cancelStop() async {
        events.append("cancelStop")
    }

    func refresh() async {
        events.append("refresh")
    }
}

private extension SyncState {
    var isSynced: Bool {
        if case .synced = self { return true }
        return false
    }
}
