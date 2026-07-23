import BigInt
import Foundation

fileprivate final class SendRuntimeAdmissionState: @unchecked Sendable {
    private let lock = NSLock()
    private var activeGeneration: UInt64?

    func activate(generation: UInt64) {
        lock.lock(); defer { lock.unlock() }
        activeGeneration = generation
    }

    func invalidate(generation: UInt64) {
        lock.lock(); defer { lock.unlock() }
        if activeGeneration == generation { activeGeneration = nil }
    }

    func isActive() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return activeGeneration != nil
    }
}

actor SendRuntime {
    private let address: Address?
    private let quoteStore: QuoteStore
    fileprivate nonisolated let admissionState = SendRuntimeAdmissionState()
    private var activeGeneration: UInt64?

    init(address: Address? = nil, clientID: UUID = UUID()) {
        self.address = address
        quoteStore = QuoteStore(clientID: clientID)
    }

    func authorityClientID() -> UUID { quoteStore.clientID }

    func activate(generation: UInt64) {
        activeGeneration = generation
        admissionState.activate(generation: generation)
    }

    func invalidate(generation: UInt64) {
        if activeGeneration == generation { activeGeneration = nil }
        admissionState.invalidate(generation: generation)
        quoteStore.invalidate(generation: generation)
    }

    nonisolated func invalidateImmediately(generation: UInt64) {
        admissionState.invalidate(generation: generation)
    }

    func quote(to recipient: Address, amount: SendAmount, memo: String?) throws -> SendQuote {
        try admit()
        guard let address else { throw SendError.operationUnavailable }
        if let exact = amount.exactAmount, exact == 0 { throw SendError.invalidAmount }
        guard recipient.network == address.network else { throw SendError.invalidRecipient }
        guard recipient != address else { throw SendError.selfRecipient }
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
        guard activeGeneration != nil, admissionState.isActive() else { throw SendError.kitNotStarted }
    }
}
