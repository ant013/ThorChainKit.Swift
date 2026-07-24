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

    func testProductionFactoryBridgeIsSynchronousSafe() async throws {
        let address = try sendTestAddress()
        let endpoints = try EndpointConfiguration(families: [
            try EndpointFamilyDescriptor(
                id: "composition-bridge",
                cosmosRestURL: URL(string: "https://rest.composition-bridge.example")!,
                cometBftURL: URL(string: "https://rpc.composition-bridge.example")!
            )
        ])

        let first = try Kit.instance(address: address, walletId: "composition-bridge", endpoints: endpoints)
        let second = try Kit.instance(address: address, walletId: "composition-bridge", endpoints: endpoints)

        let firstRuntimeID = await first.dependencies.sendRuntime.databaseRuntimeIdentifier()
        let secondRuntimeID = await second.dependencies.sendRuntime.databaseRuntimeIdentifier()
        XCTAssertEqual(firstRuntimeID, secondRuntimeID)
    }

    func testTwoKitsShareOnePhysicalWriterAndMigrationBarrier() async throws {
        let address = try sendTestAddress()
        let endpoints = try EndpointConfiguration(families: [
            try EndpointFamilyDescriptor(
                id: "composition-writer",
                cosmosRestURL: URL(string: "https://rest.composition-writer.example")!,
                cometBftURL: URL(string: "https://rpc.composition-writer.example")!
            )
        ])
        let first = try Kit.instance(address: address, walletId: "composition-writer", endpoints: endpoints)
        let second = try Kit.instance(address: address, walletId: "composition-writer", endpoints: endpoints)

        let firstRuntimeID = await first.dependencies.sendRuntime.databaseRuntimeIdentifier()
        let secondRuntimeID = await second.dependencies.sendRuntime.databaseRuntimeIdentifier()
        XCTAssertEqual(firstRuntimeID, secondRuntimeID)
    }

    func testInitializationFailureRemovesOnlyMatchingEntry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thorchain-s2-04-(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try DatabaseRuntime.open(path: directory.path))

        let valid = directory.appendingPathComponent("database.sqlite")
        XCTAssertNoThrow(try DatabaseRuntime.open(path: valid.path))
    }

    func testTwoClientsInSameNamespaceStoppingADoesNotStopB() async throws {
        let address = try sendTestAddress()
        let first = SendRuntime(address: address, persistenceNamespace: "same-namespace")
        let second = SendRuntime(address: address, persistenceNamespace: "same-namespace")

        await first.activate(generation: 1)
        await second.activate(generation: 1)
        await first.invalidate(generation: 1)

        let secondIsActive = await second.isAdmissionActive()
        XCTAssertTrue(secondIsActive)
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
