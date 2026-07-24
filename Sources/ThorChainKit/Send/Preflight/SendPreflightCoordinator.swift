import BigInt
import Foundation

struct SendQuoteRequest: Sendable {
    let sender: Address
    let recipient: Address
    let amount: SendAmount
    let memo: String?

    init(sender: Address, recipient: Address, amount: SendAmount, memo: String? = nil) {
        self.sender = sender; self.recipient = recipient; self.amount = amount; self.memo = memo
    }
}

struct PreparedQuote: Sendable {
    let quote: SendQuote
    let snapshot: SendSnapshot
}

protocol SendPreflightProviding: Sendable {
    func lease(minimumHeight: Int64?) async throws -> EndpointLease
    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy) async throws -> SendSnapshot
}

struct SendPreflightFixtureProvider: SendPreflightProviding {
    let fixture: SendSnapshot
    let leaseValue: EndpointLease

    init(fixture: SendSnapshot, lease: EndpointLease) {
        self.fixture = fixture; self.leaseValue = lease
    }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        guard minimumHeight.map({ leaseValue.commonReadHeight >= $0 }) ?? true else { throw SendError.heightUnproven }
        return leaseValue
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy) async throws -> SendSnapshot {
        guard lease.family.id == fixture.familyID, height == fixture.height else { throw SendError.heightUnproven }
        try policy.validate(memo: request.memo)
        return fixture
    }
}

final class SendPreflightCoordinator: @unchecked Sendable {
    private let runtime: SendRuntime
    private let provider: any SendPreflightProviding
    private let policy: SendPolicy
    private let runner: EndpointOperationRunner

    init(runtime: SendRuntime, provider: any SendPreflightProviding, policy: SendPolicy? = nil) {
        self.runtime = runtime; self.provider = provider; self.policy = policy ?? .standard
        runner = EndpointOperationRunner(deadline: (policy ?? .standard).operationDeadline)
    }

    func prepareQuote(request: SendQuoteRequest) async throws -> PreparedQuote {
        try Task.checkCancellation()
        try policy.validate(memo: request.memo)
        guard request.sender.network == request.recipient.network else { throw SendError.invalidRecipient }
        let generation = try await runtime.admittedGeneration()
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        let lease = try await runner.run { try await self.provider.lease(minimumHeight: nil) }
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        guard NativeRuneEndpointRegistry.familyIDs.contains(lease.family.id), lease.commonReadHeight > 0 else {
            throw SendError.policyUnavailable
        }
        let snapshot = try await runner.run {
            try await self.provider.snapshot(request: request, lease: lease, height: lease.commonReadHeight, policy: self.policy)
        }
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        guard snapshot.familyID == lease.family.id, snapshot.height == lease.commonReadHeight else { throw SendError.heightUnproven }
        guard try HaltEvaluator.evaluate(height: snapshot.height, mimir: snapshot.mimir) == .allowed else { throw SendError.chainHalted }
        guard snapshot.recipientClassification != .module else { throw SendError.recipientIsModule }
        guard snapshot.recipient == request.recipient.raw else { throw SendError.invalidRecipient }
        let quote = try await runtime.issuePreflightQuote(request: request, snapshot: snapshot)
        return PreparedQuote(quote: quote, snapshot: snapshot)
    }

    func revalidate(_ prepared: PreparedQuote) async throws -> RevalidationResult {
        let generation = try await runtime.admittedGeneration()
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        let lease = try await runner.run { try await self.provider.lease(minimumHeight: prepared.snapshot.height) }
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        guard lease.family.id == prepared.snapshot.familyID, lease.commonReadHeight >= prepared.snapshot.height else {
            throw SendError.quoteChanged(QuoteChanges(validating: [.providerIdentity, .heightRollback])!)
        }
        let sender: Address
        do { sender = try Address(prepared.snapshot.sender, network: .mainnet) }
        catch { throw SendError.providerUnavailable }
        let request = SendQuoteRequest(sender: sender, recipient: prepared.quote.recipient, amount: .exact(prepared.snapshot.amount), memo: prepared.quote.memo)
        let fresh = try await runner.run { try await self.provider.snapshot(request: request, lease: lease, height: lease.commonReadHeight, policy: self.policy) }
        guard runtime.isAdmissionActive(generation: generation) else { throw SendError.kitNotStarted }
        guard fresh.height >= prepared.snapshot.height else { throw SendError.quoteChanged(QuoteChanges(validating: [.heightRollback])!) }
        var changes = Set<QuoteChange>()
        if fresh.familyID != prepared.snapshot.familyID || fresh.chainID != prepared.snapshot.chainID { changes.insert(.providerIdentity) }
        if fresh.height < prepared.snapshot.height { changes.insert(.heightRollback) }
        if fresh.accountNumber != prepared.snapshot.accountNumber { changes.insert(.accountNumber) }
        if fresh.sequence != prepared.snapshot.sequence { changes.insert(.sequence) }
        if fresh.amount + fresh.nativeFee < prepared.quote.totalDebit { changes.insert(.balance) }
        if fresh.nativeFee != prepared.snapshot.nativeFee { changes.insert(.nativeFee) }
        if fresh.mimir != prepared.snapshot.mimir { changes.insert(.haltStatus) }
        if fresh.memoMaximumBytes != prepared.snapshot.memoMaximumBytes { changes.insert(.memoPolicy) }
        if fresh.recipientClassification != prepared.snapshot.recipientClassification || fresh.policyRevision != prepared.snapshot.policyRevision { changes.insert(.recipientPolicy) }
        if let result = QuoteChanges(validating: changes) { throw SendError.quoteChanged(result) }
        return RevalidationResult(snapshot: fresh, quote: prepared.quote)
    }
}

struct RevalidationResult: Sendable {
    let snapshot: SendSnapshot
    let quote: SendQuote
}
