import BigInt
import Foundation

public extension Kit {
    func quote(to recipient: Address, amount: SendAmount, memo: String? = nil) async throws -> SendQuote {
        if let preflight {
            return try await preflight.prepareQuote(
                request: SendQuoteRequest(
                    sender: address,
                    recipient: recipient,
                    amount: amount,
                    memo: memo == "" ? nil : memo
                )
            ).quote
        }
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
