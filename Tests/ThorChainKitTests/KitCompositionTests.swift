import Foundation
import XCTest
@_spi(Testing) @testable import ThorChainKit

final class KitCompositionTests: XCTestCase {
    func testKitCompositionRetainsOneSendRuntimeAndPendingFacade() throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle(), sendRuntime: runtime),
            persistenceNamespace: "composition",
            facadeDispatcher: DispatchQueue(label: "composition")
        )

        XCTAssertTrue(kit.pendingTransactions.isEmpty)
        if case .degraded = kit.pendingTransactionsStatus {} else {
            XCTFail("S2-01 pending state must be explicitly degraded")
        }
        XCTAssertNotNil(kit.dependencies.sendRuntime)
    }

    func testInstanceAndFixtureFactoriesEachOwnOneDistinctSendRuntime() async throws {
        let address = try sendTestAddress()
        let walletId = "composition-same-wallet"
        let endpoints = try EndpointConfiguration(families: [
            try EndpointFamilyDescriptor(
                id: "composition",
                cosmosRestURL: URL(string: "https://rest.composition.example")!,
                cometBftURL: URL(string: "https://rpc.composition.example")!
            )
        ])
        let instance = try Kit.instance(
            address: address,
            walletId: walletId,
            endpoints: endpoints
        )
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thorchain-s2-01-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }
        let fixture = try Kit.fixture(
            address: address,
            walletId: walletId,
            endpoints: endpoints,
            transport: CompositionTransport(),
            databasePath: databaseURL.path,
            observedAt: Date(timeIntervalSince1970: 1)
        )

        XCTAssertNotEqual(ObjectIdentifier(instance.dependencies.sendRuntime), ObjectIdentifier(fixture.dependencies.sendRuntime))
        let instanceAuthority = await instance.dependencies.sendRuntime.authorityClientID()
        let fixtureAuthority = await fixture.dependencies.sendRuntime.authorityClientID()
        XCTAssertNotEqual(instanceAuthority, fixtureAuthority)
        XCTAssertTrue(instance.pendingTransactions.isEmpty)
        XCTAssertTrue(fixture.pendingTransactions.isEmpty)
        if case .degraded = instance.pendingTransactionsStatus {} else { XCTFail("instance pending status must be degraded") }
        if case .degraded = fixture.pendingTransactionsStatus {} else { XCTFail("fixture pending status must be degraded") }
    }
}

private actor CompositionTransport: TestingHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
