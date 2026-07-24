import BigInt
import XCTest
@testable import ThorChainKit

final class SendPolicyTests: XCTestCase {
    func testMemoUsesUTF8BytesAndCanonicalPositiveLimit() throws {
        let policy = try SendPolicy(memoMaximumBytes: 4, operationDeadline: 1)

        XCTAssertNoThrow(try policy.validate(memo: "éé"))
        XCTAssertThrowsError(try policy.validate(memo: "ééa")) { error in
            XCTAssertEqual(error as? SendError, .memoTooLong(maxUTF8Bytes: 4))
        }
        XCTAssertThrowsError(try SendPolicy(memoMaximumBytes: 0, operationDeadline: 1))
        XCTAssertThrowsError(try SendPolicy(memoMaximumBytes: 4, operationDeadline: 0))
    }
}
