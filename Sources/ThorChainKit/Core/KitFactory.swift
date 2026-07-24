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
        let databaseRuntime = try DatabaseRuntime.open(path: try databasePath(namespace: namespace))
        let storage = GrdbAccountStateStorage(writer: databaseRuntime.pool)
        let probe = LiveNodeProbe(configuration: endpoints)
        let pool = EndpointPool(network: address.network, configuration: endpoints, probe: probe)
        let liveClient = LiveThorNodeClient(
            requestTimeout: endpoints.requestTimeout,
            clientId: endpoints.clientId,
            maximumBalancePageCount: endpoints.policy.maximumBalancePageCount
        )
        let broadcastClients = Dictionary(uniqueKeysWithValues: endpoints.families.map { family in
            (family.id, CosmosTransactionBroadcaster(baseURL: family.cosmosRestURL))
        })
        let lookupClients = Dictionary(uniqueKeysWithValues: endpoints.families.map { family in
            (family.id, CosmosTransactionLookupClient(baseURL: family.cosmosRestURL))
        })
        let reader = ReadOperationCoordinator(
            pool: pool,
            client: liveClient,
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
        let publicationBarrier = PendingPublicationBarrier()
        let pendingRepository = PendingTransactionRepository(
            journal: SendJournal(writer: databaseRuntime.pool, persistenceNamespace: namespace),
            network: address.network,
            publicationBarrier: publicationBarrier
        )
        let sendRuntime = SendRuntime(
            address: address,
            persistenceNamespace: namespace,
            runtimeIdentifier: databaseRuntime.location.identity.rawValue,
            databaseWriter: databaseRuntime.pool,
            broadcastOperation: { familyID, transaction in
                guard let client = broadcastClients[familyID] else { throw BroadcastTransportError.invalidEndpoint }
                return try await client.broadcast(transaction: transaction)
            },
            pendingRepository: pendingRepository,
            publicationBarrier: publicationBarrier,
            lookupOperation: { familyID, transactionID in
                guard let client = lookupClients[familyID] else { return .providerInconsistent }
                return await client.lookup(transactionID: transactionID)
            },
            operationDeadline: endpoints.requestTimeout
        )
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: reader,
            storage: storage,
            gate: gate
        )
        let bridge = LifecycleCommandBridge(syncer: syncer, gate: gate, sendRuntime: sendRuntime)
        let preflight = SendPreflightCoordinator(
            runtime: sendRuntime,
            provider: ThorNodeSendPreflightProvider(
                node: ThorNodeSendClient(transport: liveClient),
                leaseProvider: { try await pool.lease(excludingFamilyIds: []) },
                runtime: sendRuntime,
                freshLeaseProvider: { familyID in try await pool.freshLease(familyID: familyID) }
            )
        )
        return Kit(
            address: address,
            dependencies: KitDependencies(
                lifecycle: bridge,
                sendRuntime: sendRuntime,
                preflight: preflight,
                pendingRepository: pendingRepository
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
        let databaseRuntime = try DatabaseRuntime.open(path: databasePath)
        let storage = GrdbAccountStateStorage(writer: databaseRuntime.pool)
        let adapter = FixtureHTTPTransportAdapter(transport: transport)
        let probe = LiveNodeProbe(configuration: endpoints, transport: adapter)
        let pool = EndpointPool(network: address.network, configuration: endpoints, probe: probe)
        let liveClient = LiveThorNodeClient(
            transport: adapter,
            requestTimeout: endpoints.requestTimeout,
            clientId: endpoints.clientId,
            maximumBalancePageCount: endpoints.policy.maximumBalancePageCount
        )
        let broadcastClients = Dictionary(uniqueKeysWithValues: endpoints.families.map { family in
            (family.id, CosmosTransactionBroadcaster(baseURL: family.cosmosRestURL, transport: adapter))
        })
        let lookupClients = Dictionary(uniqueKeysWithValues: endpoints.families.map { family in
            (family.id, CosmosTransactionLookupClient(baseURL: family.cosmosRestURL, transport: adapter))
        })
        let reader = ReadOperationCoordinator(
            pool: pool,
            client: liveClient,
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
        let publicationBarrier = PendingPublicationBarrier()
        let pendingRepository = PendingTransactionRepository(
            journal: SendJournal(writer: databaseRuntime.pool, persistenceNamespace: namespace),
            network: address.network,
            publicationBarrier: publicationBarrier
        )
        let sendRuntime = SendRuntime(
            address: address,
            persistenceNamespace: namespace,
            runtimeIdentifier: databaseRuntime.location.identity.rawValue,
            databaseWriter: databaseRuntime.pool,
            broadcastOperation: { familyID, transaction in
                guard let client = broadcastClients[familyID] else { throw BroadcastTransportError.invalidEndpoint }
                return try await client.broadcast(transaction: transaction)
            },
            pendingRepository: pendingRepository,
            publicationBarrier: publicationBarrier,
            lookupOperation: { familyID, transactionID in
                guard let client = lookupClients[familyID] else { return .providerInconsistent }
                return await client.lookup(transactionID: transactionID)
            },
            operationDeadline: endpoints.requestTimeout
        )
        let syncer = AccountSyncer(
            address: address,
            storageKey: key,
            reader: reader,
            storage: storage,
            gate: gate
        )
        let preflight = SendPreflightCoordinator(
            runtime: sendRuntime,
            provider: ThorNodeSendPreflightProvider(
                node: ThorNodeSendClient(transport: liveClient),
                leaseProvider: { try await pool.lease(excludingFamilyIds: []) },
                runtime: sendRuntime,
                freshLeaseProvider: { familyID in try await pool.freshLease(familyID: familyID) }
            )
        )
        return Kit(
            address: address,
            dependencies: KitDependencies(
                lifecycle: LifecycleCommandBridge(syncer: syncer, gate: gate, sendRuntime: sendRuntime),
                sendRuntime: sendRuntime,
                preflight: preflight,
                pendingRepository: pendingRepository
            ),
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
