import BigInt
import Foundation

actor SendRuntime {
    private let address: Address?
    private let quoteStore: QuoteStore
    private var activeGeneration: UInt64?

    init(address: Address? = nil, clientID: UUID = UUID()) {
        self.address = address
        quoteStore = QuoteStore(clientID: clientID)
    }

    func authorityClientID() -> UUID { quoteStore.clientID }

    func activate(generation: UInt64) {
        activeGeneration = generation
    }

    func invalidate(generation: UInt64) {
        if activeGeneration == generation { activeGeneration = nil }
        quoteStore.invalidate(generation: generation)
    }

    func quote(to recipient: Address, amount: SendAmount, memo: String?) throws -> SendQuote {
        try admit()
        guard let address else { throw SendError.operationUnavailable }
        guard recipient.network == address.network else { throw SendError.invalidRecipient }
        guard recipient != address else { throw SendError.selfRecipient }
        if let exact = amount.exactAmount, exact == 0 { throw SendError.invalidAmount }
        try Task.checkCancellation()
        _ = memo
        throw SendError.operationUnavailable
    }

    func send(quote: SendQuote, signer: any Signer) throws -> SendSubmission {
        try admit()
        _ = quote
        _ = signer
        throw SendError.operationUnavailable
    }

    func retryBroadcast(transactionId: TransactionID, acceptingNativeFee: Data?) throws -> SendSubmission {
        try admit()
        _ = transactionId
        _ = acceptingNativeFee
        throw SendError.operationUnavailable
    }

    private func admit() throws {
        guard activeGeneration != nil else { throw SendError.kitNotStarted }
    }
}
