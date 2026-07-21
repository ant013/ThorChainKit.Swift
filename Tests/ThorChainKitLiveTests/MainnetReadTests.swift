import Foundation
import XCTest
@testable import ThorChainKit

final class MainnetReadTests: XCTestCase {
    func testOptInMainnetReadRequiresExplicitInputs() async throws {
        guard ProcessInfo.processInfo.environment["THORCHAIN_RUN_LIVE"] == "1" else {
            XCTFail("THORCHAIN_RUN_LIVE=1 is required for the explicit live target")
            return
        }
        XCTAssertFalse(ProcessInfo.processInfo.environment["THORCHAIN_PROVIDER_CREDENTIAL"] != nil)
    }
}
