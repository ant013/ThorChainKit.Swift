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
            nodeVersion: base.nodeVersion, querierVersion: base.querierVersion, recipientClassification: base.recipientClassification,
            policyRevision: base.policyRevision, accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: Data([2] + Array(repeating: 1, count: 32))
        )
        XCTAssertNotEqual(base.digest, withKey.digest)
        XCTAssertEqual(withKey.digestHex, "3d73e3368f3431b3013cb95bcebf510e1bf537bfc771182d729a2b431ca41a42")
    }

    func testDigestMatchesTheApprovedFixedVector() throws {
        // Re-approved when the digest began binding the denom and the amount's own
        // spendable balance, so a TCY quote can no longer match a RUNE snapshot.
        XCTAssertEqual(try SendSnapshot.fixture(height: 42).digestHex, "daadbe8f89434522f1a8e3d60dc3bedfdef4068b4194023954bc82ca9bb524ae")
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
                nodeVersion: base.nodeVersion, querierVersion: base.querierVersion, recipientClassification: base.recipientClassification,
                policyRevision: base.policyRevision, accountPublicKey: typeURL, accountPublicKeyData: data
            ))
        }
    }
}
