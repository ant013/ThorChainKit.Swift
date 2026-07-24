import Foundation
import XCTest
@testable import ThorChainKit

final class SigningRequestRedactionTests: XCTestCase {
    func testDebugAndMirrorDoNotExposeSigningBytes() throws {
        let digest = Data(repeating: 0xa5, count: 32)
        let signDoc = Data(repeating: 0x5a, count: 8)
        let summary = SigningRequest.Summary(
            sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
            recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
            amount: "0.00000100",
            nativeFee: "0.00000002",
            totalDebit: "0.00000102",
            memo: nil,
            accountNumber: "1",
            sequence: "2"
        )
        let request = try XCTUnwrap(SigningRequest(
            digest: digest,
            serializedSignDoc: signDoc,
            chainId: "thorchain-1",
            requestId: "request",
            summary: summary
        ))

        XCTAssertFalse(request.debugDescription.contains("a5"))
        XCTAssertFalse(request.customMirror.children.contains { String(describing: $0.value).contains("5a") })
    }
}
