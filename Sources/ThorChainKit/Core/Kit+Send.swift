import BigInt
import Foundation

public extension Kit {
    /// `denom` is what gets sent. The network fee is charged in RUNE regardless, so a
    /// non-RUNE send needs a RUNE balance for the fee on top of the token balance.
    func quote(to recipient: Address, amount: SendAmount, memo: String? = nil, denom: Denom = .rune) async throws -> SendQuote {
        if let preflight {
            return try await preflight.prepareQuote(
                request: SendQuoteRequest(
                    sender: address,
                    recipient: recipient,
                    amount: amount,
                    memo: memo == "" ? nil : memo,
                    denom: denom
                )
            ).quote
        }
        // The fallback path predates denoms and would quote RUNE whatever was asked for.
        // Refuse rather than send the wrong asset.
        guard denom == .rune else { throw SendError.operationUnavailable }
        return try await transactionSender.quote(to: recipient, amount: amount, memo: memo == "" ? nil : memo)
    }

    func send(quote: SendQuote, signer: any ISigner) async throws -> SendSubmission {
        try await transactionSender.send(quote: quote, signer: signer)
    }

    func retryBroadcast(transactionId: TransactionID, acceptingNativeFee: BigUInt? = nil) async throws -> SendSubmission {
        let snapshot = acceptingNativeFee.map { SendMagnitude($0).data }
        return try await transactionSender.retryBroadcast(
            transactionId: transactionId,
            acceptingNativeFee: snapshot
        )
    }
}
