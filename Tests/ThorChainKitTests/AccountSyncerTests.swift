import Foundation
import XCTest
@testable import ThorChainKit

final class AccountSyncerTests: XCTestCase {
    func testRefreshStoresAndPublishesCompleteSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let address = try testAddress()
        let accountStorage = try AccountInfoStorage(databaseDirectoryUrl: directory, databaseFileName: "account-info-storage")
        let syncerStorage = try SyncerStorage(databaseDirectoryUrl: directory, databaseFileName: "syncer-state-storage")
        let manager = AccountInfoManager(storage: accountStorage)
        let syncer = Syncer(
            accountInfoManager: manager,
            reader: ImmediateReader(),
            storage: syncerStorage,
            address: address,
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )

        _ = syncer.start()
        for _ in 0..<100 where manager.accountState == nil {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        _ = syncer.stop()

        XCTAssertEqual(manager.accountState?.balances[.rune], 7)
        XCTAssertEqual(syncer.lastBlockHeight, 100)
        XCTAssertEqual(syncerStorage.lastBlockHeight, 100)
        XCTAssertEqual(try accountStorage.accountInfo()?.acceptedHeight, 100)
    }

    func testStoppedReadCannotPersistOrPublish() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let address = try testAddress()
        let storage = try AccountInfoStorage(databaseDirectoryUrl: directory, databaseFileName: "account-info-storage")
        let reader = ControlledReader()
        let manager = AccountInfoManager(storage: storage)
        let syncer = Syncer(accountInfoManager: manager, reader: reader, storage: try SyncerStorage(databaseDirectoryUrl: directory, databaseFileName: "syncer-state-storage"), address: address, schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60))

        _ = syncer.start()
        for _ in 0..<100 {
            if await reader.didStart { break }
            await Task.yield()
        }
        let didStart = await reader.didStart
        XCTAssertTrue(didStart)
        _ = syncer.stop()
        await reader.release()
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(try storage.accountInfo())
        XCTAssertNil(manager.accountState)
    }
}

private struct ImmediateReader: AccountReading {
    func read(address: Address) async throws -> AccountReadTransport {
        try AccountReadTransport(
            acceptedHeight: 100,
            account: AccountTransport(accountNumber: 1, sequence: 2),
            balances: [BalanceTransport(denom: .rune, amountDecimal: "7")],
            familyId: "primary",
            observedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

private func testAddress() throws -> Address {
    try Address("thor166aczv0jatlnyzz8zsczdzk9xxxgppfpu530jl", network: .mainnet)
}

private actor ControlledReader: AccountReading {
    private var continuation: CheckedContinuation<AccountReadTransport, Error>?
    private(set) var didStart = false

    func read(address: Address) async throws -> AccountReadTransport {
        didStart = true
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume(returning: try! AccountReadTransport(
            acceptedHeight: 100,
            account: AccountTransport(accountNumber: 1, sequence: 2),
            balances: [BalanceTransport(denom: .rune, amountDecimal: "7")],
            familyId: "primary",
            observedAt: Date(timeIntervalSince1970: 1)
        ))
        continuation = nil
    }
}
