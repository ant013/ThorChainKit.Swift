import BigInt
import Foundation
import XCTest
@testable import ThorChainKit

final class AccountStateStorageTests: XCTestCase {
    func testInvalidFreshRecordIsRejectedBeforeSave() throws {
        XCTAssertThrowsError(
            try StorageRecord(
                storageKey: StorageKey(persistenceNamespace: String(repeating: "a", count: 64)),
                address: "thor1address",
                networkChainId: "thorchain-1",
                accountExists: true,
                accountNumber: 1,
                sequence: 2,
                acceptedHeight: 100,
                fetchedAt: Date(timeIntervalSince1970: 1),
                providerFamilyId: "primary",
                balances: [StoredBalance(denom: "x", amountDecimalString: "1")]
            )
        )
    }

    func testLoadUsesOneConsistentReadSnapshot() async throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("thorchain-s1-05-(UUID().uuidString).sqlite")
            .path
        defer { try? FileManager.default.removeItem(atPath: path) }

        let storage = try GrdbAccountStateStorage(path: path)
        let key = StorageKey(persistenceNamespace: String(repeating: "b", count: 64))
        XCTAssertEqual(try storage.advanceGeneration(key: key), 1)
        let record = try StorageRecord(
            storageKey: key,
            address: "thor1address",
            networkChainId: "thorchain-1",
            accountExists: true,
            accountNumber: 1,
            sequence: 2,
            acceptedHeight: 100,
            fetchedAt: Date(timeIntervalSince1970: 1),
            providerFamilyId: "primary",
            balances: [
                StoredBalance(denom: "rune", amountDecimalString: "7"),
                StoredBalance(denom: "thor", amountDecimalString: "9"),
            ]
        )

        let saved = try await storage.saveIfCurrent(record, key: key, expectedGeneration: 1)
        let loaded = try await storage.load(key: key)
        XCTAssertTrue(saved)
        XCTAssertEqual(loaded, record)
    }

    func testStorageSaveFailurePublishesStorageUnavailableWithoutSynced() throws {
        let address = try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
        let key = StorageKey(persistenceNamespace: String(repeating: "b", count: 64))
        let publishing = StatePublishing()
        let gate = LifecycleGate(
            dispatcher: DispatchQueue(label: "s1-05-storage-failure-test"),
            address: address,
            key: key,
            storage: TestStorageFailureStorage(),
            publishing: publishing
        )
        let generation = try XCTUnwrap(gate.start())
        gate.publishFailureIfCurrent(SyncFailure(
            generation: generation,
            address: address.raw,
            networkChainId: address.network.expectedChainId,
            error: .storageUnavailable
        ))

        guard case let .notSynced(error, cached: nil) = publishing.snapshot.syncState else {
            return XCTFail("Expected storage failure without a synced snapshot")
        }
        XCTAssertEqual(error, .storageUnavailable)
    }
}

private struct TestStorageFailureStorage: AccountStateStorage {
    func load(key: StorageKey) async throws -> StorageRecord? { nil }
    func advanceGeneration(key: StorageKey) throws -> UInt64 { 1 }
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool {
        throw StorageRecordError.invalid
    }
    func clear(key: StorageKey) async throws {}
}
