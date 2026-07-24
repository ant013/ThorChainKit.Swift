import Foundation
import XCTest
@testable import ThorChainKit

final class BroadcastClassifierTests: XCTestCase {
    func testHashMismatchWinsOverCode() throws {
        let local = try XCTUnwrap(TransactionID(hash: String(repeating: "A", count: 64)))
        let response = BroadcastResponse(txHash: String(repeating: "B", count: 64), code: 0, codespace: nil, sanitizedLog: nil)
        XCTAssertEqual(BroadcastClassifier.classify(localHash: local, response: response), .unknown)
    }

    func testSdkDuplicateCodeIsAcceptedOnlyWithMatchingHash() throws {
        let local = try XCTUnwrap(TransactionID(hash: String(repeating: "A", count: 64)))
        let response = BroadcastResponse(txHash: local.hash, code: 19, codespace: "sdk", sanitizedLog: nil)
        XCTAssertEqual(BroadcastClassifier.classify(localHash: local, response: response), .checkTxAccepted)
    }
}
