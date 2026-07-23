import Foundation

public struct SigningRequest: Sendable, CustomDebugStringConvertible, CustomReflectable {
    public struct Summary: Sendable {
        public let sender: String
        public let recipient: String
        public let amount: String
        public let nativeFee: String
        public let totalDebit: String
        public let memo: String?
        public let accountNumber: String
        public let sequence: String

        internal init(
            sender: String,
            recipient: String,
            amount: String,
            nativeFee: String,
            totalDebit: String,
            memo: String?,
            accountNumber: String,
            sequence: String
        ) {
            self.sender = sender
            self.recipient = recipient
            self.amount = amount
            self.nativeFee = nativeFee
            self.totalDebit = totalDebit
            self.memo = memo
            self.accountNumber = accountNumber
            self.sequence = sequence
        }
    }

    public let digest: Data
    public let serializedSignDoc: Data
    public let chainId: String
    public let requestId: String
    public let summary: Summary

    internal init?(
        digest: Data,
        serializedSignDoc: Data,
        chainId: String,
        requestId: String,
        summary: Summary
    ) {
        guard digest.count == 32,
              !serializedSignDoc.isEmpty,
              !chainId.isEmpty,
              !requestId.isEmpty
        else { return nil }
        self.digest = digest
        self.serializedSignDoc = serializedSignDoc
        self.chainId = chainId
        self.requestId = requestId
        self.summary = summary
    }

    public var debugDescription: String {
        "SigningRequest(chainId: \(chainId), requestId: \(requestId), summary: \(summary.sender) -> \(summary.recipient), amount: \(summary.amount), nativeFee: \(summary.nativeFee), totalDebit: \(summary.totalDebit), memo: \(summary.memo ?? "nil"))"
    }

    public var customMirror: Mirror {
        Mirror(self, children: [
            "chainId": chainId,
            "requestId": requestId,
            "summary": summary
        ], displayStyle: .struct)
    }
}
