import Foundation
import XCTest
@testable import ThorChainKit

final class RedactionTests: XCTestCase {
    func testRawNodeLogNeverLeavesEnumDiagnosticSurface() throws {
        let canary = "node-controlled-raw-log"
        let rejection = BroadcastRejection(code: 12, codespace: "sdk", sanitizedLog: .invalidResponse)
        let error = SendError.broadcastRejected(rejection)

        XCTAssertFalse(error.description.contains(canary))
        XCTAssertFalse(String(reflecting: error).contains(canary))
        XCTAssertEqual(rejection.sanitizedLog, "invalidResponse")
    }
}
