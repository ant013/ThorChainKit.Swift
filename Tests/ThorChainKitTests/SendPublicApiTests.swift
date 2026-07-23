import BigInt
import Combine
import Foundation
import XCTest
@testable import ThorChainKit

final class SendPublicApiTests: XCTestCase {
    func testPendingFacadeReplaysEmptyDegradedSnapshotWithoutStorage() throws {
        let address = try sendTestAddress()
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle()),
            persistenceNamespace: "send-public-api",
            facadeDispatcher: DispatchQueue(label: "send-public-api")
        )
        var snapshots = [[PendingTransaction]]()
        var statuses = [PendingTransactionsStatus]()
        let snapshotCancellable = kit.pendingTransactionsPublisher.sink { snapshots.append($0) }
        let statusCancellable = kit.pendingTransactionsStatusPublisher.sink { statuses.append($0) }

        XCTAssertTrue(kit.pendingTransactions.isEmpty)
        if case .degraded = kit.pendingTransactionsStatus {} else {
            XCTFail("pending status must be degraded before S2-05")
        }
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertTrue(snapshots[0].isEmpty)
        XCTAssertEqual(statuses.count, 1)
        if case .degraded = statuses[0] {} else {
            XCTFail("pending publisher must replay degraded status")
        }

        snapshotCancellable.cancel()
        statusCancellable.cancel()
    }

    func testLifecycleAdmissionPrecedesValidationAndDeferredEnginesFailClosed() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle(), sendRuntime: runtime),
            persistenceNamespace: "send-admission",
            facadeDispatcher: DispatchQueue(label: "send-admission")
        )

        do {
            _ = try await kit.quote(to: address, amount: .exact(0))
            XCTFail("inactive kit must reject before validation")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }

        await runtime.activate(generation: 1)
        let otherRecipient = try Address(
            "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
            network: .mainnet
        )
        do {
            _ = try await kit.quote(to: otherRecipient, amount: .exact(0))
            XCTFail("invalid amount must be rejected before deferred engine")
        } catch let error as SendError {
            XCTAssertEqual(error, .invalidAmount)
        }
    }

    func testPublicSendTypesRemainConstructibleOnlyThroughKitContracts() {
        let _: (SendAmount) -> BigUInt? = { $0.exactAmount }
        let _: (PendingTransactionsStatus) -> Void = { _ in }
        let _: (TransactionID) -> String = { $0.hash }
        XCTAssertTrue(SendAmount.maximum.isMaximum)
        XCTAssertNil(TransactionID(hash: String(repeating: "a", count: 64)))
    }

    func testSigningRequestReflectionOmitsImmutableBytes() {
        let summary = SigningRequest.Summary(
            sender: "thor1sender",
            recipient: "thor1recipient",
            amount: "1.00000000",
            nativeFee: "0.00000000",
            totalDebit: "1.00000000",
            memo: "reviewed",
            accountNumber: "1",
            sequence: "2"
        )
        let request = SigningRequest(
            digest: Data(repeating: 0xAB, count: 32),
            serializedSignDoc: Data(repeating: 0xCD, count: 8),
            chainId: "thorchain-1",
            requestId: "opaque",
            summary: summary
        )!
        let rendered = "\(request) \(String(reflecting: request))"

        XCTAssertTrue(rendered.contains("thorchain-1"))
        XCTAssertFalse(rendered.contains("digest"))
        XCTAssertFalse(rendered.contains("serializedSignDoc"))
        XCTAssertFalse(rendered.contains("ABAB"))
    }
}
