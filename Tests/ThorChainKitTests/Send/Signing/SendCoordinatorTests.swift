import Foundation
import XCTest
@testable import ThorChainKit

final class SendCoordinatorTests: XCTestCase {
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
        let runtime = SendRuntime(address: try sendTestAddress(), persistenceNamespace: "coordinator-h2")
        await runtime.activate(generation: 1)
        let signer = CountingSigner(publicKey: Data(repeating: 0, count: 33))
        let snapshot = try SendSnapshot.fixture(height: 12)
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(
                sender: try sendTestAddress(),
                recipient: try sendOtherAddress(),
                amount: .exact(snapshot.amount),
                memo: nil
            ),
            snapshot: snapshot
        )
        let result = await SendCoordinator(runtime: runtime).execute(quote: quote, signer: signer)

        XCTAssertEqual(result.failure, .invalidPublicKey)
        XCTAssertEqual(signer.callCount, 0)
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
