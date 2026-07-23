import BigInt
import Foundation
import XCTest
@testable import ThorChainKit

final class SendReflectionTests: XCTestCase {
    func testPublicSendReflectionsContainOnlyReviewedFields() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock, memo: "reviewed")
        let error = SendError.broadcastRejected(
            BroadcastRejection(code: 4, codespace: "secret-provider", sanitizedLog: .invalidResponse)
        )
        let request = SigningRequest(
            digest: Data(repeating: 0xAB, count: 32),
            serializedSignDoc: Data(repeating: 0xCD, count: 8),
            chainId: "thorchain-1",
            requestId: "opaque",
            summary: SigningRequest.Summary(
                sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
                recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
                amount: "100.00000000",
                nativeFee: "0.00000000",
                totalDebit: "100.00000000",
                memo: nil,
                accountNumber: "15",
                sequence: "5"
            )
        )!
        let pending = PendingTransaction(
            transactionId: try XCTUnwrap(TransactionID(hash: String(repeating: "B", count: 64))),
            recipient: try sendTestAddress(),
            amountMagnitude: SendMagnitude(BigUInt("18446744073709551617")).data,
            nativeFeeMagnitude: SendMagnitude(1).data,
            memo: nil,
            state: .unknown,
            retryAvailability: .notApplicable,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let token = quote.internalAuthorityRecord.envelope.token.map { String(format: "%02X", $0) }.joined()

        let quoteOutput = "\(quote) \(String(reflecting: quote))"
        let errorOutput = "\(error) \(String(reflecting: error))"
        XCTAssertTrue(quoteOutput.contains("reviewed"))
        XCTAssertFalse(quoteOutput.contains("authorityRecord"))
        XCTAssertFalse(quoteOutput.contains("token"))
        XCTAssertFalse(errorOutput.contains("secret-provider"))
        XCTAssertFalse(errorOutput.contains("response"))

        for representation in [String(describing: quote), String(reflecting: quote),
                               String(describing: error), String(reflecting: error),
                               capturedDump(quote), capturedDump(request),
                               capturedDump(pending), capturedDump(error)] {
            XCTAssertFalse(representation.contains("authorityRecord"))
            XCTAssertFalse(representation.contains("token"))
            XCTAssertFalse(representation.contains(token))
            XCTAssertFalse(representation.contains("digest"))
            XCTAssertFalse(representation.contains("serializedSignDoc"))
            XCTAssertFalse(representation.contains("ABAB"))
            XCTAssertFalse(representation.contains("CDCD"))
            XCTAssertFalse(representation.contains("secret-provider"))
            XCTAssertFalse(representation.contains("responseBody"))
            XCTAssertFalse(representation.contains("https://"))
            XCTAssertFalse(representation.contains("credential"))
            XCTAssertFalse(representation.contains("privateKey"))
            XCTAssertFalse(representation.contains("signature"))
            XCTAssertFalse(representation.contains("SignDoc"))
            XCTAssertFalse(representation.contains("TxRaw"))
            XCTAssertFalse(representation.contains("raw-codespace"))
            XCTAssertFalse(representation.contains("response text"))
        }
    }

    func testPendingReflectionOmitsStoredMagnitudeFields() throws {
        let pending = PendingTransaction(
            transactionId: try XCTUnwrap(TransactionID(hash: String(repeating: "B", count: 64))),
            recipient: try sendTestAddress(),
            amountMagnitude: SendMagnitude(BigUInt("18446744073709551617")).data,
            nativeFeeMagnitude: SendMagnitude(1).data,
            memo: nil,
            state: .unknown,
            retryAvailability: .notApplicable,
            createdAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertFalse(String(reflecting: pending).contains("amountMagnitude"))
        XCTAssertFalse(String(reflecting: pending).contains("nativeFeeMagnitude"))
    }
}

private func capturedDump<T>(_ value: T) -> String {
    var output = StringDumpOutput()
    dump(value, to: &output)
    return output.value
}

private struct StringDumpOutput: TextOutputStream {
    var value = ""

    mutating func write(_ string: String) {
        value.append(string)
    }
}
