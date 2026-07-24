import BigInt
import XCTest
@testable import ThorChainKit

final class SendPreflightCoordinatorTests: XCTestCase {
    func testPreparationUsesOneFamilyAndOneCommonHeight() async throws {
        let address = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 43, poolGeneration: 1)
        let snapshot = try SendSnapshot.fixture(height: 42)
        let provider = ScriptedSendProvider(leases: [lease], snapshots: [snapshot])
        let runtime = SendRuntime(address: address)
        await runtime.activate(generation: 1)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: provider)
        let prepared = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: address, recipient: try sendOtherAddress(), amount: .exact(100)))

        XCTAssertEqual(prepared.quote.acceptedHeight, 42)
        XCTAssertEqual(prepared.snapshot.familyID, "rorcual-mainnet")
        XCTAssertEqual(provider.heights, [42])
    }

    func testCrossFamilyOrCrossHeightSnapshotFailsClosed() async throws {
        let address = try sendTestAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        let wrongHeight = try SendSnapshot.fixture(height: 43)
        let runtime = SendRuntime(address: address)
        await runtime.activate(generation: 1)
        let coordinator = SendPreflightCoordinator(runtime: runtime, provider: ScriptedSendProvider(leases: [lease], snapshots: [wrongHeight]))
        do {
            _ = try await coordinator.prepareQuote(request: SendQuoteRequest(sender: address, recipient: try sendOtherAddress(), amount: .exact(100)))
            XCTFail("mixed height must fail")
        } catch let error as SendError {
            XCTAssertEqual(error, .heightUnproven)
        }
    }

    func testRevalidationIsMonotonicAndQuoteRemainsImmutable() async throws {
        let sender = try sendTestAddress()
        let recipient = try sendOtherAddress()
        let family = try EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!)
        let lease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 42, cometReferenceHeight: 42, poolGeneration: 1)
        let freshLease = EndpointLease(family: family, verifiedChainId: "thorchain-1", cosmosReadHeight: 43, cometReferenceHeight: 43, poolGeneration: 2)
        let provider = ScriptedSendProvider(leases: [lease, freshLease], snapshots: [try SendSnapshot.fixture(height: 42), try SendSnapshot.fixture(height: 43)])
        let runtime = SendRuntime(address: sender)
        await runtime.activate(generation: 1)
        let prepared = try await SendPreflightCoordinator(runtime: runtime, provider: provider).prepareQuote(request: SendQuoteRequest(sender: sender, recipient: recipient, amount: .maximum))
        let before = prepared.quote
        let result = try await SendPreflightCoordinator(runtime: runtime, provider: provider).revalidate(prepared)
        XCTAssertEqual(result.quote.acceptedHeight, before.acceptedHeight)
        XCTAssertEqual(result.quote.amount, before.amount)
        XCTAssertEqual(result.quote.nativeFee, before.nativeFee)
        XCTAssertEqual(prepared.snapshot.digest, try SendSnapshot.fixture(height: 42).digest)
    }
}

private final class ScriptedSendProvider: SendPreflightProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var leases: [EndpointLease]
    private var snapshots: [SendSnapshot]
    private(set) var heights = [Int64]()

    init(leases: [EndpointLease], snapshots: [SendSnapshot]) { self.leases = leases; self.snapshots = snapshots }

    func lease(minimumHeight: Int64?) async throws -> EndpointLease {
        lock.lock(); defer { lock.unlock() }
        guard !leases.isEmpty else { throw SendError.providerUnavailable }
        let lease = leases.removeFirst()
        guard minimumHeight.map({ lease.commonReadHeight >= $0 }) ?? true else { throw SendError.heightUnproven }
        return lease
    }

    func snapshot(request: SendQuoteRequest, lease: EndpointLease, height: Int64, policy: SendPolicy) async throws -> SendSnapshot {
        lock.lock(); defer { lock.unlock() }
        heights.append(height)
        guard !snapshots.isEmpty else { throw SendError.providerUnavailable }
        return snapshots.removeFirst()
    }
}
