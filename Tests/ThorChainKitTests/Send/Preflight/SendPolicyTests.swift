import BigInt
import XCTest
@testable import ThorChainKit

final class SendPolicyTests: XCTestCase {
    func testFeeSharingIsReadFromTheFlagAndNotFromTheBalancesBeingEqual() throws {
        let policy = try SendPolicy()

        // Same two balances, opposite flag: the RUNE reading must subtract the fee and
        // the token reading must not. If `feeSharesBalance` were ever derived by
        // comparing the two amounts, these two calls would return the same number.
        let asRune = try policy.resolve(amount: .maximum, spendable: 500, spendableRune: 500, nativeFee: 2, feeSharesBalance: true)
        let asToken = try policy.resolve(amount: .maximum, spendable: 500, spendableRune: 500, nativeFee: 2, feeSharesBalance: false)

        XCTAssertEqual(asRune, 498)
        XCTAssertEqual(asToken, 500)
    }

    func testTokenMaximumIsTheWholeTokenBalanceBecauseTheFeeComesFromRune() throws {
        let policy = try SendPolicy()

        // Sending a token: the fee is charged in RUNE, so it must not shave the amount.
        XCTAssertEqual(
            try policy.resolve(amount: .maximum, spendable: 500, spendableRune: 10, nativeFee: 2, feeSharesBalance: false),
            500
        )
        // Sending RUNE: the same coins fund both, so the fee does come off the maximum.
        XCTAssertEqual(
            try policy.resolve(amount: .maximum, spendable: 500, spendableRune: 500, nativeFee: 2, feeSharesBalance: true),
            498
        )
    }

    func testTokenSendFailsWhenRuneCannotCoverTheFeeHoweverLargeTheTokenBalance() throws {
        let policy = try SendPolicy()

        XCTAssertThrowsError(
            try policy.resolve(amount: .exact(1), spendable: BigUInt(10).power(30), spendableRune: 1, nativeFee: 2, feeSharesBalance: false)
        ) { XCTAssertEqual($0 as? SendError, .insufficientBalance) }
    }

    func testTokenAmountIsCappedByTheTokenBalanceAloneAndNotByRune() throws {
        let policy = try SendPolicy()

        XCTAssertEqual(
            try policy.resolve(amount: .exact(500), spendable: 500, spendableRune: 10, nativeFee: 2, feeSharesBalance: false),
            500
        )
        XCTAssertThrowsError(
            try policy.resolve(amount: .exact(501), spendable: 500, spendableRune: 10, nativeFee: 2, feeSharesBalance: false)
        ) { XCTAssertEqual($0 as? SendError, .insufficientBalance) }
    }

    func testMemoUsesUTF8BytesAndCanonicalPositiveLimit() throws {
        let policy = try SendPolicy(memoMaximumBytes: 4)

        XCTAssertNoThrow(try policy.validate(memo: "éé"))
        XCTAssertThrowsError(try policy.validate(memo: "ééa")) { error in
            XCTAssertEqual(error as? SendError, .memoTooLong(maxUTF8Bytes: 4))
        }
        XCTAssertThrowsError(try SendPolicy(memoMaximumBytes: 0))
        XCTAssertThrowsError(try SendPolicy(memoMaximumBytes: 4, revision: ""))
    }

    func testMaximumUsesSpendableMinusFeeWithoutOverflow() throws {
        let policy = try SendPolicy()
        let spendable = BigUInt("340282366920938463463374607431768211455")
        let fee = BigUInt("18446744073709551615")
        let amount = try policy.resolve(amount: .maximum, spendable: spendable, spendableRune: spendable, nativeFee: fee, feeSharesBalance: true)
        XCTAssertEqual(amount, spendable - fee)
        XCTAssertThrowsError(try policy.resolve(amount: .maximum, spendable: fee, spendableRune: fee, nativeFee: spendable, feeSharesBalance: true))
    }

    func testAmountAndFeeBoundaryMatrix() throws {
        let policy = try SendPolicy()
        XCTAssertEqual(try policy.resolve(amount: .exact(1), spendable: 2, spendableRune: 2, nativeFee: 1, feeSharesBalance: true), 1)
        for amount in [SendAmount.exact(0), SendAmount.exact(3)] {
            XCTAssertThrowsError(try policy.resolve(amount: amount, spendable: 2, spendableRune: 2, nativeFee: 1, feeSharesBalance: true))
        }
        for (spendable, fee) in [(0, 0), (1, 2), (2, 2)] {
            XCTAssertThrowsError(try policy.resolve(amount: .maximum, spendable: BigUInt(spendable), spendableRune: BigUInt(spendable), nativeFee: BigUInt(fee), feeSharesBalance: true))
        }
    }
}
