import Foundation

enum BroadcastClassification: Sendable, Equatable {
    case checkTxAccepted
    case rejected(BroadcastRejection)
    case unknown
}

struct BroadcastClassifier: Sendable {
    func classify(localHash: TransactionID, response: BroadcastResponse?) -> BroadcastClassification {
        Self.classify(localHash: localHash, response: response)
    }

    static func classify(localHash: TransactionID, response: BroadcastResponse?) -> BroadcastClassification {
        guard let response,
              let local = StrictJSONEnvelopeDecoder.hashBytes(localHash.hash),
              let remote = StrictJSONEnvelopeDecoder.hashBytes(response.txHash),
              local == remote else { return .unknown }
        if response.code == 0 || (response.code == 19 && response.codespace == "sdk") {
            return .checkTxAccepted
        }
        if response.code == 19, response.codespace?.isEmpty != false { return .unknown }
        return .rejected(BroadcastRejection(code: response.code, codespace: response.codespace, sanitizedLog: response.sanitizedLog))
    }
}
