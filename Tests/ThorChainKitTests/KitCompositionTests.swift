import CryptoKit
import Foundation
import secp256k1
import XCTest
@_spi(Testing) @testable import ThorChainKit

final class KitCompositionTests: XCTestCase {
    func testKitCompositionRetainsOneSendRuntimeAndPendingFacade() throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = makeTestKit(address: address, sendRuntime: runtime, persistenceNamespace: "composition")

        XCTAssertTrue(kit.pendingTransactions.isEmpty)
        if case .degraded = kit.pendingTransactionsStatus {} else {
            XCTFail("S2-01 pending state must be explicitly degraded")
        }
        XCTAssertNotNil(kit.sendRuntime)
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

        let firstRuntimeID = await first.sendRuntime.databaseRuntimeIdentifier()
        let secondRuntimeID = await second.sendRuntime.databaseRuntimeIdentifier()
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

        let firstRuntimeID = await first.sendRuntime.databaseRuntimeIdentifier()
        let secondRuntimeID = await second.sendRuntime.databaseRuntimeIdentifier()
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

        XCTAssertNotEqual(ObjectIdentifier(instance.sendRuntime), ObjectIdentifier(fixture.sendRuntime))
        let instanceAuthority = await instance.sendRuntime.authorityClientID()
        let fixtureAuthority = await fixture.sendRuntime.authorityClientID()
        XCTAssertNotEqual(instanceAuthority, fixtureAuthority)
        XCTAssertTrue(instance.pendingTransactions.isEmpty)
        XCTAssertTrue(fixture.pendingTransactions.isEmpty)
        if case .ready = instance.pendingTransactionsStatus {} else { XCTFail("instance pending status must be ready after journal recovery") }
        if case .ready = fixture.pendingTransactionsStatus {} else { XCTFail("fixture pending status must be ready after journal recovery") }
    }

    func testFixtureFactoryUsesRegisteredFamilyAndInjectedTransportAfterStart() async throws {
        let address = try sendTestAddress()
        let family = try XCTUnwrap(NativeRuneEndpointRegistry.families().first { $0.id == "rorcual-mainnet" })
        let endpoints = try EndpointConfiguration(families: [family])
        let transport = CompositionTransport()
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thorchain-s2-06-(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let fixture = try Kit.fixture(
            address: address,
            walletId: "composition-s2-06",
            endpoints: endpoints,
            transport: transport,
            databasePath: databaseURL.path,
            observedAt: Date(timeIntervalSince1970: 1)
        )
        fixture.start()

        var isActive = false
        var urls = [URL]()
        for _ in 0..<100 {
            isActive = await fixture.sendRuntime.isAdmissionActive()
            urls = await transport.requestURLs()
            if isActive && !urls.isEmpty { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        XCTAssertTrue(isActive)
        XCTAssertFalse(urls.isEmpty)
        XCTAssertTrue(urls.allSatisfy { $0.host == family.cosmosRestURL.host || $0.host == family.cometBftURL.host })
    }

    func testFixtureSendReachesInjectedTransportOnceAndAcceptsCheckTx() async throws {
        let signer = try FixtureBroadcastSigner()
        let address = try AccountAddressFactory.address(
            compressedPublicKey: signer.compressedPublicKey,
            network: .mainnet
        )
        let family = try XCTUnwrap(NativeRuneEndpointRegistry.families().first { $0.id == "rorcual-mainnet" })
        let endpoints = try EndpointConfiguration(families: [family])
        let transport = FixtureBroadcastTransport()
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thorchain-s2-06-broadcast-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let fixture = try Kit.fixture(
            address: address,
            walletId: "composition-s2-06-broadcast",
            endpoints: endpoints,
            transport: transport,
            databasePath: databaseURL.path,
            observedAt: Date(timeIntervalSince1970: 1)
        )
        let runtime = fixture.sendRuntime
        await runtime.activate(generation: 1)
        let snapshot = try SendSnapshot(
            familyID: family.id,
            chainID: "thorchain-1",
            height: 12,
            sender: address.raw,
            recipient: try sendOtherAddress().raw,
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
            accountPublicKeyData: signer.compressedPublicKey
        )
        let quote = try await runtime.issuePreflightQuote(
            request: SendQuoteRequest(
                sender: address,
                recipient: try sendOtherAddress(),
                amount: .exact(snapshot.amount)
            ),
            snapshot: snapshot
        )

        let submission = try await fixture.send(quote: quote, signer: signer)

        let postCount = await transport.postCount()
        let requestPath = await transport.requestPath()
        XCTAssertEqual(submission.state, .checkTxAccepted)
        XCTAssertEqual(postCount, 1)
        XCTAssertEqual(requestPath, "/cosmos/tx/v1beta1/txs")
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
    private var requests = [URLRequest]()

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func requestURLs() -> [URL] { requests.compactMap(\.url) }
}

private actor FixtureBroadcastTransport: TestingHTTPTransport {
    private var posts = 0
    private var path: String?

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard request.httpMethod == "POST", let url = request.url, let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: String],
              let txBytes = object["tx_bytes"], object["mode"] == "BROADCAST_MODE_SYNC",
              let raw = Data(base64Encoded: txBytes) else {
            throw BroadcastTransportError.invalidResponse
        }
        posts += 1
        path = url.path
        let hash = SHA256.hash(data: raw).map { String(format: "%02X", $0) }.joined()
        let response = Data("{\"tx_response\":{\"txhash\":\"\(hash)\",\"code\":0}}".utf8)
        return (response, HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!)
    }

    func postCount() -> Int { posts }
    func requestPath() -> String? { path }
}

private final class FixtureBroadcastSigner: Signer, @unchecked Sendable {
    private let key: secp256k1.Signing.PrivateKey
    let compressedPublicKey: Data

    init() throws {
        let key = try secp256k1.Signing.PrivateKey()
        self.key = key
        compressedPublicKey = key.publicKey.rawRepresentation
    }

    func sign(_ request: SigningRequest) async throws -> Data {
        try key.ecdsa.signature(for: SHA256.hash(data: request.serializedSignDoc)).compactRepresentation
    }
}
