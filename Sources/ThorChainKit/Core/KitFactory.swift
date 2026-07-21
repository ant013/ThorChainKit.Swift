import CryptoKit
import Foundation

public extension Kit {
    static func instance(
        address: Address,
        walletId: String,
        endpoints: EndpointConfiguration
    ) throws -> Kit {
        guard !walletId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KitConfigurationError.invalidWalletId
        }

        var namespaceInput = Data(walletId.utf8)
        namespaceInput.append(0)
        namespaceInput.append(contentsOf: address.network.persistenceKey.utf8)
        let namespace = SHA256.hash(data: namespaceInput)
            .map { String(format: "%02x", $0) }
            .joined()

        let facadeDispatcher = DispatchQueue(label: "io.horizontalsystems.thorchain-kit.facade")
        let publishing = StatePublishing()
        let storage = try GrdbAccountStateStorage(path: try databasePath(namespace: namespace))
        let probe = LiveNodeProbe(configuration: endpoints)
        let pool = EndpointPool(network: address.network, configuration: endpoints, probe: probe)
        let reader = ReadOperationCoordinator(
            pool: pool,
            client: LiveThorNodeClient(
                requestTimeout: endpoints.requestTimeout,
                clientId: endpoints.clientId,
                maximumBalancePageCount: endpoints.policy.maximumBalancePageCount
            ),
            configuration: endpoints
        )
        let key = StorageKey(persistenceNamespace: namespace)
        let gate = LifecycleGate(
            dispatcher: facadeDispatcher,
            address: address,
            key: key,
            storage: storage,
            publishing: publishing
        )
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: reader,
            storage: storage,
            gate: gate
        )
        let bridge = LifecycleCommandBridge(syncer: syncer, gate: gate)
        return Kit(
            address: address,
            dependencies: KitDependencies(
                lifecycle: bridge
            ),
            persistenceNamespace: namespace,
            facadeDispatcher: facadeDispatcher,
            publishing: publishing
        )
    }

    @_spi(Testing)
    static func fixture(
        address: Address,
        walletId: String,
        endpoints: EndpointConfiguration,
        transport: any TestingHTTPTransport,
        databasePath: String,
        observedAt: Date
    ) throws -> Kit {
        guard !walletId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KitConfigurationError.invalidWalletId
        }

        var namespaceInput = Data(walletId.utf8)
        namespaceInput.append(0)
        namespaceInput.append(contentsOf: address.network.persistenceKey.utf8)
        let namespace = SHA256.hash(data: namespaceInput)
            .map { String(format: "%02x", $0) }
            .joined()
        let facadeDispatcher = DispatchQueue(label: "io.horizontalsystems.thorchain-kit.facade")
        let publishing = StatePublishing()
        let storage = try GrdbAccountStateStorage(path: databasePath)
        let adapter = FixtureHTTPTransportAdapter(transport: transport)
        let probe = LiveNodeProbe(configuration: endpoints, transport: adapter)
        let pool = EndpointPool(network: address.network, configuration: endpoints, probe: probe)
        let reader = ReadOperationCoordinator(
            pool: pool,
            client: LiveThorNodeClient(
                transport: adapter,
                requestTimeout: endpoints.requestTimeout,
                clientId: endpoints.clientId,
                maximumBalancePageCount: endpoints.policy.maximumBalancePageCount
            ),
            configuration: endpoints,
            wallClock: FixtureAccountReadWallClock(now: observedAt)
        )
        let key = StorageKey(persistenceNamespace: namespace)
        let gate = LifecycleGate(
            dispatcher: facadeDispatcher,
            address: address,
            key: key,
            storage: storage,
            publishing: publishing
        )
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: reader,
            storage: storage,
            gate: gate
        )
        return Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: LifecycleCommandBridge(syncer: syncer, gate: gate)),
            persistenceNamespace: namespace,
            facadeDispatcher: facadeDispatcher,
            publishing: publishing
        )
    }

    private static func databasePath(namespace: String) throws -> String {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ThorChainKit", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("account-\(namespace).sqlite").path
    }
}

private struct FixtureHTTPTransportAdapter: HTTPTransporting {
    let transport: any TestingHTTPTransport

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await transport.data(for: request)
    }
}

private struct FixtureAccountReadWallClock: AccountReadWallClock {
    let now: Date
}
