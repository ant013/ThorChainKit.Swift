import XCTest
@testable import ThorChainKit

final class SendRouteDecoderTests: XCTestCase {
    func testFeeAllowsZeroAndRejectsMalformedBounds() throws {
        var response = Types_QueryNetworkResponse()
        response.nativeTxFeeRune = "0"
        XCTAssertEqual(try SendRouteDecoders.networkFee(response.serializedData()), 0)
        for value in ["", "-1", "01", "18446744073709551616", "184467440737095516160000000000000000000"] {
            response.nativeTxFeeRune = value
            XCTAssertThrowsError(try SendRouteDecoders.networkFee(response.serializedData()))
        }
    }

    func testBalanceRequiresLiteralRuneAndCanonicalUnsignedAmount() throws {
        XCTAssertEqual(try SendRouteDecoders.balance(Data(#"{"balance":{"denom":"rune","amount":"0"}}"#.utf8)).amount, "0")
        for body in [
            #"{"balance":{"denom":"RUNE","amount":"1"}}"#,
            #"{"balance":{"denom":"rune","amount":"01"}}"#,
            #"{"balance":{"denom":"rune","amount":"-1"}}"#,
            #"{"balance":{"denom":"rune","amount":"1","extra":true}}"#,
            #"{"denom":"rune","amount":"1"}"#
        ] {
            XCTAssertThrowsError(try SendRouteDecoders.balance(Data(body.utf8)))
        }
        for body in [
            #"{"balance":{"denom":"rune"}}"#,
            #"{"balance":{"denom":"rune","amount":1}}"#,
            #"{"balance":{"denom":"rune","amount":""}}"#
        ] {
            XCTAssertThrowsError(try SendRouteDecoders.balance(Data(body.utf8)))
        }
    }

    func testMimirBoundsAndExactShape() throws {
        XCTAssertEqual(try SendRouteDecoders.mimir(Data("-1".utf8)), -1)
        XCTAssertEqual(try SendRouteDecoders.mimir(Data("9223372036854775807".utf8)), Int64.max)
        for body in ["", "-2", #"{"value":1}"#, "\"bad\"", "9223372036854775808"] {
            XCTAssertThrowsError(try SendRouteDecoders.mimir(Data(body.utf8)))
        }
    }

    func testAuthAndVersionRequireExactTypedFields() throws {
        let auth = #"{"params":{"max_memo_characters":"256","tx_sig_limit":"7","tx_size_cost_per_byte":"10","sig_verify_cost_ed25519":"590","sig_verify_cost_secp256k1":"1000"}}"#
        XCTAssertEqual(try SendRouteDecoders.authMaximum(Data(auth.utf8)), 256)
        let version = #"{"current":"3.19.3","next":"3.19.3","next_since_height":"0","querier":"3.19.0"}"#
        XCTAssertEqual(try SendRouteDecoders.version(Data(version.utf8)).current, "3.19.3")
        for body in [
            #"{"params":{"max_memo_characters":"0","tx_sig_limit":"7","tx_size_cost_per_byte":"10","sig_verify_cost_ed25519":"590","sig_verify_cost_secp256k1":"1000"}}"#,
            #"{"params":{"max_memo_characters":"-1","tx_sig_limit":"7","tx_size_cost_per_byte":"10","sig_verify_cost_ed25519":"590","sig_verify_cost_secp256k1":"1000"}}"#,
            #"{"params":{"max_memo_characters":"18446744073709551616","tx_sig_limit":"7","tx_size_cost_per_byte":"10","sig_verify_cost_ed25519":"590","sig_verify_cost_secp256k1":"1000"}}"#,
            #"{"params":{"max_memo_characters":"256","tx_sig_limit":"7"}}"#,
        ] {
            XCTAssertThrowsError(try SendRouteDecoders.authMaximum(Data(body.utf8)))
        }
        for body in [
            #"{"current":"3.19.3","next":"3.19.3","next_since_height":"0"}"#,
            #"{"current":"","next":"3.19.3","next_since_height":"0","querier":"3.19.0"}"#,
            #"{"current":"3.19.3","next":"3.19.3","next_since_height":"9223372036854775808","querier":"3.19.0"}"#,
            #"{"current":"3.19.3","next":"3.19.3","next_since_height":"0","querier":"","extra":true}"#
        ] {
            XCTAssertThrowsError(try SendRouteDecoders.version(Data(body.utf8)))
        }
    }
}
