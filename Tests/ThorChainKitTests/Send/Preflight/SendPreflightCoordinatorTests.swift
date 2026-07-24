import BigInt
import XCTest
@testable import ThorChainKit

final class SendPreflightCoordinatorTests: XCTestCase {
    func testPreparationUsesOneFamilyAndOneCommonHeight() async throws {
        let address = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 43, poolGeneration: 1)
        let snapshot = try SendSnapshot.fixture(height: 42)
        let provider = ScriptedSendProvider(leases: [lease], snapshots: [snapshot], runtime: nil)
        let runtime = SendRuntime(address: address)
        await runtime.activate(generation: 1)
        provider.runtime = runtime
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        let prepared = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: address, recipient: try sendOtherAddress(), amount: .exact(100)))

        XCTAssertEqual(prepared.quote.acceptedHeight, 42)
        XCTAssertEqual(prepared.snapshot.familyID, "rorcual-mainnet")
        XCTAssertEqual(prepared.quote.preflightContext, prepared.snapshot)
        XCTAssertEqual(prepared.quote.preflightContext?.digest.count, 32)
        XCTAssertEqual(provider.heights, [42])
    }

    func testCrossFamilyOrCrossHeightSnapshotFailsClosed() async throws {
        let address = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        let wrongHeight = try SendSnapshot.fixture(height: 43)
        let runtime = SendRuntime(address: address)
        await runtime.activate(generation: 1)
        let provider = ScriptedSendProvider(leases: [lease], snapshots: [wrongHeight], runtime: runtime)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        do {
            _ = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: address, recipient: try sendOtherAddress(), amount: .exact(100)))
            XCTFail("mixed height must fail")
        } catch let error as SendError {
            XCTAssertEqual(error, .heightUnproven)
        }
        let activeAttempts = await runtime.activePreflightAttemptCount()
        XCTAssertEqual(activeAttempts, 0)
    }

    func testSnapshotResultMustReturnExplicitFinalRecipientRoute() async throws {
        let sender = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        for routeID in [nil, "stale-route", "wrong-route"] as [String?] {
            let runtime = SendRuntime(address: sender)
            await runtime.activate(generation: 1)
            let provider = ScriptedSendProvider(leases: [lease], snapshots: [try SendSnapshot.fixture(height: 42)], finalRouteID: routeID, runtime: runtime)
            let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
            do {
                _ = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: sender, recipient: try sendOtherAddress(), amount: .exact(100)))
                XCTFail("missing or stale final route must fail closed")
            } catch let error as SendError {
                XCTAssertEqual(error, .policyUnavailable)
            }
            let activeAttempts = await runtime.activePreflightAttemptCount()
            XCTAssertEqual(activeAttempts, 0)
        }
    }

    func testRevalidationIsMonotonicAndQuoteRemainsImmutable() async throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        let freshLease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 43, cometReferenceHeight: 43, poolGeneration: 2)
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let provider = ScriptedSendProvider(leases: [lease, freshLease, freshLease], snapshots: [try SendSnapshot.fixture(height: 42), try SendSnapshot.fixture(height: 43), try SendSnapshot.fixture(height: 43)], runtime: runtime)
        let prepared = try await SendPreflightCoordinator(runtime: runtime, provider: provider).prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .maximum))
        let before = prepared.quote
        let beforeAuthority = before.internalAuthorityRecord
        let result = try await SendPreflightCoordinator(runtime: runtime, provider: provider).revalidate(prepared)
        XCTAssertEqual(result.quote.acceptedHeight, before.acceptedHeight)
        XCTAssertEqual(result.quote.amount, before.amount)
        XCTAssertEqual(result.quote.nativeFee, before.nativeFee)
        XCTAssertEqual(prepared.snapshot.digest, try SendSnapshot.fixture(height: 42).digest)
        XCTAssertEqual(prepared.quote.internalAuthorityRecord, beforeAuthority)
        XCTAssertEqual(prepared.snapshot, try SendSnapshot.fixture(height: 42))

        let quoteResult = try await SendPreflightCoordinator(runtime: runtime, provider: provider).revalidate(prepared.quote)
        XCTAssertEqual(quoteResult.quote.acceptedHeight, before.acceptedHeight)
    }

    func testH0H1H2RevalidationIsFreshMonotonicAndKeepsFamilyAndQuoteBytes() async throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let leases = [42, 43, 44].map { EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: Int64($0), cometReferenceHeight: Int64($0), poolGeneration: UInt64($0)) }
        let snapshots = try [42, 43, 44].map(SendSnapshot.fixture(height:))
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let provider = ScriptedSendProvider(leases: leases, snapshots: snapshots, runtime: runtime)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        let prepared = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .maximum, memo: "memo"))
        let amount = prepared.quote.amount
        let nativeFee = prepared.quote.nativeFee
        let totalDebit = prepared.quote.totalDebit
        let memo = prepared.quote.memo
        let acceptedHeight = prepared.quote.acceptedHeight
        let h1 = try await coordinator.revalidate(prepared)
        let h2 = try await coordinator.revalidate(prepared)
        XCTAssertEqual(provider.heights, [42, 43, 44])
        XCTAssertEqual(h1.snapshot.familyID, prepared.snapshot.familyID)
        XCTAssertEqual(h2.snapshot.familyID, prepared.snapshot.familyID)
        XCTAssertEqual(h2.quote.amount, amount)
        XCTAssertEqual(h2.quote.nativeFee, nativeFee)
        XCTAssertEqual(h2.quote.totalDebit, totalDebit)
        XCTAssertEqual(h2.quote.memo, memo)
        XCTAssertEqual(h2.quote.acceptedHeight, acceptedHeight)
        XCTAssertEqual(h1.snapshot.height, 43)
        XCTAssertEqual(h2.snapshot.height, 44)
    }

    func testRevalidationReportsEveryApprovedQuoteChange() async throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let base = try SendSnapshot.fixture(height: 42)
        let cases: [(QuoteChange, (SendSnapshot) throws -> SendSnapshot)] = [
            (.providerIdentity, { try changed($0, familyID: "ibs-mainnet") }),
            (.providerIdentity, { try changed($0, chainID: "other-chain") }),
            (.providerIdentity, { try changed($0, manifestRevision: "other-manifest") }),
            (.providerIdentity, { try changed($0, restEndpoint: "https://other") }),
            (.providerIdentity, { try changed($0, rpcEndpoint: "https://other") }),
            (.heightRollback, { try changed($0, height: 41) }),
            (.accountNumber, { try changed($0, accountNumber: 2) }),
            (.sequence, { try changed($0, sequence: 3) }),
            (.accountPublicKey, { try changed($0, accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: Data([2] + Array(repeating: 1, count: 32))) }),
            (.balance, { try changed($0, spendableRune: 101) }),
            (.nativeFee, { try changed($0, nativeFee: 3) }),
            (.haltStatus, { try changed($0, mimir: MimirSnapshot(haltChainGlobal: 43, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1)) }),
            (.memoPolicy, { try changed($0, memoMaximumBytes: 255) }),
            (.recipientPolicy, { try changed($0, nodeVersion: "3.19.2") }),
            (.recipientPolicy, { try changed($0, querierVersion: "3.19.1") }),
            (.recipientPolicy, { try changed($0, recipientClassification: .module) }),
            (.recipientPolicy, { try changed($0, policyRevision: "other-policy") })
        ]
        for (change, mutate) in cases {
            let runtime = SendRuntime(address: sender)
            await runtime.activate(generation: 1)
            let freshLease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 43, cometReferenceHeight: 43, poolGeneration: 2)
            let provider = ScriptedSendProvider(leases: [EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1), freshLease], snapshots: [base, try mutate(base)], runtime: runtime)
            let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
            let prepared = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .maximum, memo: "memo"))
            do {
                _ = try await coordinator.revalidate(prepared)
                XCTFail("\(change) must be detected")
            } catch let error as SendError {
                guard case let .quoteChanged(changes) = error else { XCTFail("unexpected error: \(error)"); continue }
                XCTAssertEqual(changes.values, [change])
            }
        }
    }

    func testRevalidationRejectsCallerSubstitutedSnapshotContext() async throws {
        let sender = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let provider = ScriptedSendProvider(leases: [EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1), EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 43, cometReferenceHeight: 43, poolGeneration: 2)], snapshots: [try SendSnapshot.fixture(height: 42), try SendSnapshot.fixture(height: 43)], runtime: runtime)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        let prepared = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: sender, recipient: try sendOtherAddress(), amount: .exact(100)))
        let substituted = PreparedQuote(quote: prepared.quote, snapshot: try SendSnapshot.fixture(height: 43))
        do {
            _ = try await coordinator.revalidate(substituted)
            XCTFail("caller-substituted snapshot must fail closed")
        } catch let error as SendError {
            XCTAssertEqual(error, .operationUnavailable)
        }
    }

    func testStoppedGenerationRejectsLatePreflightResult() async throws {
        let sender = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let provider = DelayedSendProvider(lease: lease, snapshot: try SendSnapshot.fixture(height: 42), runtime: runtime)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        let task = Task { try await coordinator.prepareQuote(request: SendQuoteRequest(sender: sender, recipient: try sendOtherAddress(), amount: .exact(100))) }
        await runtime.invalidate(generation: 1)
        do {
            _ = try await task.value
            XCTFail("stopped generation must reject late result")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }
    }

    func testRapidRestartCannotReviveOldAttemptAndNewGenerationPrepares() async throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let delayed = DelayedSendProvider(lease: EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1), snapshot: try SendSnapshot.fixture(height: 42), runtime: runtime)
        let oldTask = Task { try await SendPreflightCoordinator(runtime: runtime, provider: delayed).prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .exact(100))) }
        while await runtime.activePreflightAttemptCount() == 0 { await Task.yield() }
        await runtime.invalidate(generation: 1)
        await runtime.activate(generation: 2)
        do {
            _ = try await oldTask.value
            XCTFail("old generation must not revive")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }
        let fresh = ScriptedSendProvider(leases: [EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 2)], snapshots: [try SendSnapshot.fixture(height: 42)], runtime: runtime)
        let prepared = try await SendPreflightCoordinator(runtime: runtime, provider: fresh).prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .exact(100)))
        XCTAssertEqual(prepared.quote.acceptedHeight, 42)
        let activeAttempts = await runtime.activePreflightAttemptCount()
        XCTAssertEqual(activeAttempts, 0)
    }

}

private func changed(
    _ snapshot: SendSnapshot,
    familyID: String? = nil,
    chainID: String? = nil,
    height: Int64? = nil,
    accountNumber: UInt64? = nil,
    sequence: UInt64? = nil,
    accountPublicKey: String? = nil,
        accountPublicKeyData: Data? = nil,
        spendableRune: BigUInt? = nil,
        nativeFee: BigUInt? = nil,
        mimir: MimirSnapshot? = nil,
        memoMaximumBytes: Int? = nil,
        nodeVersion: String? = nil,
        querierVersion: String? = nil,
        recipientClassification: RecipientAccountClassification? = nil,
    policyRevision: String? = nil,
    restEndpoint: String? = nil,
    rpcEndpoint: String? = nil,
    manifestRevision: String? = nil
) throws -> SendSnapshot {
    try SendSnapshot(
        familyID: familyID ?? snapshot.familyID, chainID: chainID ?? snapshot.chainID, height: height ?? snapshot.height,
        sender: snapshot.sender, recipient: snapshot.recipient, accountNumber: accountNumber ?? snapshot.accountNumber,
        sequence: sequence ?? snapshot.sequence, amount: snapshot.amount, nativeFee: nativeFee ?? snapshot.nativeFee,
        spendableRune: spendableRune ?? snapshot.spendableRune, mimir: mimir ?? snapshot.mimir,
        memoMaximumBytes: memoMaximumBytes ?? snapshot.memoMaximumBytes, nodeVersion: nodeVersion ?? snapshot.nodeVersion,
        querierVersion: querierVersion ?? snapshot.querierVersion, recipientClassification: recipientClassification ?? snapshot.recipientClassification,
        policyRevision: policyRevision ?? snapshot.policyRevision, accountPublicKey: accountPublicKey ?? snapshot.accountPublicKey,
        accountPublicKeyData: accountPublicKeyData ?? snapshot.accountPublicKeyData, restEndpoint: restEndpoint ?? snapshot.restEndpoint,
        rpcEndpoint: rpcEndpoint ?? snapshot.rpcEndpoint, manifestRevision: manifestRevision ?? snapshot.manifestRevision
    )
}

private final class ScriptedSendProvider: SendPreflightProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var leases: [EndpointLease]
    private var snapshots: [SendSnapshot]
    var runtime: SendRuntime?
    private(set) var heights = [Int64]()

    private let finalRouteID: String?

    init(leases: [EndpointLease], snapshots: [SendSnapshot], finalRouteID: String? = "recipient-account", runtime: SendRuntime? = nil) {
        self.leases = leases; self.snapshots = snapshots; self.finalRouteID = finalRouteID; self.runtime = runtime
    }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        let lease = try withLock {
            guard !leases.isEmpty else { throw SendError.providerUnavailable }
            return leases.removeFirst()
        }
        guard minimumHeight.map({ lease.commonReadHeight >= $0 }) ?? true else { throw SendError.heightUnproven }
        return lease
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot {
        try withLock {
            heights.append(height)
            guard !snapshots.isEmpty else { throw SendError.providerUnavailable }
            return snapshots.removeFirst()
        }
    }

    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult {
        let finalAttempt = finalRouteID.map { attempt.withRoute($0) } ?? attempt
        let boundAttempt: SendPreflightAttempt
        if let runtime, let routeID = finalAttempt.routeID {
            boundAttempt = try await runtime.bindRoute(attempt, routeID: routeID)
        } else {
            boundAttempt = finalAttempt
        }
        return SendSnapshotResult(snapshot: try await snapshot(request: request, lease: lease, height: height, policy: policy, attempt: attempt), attempt: boundAttempt)
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body()
    }
}

private struct DelayedSendProvider: SendPreflightProviding {
    let leaseValue: EndpointLease
    let snapshotValue: SendSnapshot
    let runtime: SendRuntime?

    init(lease: EndpointLease, snapshot: SendSnapshot, runtime: SendRuntime? = nil) { leaseValue = lease; snapshotValue = snapshot; self.runtime = runtime }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        try await Task.sleep(nanoseconds: 50_000_000)
        return leaseValue
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot {
        try await Task.sleep(nanoseconds: 50_000_000)
        return snapshotValue
    }

    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult {
        let finalAttempt: SendPreflightAttempt
        if let runtime {
            finalAttempt = try await runtime.bindRoute(attempt, routeID: "recipient-account")
        } else {
            finalAttempt = attempt.withRoute("recipient-account")
        }
        return SendSnapshotResult(snapshot: try await snapshot(request: request, lease: lease, height: height, policy: policy, attempt: attempt), attempt: finalAttempt)
    }
}
