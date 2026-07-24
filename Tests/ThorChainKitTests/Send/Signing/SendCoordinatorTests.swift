import Foundation
import XCTest
@testable import ThorChainKit

final class SendCoordinatorTests: XCTestCase {
    func testSignerStartsAfterAdmissionQuoteConsumptionBindingAndH1() async throws {
        let sender = try sendOtherAddress()
        let recipient = try sendTestAddress()
        let publicKey = Data(hex: "02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7")
        let snapshot = try SendSnapshot(
            familyID: "rorcual-mainnet", chainID: "thorchain-1", height: 12,
            sender: sender.raw, recipient: recipient.raw, accountNumber: 1, sequence: 2,
            amount: 100, nativeFee: 2, spendableRune: 102,
            mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256, nodeVersion: "3.19.3", querierVersion: "3.19.0",
            accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: publicKey
        )
        let runtime = SendRuntime(address: sender, persistenceNamespace: "coordinator-ordering")
        await runtime.activate(generation: 1)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .exact(snapshot.amount), memo: nil),
            snapshot: snapshot
        )
        let signer = CountingSigner(publicKey: publicKey)

        let result = await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer)

        XCTAssertEqual(signer.callCount, 1)
        XCTAssertEqual(result.failure, .invalidSignature)
        do {
            _ = try await runtime.consumeQuote(quote)
            XCTFail("consumed quote must not be reusable")
        } catch {
            XCTAssertEqual(error as? SendError, .quoteAlreadyConsumed)
        }
    }

    func testCancelledBeforeAdmissionLeavesQuoteUnused() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-pre-cancel")
        await runtime.activate(generation: 1)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(sender: try sendTestAddress(), recipient: try sendOtherAddress(), amount: .exact(100), memo: nil),
            snapshot: try SendSnapshot.fixture(height: 12)
        )
        let signer = CountingSigner(publicKey: Data(repeating: 0, count: 33))
        let task = Task { await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer) }
        task.cancel()

        let result = await task.value
        XCTAssertEqual(result.failure, .signerCancelled)
        XCTAssertEqual(signer.callCount, 0)
        do {
            _ = try await runtime.consumeQuote(quote)
        } catch {
            XCTFail("pre-cancelled quote must remain unused: \(error)")
        }
    }

    func testNonCooperativeSignerCancellationReturnsPromptlyAndLateResultIsDiscarded() async throws {
        let (runtime, quote, publicKey, snapshot) = try await makeBlockingQuote(namespace: "coordinator-cancel")
        let signer = NonCooperativeSigner(publicKey: publicKey)
        let task = Task { await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer) }
        XCTAssertEqual(signer.started.wait(timeout: .now() + 1), .success)

        task.cancel()
        let result = await task.value
        XCTAssertEqual(result.failure, .signerCancelled)
        XCTAssertEqual(signer.callCount, 1)

        let second = await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer)
        XCTAssertEqual(second.failure, .sendInProgress)
        XCTAssertEqual(signer.callCount, 1)

        signer.finish(Data(repeating: 1, count: 64))
        XCTAssertEqual(signer.finished.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(signer.lateHandoffCount, 0)

        let freshQuote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(sender: try sendOtherAddress(), recipient: try sendTestAddress(), amount: .exact(snapshot.amount), memo: nil),
            snapshot: snapshot
        )
        let freshSigner = CountingSigner(publicKey: publicKey)
        _ = await SendCoordinator(runtime: runtime).execute(quote: freshQuote, signer: freshSigner)
        XCTAssertEqual(freshSigner.callCount, 1)
    }

    func testAdmissionAndOperationHoldPrecedeQuoteAccess() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-order")
        let signer = CountingSigner(publicKey: Data(repeating: 0, count: 33))
        let quote = try issueTestQuote(in: QuoteStore(), clock: TestSendClock())
        let result = await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer)

        XCTAssertEqual(result.failure, .kitNotStarted)
        let admitted = await runtime.beginAccountAttempt(quote.internalAuthorityRecord.snapshot.sender)
        XCTAssertFalse(admitted)
        XCTAssertEqual(signer.callCount, 0)
    }

    func testStopDoesNotReleaseAdmittedAttemptHold() async throws {
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-stop")
        await runtime.activate(generation: 1)
        let sender = try sendTestAddress().raw
        let admitted = await runtime.beginAccountAttempt(sender)
        XCTAssertTrue(admitted)

        await runtime.invalidate(generation: 1)
        let admittedAfterStop = await runtime.beginAccountAttempt(sender)
        XCTAssertFalse(admittedAfterStop)
        await runtime.endAccountAttempt(sender)
    }

    func testExactDigestAndTxRawCrossWireIsRejected() async throws {
        let vector = try await makeGoldenVector()
        let payload = try DirectSignCodec.makeSignPayload(
            snapshot: vector.snapshot,
            quote: PreparedQuote(quote: vector.quote, snapshot: vector.snapshot),
            publicKey: vector.publicKey
        )
        XCTAssertEqual(payload.digest.hex, vector.digestHex)

        let compact = try SignerVerifier().verify(
            signature: vector.signature,
            digest: payload.digest,
            publicKey: vector.publicKey
        )
        let signed = try DirectSignCodec.makeTxRaw(payload: payload, compactSignature: compact.rawValue)
        XCTAssertEqual(signed.txRaw.hex, vector.txRawHex)

        let changedSnapshot = try changed(vector.snapshot, sequence: 2)
        let changedQuote = try QuoteStore(clock: TestSendClock()).issue(
            sender: try Address(vector.snapshot.sender, network: .mainnet),
            recipient: try Address(vector.snapshot.recipient, network: .mainnet),
            amountMagnitude: SendMagnitude(vector.snapshot.amount).data,
            isMaximum: false,
            nativeFeeMagnitude: SendMagnitude(vector.snapshot.nativeFee).data,
            totalDebitMagnitude: SendMagnitude(vector.snapshot.totalDebit).data,
            memo: nil,
            acceptedHeight: changedSnapshot.height,
            generation: 1,
            accountNumber: changedSnapshot.accountNumber,
            sequence: changedSnapshot.sequence,
            providerFamilyID: changedSnapshot.familyID,
            preflightContext: changedSnapshot
        )
        let changedPayload = try DirectSignCodec.makeSignPayload(
            snapshot: changedSnapshot,
            quote: PreparedQuote(quote: changedQuote, snapshot: changedSnapshot),
            publicKey: vector.publicKey
        )
        XCTAssertNotEqual(payload.digest, changedPayload.digest)
        XCTAssertThrowsError(try SignerVerifier().verify(
            signature: vector.signature,
            digest: changedPayload.digest,
            publicKey: vector.publicKey
        ))
    }

    func testH2RejectsChangedStaleCancelledExpiredAndLateResults() async throws {
        for (name, mutation, expectedChange) in [
            ("changed", { try changed($0, sequence: 3) }, QuoteChange.sequence),
            ("stale", { try changed($0, height: 11) }, QuoteChange.heightRollback)
        ] as [(String, (SendSnapshot) throws -> SendSnapshot, QuoteChange)] {
            let (runtime, quote, publicKey, snapshot) = try await makeBlockingQuote(namespace: "coordinator-h2-" + name)
            let provider = try CoordinatorH2Provider(
                runtime: runtime,
                base: snapshot,
                h2: try mutation(snapshot)
            )
            let signer = CountingSigner(publicKey: publicKey)
            let result = await SendCoordinator(runtime: runtime, preflight: SendPreflightCoordinator(runtime: runtime, provider: provider)).execute(
                quote: quote,
                signer: signer
            )

            guard case let .failure(error) = result else { return XCTFail("H2 " + name + " must not hand off") }
            guard case let .quoteChanged(changes) = error else { return XCTFail("H2 " + name + " returned \(error)") }
            XCTAssertTrue(changes.values.contains(expectedChange))
            XCTAssertEqual(signer.callCount, 1)
            XCTAssertEqual(provider.snapshotCount, 2)
            await Task.yield()
            XCTAssertEqual(provider.snapshotCount, 2, name + " rejection must not start a later provider request")
        }

        let (lateRuntime, lateQuote, latePublicKey, lateSnapshot) = try await makeBlockingQuote(namespace: "coordinator-h2-late")
        let lateProvider = try CoordinatorH2Provider(runtime: lateRuntime, base: lateSnapshot, h2: lateSnapshot, blocksH2: true)
        let lateSigner = CountingSigner(publicKey: latePublicKey)
        let lateTask = Task {
            await SendCoordinator(runtime: lateRuntime, preflight: SendPreflightCoordinator(runtime: lateRuntime, provider: lateProvider)).execute(
                quote: lateQuote,
                signer: lateSigner
            )
        }
        XCTAssertEqual(lateProvider.h2Started.wait(timeout: .now() + 1), .success)
        await lateRuntime.invalidate(generation: 1)
        let lateResult = await lateTask.value
        XCTAssertEqual(lateResult.failure, .kitNotStarted)
        XCTAssertEqual(lateSigner.callCount, 1)
        XCTAssertEqual(lateProvider.snapshotCount, 2)
        lateProvider.releaseH2()
        for _ in 0..<4 { await Task.yield() }
        XCTAssertEqual(lateProvider.snapshotCount, 2, "late H2 completion must not start a later provider request")
    }

    func testCleanupFailureReturnsRepairPending() async throws {
        let sender = try sendOtherAddress()
        let recipient = try sendTestAddress()
        let publicKey = Data(hex: "02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7")
        let snapshot = try SendSnapshot(
            familyID: "rorcual-mainnet",
            chainID: "thorchain-1",
            height: 12,
            sender: sender.raw,
            recipient: recipient.raw,
            accountNumber: 1,
            sequence: 2,
            amount: 100,
            nativeFee: 2,
            spendableRune: 102,
            mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256,
            nodeVersion: "3.19.3",
            querierVersion: "3.19.0",
            accountPublicKey: "/cosmos.crypto.secp256k1.PubKey",
            accountPublicKeyData: publicKey
        )
        let runtime = SendRuntime(
            address: sender,
            persistenceNamespace: "coordinator-repair",
            reservationStore: FailingReservationStore()
        )
        await runtime.activate(generation: 1)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .exact(snapshot.amount), memo: nil),
            snapshot: snapshot
        )
        let result = await SendCoordinator(runtime: runtime, network: .mainnet).execute(
            quote: quote,
            signer: CountingSigner(publicKey: publicKey)
        )

        guard case let .repairPending(intent) = result else {
            if case let .failure(error) = result {
                return XCTFail("failed owner cleanup returned \(error)")
            }
            return XCTFail("failed owner cleanup must retain typed repair intent")
        }
        XCTAssertEqual(intent.sequence, 2)
        XCTAssertFalse(intent.reservationOwnerToken.isEmpty)
        XCTAssertEqual(intent.accountGate.sender, sender.raw)
        XCTAssertEqual(intent.operationHold.accountGate, intent.accountGate)
    }

    private func makeBlockingQuote(namespace: String) async throws -> (SendRuntime, SendQuote, Data, SendSnapshot) {
        let sender = try sendOtherAddress()
        let recipient = try sendTestAddress()
        let publicKey = Data(hex: "02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7")
        let snapshot = try SendSnapshot(
            familyID: "rorcual-mainnet", chainID: "thorchain-1", height: 12,
            sender: sender.raw, recipient: recipient.raw, accountNumber: 1, sequence: 2,
            amount: 100, nativeFee: 2, spendableRune: 102,
            mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256, nodeVersion: "3.19.3", querierVersion: "3.19.0",
            accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: publicKey
        )
        let runtime = SendRuntime(address: sender, persistenceNamespace: namespace)
        await runtime.activate(generation: 1)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .exact(snapshot.amount), memo: nil),
            snapshot: snapshot
        )
        return (runtime, quote, publicKey, snapshot)
    }

    private func makeGoldenVector(namespace: String = "coordinator-golden") async throws -> GoldenVector {
        let sender = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68"
        let recipient = "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean"
        let publicKey = Data(hex: "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        let snapshot = try SendSnapshot(
            familyID: "thorchain-mainnet", chainID: "thorchain-1", height: 1,
            sender: sender, recipient: recipient, accountNumber: 123_456, sequence: 1,
            amount: 100_000_000, nativeFee: 0, spendableRune: 100_000_000,
            mimir: MimirSnapshot(haltChainGlobal: -1, nodePauseChainGlobal: -1, haltTHORChain: -1, solvencyHaltTHORChain: -1),
            memoMaximumBytes: 256, nodeVersion: "3.19.3", querierVersion: "3.19.3",
            accountPublicKey: "/cosmos.crypto.secp256k1.PubKey", accountPublicKeyData: publicKey
        )
        let runtime = SendRuntime(address: try Address(sender, network: .mainnet), persistenceNamespace: namespace)
        await runtime.activate(generation: 1)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(
                sender: try Address(sender, network: .mainnet),
                recipient: try Address(recipient, network: .mainnet),
                amount: .exact(snapshot.amount)
            ),
            snapshot: snapshot
        )
        return GoldenVector(
            runtime: runtime,
            quote: quote,
            snapshot: snapshot,
            publicKey: publicKey,
            signature: Data(hex: "23103daa64330d051da3bfa85ea7c8af9080edf19b19a306403303634b0992a32cc1b9061b2e76cd245edb2976bb437bc6636dfb23deae31e38508c5478dae45"),
            digestHex: "1ff56dd4c3627af0cee040965178f50c8d7c854e909d7b54aedbd1b7bf110b68",
            txRawHex: "0a530a510a0e2f74797065732e4d736753656e64123f0a14751e76e8199196d454941c45d1b3a323f1433bd612145a0dba49dab8fec87c6dd7c01b564ee72a8515a61a110a0472756e65120931303030303030303012590a500a460a1f2f636f736d6f732e63727970746f2e736563703235366b312e5075626b7912230a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f8179812040a0208011801120510c08db7011a4023103daa64330d051da3bfa85ea7c8af9080edf19b19a306403303634b0992a32cc1b9061b2e76cd245edb2976bb437bc6636dfb23deae31e38508c5478dae45"
        )
    }
}

private struct GoldenVector {
    let runtime: SendRuntime
    let quote: SendQuote
    let snapshot: SendSnapshot
    let publicKey: Data
    let signature: Data
    let digestHex: String
    let txRawHex: String
}

private final class CoordinatorH2Provider: SendPreflightProviding, @unchecked Sendable {
    private let runtime: SendRuntime
    private let base: SendSnapshot
    private let h2: SendSnapshot
    private let blocksH2: Bool
    private let family: EndpointFamilyDescriptor
    private let lock = NSLock()
    private var leasesIssued = 0
    private var snapshotsIssued = 0
    private var h2Continuation: CheckedContinuation<Void, Never>?

    let h2Started = DispatchSemaphore(value: 0)

    init(runtime: SendRuntime, base: SendSnapshot, h2: SendSnapshot, blocksH2: Bool = false) throws {
        self.runtime = runtime
        self.base = base
        self.h2 = h2
        self.blocksH2 = blocksH2
        family = try EndpointFamilyDescriptor(
            id: base.familyID,
            cosmosRestURL: URL(string: "https://rest.coordinator-h2.example")!,
            cometBftURL: URL(string: "https://rpc.coordinator-h2.example")!
        )
    }

    var snapshotCount: Int {
        lock.lock(); defer { lock.unlock() }
        return snapshotsIssued
    }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        lock.lock(); leasesIssued += 1; lock.unlock()
        return EndpointLease(family: family, verifiedChainId: base.chainID, cosmosReadHeight: base.height, cometReferenceHeight: base.height, poolGeneration: 1)
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshot {
        try await snapshotResult(request: request, lease: lease, height: height, policy: policy, attempt: attempt).snapshot
    }

    func snapshotResult(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy, attempt: SendPreflightAttempt) async throws -> SendSnapshotResult {
        let index = withLock {
            snapshotsIssued += 1
            return snapshotsIssued
        }
        if index == 2, blocksH2 {
            h2Started.signal()
            await withCheckedContinuation { continuation in
                withLock { h2Continuation = continuation }
            }
        }
        let snapshot = index == 1 ? base : h2
        let boundAttempt = try await runtime.bindRoute(attempt, routeID: "recipient-account")
        return SendSnapshotResult(snapshot: snapshot, attempt: boundAttempt)
    }

    func releaseH2() {
        let continuation = withLock { () -> CheckedContinuation<Void, Never>? in
            let continuation = h2Continuation
            h2Continuation = nil
            return continuation
        }
        continuation?.resume()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }
}

private final class CountingSigner: Signer, @unchecked Sendable {
    let compressedPublicKey: Data
    private(set) var callCount = 0

    init(publicKey: Data) {
        compressedPublicKey = publicKey
    }

    func sign(_ request: SigningRequest) async throws -> Data {
        callCount += 1
        return Data()
    }
}

private final class NonCooperativeSigner: Signer, @unchecked Sendable {
    let compressedPublicKey: Data
    let started = DispatchSemaphore(value: 0)
    let finished = DispatchSemaphore(value: 0)
    private let stateQueue = DispatchQueue(label: "ThorChainKit.Tests.NonCooperativeSigner")
    private var continuation: CheckedContinuation<Data, Never>?
    private(set) var callCount = 0
    private(set) var lateHandoffCount = 0

    init(publicKey: Data) { compressedPublicKey = publicKey }

    func sign(_ request: SigningRequest) async throws -> Data {
        stateQueue.sync { callCount += 1 }
        started.signal()
        return await withCheckedContinuation { continuation in
            stateQueue.sync { self.continuation = continuation }
        }
    }

    func finish(_ signature: Data) {
        let continuation = stateQueue.sync { () -> CheckedContinuation<Data, Never>? in
            let continuation = self.continuation
            self.continuation = nil
            return continuation
        }
        continuation?.resume(returning: signature)
        finished.signal()
    }
}

private final class TaskCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<SendCoordinatorResult, Never>?
    private var requested = false

    func install(_ task: Task<SendCoordinatorResult, Never>) {
        lock.lock()
        self.task = task
        let requested = self.requested
        lock.unlock()
        if requested { task.cancel() }
    }

    func cancel() {
        lock.lock()
        requested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}

private extension SendCoordinatorResult {
    var failure: SendError? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

private final class FailingReservationStore: SequenceReservationManaging, @unchecked Sendable {
    func acquire(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool { true }
    func release(_ key: SequenceReservationKey, ownerToken: Data) throws -> Bool { false }
}

private extension Data {
    init(hex: String) {
        self.init(stride(from: 0, to: hex.count, by: 2).map { index in
            let start = hex.index(hex.startIndex, offsetBy: index)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)!
        })
    }
}
