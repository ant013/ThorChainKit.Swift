import Foundation
import BigInt
import Combine
import XCTest
@testable import ThorChainKit

final class SendFacadeAdmissionTests: XCTestCase {
    func testRetryAdmissionIsLifecycleFirstAndDeferredEngineFailsClosed() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle(), sendRuntime: runtime),
            persistenceNamespace: "admission",
            facadeDispatcher: DispatchQueue(label: "admission")
        )
        let transactionId = try XCTUnwrap(TransactionID(hash: String(repeating: "A", count: 64)))

        do {
            _ = try await kit.retryBroadcast(transactionId: transactionId, acceptingNativeFee: 1)
            XCTFail("inactive kit must reject retry")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }

        await runtime.activate(generation: 1)
        do {
            _ = try await kit.retryBroadcast(transactionId: transactionId, acceptingNativeFee: 1)
            XCTFail("deferred retry engine must fail closed")
        } catch let error as SendError {
            XCTAssertEqual(error, .operationUnavailable)
        }
    }

    func testInactiveFacadeRejectsEveryMutationBeforeDeferredDependencies() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle(), sendRuntime: runtime),
            persistenceNamespace: "admission-all",
            facadeDispatcher: DispatchQueue(label: "admission-all")
        )
        let source = QuoteStore()
        let sourceClock = TestSendClock()
        let quote = try issueTestQuote(in: source, clock: sourceClock)
        let id = try XCTUnwrap(TransactionID(hash: String(repeating: "C", count: 64)))
        let signer = AdmissionSigner()
        var pendingSnapshots = [[PendingTransaction]]()
        var pendingStatuses = [PendingTransactionsStatus]()
        let pendingCancellable = kit.pendingTransactionsPublisher.sink { pendingSnapshots.append($0) }
        let statusCancellable = kit.pendingTransactionsStatusPublisher.sink { pendingStatuses.append($0) }

        do { _ = try await kit.quote(to: address, amount: .maximum); XCTFail("quote must be lifecycle-gated") }
        catch let error as SendError { XCTAssertEqual(error, .kitNotStarted) }
        do { _ = try await kit.send(quote: quote, signer: signer); XCTFail("send must be lifecycle-gated") }
        catch let error as SendError { XCTAssertEqual(error, .kitNotStarted) }
        do { _ = try await kit.retryBroadcast(transactionId: id, acceptingNativeFee: BigUInt(1)); XCTFail("retry must be lifecycle-gated") }
        catch let error as SendError { XCTAssertEqual(error, .kitNotStarted) }

        await runtime.activate(generation: 1)
        do { _ = try await kit.quote(to: try sendOtherAddress(), amount: .exact(BigUInt(1))); XCTFail("valid quote request must reach deferred engine") }
        catch let error as SendError { XCTAssertEqual(error, .operationUnavailable) }
        do { _ = try await kit.quote(to: address, amount: .exact(BigUInt(1))); XCTFail("self recipient must be locally rejected") }
        catch let error as SendError { XCTAssertEqual(error, .selfRecipient) }
        do { _ = try await kit.send(quote: quote, signer: signer); XCTFail("deferred send must fail closed") }
        catch let error as SendError { XCTAssertEqual(error, .operationUnavailable) }
        do { _ = try await kit.retryBroadcast(transactionId: id, acceptingNativeFee: BigUInt("18446744073709551617")); XCTFail("deferred retry must fail closed") }
        catch let error as SendError { XCTAssertEqual(error, .operationUnavailable) }

        XCTAssertEqual(signer.signCallCount, 0)
        XCTAssertNoThrow(try source.consume(quote, activeGeneration: 7))
        XCTAssertEqual(pendingSnapshots.count, 1)
        XCTAssertTrue(pendingSnapshots[0].isEmpty)
        XCTAssertEqual(pendingStatuses.count, 1)
        if case .degraded = pendingStatuses[0] {} else { XCTFail("pending status must not mutate") }
        pendingCancellable.cancel()
        statusCancellable.cancel()
    }
}

private final class AdmissionSigner: Signer, @unchecked Sendable {
    let compressedPublicKey = Data()
    private(set) var signCallCount = 0
    func sign(_ request: SigningRequest) async throws -> Data {
        signCallCount += 1
        return Data()
    }
}
