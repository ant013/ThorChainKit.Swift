import Foundation
import XCTest
@testable import ThorChainKit

final class LifecycleInvariantProbeTests: XCTestCase {
    func testDuplicateStart() async throws {
        let syncer = makeSyncer()
        await syncer.start(generation: 1)
        await syncer.start(generation: 1)
    }

    func testStoppedRefresh() async throws {
        await makeSyncer().refresh()
    }

    func testDuplicateStop() async throws {
        let syncer = makeSyncer()
        await syncer.start(generation: 1)
        await syncer.stop(generation: 1)
        await syncer.stop(generation: 1)
    }

    private func makeSyncer() -> AccountSyncer {
        let address = try! Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "0", count: 64))
        let storage = InvariantProbeStorage()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-invariant-probe"),
            address: address,
            key: key,
            storage: storage,
            publishing: StatePublishing()
        )
        return AccountSyncer(
            address: address,
            storageKey: key,
            reader: InvariantProbeReader(),
            storage: storage,
            gate: gate,
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )
    }
}

private struct InvariantProbeReader: AccountReading {
    func read(address: Address) async throws -> AccountReadTransport {
        try AccountReadTransport(
            acceptedHeight: 1,
            account: nil,
            balances: [],
            familyId: "probe",
            observedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private struct InvariantProbeStorage: AccountStateStorage {
    func load(key: StorageKey) async throws -> StorageRecord? { nil }
    func advanceGeneration(key: StorageKey) throws -> UInt64 { 1 }
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool { true }
    func clear(key: StorageKey) async throws {}
}
