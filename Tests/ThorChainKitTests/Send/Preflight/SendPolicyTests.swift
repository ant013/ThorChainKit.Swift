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

    func testMaximumUsesSpendableMinusFeeWithoutOverflow() throws {
        let policy = try SendPolicy()
        let spendable = BigUInt("340282366920938463463374607431768211455")
        let fee = BigUInt("18446744073709551615")
        let amount = try policy.resolve(amount: .maximum, spendableRune: spendable, nativeFee: fee)
        XCTAssertEqual(amount, spendable - fee)
        XCTAssertThrowsError(try policy.resolve(amount: .maximum, spendableRune: fee, nativeFee: spendable))
    }

    func testAmountAndFeeBoundaryMatrix() throws {
        let policy = try SendPolicy()
        XCTAssertEqual(try policy.resolve(amount: .exact(1), spendableRune: 2, nativeFee: 1), 1)
        for amount in [SendAmount.exact(0), SendAmount.exact(3)] {
            XCTAssertThrowsError(try policy.resolve(amount: amount, spendableRune: 2, nativeFee: 1))
        }
        for (spendable, fee) in [(0, 0), (1, 2), (2, 2)] {
            XCTAssertThrowsError(try policy.resolve(amount: .maximum, spendableRune: BigUInt(spendable), nativeFee: BigUInt(fee)))
        }
    }
}
