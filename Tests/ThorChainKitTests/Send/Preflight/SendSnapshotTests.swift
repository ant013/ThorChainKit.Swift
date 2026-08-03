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

    func testDigestIncludesPublicKeyAndPolicyState() throws {
        let base = try SendSnapshot.fixture(height: 42)
        let withKey = try SendSnapshot(
            familyID: base.familyID, chainID: base.chainID, height: base.height, sender: base.sender, recipient: base.recipient,
            accountNumber: base.accountNumber, sequence: base.sequence, amount: base.amount, nativeFee: base.nativeFee,
            spendableRune: base.spendableRune, mimir: base.mimir, memoMaximumBytes: base.memoMaximumBytes,
            policyRevision: base.policyRevision, accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: Data([2] + Array(repeating: 1, count: 32))
        )
        XCTAssertNotEqual(base.digest, withKey.digest)
        XCTAssertEqual(withKey.digestHex, "2a17c9aed3b970f1600a1a0487b56aa2411f03e8ec679d791a26739eb0b406d2")
    }

    func testDigestMatchesTheApprovedFixedVector() throws {
        // Re-approved when the node version left the snapshot: the preflight no longer
        // reads /thorchain/version, so the digest cannot bind what it never saw.
        XCTAssertEqual(try SendSnapshot.fixture(height: 42).digestHex, "5c0debb7ac331484b77c9b0f8e762fcfbc057a49c2688db00f2277c4eb14a3c6")
    }

    func testPublicKeyStateRejectsImpossibleAndUncompressedValues() throws {
        let base = try SendSnapshot.fixture(height: 42)
        for (typeURL, data) in [
            ("/cosmos.crypto.secp256k1.PubKey" as String?, nil as Data?),
            (nil as String?, Data([2] + Array(repeating: 1, count: 32))),
            ("/cosmos.crypto.secp256k1.PubKey" as String?, Data([4] + Array(repeating: 1, count: 32)))
        ] {
            XCTAssertThrowsError(try SendSnapshot(
                familyID: base.familyID, chainID: base.chainID, height: base.height, sender: base.sender, recipient: base.recipient,
                accountNumber: base.accountNumber, sequence: base.sequence, amount: base.amount, nativeFee: base.nativeFee,
                spendableRune: base.spendableRune, mimir: base.mimir, memoMaximumBytes: base.memoMaximumBytes,
                policyRevision: base.policyRevision, accountPublicKey: typeURL, accountPublicKeyData: data
            ))
        }
    }
}
