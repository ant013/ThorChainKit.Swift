import XCTest
@testable import ThorChainKit

final class ForbiddenModuleAddressSetTests: XCTestCase {
    func testPinnedVersionAndThorchainVector() throws {
        let policy = try ForbiddenModuleAddressSet(current: "3.19.3", querier: "3.19.0")
        XCTAssertTrue(policy.contains("thor1v8ppstuf6e3x0r4glqc68d5jqcs2tf38cg2q6y"))
        XCTAssertThrowsError(try ForbiddenModuleAddressSet(current: "3.19.4", querier: "3.19.0"))
    }
}
