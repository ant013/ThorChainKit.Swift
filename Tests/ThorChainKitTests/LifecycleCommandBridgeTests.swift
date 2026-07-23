import Foundation
import BigInt
import XCTest
@testable import ThorChainKit

final class LifecycleCommandBridgeTests: XCTestCase {
    func testStartActivatesRuntimeAndStopInvalidatesItsGeneration() async throws {
        let address = try sendTestAddress()
        let dispatcher = DispatchQueue(label: "s2-01-bridge")
        let storage = BridgeStorage()
        let gate = LifecycleGate(
            dispatcher: dispatcher,
            address: address,
            key: StorageKey(persistenceNamespace: String(repeating: "b", count: 64)),
            storage: storage,
            publishing: StatePublishing()
        )
        let runtime = SendRuntime(address: address)
        let bridge = LifecycleCommandBridge(
            syncer: BridgeSyncer(runtime: runtime),
            gate: gate,
            sendRuntime: runtime
        )
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: bridge, sendRuntime: runtime),
            persistenceNamespace: "bridge",
            facadeDispatcher: dispatcher
        )

        kit.start()
        do {
            _ = try await kit.quote(to: try sendOtherAddress(), amount: .exact(BigUInt(0)))
            XCTFail("active runtime should reach local validation")
        } catch let error as SendError {
            XCTAssertEqual(error, .invalidAmount)
        }

        kit.stop()
        do {
            _ = try await kit.quote(to: try sendOtherAddress(), amount: .exact(BigUInt(1)))
            XCTFail("stopped runtime must reject admission")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }
    }

    func testStopInvalidatesBeforeSyncerCloseOnSuccessAndFailure() async throws {
        let address = try sendTestAddress()
        let successStorage = BridgeStorage()
        let successRuntime = SendRuntime(address: address)
        let successSyncer = BridgeSyncer(runtime: successRuntime)
        let successGate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s2-01-success-gate"),
            address: address,
            key: StorageKey(persistenceNamespace: String(repeating: "s", count: 64)),
            storage: successStorage,
            publishing: StatePublishing()
        )
        let successBridge = LifecycleCommandBridge(syncer: successSyncer, gate: successGate, sendRuntime: successRuntime)
        successBridge.start(sequence: 1).wait()
        successBridge.stop(sequence: 2).wait()
        let successEvents = await successSyncer.events()
        XCTAssertEqual(successEvents, ["start", "cancelRefresh:invalidated", "stop"])

        let failureStorage = BridgeStorage()
        let failureRuntime = SendRuntime(address: address)
        let failureSyncer = BridgeSyncer(runtime: failureRuntime)
        let failureGate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s2-01-failure-gate"),
            address: address,
            key: StorageKey(persistenceNamespace: String(repeating: "f", count: 64)),
            storage: failureStorage,
            publishing: StatePublishing()
        )
        let failureBridge = LifecycleCommandBridge(syncer: failureSyncer, gate: failureGate, sendRuntime: failureRuntime)
        failureBridge.start(sequence: 1).wait()
        failureStorage.failNextAdvance()
        failureBridge.stop(sequence: 2).wait()
        let failureEvents = await failureSyncer.events()
        XCTAssertEqual(failureEvents, ["start", "cancelRefresh:invalidated", "cancelStop"])
    }

    func testStopClosesAdmissionBeforeQueuedCloseWork() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s2-01-admission-gate"),
            address: address,
            key: StorageKey(persistenceNamespace: String(repeating: "a", count: 64)),
            storage: BridgeStorage(),
            publishing: StatePublishing()
        )
        let bridge = LifecycleCommandBridge(
            syncer: BridgeSyncer(runtime: runtime),
            gate: gate,
            sendRuntime: runtime
        )

        bridge.start(sequence: 1).wait()
        _ = bridge.stop(sequence: 2)

        let transactionId = try XCTUnwrap(TransactionID(hash: String(repeating: "A", count: 64)))
        do {
            _ = try await runtime.retryBroadcast(transactionId: transactionId, acceptingNativeFee: nil)
            XCTFail("stop must close send admission before queued close work")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }
    }

    func testRapidRestartRejectsLateFailureFromPreviousGeneration() async throws {
        let address = try sendTestAddress()
        let publishing = StatePublishing()
        let storage = BridgeStorage()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s2-01-restart-gate"),
            address: address,
            key: StorageKey(persistenceNamespace: String(repeating: "r", count: 64)),
            storage: storage,
            publishing: publishing
        )
        let runtime = SendRuntime(address: address)
        let bridge = LifecycleCommandBridge(syncer: BridgeSyncer(runtime: runtime), gate: gate, sendRuntime: runtime)

        bridge.start(sequence: 1).wait()
        storage.failNextAdvance()
        bridge.stop(sequence: 2).wait()
        bridge.start(sequence: 3).wait()
        publishing.apply(StateSnapshot(accountState: nil, syncState: .idle(cached: false), lastBlockHeight: nil))
        gate.publishFailureIfCurrent(SyncFailure(
            generation: 1,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            error: .noConnection
        ))

        if case .notSynced = publishing.snapshot.syncState {
            XCTFail("late failure from the previous generation must be ignored")
        }
    }
}

private final class BridgeStorage: AccountStateStorage, @unchecked Sendable {
    private var generation: UInt64 = 0
    private var failAdvance = false

    func load(key: StorageKey) async throws -> StorageRecord? { nil }
    func advanceGeneration(key: StorageKey) throws -> UInt64 {
        if failAdvance {
            failAdvance = false
            throw StorageRecordError.invalid
        }
        generation += 1
        return generation
    }

    func failNextAdvance() { failAdvance = true }
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        generation == expectedGeneration
    }
    func clear(key: StorageKey) async throws {}
}

private actor BridgeSyncer: AccountSyncing {
    private let runtime: SendRuntime
    private var recordedEvents = [String]()

    init(runtime: SendRuntime) { self.runtime = runtime }

    func start(generation: UInt64) async { recordedEvents.append("start") }
    func stop(generation: UInt64) async { recordedEvents.append("stop") }
    func cancelRefresh() async {
        let id = TransactionID(hash: String(repeating: "A", count: 64))!
        do {
            _ = try await runtime.retryBroadcast(transactionId: id, acceptingNativeFee: nil)
            recordedEvents.append("cancelRefresh:active")
        } catch let error as SendError where error == .kitNotStarted {
            recordedEvents.append("cancelRefresh:invalidated")
        } catch {
            recordedEvents.append("cancelRefresh:other")
        }
    }
    func cancelStop() async { recordedEvents.append("cancelStop") }
    func refresh() async {}
    func events() -> [String] { recordedEvents }
}
