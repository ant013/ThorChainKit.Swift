import BigInt
import Foundation

fileprivate final class SendRuntimeAdmissionState: Sendable {
    private let stateQueue = DispatchQueue(label: "ThorChainKit.Send.Admission")
    private let generationKey = DispatchSpecificKey<UInt64>()

    func activate(generation: UInt64) {
        stateQueue.sync { stateQueue.setSpecific(key: generationKey, value: generation) }
    }

    func invalidate(generation: UInt64) {
        stateQueue.sync {
            if stateQueue.getSpecific(key: generationKey) == generation {
                stateQueue.setSpecific(key: generationKey, value: nil)
            }
        }
    }

    func isActive() -> Bool {
        stateQueue.sync { stateQueue.getSpecific(key: generationKey) != nil }
    }

    func isActive(generation: UInt64) -> Bool {
        stateQueue.sync { stateQueue.getSpecific(key: generationKey) == generation }
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

    nonisolated func isAdmissionActive(generation: UInt64) -> Bool {
        admissionState.isActive(generation: generation)
    }

    func admittedGeneration() throws -> UInt64 {
        guard let activeGeneration else { throw SendError.kitNotStarted }
        return activeGeneration
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

    func issuePreflightQuote(request: SendQuoteRequest, snapshot: SendSnapshot) throws -> SendQuote {
        try admit()
        let amount = snapshot.amount
        let fee = snapshot.nativeFee
        return try quoteStore.issue(
            sender: request.sender,
            recipient: request.recipient,
            amountMagnitude: SendMagnitude(amount).data,
            isMaximum: request.amount.isMaximum,
            nativeFeeMagnitude: SendMagnitude(fee).data,
            totalDebitMagnitude: SendMagnitude(snapshot.totalDebit).data,
            memo: request.memo,
            acceptedHeight: snapshot.height,
            generation: activeGeneration ?? 0,
            accountNumber: snapshot.accountNumber,
            sequence: snapshot.sequence,
            providerFamilyID: snapshot.familyID
        )
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
