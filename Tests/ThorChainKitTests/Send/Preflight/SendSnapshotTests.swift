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
        XCTAssertEqual(withKey.digestHex, "44e0b701017418f997f3d0792810e907dedc1446310241361d6b090a5f844e7b")
    }

    func testDigestMatchesTheApprovedFixedVector() throws {
        XCTAssertEqual(try SendSnapshot.fixture(height: 42).digestHex, "ff5807737661ff49c0aa00a760ec82bceae2a61ebe25b071450ef2148e708761")
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
