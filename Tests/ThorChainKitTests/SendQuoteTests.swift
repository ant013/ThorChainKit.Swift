import BigInt
import Foundation
import XCTest
@testable import ThorChainKit

final class SendQuoteTests: XCTestCase {
    func testQuoteExposesImmutableReviewProjectionAndHidesAuthority() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock, amount: BigUInt("18446744073709551617"), memo: "memo")

        XCTAssertEqual(quote.amount, BigUInt("18446744073709551617"))
        XCTAssertEqual(quote.nativeFee, 2)
        XCTAssertEqual(quote.totalDebit, BigUInt("18446744073709551619"))
        XCTAssertEqual(quote.memo, "memo")
        XCTAssertFalse(String(reflecting: quote).contains("authorityRecord"))
        XCTAssertFalse(String(reflecting: quote).contains("token"))
        XCTAssertFalse(String(reflecting: quote).contains("clientID"))
    }

    func testQuoteProjectionMismatchIsNotAuthoritative() throws {
        let clock = TestSendClock()
        let source = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: source, clock: clock)
        let tampered = SendQuote(
            recipient: quote.recipient,
            amountMagnitude: SendMagnitude(101).data,
            isMaximum: quote.isMaximum,
            nativeFeeMagnitude: SendMagnitude(2).data,
            totalDebitMagnitude: SendMagnitude(103).data,
            memo: quote.memo,
            acceptedHeight: quote.acceptedHeight,
            expiresAt: quote.expiresAt,
            authorityRecord: quote.internalAuthorityRecord
        )

        XCTAssertFalse(tampered.hasConsistentAuthorityProjection)
        XCTAssertThrowsError(try source.consume(tampered, activeGeneration: 7)) { error in
            XCTAssertEqual(error as? SendError, .operationUnavailable)
        }
    }
}
