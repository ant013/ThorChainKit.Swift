import Foundation
import XCTest
@testable import ThorChainKit

final class StrictJSONEnvelopeDecoderTests: XCTestCase {
    func testDuplicateKeysAndTrailingTokensAreNotAuthoritative() {
        let decoder = StrictJSONEnvelopeDecoder()
        XCTAssertThrowsError(try decoder.decode(Data(#"{"tx_response":{"txhash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","code":0,"code":1}}"#.utf8)))
        XCTAssertThrowsError(try decoder.decode(Data(#"{"tx_response":{"txhash":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA","code":0}} trailing"#.utf8)))
    }

    func testBroadcastEnvelopeReturnsOnlyBoundedFields() throws {
        let data = Data(#"{"tx_response":{"txhash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","code":19,"codespace":"sdk","raw_log":"node secret"}}"#.utf8)
        let response = try StrictJSONEnvelopeDecoder().decode(data)
        XCTAssertEqual(response.txHash, String(repeating: "A", count: 64))
        XCTAssertEqual(response.code, 19)
        XCTAssertEqual(response.codespace, "sdk")
        XCTAssertEqual(response.sanitizedLog, .invalidResponse)
    }
}
