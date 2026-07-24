import BigInt
import XCTest
@testable import ThorChainKit

final class SendSnapshotTests: XCTestCase {
    func testDigestIsStableForTheSameCanonicalSnapshot() throws {
        let first = try SendSnapshot.fixture(height: 42)
        let second = try SendSnapshot.fixture(height: 42)
        XCTAssertEqual(first.digest, second.digest)
        XCTAssertNotEqual(first.digest, try SendSnapshot.fixture(height: 43).digest)
        XCTAssertEqual(first.amount + first.nativeFee, first.totalDebit)
    }
}
