import BigInt
import Foundation

struct SendPreflightAttempt: Sendable, Equatable {
    let clientID: UUID
    let generation: UInt64
    let attemptID: UUID
    let familyID: String?
    let routeID: String?

    func withRoute(_ routeID: String) -> SendPreflightAttempt {
        SendPreflightAttempt(clientID: clientID, generation: generation, attemptID: attemptID, familyID: familyID, routeID: routeID)
    }
}

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

struct SendSnapshotResult: Sendable {
    let snapshot: SendSnapshot
    let attempt: SendPreflightAttempt
}

protocol SendPreflightProviding: Sendable {
    func lease(minimumHeight: Int64?) async throws -> EndpointLease
    func lease(minimumHeight: Int64?, familyID: String) async throws -> EndpointLease
    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot
    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult
}

extension SendPreflightProviding {
    func lease(minimumHeight: Int64?, familyID: String) async throws -> EndpointLease {
        let lease = try await lease(minimumHeight: minimumHeight)
        guard lease.family.id == familyID else { throw SendError.quoteChanged(QuoteChanges(validating: [.providerIdentity])!) }
        return lease
    }

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

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot {
        try await snapshotResult(request: request, lease: lease, height: height, policy: policy, attempt: attempt).snapshot
    }

    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult {
        guard lease.family.id == fixture.familyID, height == fixture.height else { throw SendError.heightUnproven }
        try policy.validate(memo: request.memo)
        return SendSnapshotResult(snapshot: fixture, attempt: attempt.withRoute("recipient-account"))
    }
}

final class SendPreflightCoordinator: @unchecked Sendable {
    private let runtime: SendRuntime
    private let provider: any SendPreflightProviding
    private let policy: SendPolicy
    private let runner: EndpointOperationRunner
    private let validationState = SendValidationState()

    init(runtime: SendRuntime, provider: any SendPreflightProviding, policy: SendPolicy? = nil) {
        self.runtime = runtime; self.provider = provider; self.policy = policy ?? .standard
        runner = EndpointOperationRunner(deadline: (policy ?? .standard).operationDeadline)
    }

    func prepareQuote(request: SendQuoteRequest) async throws -> PreparedQuote {
        try Task.checkCancellation()
        try policy.validate(memo: request.memo)
        guard request.sender.network == request.recipient.network else { throw SendError.invalidRecipient }
        var activeAttempt: SendPreflightAttempt?
        do {
        var attempt = try await runtime.beginPreflight()
        activeAttempt = attempt
        let generation = attempt.generation
        let lease = try await runner.run(lifecycle: { !self.runtime.isAdmissionActive(generation: generation) }) { try await self.provider.lease(minimumHeight: nil) }
        attempt = try await runtime.bindFamily(attempt, familyID: lease.family.id)
        try await runtime.guardPreflight(attempt, familyID: lease.family.id)
        guard NativeRuneEndpointRegistry.familyIDs.contains(lease.family.id), lease.commonReadHeight > 0 else {
            throw SendError.policyUnavailable
        }
        let snapshotAttempt = attempt
        let result = try await runner.run(familyID: lease.family.id, lifecycle: { !self.runtime.isAdmissionActive(generation: generation) }) {
            try await self.provider.snapshotResult(request: request, lease: lease, height: lease.commonReadHeight, policy: self.policy, attempt: snapshotAttempt)
        }
        guard result.attempt.routeID == "recipient-account",
              result.attempt.clientID == attempt.clientID,
              result.attempt.generation == attempt.generation,
              result.attempt.attemptID == attempt.attemptID,
              result.attempt.familyID == attempt.familyID else { throw SendError.policyUnavailable }
        attempt = result.attempt
        activeAttempt = attempt
        try await runtime.guardPreflight(attempt, familyID: lease.family.id, routeID: "recipient-account")
        let snapshot = result.snapshot
        guard snapshot.familyID == lease.family.id, snapshot.height == lease.commonReadHeight else { throw SendError.heightUnproven }
        guard try HaltEvaluator.evaluate(height: snapshot.height, mimir: snapshot.mimir) == .allowed else { throw SendError.chainHalted }
        guard snapshot.recipientClassification != .module else { throw SendError.recipientIsModule }
        guard snapshot.recipient == request.recipient.raw else { throw SendError.invalidRecipient }
        try policy.validate(memo: request.memo, maximumBytes: snapshot.memoMaximumBytes)
        let quote = try await runtime.issuePreflightQuote(request: request, snapshot: snapshot)
        await runtime.finishPreflight(attempt)
        return PreparedQuote(quote: quote, snapshot: snapshot)
        } catch {
            if let activeAttempt { await runtime.finishPreflight(activeAttempt) }
            if let error = error as? EndpointOperationError, error == .lifecycleInvalidated { throw SendError.kitNotStarted }
            throw error
        }
    }

    func revalidate(_ prepared: PreparedQuote) async throws -> RevalidationResult {
        guard prepared.quote.expiresAt > Date() else { throw SendError.quoteExpired }
        guard let storedContext = prepared.quote.preflightContext,
              prepared.quote.hasConsistentAuthorityProjection,
              storedContext == prepared.snapshot else { throw SendError.operationUnavailable }
        var activeAttempt: SendPreflightAttempt?
        do {
        var attempt = try await runtime.beginPreflight()
        activeAttempt = attempt
        let generation = attempt.generation
        let priorHeight = await validationState.height(for: storedContext.digest) ?? prepared.snapshot.height
        let lease = try await runner.run(lifecycle: { !self.runtime.isAdmissionActive(generation: generation) }) { try await self.provider.lease(minimumHeight: priorHeight, familyID: prepared.snapshot.familyID) }
        attempt = try await runtime.bindFamily(attempt, familyID: lease.family.id)
        guard lease.family.id == prepared.snapshot.familyID, lease.commonReadHeight >= priorHeight else {
            throw SendError.quoteChanged(QuoteChanges(validating: [.providerIdentity, .heightRollback])!)
        }
        let sender: Address
        do { sender = try Address(prepared.snapshot.sender, network: .mainnet) }
        catch { throw SendError.providerUnavailable }
        let request = SendQuoteRequest(sender: sender, recipient: prepared.quote.recipient, amount: .exact(prepared.snapshot.amount), memo: prepared.quote.memo)
        let snapshotAttempt = attempt
        let result = try await runner.run(familyID: lease.family.id, lifecycle: { !self.runtime.isAdmissionActive(generation: generation) }) { try await self.provider.snapshotResult(request: request, lease: lease, height: lease.commonReadHeight, policy: self.policy, attempt: snapshotAttempt) }
        guard result.attempt.routeID == "recipient-account",
              result.attempt.clientID == attempt.clientID,
              result.attempt.generation == attempt.generation,
              result.attempt.attemptID == attempt.attemptID,
              result.attempt.familyID == attempt.familyID else { throw SendError.policyUnavailable }
        attempt = result.attempt
        activeAttempt = attempt
        try await runtime.guardPreflight(attempt, familyID: lease.family.id, routeID: "recipient-account")
        let fresh = result.snapshot
        guard fresh.height >= priorHeight else { throw SendError.quoteChanged(QuoteChanges(validating: [.heightRollback])!) }
        var changes = Set<QuoteChange>()
        if fresh.familyID != prepared.snapshot.familyID || fresh.chainID != prepared.snapshot.chainID || fresh.restEndpoint != prepared.snapshot.restEndpoint || fresh.rpcEndpoint != prepared.snapshot.rpcEndpoint || fresh.manifestRevision != prepared.snapshot.manifestRevision { changes.insert(.providerIdentity) }
        if fresh.height < prepared.snapshot.height { changes.insert(.heightRollback) }
        if fresh.accountNumber != prepared.snapshot.accountNumber { changes.insert(.accountNumber) }
        if fresh.sequence != prepared.snapshot.sequence { changes.insert(.sequence) }
        if fresh.accountPublicKey != prepared.snapshot.accountPublicKey || fresh.accountPublicKeyData != prepared.snapshot.accountPublicKeyData { changes.insert(.accountPublicKey) }
        if fresh.spendableRune < prepared.quote.totalDebit { changes.insert(.balance) }
        if fresh.nativeFee != prepared.snapshot.nativeFee { changes.insert(.nativeFee) }
        if fresh.mimir != prepared.snapshot.mimir { changes.insert(.haltStatus) }
        if fresh.memoMaximumBytes != prepared.snapshot.memoMaximumBytes { changes.insert(.memoPolicy) }
        if fresh.nodeVersion != prepared.snapshot.nodeVersion || fresh.querierVersion != prepared.snapshot.querierVersion || fresh.recipientClassification != prepared.snapshot.recipientClassification || fresh.policyRevision != prepared.snapshot.policyRevision { changes.insert(.recipientPolicy) }
        if let result = QuoteChanges(validating: changes) { throw SendError.quoteChanged(result) }
        await validationState.record(digest: prepared.snapshot.digest, height: fresh.height)
        await runtime.finishPreflight(attempt)
        return RevalidationResult(snapshot: fresh, quote: prepared.quote)
        } catch {
            if let activeAttempt { await runtime.finishPreflight(activeAttempt) }
            if let error = error as? EndpointOperationError, error == .lifecycleInvalidated { throw SendError.kitNotStarted }
            throw error
        }
    }

    func revalidate(_ quote: SendQuote) async throws -> RevalidationResult {
        guard let context = quote.preflightContext else { throw SendError.operationUnavailable }
        return try await revalidate(PreparedQuote(quote: quote, snapshot: context))
    }
}

struct RevalidationResult: Sendable {
    let snapshot: SendSnapshot
    let quote: SendQuote
}

private actor SendValidationState {
    private var acceptedHeights = [Data: Int64]()

    func height(for digest: Data) -> Int64? { acceptedHeights[digest] }
    func record(digest: Data, height: Int64) { acceptedHeights[digest] = height }
}

struct ThorNodeSendPreflightProvider: SendPreflightProviding {
    let node: ThorNodeSendClient
    let leaseProvider: @Sendable () async throws -> EndpointLease
    let capabilities: [SendFamilyCapability]
    let runtime: SendRuntime?
    let runner: EndpointOperationRunner
    let freshLeaseProvider: (@Sendable (String) async throws -> EndpointLease)?

    init(node: ThorNodeSendClient, leaseProvider: @escaping @Sendable () async throws -> EndpointLease, capabilities: [SendFamilyCapability] = NativeRuneEndpointRegistry.capabilities(), runtime: SendRuntime? = nil, operationDeadline: TimeInterval = 15, freshLeaseProvider: (@Sendable (String) async throws -> EndpointLease)? = nil) {
        self.node = node; self.leaseProvider = leaseProvider; self.capabilities = capabilities; self.runtime = runtime; runner = EndpointOperationRunner(deadline: operationDeadline); self.freshLeaseProvider = freshLeaseProvider
    }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        let lease = try await leaseProvider()
        guard NativeRuneEndpointRegistry.familyIDs.contains(lease.family.id), minimumHeight.map({ lease.commonReadHeight >= $0 }) ?? true else { throw SendError.policyUnavailable }
        guard let capability = capabilities.first(where: { $0.familyID == lease.family.id }),
              capability.manifestRevision == NativeRuneEndpointRegistry.capabilities().first(where: { $0.familyID == lease.family.id })?.manifestRevision,
              capability.isSendCapable,
              capability.routes.allSatisfy({ NativeRuneEndpointRegistry.matches($0, family: lease.family) }) else { throw SendError.policyUnavailable }
        return lease
    }

    func lease(minimumHeight: Int64?, familyID: String) async throws -> EndpointLease {
        let lease: EndpointLease
        if let freshLeaseProvider {
            lease = try await freshLeaseProvider(familyID)
        } else {
            lease = try await leaseProvider()
        }
        guard lease.family.id == familyID,
              NativeRuneEndpointRegistry.familyIDs.contains(lease.family.id),
              minimumHeight.map({ lease.commonReadHeight >= $0 }) ?? true,
              capabilities.first(where: { $0.familyID == lease.family.id }).map({ capability in
                  capability.manifestRevision == NativeRuneEndpointRegistry.capabilities().first(where: { $0.familyID == lease.family.id })?.manifestRevision
                      && capability.isSendCapable
                      && capability.routes.allSatisfy({ NativeRuneEndpointRegistry.matches($0, family: lease.family) })
              }) == true
        else { throw SendError.policyUnavailable }
        return lease
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot {
        try await snapshotResult(request: request, lease: lease, height: height, policy: policy, attempt: attempt).snapshot
    }

    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult {
        guard height == lease.commonReadHeight else { throw SendError.heightUnproven }
        let capability = capabilities.first(where: { $0.familyID == lease.family.id })
        let routes = capability?.routes ?? []
        let route: @Sendable (String) throws -> SendManifestRoute = { name in
            guard let route = routes.first(where: { $0.route == name }) else { throw SendError.policyUnavailable }
            return route
        }
        var routeAttempt = attempt
        func read(_ name: String, address: String? = nil, requestData: Data = Data()) async throws -> SendRouteResponse {
            if let runtime { routeAttempt = try await runtime.bindRoute(routeAttempt, routeID: name); try await runtime.guardPreflight(routeAttempt, familyID: lease.family.id, routeID: name) }
            let lifecycleGeneration = routeAttempt.generation
            let response = try await runner.run(familyID: lease.family.id, lifecycle: {
                if let runtime { return !runtime.isAdmissionActive(generation: lifecycleGeneration) }
                return false
            }) {
                try await self.node.read(route: route(name), using: lease, height: height, address: address, requestData: requestData)
            }
            if let runtime { try await runtime.guardPreflight(routeAttempt, familyID: lease.family.id, routeID: name) }
            return response
        }
        let accountRequest = try CosmosQueryCodec.accountRequest(address: request.sender.raw)
        let recipientRequest = try CosmosQueryCodec.accountRequest(address: request.recipient.raw)
        let networkRequest = try CosmosQueryCodec.networkRequest(height: height)
        let account = try await read("account", address: request.sender.raw, requestData: accountRequest)
        let balance = try await read("spendable-rune", address: request.sender.raw, requestData: try CosmosQueryCodec.spendableRequest(address: request.sender.raw))
        let fee = try await read("network-fee", requestData: networkRequest)
        let mimirRoutes = [
            ("mimir-halt-chain-global", "HaltChainGlobal"),
            ("mimir-node-pause-chain-global", "NodePauseChainGlobal"),
            ("mimir-halt-thorchain", "HaltTHORChain"),
            ("mimir-solvency-halt-thorchain", "SolvencyHaltTHORChain")
        ]
        var mimirValues = [String: Int64]()
        for (routeName, key) in mimirRoutes {
            let response = try await read(routeName)
            mimirValues[key] = try SendRouteDecoders.mimir(response.value)
        }
        let auth = try await read("auth-params")
        let versions = try await read("node-version")
        let recipient = try await read("recipient-account", address: request.recipient.raw, requestData: recipientRequest)
        guard account.code == 0 else { throw SendError.accountUnavailable }
        guard let accountValue = try CosmosQueryCodec.decodeAccountPayload(account.value),
              accountValue.typeURL != "/cosmos.auth.v1beta1.ModuleAccount",
              accountValue.address == request.sender.raw else {
            throw SendError.accountUnavailable
        }
        let balanceValue = try SendRouteDecoders.balance(balance.value)
        guard let spendable = BigUInt(balanceValue.amount) else { throw SendError.insufficientBalance }
        let nativeFee = try SendRouteDecoders.networkFee(fee.value)
        let mimirSnapshot = MimirSnapshot(
            haltChainGlobal: try Self.mimirValue(mimirValues, key: "HaltChainGlobal"),
            nodePauseChainGlobal: try Self.mimirValue(mimirValues, key: "NodePauseChainGlobal"),
            haltTHORChain: try Self.mimirValue(mimirValues, key: "HaltTHORChain"),
            solvencyHaltTHORChain: try Self.mimirValue(mimirValues, key: "SolvencyHaltTHORChain")
        )
        let memoMaximum = try SendRouteDecoders.authMaximum(auth.value)
        guard memoMaximum > 0 else { throw SendError.providerUnavailable }
        let version = try SendRouteDecoders.version(versions.value)
        let forbidden = try ForbiddenModuleAddressSet(current: version.current, querier: version.querier)
        let recipientPayload = try CosmosQueryCodec.decodeAccountPayload(recipient.value)
        let recipientResponse = RecipientAccountResponse(height: height, code: recipient.code, codespace: recipient.codespace, type: recipientPayload?.typeURL, address: recipientPayload?.address, value: recipient.value)
        let classification = try RecipientAccountClassifier.classify(recipientResponse, expectedHeight: height, recipient: request.recipient.raw, forbidden: forbidden)
        let amount = try policy.resolve(amount: request.amount, spendableRune: spendable, nativeFee: nativeFee)
        try policy.validate(memo: request.memo)
        return SendSnapshotResult(snapshot: try SendSnapshot(familyID: lease.family.id, chainID: lease.verifiedChainId, height: height, sender: request.sender.raw, recipient: request.recipient.raw, accountNumber: accountValue.accountNumber, sequence: accountValue.sequence, amount: amount, nativeFee: nativeFee, spendableRune: spendable, mimir: mimirSnapshot, memoMaximumBytes: memoMaximum, nodeVersion: version.current, querierVersion: version.querier, recipientClassification: classification, policyRevision: forbidden.revision, accountPublicKey: accountValue.publicKeyTypeURL, accountPublicKeyData: accountValue.publicKeyData, restEndpoint: lease.family.cosmosRestURL.absoluteString, rpcEndpoint: lease.family.cometBftURL.absoluteString, manifestRevision: capability?.manifestRevision ?? ""), attempt: routeAttempt)
    }

    private static func mimirValue(_ values: [String: Int64], key: String) throws -> Int64 {
        guard let value = values[key] else { throw SendError.policyUnavailable }
        return value
    }
}

enum SendRouteDecoders {
    static func balance(_ data: Data) throws -> (denom: String, amount: String) {
        let envelope = try exactObject(data, keys: ["balance"])
        guard let balance = envelope["balance"] as? [String: Any], Set(balance.keys) == ["denom", "amount"],
              let denom = balance["denom"] as? String, denom == "rune",
              let amount = canonicalUnsigned(balance["amount"]) else { throw SendError.insufficientBalance }
        return (denom, amount)
    }

    static func networkFee(_ data: Data) throws -> BigUInt {
        let response = try Types_QueryNetworkResponse(serializedBytes: data)
        guard try response.serializedData() == data else { throw SendError.providerUnavailable }
        guard canonicalUnsigned(response.nativeTxFeeRune) != nil,
              let fee = BigUInt(response.nativeTxFeeRune), fee <= BigUInt(UInt64.max) else {
            throw SendError.providerUnavailable
        }
        return fee
    }

    static func authMaximum(_ data: Data) throws -> Int {
        let envelope = try exactObject(data, keys: ["params"])
        guard let params = envelope["params"] as? [String: Any],
              Set(params.keys) == ["max_memo_characters", "tx_sig_limit", "tx_size_cost_per_byte", "sig_verify_cost_ed25519", "sig_verify_cost_secp256k1"],
              let value = canonicalUnsigned(params["max_memo_characters"]), let integer = Int(value), integer > 0 else { throw SendError.providerUnavailable }
        for key in ["tx_sig_limit", "tx_size_cost_per_byte", "sig_verify_cost_ed25519", "sig_verify_cost_secp256k1"] {
            guard canonicalUnsigned(params[key]) != nil else { throw SendError.providerUnavailable }
        }
        return integer
    }

    static func version(_ data: Data) throws -> (current: String, querier: String) {
        let object = try exactObject(data, keys: ["current", "next", "next_since_height", "querier"])
        guard let current = object["current"] as? String, !current.isEmpty,
              let querier = object["querier"] as? String, !querier.isEmpty else { throw SendError.providerUnavailable }
        guard let next = object["next"] as? String, !next.isEmpty,
              canonicalInt64(object["next_since_height"]) != nil else { throw SendError.providerUnavailable }
        return (current, querier)
    }

    static func mimir(_ data: Data) throws -> Int64 {
        guard JSONDuplicateKeyGuard.hasNoDuplicates(data) else { throw SendError.policyUnavailable }
        guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Int64(token), String(value) == token else { throw SendError.policyUnavailable }
        guard value >= -1 else { throw SendError.policyUnavailable }
        return value
    }

    private static func exactObject(_ data: Data, keys: Set<String>) throws -> [String: Any] {
        guard JSONDuplicateKeyGuard.hasNoDuplicates(data) else { throw SendError.providerUnavailable }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == keys else {
            throw SendError.providerUnavailable
        }
        return object
    }

    private static func canonicalUnsigned(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty,
              string == "0" || (string.first != "0" && string.allSatisfy({ $0.isNumber })) else { return nil }
        return string
    }

    private static func canonicalInt64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return Int64(exactly: number) }
        if let string = value as? String, !string.isEmpty, (string == "0" || string.first != "0") { return Int64(string) }
        return nil
    }
}
