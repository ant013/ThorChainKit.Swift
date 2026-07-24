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

    func testDatabaseAliasesConvergeOnOnePhysicalIdentity() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thorchain-s2-04-alias-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let original = directory.appendingPathComponent("database.sqlite")
        let hardLink = directory.appendingPathComponent("database-hard.sqlite")
        let symlink = directory.appendingPathComponent("database-link.sqlite")
        XCTAssertTrue(FileManager.default.createFile(atPath: original.path, contents: nil))
        try FileManager.default.linkItem(at: original, to: hardLink)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: original)

        let first = try DatabaseRuntime.open(path: original.path)
        let second = try DatabaseRuntime.open(path: hardLink.path)
        let third = try DatabaseRuntime.open(path: symlink.path)

        XCTAssertTrue(first === second)
        XCTAssertTrue(second === third)
        XCTAssertEqual(first.location.identity, second.location.identity)
    }

    func testInitializationFailureRemovesOnlyMatchingEntry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thorchain-s2-04-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let invalid = directory.appendingPathComponent("invalid.sqlite")
        let invalidAlias = directory.appendingPathComponent("invalid-alias.sqlite")
        let unrelated = directory.appendingPathComponent("unrelated.sqlite")
        XCTAssertTrue(FileManager.default.createFile(atPath: invalid.path, contents: Data("not-sqlite".utf8)))
        try FileManager.default.linkItem(at: invalid, to: invalidAlias)
        let unrelatedRuntime = try DatabaseRuntime.open(path: unrelated.path)
        let invalidIdentity = try DatabaseLocation.resolve(path: invalid.path).identity
        let probe = InitializationProbe(identity: invalidIdentity)
        DatabaseRuntime.initializationControl.install { identity in probe.wait(for: identity) }
        DatabaseRuntime.initializationControl.installSelectionObserver { identity, taskID in
            probe.selected(identity: identity, taskID: taskID)
        }
        defer { DatabaseRuntime.initializationControl.clear() }

        let failures = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            group.addTask { (try? DatabaseRuntime.open(path: invalid.path)) == nil }
            XCTAssertEqual(probe.started.wait(timeout: .now() + 1), .success)
            group.addTask { (try? DatabaseRuntime.open(path: invalidAlias.path)) == nil }
            group.addTask { (try? DatabaseRuntime.open(path: invalid.path)) == nil }
            group.addTask { (try? DatabaseRuntime.open(path: invalidAlias.path)) == nil }
            for _ in 0..<4 {
                XCTAssertEqual(probe.selection.wait(timeout: .now() + 1), .success)
            }
            XCTAssertEqual(probe.uniqueTaskCount, 1)
            probe.release()
            var results = [Bool]()
            for await result in group { results.append(result) }
            return results
        }
        XCTAssertEqual(failures, [true, true, true, true])
        XCTAssertEqual(probe.callbackCount, 1, "aliases must share one in-flight initialization")
        let unrelatedAfterFailure = try DatabaseRuntime.open(path: unrelated.path)
        XCTAssertTrue(unrelatedRuntime === unrelatedAfterFailure)
        DatabaseRuntime.initializationControl.clear()

        let handle = try FileHandle(forWritingTo: invalid)
        try handle.truncate(atOffset: 0)
        try handle.close()

        let retries = await withTaskGroup(of: DatabaseRuntime?.self, returning: [DatabaseRuntime].self) { group in
            for path in [invalid.path, invalidAlias.path, invalid.path, invalidAlias.path] {
                group.addTask { try? DatabaseRuntime.open(path: path) }
            }
            var runtimes = [DatabaseRuntime]()
            for await runtime in group {
                if let runtime { runtimes.append(runtime) }
            }
            return runtimes
        }
        XCTAssertEqual(retries.count, 4)
        if let first = retries.first {
            for runtime in retries.dropFirst() {
                XCTAssertTrue(first === runtime, "concurrent aliases must share one retried writer")
            }
        }
        let unrelatedAfterRetry = try DatabaseRuntime.open(path: unrelated.path)
        XCTAssertTrue(unrelatedRuntime === unrelatedAfterRetry)
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

private final class InitializationProbe: @unchecked Sendable {
    private let identity: DatabaseFileIdentity
    private let lock = NSLock()
    private(set) var callbackCount = 0
    private var taskIDs = Set<UUID>()
    let started = DispatchSemaphore(value: 0)
    let selection = DispatchSemaphore(value: 0)
    private let gate = DispatchSemaphore(value: 0)

    init(identity: DatabaseFileIdentity) {
        self.identity = identity
    }

    func wait(for identity: DatabaseFileIdentity) {
        guard identity == self.identity else { return }
        lock.lock()
        callbackCount += 1
        lock.unlock()
        started.signal()
        gate.wait()
    }

    func release() {
        gate.signal()
    }

    func selected(identity: DatabaseFileIdentity, taskID: UUID) {
        guard identity == self.identity else { return }
        lock.lock()
        taskIDs.insert(taskID)
        lock.unlock()
        selection.signal()
    }

    var uniqueTaskCount: Int {
        lock.lock(); defer { lock.unlock() }
        return taskIDs.count
    }
}

private actor CompositionTransport: TestingHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
