import BigInt
import CryptoKit
import Foundation
import secp256k1
import XCTest
@testable import ThorChainKit

final class DirectSignCodecTests: XCTestCase {
    private let sender = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68"
    private let recipient = "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean"
    private let publicKey = Data(hex: "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
    private let signature = Data(hex: "23103daa64330d051da3bfa85ea7c8af9080edf19b19a306403303634b0992a32cc1b9061b2e76cd245edb2976bb437bc6636dfb23deae31e38508c5478dae45")

    func testOfficialScalarOneVectorMatchesEverySignedByteAndHash() throws {
        let snapshot = try makeSnapshot()
        let payload = try makePayload(snapshot: snapshot)

        XCTAssertEqual(payload.signDocBytes.count, 193)
        XCTAssertEqual(payload.digest.hex, "1ff56dd4c3627af0cee040965178f50c8d7c854e909d7b54aedbd1b7bf110b68")

        let signed = try DirectSignCodec.makeTxRaw(payload: payload, compactSignature: signature)
        XCTAssertEqual(signed.txRaw.hex, "0a530a510a0e2f74797065732e4d736753656e64123f0a14751e76e8199196d454941c45d1b3a323f1433bd612145a0dba49dab8fec87c6dd7c01b564ee72a8515a61a110a0472756e65120931303030303030303012590a500a460a1f2f636f736d6f732e63727970746f2e736563703235366b312e5075624b657912230a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f8179812040a0208011801120510c08db7011a4023103daa64330d051da3bfa85ea7c8af9080edf19b19a306403303634b0992a32cc1b9061b2e76cd245edb2976bb437bc6636dfb23deae31e38508c5478dae45")
        XCTAssertEqual(signed.transactionID.hash, "3685BF7AD0C65889B763D4B6D1F1EDEEC96E9B63B63F8DB992D00757EB5F136E")

        let decodedRaw = try Cosmos_Tx_V1beta1_TxRaw(serializedBytes: signed.txRaw)
        let decodedBody = try Cosmos_Tx_V1beta1_TxBody(serializedBytes: decodedRaw.bodyBytes)
        let decodedMessage = try Types_MsgSend(serializedBytes: decodedBody.messages[0].value)
        XCTAssertEqual(decodedBody.messages.count, 1)
        XCTAssertEqual(decodedBody.messages[0].typeURL, "/types.MsgSend")
        XCTAssertEqual(decodedMessage.amount.first?.denom, "rune")
        XCTAssertEqual(decodedMessage.amount.first?.amount, "100000000")
        XCTAssertEqual(decodedRaw.signatures, [signature])
    }

    func testConstructionIsDeterministicAndUsesExactTxRawBytes() throws {
        let snapshot = try makeSnapshot()
        let first = try makePayload(snapshot: snapshot)
        let second = try makePayload(snapshot: snapshot)
        XCTAssertEqual(first.signDocBytes, second.signDocBytes)
        XCTAssertEqual(first.bodyBytes, second.bodyBytes)
        XCTAssertEqual(first.authInfoBytes, second.authInfoBytes)

        let signed = try DirectSignCodec.makeTxRaw(payload: first, compactSignature: signature)
        var mutated = signed.txRaw
        mutated[mutated.startIndex] ^= 1
        XCTAssertNotEqual(DirectSignCodec.transactionId(txRaw: signed.txRaw), DirectSignCodec.transactionId(txRaw: mutated))
    }

    func testTxRawRejectsEverySignatureLengthExceptCompact() throws {
        let payload = try makePayload(snapshot: makeSnapshot())
        for length in [0, 63, 65] {
            XCTAssertThrowsError(try DirectSignCodec.makeTxRaw(payload: payload, compactSignature: Data(repeating: 0, count: length)))
        }
        XCTAssertNoThrow(try DirectSignCodec.makeTxRaw(payload: payload, compactSignature: Data(repeating: 0, count: 64)))
    }

    func testLegacyTwentyMillionGasIsOnlyACompatibilityControl() throws {
        let legacySender = "thor18altpx2gwt4c4ejr5uzda4kyzsudyn9q56fnng"
        let legacyPublicKey = Data(hex: "023e4b76861289ad4528b33c2fd21b3a5160cd37b3294234914e21efb6ed4a452b")
        let payload = try makePayload(sender: legacySender, publicKey: legacyPublicKey)
        var auth = try Cosmos_Tx_V1beta1_AuthInfo(serializedBytes: payload.authInfoBytes)
        auth.fee.gasLimit = 20_000_000
        var signDoc = Cosmos_Tx_V1beta1_SignDoc()
        signDoc.bodyBytes = payload.bodyBytes
        signDoc.authInfoBytes = try auth.serializedData()
        signDoc.chainID = "thorchain-1"
        signDoc.accountNumber = 123_456
        let legacyDigest = Data(SHA256.hash(data: try signDoc.serializedData()))
        XCTAssertEqual(legacyDigest.hex, "7e513b23957b2e3caf77e796ba1412851be066cd77f96a7d196c3c856c641ebf")
    }

    func testVultisigInputsUseOfficialGasInProductionCodec() throws {
        let legacySender = "thor18altpx2gwt4c4ejr5uzda4kyzsudyn9q56fnng"
        let legacyPublicKey = Data(hex: "023e4b76861289ad4528b33c2fd21b3a5160cd37b3294234914e21efb6ed4a452b")
        let payload = try makePayload(sender: legacySender, publicKey: legacyPublicKey)
        XCTAssertEqual(payload.signDocBytes.count, 193)
        XCTAssertEqual(payload.digest.hex, "83a508ff301fc5cf7ab5126d861e7bac8dd1ebc5691df4842d6b2ac84dd3668f")
    }

    func testStaticSignatureIsVerifiedOnlyByIndependentTestOracle() throws {
        let payload = try makePayload(snapshot: makeSnapshot())
        let key = try secp256k1.Signing.PublicKey(rawRepresentation: publicKey, format: .compressed)
        let parsedSignature = try secp256k1.Signing.ECDSASignature(compactRepresentation: signature)
        XCTAssertTrue(key.ecdsa.isValidSignature(parsedSignature, for: SHA256.hash(data: payload.signDocBytes)))
    }

    func testCodecRejectsMaximumMemoOverflowAndMalformedPublicKeyFraming() throws {
        let snapshot = try makeSnapshot()
        XCTAssertThrowsError(try makePayload(snapshot: snapshot, isMaximum: true))
        XCTAssertThrowsError(try makePayload(snapshot: snapshot, memo: String(repeating: "a", count: 257)))
        for malformedKey in [Data(repeating: 2, count: 32), Data([4] + Array(repeating: UInt8(0), count: 32))] {
            XCTAssertThrowsError(try makePayload(snapshot: snapshot, publicKey: malformedKey))
        }
    }

    private func makePayload(snapshot: SendSnapshot, publicKey: Data? = nil, isMaximum: Bool = false, memo: String? = nil) throws -> SignPayload {
        let quote = try makeQuote(sender: snapshot.sender, isMaximum: isMaximum, memo: memo, preflightContext: snapshot)
        return try DirectSignCodec.makeSignPayload(
            snapshot: snapshot,
            quote: PreparedQuote(quote: quote, snapshot: snapshot),
            publicKey: publicKey ?? self.publicKey
        )
    }

    private func makePayload(sender: String, publicKey: Data) throws -> SignPayload {
        let snapshot = try makeSnapshot(sender: sender, publicKey: publicKey)
        return try makePayload(snapshot: snapshot, publicKey: publicKey)
    }

    private func makeSnapshot(sender: String = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68", publicKey: Data? = nil) throws -> SendSnapshot {
        try SendSnapshot(
            familyID: "thorchain-mainnet",
            chainID: "thorchain-1",
            height: 1,
            sender: sender,
            recipient: recipient,
            accountNumber: 123_456,
            sequence: 1,
            amount: BigUInt(100_000_000),
            nativeFee: 0,
            spendableRune: BigUInt(100_000_000),
            mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256,
            nodeVersion: "3.19.3",
            querierVersion: "3.19.3",
            accountPublicKey: "/cosmos.crypto.secp256k1.PubKey",
            accountPublicKeyData: publicKey ?? self.publicKey
        )
    }

    private func makeQuote(sender: String = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68", isMaximum: Bool = false, memo: String? = nil, preflightContext: SendSnapshot? = nil) throws -> SendQuote {
        let clock = TestSendClock()
        return try QuoteStore(clock: clock).issue(
            sender: try Address(sender, network: .mainnet),
            recipient: try Address(recipient, network: .mainnet),
            amountMagnitude: SendMagnitude(BigUInt(100_000_000)).data,
            isMaximum: isMaximum,
            nativeFeeMagnitude: Data(),
            totalDebitMagnitude: SendMagnitude(BigUInt(100_000_000)).data,
            memo: memo,
            acceptedHeight: 1,
            generation: 1,
            accountNumber: 123_456,
            sequence: 1,
            providerFamilyID: "thorchain-mainnet",
            preflightContext: preflightContext
        )
    }
}

private extension Data {
    init(hex: String) {
        self.init(hex.chunked(2).map { UInt8($0, radix: 16)! })
    }

    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

private extension String {
    func chunked(_ size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: min(size, distance(from: start, to: endIndex)))
            return String(self[start..<end])
        }
    }
}
