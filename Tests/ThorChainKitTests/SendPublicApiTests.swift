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

    func testQuoteZeroAmountPrecedesRecipientChecks() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle(), sendRuntime: runtime),
            persistenceNamespace: "send-validation-order",
            facadeDispatcher: DispatchQueue(label: "send-validation-order")
        )

        await runtime.activate(generation: 1)
        do {
            _ = try await kit.quote(to: address, amount: .exact(0))
            XCTFail("invalid amount must be rejected before recipient checks")
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

    func testSigningRequestCanonicalSummaryRejectsMalformedInput() {
        let validSummary = SigningRequest.Summary(
            sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
            recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
            amount: "1.00000000",
            nativeFee: "0.00000000",
            totalDebit: "1.00000000",
            memo: nil,
            accountNumber: "15",
            sequence: "7"
        )

        XCTAssertNotNil(
            SigningRequest(
                digest: Data(repeating: 0xAB, count: 32),
                serializedSignDoc: Data(repeating: 0x01, count: 2),
                chainId: "thorchain-1",
                requestId: "rqid-1",
                summary: validSummary
            )
        )

        let malformedSummaries: [SigningRequest.Summary] = [
            (SigningRequest.Summary(
                sender: "thor1sender", recipient: validSummary.recipient,
                amount: validSummary.amount, nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: "1", nativeFee: validSummary.nativeFee,
                totalDebit: "1.00000000", memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: validSummary.amount, nativeFee: validSummary.nativeFee,
                totalDebit: "2.00000000", memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: validSummary.amount, nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: "01", sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: validSummary.amount, nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: "foo"
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender.uppercased(), recipient: validSummary.recipient,
                amount: validSummary.amount, nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: "1.0000000\u{301}0", nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: "1..00000000", nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            )),
            (SigningRequest.Summary(
                sender: validSummary.sender, recipient: validSummary.recipient,
                amount: "1.00000000.", nativeFee: validSummary.nativeFee,
                totalDebit: validSummary.totalDebit, memo: nil,
                accountNumber: validSummary.accountNumber, sequence: validSummary.sequence
            ))
        ]

        for summary in malformedSummaries {
            XCTAssertNil(
                SigningRequest(
                    digest: Data(repeating: 0xAB, count: 32),
                    serializedSignDoc: Data(repeating: 0x01, count: 2),
                    chainId: "thorchain-1",
                    requestId: "rqid-1",
                    summary: summary
                )
            )
        }
    }

    func testSigningRequestRejectsUppercaseBech32Exactly() {
        let request = SigningRequest(
            digest: Data(repeating: 0xAB, count: 32),
            serializedSignDoc: Data(repeating: 0x01, count: 2),
            chainId: "thorchain-1",
            requestId: "rqid-1",
            summary: SigningRequest.Summary(
                sender: "THOR1X0JKVQDH2HLPEZTD5ZYYK70N3EFX6MHUDKMNN2",
                recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
                amount: "1.00000000",
                nativeFee: "0.00000000",
                totalDebit: "1.00000000",
                memo: nil,
                accountNumber: "15",
                sequence: "7"
            )
        )

        XCTAssertNil(request)
    }

    func testSigningRequestRejectsDigitCharacterWithMultipleScalars() {
        let request = SigningRequest(
            digest: Data(repeating: 0xAB, count: 32),
            serializedSignDoc: Data(repeating: 0x01, count: 2),
            chainId: "thorchain-1",
            requestId: "rqid-1",
            summary: SigningRequest.Summary(
                sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
                recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
                amount: "1.0000000\u{301}0",
                nativeFee: "0.00000000",
                totalDebit: "1.00000000",
                memo: nil,
                accountNumber: "15",
                sequence: "7"
            )
        )

        XCTAssertNil(request)
    }

    func testSigningRequestReflectionOmitsImmutableBytes() {
        let summary = SigningRequest.Summary(
            sender: "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
            recipient: "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
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
