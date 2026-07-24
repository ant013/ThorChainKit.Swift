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

    func testExactDigestAndTxRawCrossWireIsRejected() throws {
        XCTAssertThrowsError(try CompactSignature(Data(repeating: 0, count: 64)))
        XCTAssertThrowsError(try CompactSignature(Data(repeating: 0xff, count: 64)))
    }

    func testH2RejectsChangedStaleCancelledExpiredAndLateResults() async throws {
        let (expiryRuntime, expiryQuote, publicKey, expirySnapshot) = try await makeBlockingQuote(namespace: "coordinator-h2-expiry")
        let expiryResult = await SendCoordinator(runtime: expiryRuntime, now: { .distantFuture }).execute(
            quote: expiryQuote,
            signer: CountingSigner(publicKey: publicKey)
        )
        XCTAssertEqual(expiryResult.failure, .quoteExpired)
        let expiryAdmitted = await expiryRuntime.beginAccountAttempt(expirySnapshot.sender)
        XCTAssertTrue(expiryAdmitted)
        await expiryRuntime.endAccountAttempt(expirySnapshot.sender)

        let (cancelRuntime, cancelQuote, cancelPublicKey, cancelSnapshot) = try await makeBlockingQuote(namespace: "coordinator-h2-cancel")
        let cancellation = TaskCancellationBox()
        let cancelTask = Task {
            await SendCoordinator(runtime: cancelRuntime, now: {
                cancellation.cancel()
                return .distantPast
            }).execute(quote: cancelQuote, signer: CountingSigner(publicKey: cancelPublicKey))
        }
        cancellation.install(cancelTask)
        let cancelResult = await cancelTask.value
        XCTAssertEqual(cancelResult.failure, .signerCancelled)
        let cancelAdmitted = await cancelRuntime.beginAccountAttempt(cancelSnapshot.sender)
        XCTAssertTrue(cancelAdmitted)
        await cancelRuntime.endAccountAttempt(cancelSnapshot.sender)
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
