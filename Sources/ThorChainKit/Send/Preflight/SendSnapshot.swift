import BigInt
import CryptoKit
import Foundation

struct SendSnapshot: Equatable, Sendable {
    let familyID: String
    let chainID: String
    let height: Int64
    let sender: String
    let recipient: String
    let accountNumber: UInt64
    let sequence: UInt64
    private let amountMagnitude: Data
    private let spendableRuneMagnitude: Data
    private let nativeFeeMagnitude: Data
    private let totalDebitMagnitude: Data
    let mimir: MimirSnapshot
    let memoMaximumBytes: Int
    let nodeVersion: String
    let querierVersion: String
    let recipientClassification: RecipientAccountClassification
    let policyRevision: String
    let digest: Data

    var amount: BigUInt { amountMagnitude.isEmpty ? 0 : BigUInt(amountMagnitude) }
    var nativeFee: BigUInt { nativeFeeMagnitude.isEmpty ? 0 : BigUInt(nativeFeeMagnitude) }
    var totalDebit: BigUInt { totalDebitMagnitude.isEmpty ? 0 : BigUInt(totalDebitMagnitude) }
    var spendableRune: BigUInt { spendableRuneMagnitude.isEmpty ? 0 : BigUInt(spendableRuneMagnitude) }
    var snapshotDigest: Data { digest }
    var digestHex: String { digest.map { String(format: "%02x", $0) }.joined() }

    init(
        familyID: String, chainID: String, height: Int64, sender: String, recipient: String,
        accountNumber: UInt64, sequence: UInt64, amount: BigUInt, nativeFee: BigUInt, spendableRune: BigUInt? = nil,
        mimir: MimirSnapshot, memoMaximumBytes: Int, nodeVersion: String, querierVersion: String,
        recipientClassification: RecipientAccountClassification = .user,
        policyRevision: String = "s2-02-v1"
    ) throws {
        let total = amount + nativeFee
        guard height > 0, !familyID.isEmpty, !chainID.isEmpty, !sender.isEmpty, !recipient.isEmpty,
              amount > 0, total > 0, memoMaximumBytes > 0 else { throw SendError.operationUnavailable }
        self.familyID = familyID; self.chainID = chainID; self.height = height
        self.sender = sender; self.recipient = recipient; self.accountNumber = accountNumber; self.sequence = sequence
        amountMagnitude = SendMagnitude(amount).data; spendableRuneMagnitude = SendMagnitude(spendableRune ?? total).data; nativeFeeMagnitude = SendMagnitude(nativeFee).data
        totalDebitMagnitude = SendMagnitude(total).data; self.mimir = mimir; self.memoMaximumBytes = memoMaximumBytes
        self.nodeVersion = nodeVersion; self.querierVersion = querierVersion
        self.recipientClassification = recipientClassification; self.policyRevision = policyRevision
        digest = Self.makeDigest(
            familyID: familyID, chainID: chainID, height: height, sender: sender, recipient: recipient,
            accountNumber: accountNumber, sequence: sequence, amount: amountMagnitude, spendable: spendableRuneMagnitude, fee: nativeFeeMagnitude,
            total: totalDebitMagnitude, mimir: mimir, memoMaximumBytes: memoMaximumBytes,
            nodeVersion: nodeVersion, querierVersion: querierVersion, classification: recipientClassification,
            policyRevision: policyRevision
        )
    }

    static func fixture(height: Int64) throws -> SendSnapshot {
        try SendSnapshot(
            familyID: "rorcual-mainnet", chainID: "thorchain-1", height: height,
            sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
            recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean", accountNumber: 1, sequence: 2,
            amount: 100, nativeFee: 2, spendableRune: 102, mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256, nodeVersion: "3.19.3", querierVersion: "3.19.0"
        )
    }

    private static func makeDigest(familyID: String, chainID: String, height: Int64, sender: String, recipient: String, accountNumber: UInt64, sequence: UInt64, amount: Data, spendable: Data, fee: Data, total: Data, mimir: MimirSnapshot, memoMaximumBytes: Int, nodeVersion: String, querierVersion: String, classification: RecipientAccountClassification, policyRevision: String) -> Data {
        var data = Data()
        func append(_ value: Data) { var length = UInt64(value.count).bigEndian; data.append(Data(bytes: &length, count: 8)); data.append(value) }
        append(Data(familyID.utf8)); append(Data(chainID.utf8)); append(Data(String(height).utf8)); append(Data(sender.utf8)); append(Data(recipient.utf8))
        append(Data(String(accountNumber).utf8)); append(Data(String(sequence).utf8)); append(amount); append(spendable); append(fee); append(total)
        append(Data("\(mimir.haltChainGlobal),\(mimir.nodePauseChainGlobal),\(mimir.haltTHORChain),\(mimir.solvencyHaltTHORChain)".utf8))
        append(Data(String(memoMaximumBytes).utf8)); append(Data(nodeVersion.utf8)); append(Data(querierVersion.utf8)); append(Data(classification.rawValue.utf8)); append(Data(policyRevision.utf8))
        return Data(SHA256.hash(data: data))
    }
}
