import Foundation
import XCTest
@testable import ThorChainKit

final class LifecycleInvariantProbeTests: XCTestCase {
    func testDirectSyncerLifecycleIsIdempotent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = AccountInfoManager(storage: try AccountInfoStorage(databaseDirectoryUrl: directory, databaseFileName: "account-info-storage"))
        let syncer = Syncer(
            accountInfoManager: manager,
            reader: ProbeReader(),
            storage: try SyncerStorage(databaseDirectoryUrl: directory, databaseFileName: "syncer-state-storage"),
            address: try sendTestAddress(),
            schedule: SyncSchedule(normalInterval: 60, failureBackoff: 60)
        )

        let first = syncer.start()
        let second = syncer.start()
        XCTAssertEqual(first, second)
        XCTAssertEqual(syncer.stop(), first)
        XCTAssertNil(syncer.stop())
        syncer.refresh()
    }
}

private struct ProbeReader: IAccountProvider {
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
