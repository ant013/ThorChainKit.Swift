import Foundation
import XCTest
@testable import ThorChainKit

final class SendRuntimeOwnershipTests: XCTestCase {
    func testPerKitLifecycleIsIndependentOfSharedRepair() async throws {
        let sender = try sendTestAddress()
        let namespace = "ownership-\(UUID().uuidString)"
        let first = SendRuntime(address: sender, clientID: UUID(), persistenceNamespace: namespace)
        let second = SendRuntime(address: sender, clientID: UUID(), persistenceNamespace: namespace)
        await first.activate(generation: 1)
        await second.activate(generation: 1)
        let firstActive = await first.isAdmissionActive()
        let secondActive = await second.isAdmissionActive()
        XCTAssertTrue(firstActive)
        XCTAssertTrue(secondActive)

        await first.invalidate(generation: 1)

        let firstStopped = await first.isAdmissionActive()
        let secondStillActive = await second.isAdmissionActive()
        XCTAssertFalse(firstStopped)
        XCTAssertTrue(secondStillActive)
    }

    func testOnlySharedRuntimeOwnsRecovery() throws {
        let namespace = "ownership-recovery-\(UUID().uuidString)"
        let state = SendRuntimeRegistry.shared.state(for: namespace, runtimeIdentifier: "fixture")
        XCTAssertTrue(state.claimRecovery())
        XCTAssertFalse(state.claimRecovery())
        state.releaseRecovery()
        XCTAssertTrue(state.claimRecovery())
        state.releaseRecovery()
    }
}
