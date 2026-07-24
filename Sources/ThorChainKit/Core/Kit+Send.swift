import BigInt
import Foundation

public extension Kit {
    func quote(to recipient: Address, amount: SendAmount, memo: String? = nil) async throws -> SendQuote {
        if let preflight = dependencies.preflight {
            return try await preflight.prepareQuote(
                request: SendQuoteRequest(
                    sender: address,
                    recipient: recipient,
                    amount: amount,
                    memo: memo == "" ? nil : memo
                )
            ).quote
        }
        return try await dependencies.sendRuntime.quote(to: recipient, amount: amount, memo: memo == "" ? nil : memo)
    }

    func send(quote: SendQuote, signer: any Signer) async throws -> SendSubmission {
        try await dependencies.sendRuntime.send(quote: quote, signer: signer)
    }

    func retryBroadcast(transactionId: TransactionID, acceptingNativeFee: BigUInt? = nil) async throws -> SendSubmission {
        let snapshot = acceptingNativeFee.map { SendMagnitude($0).data }
        return try await dependencies.sendRuntime.retryBroadcast(
            transactionId: transactionId,
            acceptingNativeFee: snapshot
        )
    }
}
