import BigInt
import Foundation

struct SigningRequestFactory: Sendable {
    func make(snapshot: SendSnapshot, prepared: PreparedQuote, publicKey: Data) throws -> (SigningRequest, SignPayload) {
        let payload = try DirectSignCodec.makeSignPayload(snapshot: snapshot, quote: prepared, publicKey: publicKey)
        let summary = SigningRequest.Summary(
            sender: snapshot.sender,
            recipient: snapshot.recipient,
            amount: Self.runeAmount(prepared.quote.amount),
            nativeFee: Self.runeAmount(prepared.quote.nativeFee),
            totalDebit: Self.runeAmount(prepared.quote.totalDebit),
            memo: prepared.quote.memo,
            accountNumber: String(snapshot.accountNumber),
            sequence: String(snapshot.sequence)
        )
        guard let request = SigningRequest(
            digest: payload.digest,
            serializedSignDoc: payload.signDocBytes,
            chainId: snapshot.chainID,
            requestId: UUID().uuidString,
            summary: summary
        ) else {
            throw SendError.operationUnavailable
        }
        return (request, payload)
    }

    private static func runeAmount(_ value: BigUInt) -> String {
        let base = BigUInt(100_000_000)
        let whole = value / base
        let fraction = String(value % base)
        return "\(whole).\(String(repeating: "0", count: 8 - fraction.count))\(fraction)"
    }
}
