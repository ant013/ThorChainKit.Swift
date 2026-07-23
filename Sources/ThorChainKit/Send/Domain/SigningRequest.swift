import BigInt
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
              Self.isCanonicalBech32Address(summary.sender),
              Self.isCanonicalBech32Address(summary.recipient),
              Self.isRuneAmountSummary(summary.amount),
              Self.isRuneAmountSummary(summary.nativeFee),
              Self.isRuneAmountSummary(summary.totalDebit),
              Self.isConsistentRuneTotals(
                amount: summary.amount,
                nativeFee: summary.nativeFee,
                totalDebit: summary.totalDebit
              ),
              Self.isCanonicalUnsignedDecimal(summary.accountNumber),
              Self.isCanonicalUnsignedDecimal(summary.sequence),
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

    private static func isCanonicalBech32Address(_ value: String) -> Bool {
        guard value == value.lowercased() else { return false }
        guard let decoded = try? Bech32Codec.decode(value),
              ["thor", "sthor", "cthor"].contains(decoded.hrp)
        else { return false }
        guard let payload = try? BitConversion.convert(decoded.words, fromBits: 5, toBits: 8, pad: false),
              payload.count == 20
        else { return false }
        return Bech32Codec.encode(hrp: decoded.hrp, words: decoded.words) == value
    }

    private static func isRuneAmountSummary(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2 else { return false }
        let integer = components[0]
        let fraction = components[1]
        guard !integer.isEmpty && !fraction.isEmpty && fraction.count == 8 else { return false }
        guard integer.allSatisfy(Self.isASCIIDigit), fraction.allSatisfy(Self.isASCIIDigit) else { return false }
        if integer != "0" {
            guard integer.first != "0" else { return false }
        }
        guard BigUInt(integer) != nil, BigUInt(fraction) != nil else { return false }
        return true
    }

    private static func isCanonicalUnsignedDecimal(_ value: String) -> Bool {
        guard value == "0" || value.first != "0" else { return false }
        guard !value.isEmpty, value.allSatisfy(Self.isASCIIDigit) else { return false }
        return UInt64(value) != nil
    }

    private static func isConsistentRuneTotals(amount: String, nativeFee: String, totalDebit: String) -> Bool {
        guard let amountBaseUnits = Self.runeAmountBaseUnits(from: amount),
              let nativeFeeBaseUnits = Self.runeAmountBaseUnits(from: nativeFee),
              let totalBaseUnits = Self.runeAmountBaseUnits(from: totalDebit)
        else { return false }
        return amountBaseUnits + nativeFeeBaseUnits == totalBaseUnits
    }

    private static func runeAmountBaseUnits(from value: String) -> BigUInt? {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2, components[1].count == 8,
              components[0].allSatisfy(Self.isASCIIDigit),
              components[1].allSatisfy(Self.isASCIIDigit)
        else { return nil }
        if components[0] != "0", components[0].first == "0" { return nil }
        let integerUnits = BigUInt(components[0]) ?? 0
        let fractional = BigUInt(components[1]) ?? 0
        return integerUnits * 100_000_000 + fractional
    }

    private static func isASCIIDigit(_ value: Character) -> Bool {
        let scalars = Array(value.unicodeScalars)
        guard scalars.count == 1, let scalar = scalars.first else { return false }
        return (48...57).contains(scalar.value)
    }
}
