import Foundation
import XCTest
@testable import ThorChainKit

final class SendCoordinatorConcurrencyTests: XCTestCase {
    func testSameAccountDifferentSequencesUseOneGate() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-gate")
        await runtime.activate(generation: 1)

        let firstAdmission = await runtime.beginAccountAttempt("sender")
        let secondAdmission = await runtime.beginAccountAttempt("sender")
        XCTAssertTrue(firstAdmission)
        XCTAssertFalse(secondAdmission)
        await runtime.endAccountAttempt("sender")
        let freshAdmission = await runtime.beginAccountAttempt("sender")
        XCTAssertTrue(freshAdmission)
        await runtime.endAccountAttempt("sender")
    }

    func testReleasedSignerFenceAllowsExactlyOneFreshAttempt() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-release")
        await runtime.activate(generation: 1)

        let fence = await runtime.beginSignerFence("sender")
        XCTAssertTrue(fence)
        await runtime.endSignerFence("sender")
        let firstAdmission = await runtime.beginAccountAttempt("sender")
        let secondAdmission = await runtime.beginAccountAttempt("sender")
        XCTAssertTrue(firstAdmission)
        XCTAssertFalse(secondAdmission)
        await runtime.endAccountAttempt("sender")
    }

    func testCancelledSignerRetainsFence() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-fence")
        await runtime.activate(generation: 1)

        let fence = await runtime.beginSignerFence("sender")
        let blockedAdmission = await runtime.beginAccountAttempt("sender")
        XCTAssertTrue(fence)
        XCTAssertFalse(blockedAdmission)
        await runtime.endSignerFence("sender")
        let freshAdmission = await runtime.beginAccountAttempt("sender")
        XCTAssertTrue(freshAdmission)
        await runtime.endAccountAttempt("sender")
    }
}
