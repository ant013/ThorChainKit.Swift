import Foundation

actor SendCoordinator {
    private let runtime: SendRuntime
    private let preflight: SendPreflightCoordinator?
    private let persistenceNamespace: String
    private let network: Network

    init(
        runtime: SendRuntime,
        preflight: SendPreflightCoordinator? = nil,
        persistenceNamespace: String = "",
        network: Network = .mainnet
    ) {
        self.runtime = runtime
        self.preflight = preflight
        self.persistenceNamespace = persistenceNamespace
        self.network = network
    }

    func execute(quote: SendQuote, signer: any Signer) async -> SendCoordinatorResult {
        let sender = quote.internalAuthorityRecord.snapshot.sender
        guard await runtime.isAdmissionActive() else { return .failure(.kitNotStarted) }
        guard await runtime.beginAccountAttempt(sender) else { return .failure(.sendInProgress) }

        let ownerToken = Self.makeOwnerToken()
        let operationHold = OperationHold(id: UUID())
        var reservationAcquired = false
        var ownershipTransferred = false
        var signerFenceAcquired = false
        let result: SendCoordinatorResult

        do {
            try await runtime.consumeQuote(quote)
            let publicKey = signer.compressedPublicKey
            let h1: SendSnapshot
            if let preflight, let context = quote.preflightContext {
                h1 = try await preflight.revalidate(PreparedQuote(quote: quote, snapshot: context)).snapshot
            } else if let context = quote.preflightContext {
                h1 = context
            } else {
                throw SendError.operationUnavailable
            }
            try bind(publicKey: publicKey, snapshot: h1)
            guard try await runtime.acquireReservation(sender: sender, sequence: h1.sequence, ownerToken: ownerToken) else {
                throw SendError.sendInProgress
            }
            reservationAcquired = true

            let prepared = PreparedQuote(quote: quote, snapshot: h1)
            let (request, payload) = try SigningRequestFactory().make(snapshot: h1, prepared: prepared, publicKey: publicKey)
            guard await runtime.beginSignerFence(sender) else { throw SendError.sendInProgress }
            signerFenceAcquired = true
            let signature = try await signer.sign(request)
            await runtime.endSignerFence(sender)
            signerFenceAcquired = false

            let h2: SendSnapshot
            if let preflight, let context = quote.preflightContext {
                h2 = try await preflight.revalidate(PreparedQuote(quote: quote, snapshot: context)).snapshot
            } else {
                h2 = h1
            }
            guard h2.sender == h1.sender,
                  h2.recipient == h1.recipient,
                  h2.accountNumber == h1.accountNumber,
                  h2.sequence == h1.sequence,
                  h2.familyID == h1.familyID,
                  h2.chainID == h1.chainID,
                  h2.amount == h1.amount,
                  h2.nativeFee == h1.nativeFee
            else { throw SendError.quoteChanged(QuoteChanges(validating: [.sequence])!) }
            try bind(publicKey: publicKey, snapshot: h2)

            let compact = try SignerVerifier().verify(signature: signature, digest: payload.digest, publicKey: publicKey)
            let transaction = try DirectSignCodec.makeTxRaw(payload: payload, compactSignature: compact.rawValue)
            ownershipTransferred = true
            result = .handoff(SendAttemptHandoff(
                transaction: transaction,
                persistenceNamespace: persistenceNamespace,
                sequence: h1.sequence,
                reservationOwnerToken: ownerToken,
                operationHold: operationHold,
                runtime: runtime
            ))
        } catch is CancellationError {
            result = .failure(.signerCancelled)
        } catch let error as SendError {
            result = .failure(error)
        } catch {
            result = .failure(.signerFailed)
        }

        if signerFenceAcquired { await runtime.endSignerFence(sender) }
        guard !ownershipTransferred else { return result }
        if reservationAcquired {
            do {
                guard try await runtime.releaseReservation(
                    sender: sender,
                    sequence: quote.internalAuthorityRecord.snapshot.sequence,
                    ownerToken: ownerToken
                ) else {
                    return .repairPending(RepairIntent(
                        persistenceNamespace: persistenceNamespace,
                        sequence: quote.internalAuthorityRecord.snapshot.sequence,
                        reservationOwnerToken: ownerToken,
                        operationHold: operationHold
                    ))
                }
            } catch {
                return .repairPending(RepairIntent(
                    persistenceNamespace: persistenceNamespace,
                    sequence: quote.internalAuthorityRecord.snapshot.sequence,
                    reservationOwnerToken: ownerToken,
                    operationHold: operationHold
                ))
            }
        }
        await runtime.endAccountAttempt(sender)
        return result
    }

    private func bind(publicKey: Data, snapshot: SendSnapshot) throws {
        let validatedAddress: Address
        do {
            validatedAddress = try AccountAddressFactory.address(compressedPublicKey: publicKey, network: network)
        } catch {
            throw SendError.invalidPublicKey
        }
        guard validatedAddress.raw == snapshot.sender else { throw SendError.signerAddressMismatch }
        if let expected = snapshot.accountPublicKeyData, expected != publicKey {
            throw SendError.signerAddressMismatch
        }
    }

    private static func makeOwnerToken() -> Data {
        var value = UUID().uuid
        return withUnsafeBytes(of: &value) { Data($0) }
    }
}
