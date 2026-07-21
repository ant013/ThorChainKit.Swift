@_spi(Testing) import ThorChainKit
import Foundation

struct EndpointPolicySnapshot: Equatable, Sendable {
    let selectedFamilyId: String
    let expectedChainId: String
    let identityClassification: String
    let cosmosOrigin: String
    let cometOrigin: String
    let cosmosHeight: String
    let cometHeight: String
    let heightSkew: String
    let catchingUp: String
    let rejectionReason: String
}

enum EndpointScenario: Sendable {
    case healthy
    case mixedIdentity
    case catchingUp
    case staleCosmos
}

struct AccountReadFixtureResult: Equatable, Sendable {
    let mode: String
    let exists: String
    let rune: String
    let height: String
    let family: String
}

@MainActor
struct ExampleRuntime {
    let kit: Kit
    let network: Network
    let endpointConfiguration: EndpointConfiguration
    private let fixtureTransport: ExampleAccountReadTransport

    init() throws {
        network = .mainnet
        let address = try Address(Configuration.address, network: network)
        let family = try EndpointFamilyDescriptor(
            id: "fixture",
            cosmosRestURL: Configuration.cosmosRestURL,
            cometBftURL: Configuration.cometBftURL
        )
        endpointConfiguration = try EndpointConfiguration(families: [family])
        let transport = ExampleAccountReadTransport(
            offline: UserDefaults.standard.bool(forKey: Configuration.fixtureOfflineKey),
            pending: UserDefaults.standard.bool(forKey: Configuration.fixturePendingKey)
        )
        fixtureTransport = transport
        kit = try Kit.fixture(
            address: address,
            walletId: Configuration.fixtureIdentifier,
            endpoints: endpointConfiguration,
            transport: transport,
            databasePath: try Self.fixtureDatabasePath(),
            observedAt: Date(timeIntervalSince1970: 1)
        )
    }

    func fixtureRequestCount() async -> Int { await fixtureTransport.requestCount }
    func writeFixtureEvidence(
        syncState: String,
        acceptedHeight: Int64?,
        lastBlockHeight: Int64?,
        rune: String,
        requestCount: Int
    ) {
        let evidence: [String: Any] = [
            "syncState": syncState,
            "acceptedHeight": acceptedHeight,
            "lastBlockHeight": lastBlockHeight,
            "rune": rune,
            "requestCount": requestCount
        ]
        guard JSONSerialization.isValidJSONObject(evidence),
              let data = try? JSONSerialization.data(withJSONObject: evidence)
        else { return }
        do {
            let directory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ThorChainKitExample", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent("lifecycle-evidence.json"), options: .atomic)
        } catch {
            return
        }
    }
    func setFixtureOffline(_ value: Bool) async {
        UserDefaults.standard.set(value, forKey: Configuration.fixtureOfflineKey)
        await fixtureTransport.setOffline(value)
    }
    func fixturePending() async -> Bool { await fixtureTransport.isPending }
    func setFixturePending(_ value: Bool) async {
        UserDefaults.standard.set(value, forKey: Configuration.fixturePendingKey)
        await fixtureTransport.setPending(value)
    }
    func releaseFixturePending() async {
        UserDefaults.standard.removeObject(forKey: Configuration.fixturePendingKey)
        await fixtureTransport.releasePending()
    }

    func endpointSnapshot(
        scenario: EndpointScenario
    ) async -> EndpointPolicySnapshot {
        let snapshot = await TestingEndpointPolicySession(
            network: network,
            configuration: endpointConfiguration,
            script: scenario.script
        ).snapshot()
        return EndpointPolicySnapshot(
            selectedFamilyId: snapshot.selectedFamilyId ?? "nil",
            expectedChainId: snapshot.expectedChainId,
            identityClassification: snapshot.identityClassification,
            cosmosOrigin: Self.origin(snapshot.cosmosOrigin),
            cometOrigin: Self.origin(snapshot.cometOrigin),
            cosmosHeight: snapshot.cosmosHeight.map(String.init) ?? "nil",
            cometHeight: snapshot.cometHeight.map(String.init) ?? "nil",
            heightSkew: snapshot.heightSkew.map(String.init) ?? "nil",
            catchingUp: String(snapshot.catchingUp),
            rejectionReason: snapshot.rejectionReason ?? "none"
        )
    }

    func accountFixture() async throws -> AccountReadFixtureResult {
        let address = try Address(Configuration.address, network: network)
        let family = try EndpointFamilyDescriptor(
            id: "fixture-primary",
            cosmosRestURL: Configuration.cosmosRestURL,
            cometBftURL: Configuration.cometBftURL
        )
        let configuration = try EndpointConfiguration(families: [family])
        let projection = try await TestingAccountReadSession(
            address: address,
            configuration: configuration,
            transport: ExampleAccountReadTransport(offline: false, pending: false)
        ).read()
        return AccountReadFixtureResult(
            mode: "FIXTURE",
            exists: String(projection.accountExists),
            rune: projection.runeAmountDecimal,
            height: String(projection.acceptedHeight),
            family: projection.providerFamilyId
        )
    }

    private static func origin(_ value: TestingEndpointPolicySnapshot.Origin) -> String {
        "\(value.scheme)://\(value.host)\(value.port.map { ":\($0)" } ?? "")"
    }

    private static func fixtureDatabasePath() throws -> String {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ThorChainKitExample", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("fixture-account.sqlite").path
    }
}

private extension EndpointScenario {
    var script: TestingEndpointPolicySession.Script {
        switch self {
        case .healthy: .healthy
        case .mixedIdentity: .mixedIdentity
        case .catchingUp: .catchingUp
        case .staleCosmos: .staleCosmos
        }
    }
}

actor ExampleAccountReadTransport: TestingHTTPTransport {
    private(set) var requestCount = 0
    private var offline = false
    private var pending = false
    private var pendingContinuations = [CheckedContinuation<Void, Never>]()

    init(offline: Bool, pending: Bool) {
        self.offline = offline
        self.pending = pending
        requestCount = UserDefaults.standard.integer(forKey: Configuration.fixtureRequestCountKey)
    }

    func setOffline(_ value: Bool) { offline = value }
    var isPending: Bool { pending }
    func setPending(_ value: Bool) {
        pending = value
        if !value { releasePending() }
    }
    func releasePending() {
        pending = false
        let continuations = pendingContinuations
        pendingContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        UserDefaults.standard.set(requestCount, forKey: Configuration.fixtureRequestCountKey)
        if pending {
            await withTaskCancellationHandler(operation: {
                await withCheckedContinuation { continuation in
                    pendingContinuations.append(continuation)
                }
            }, onCancel: {
                Task { await self.releasePending() }
            })
        }
        guard !offline else { throw URLError(.notConnectedToInternet) }
        let path = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.path
        let body: String
        if path.hasSuffix("node_info") {
            body = #"{"default_node_info":{"network":"thorchain-1"}}"#
        } else if path.hasSuffix("blocks/latest") {
            body = #"{"block":{"header":{"chain_id":"thorchain-1","height":"12345678"}}}"#
        } else if path == "/status" {
            body = #"{"result":{"node_info":{"network":"thorchain-1"},"sync_info":{"latest_block_height":"12345678","catching_up":false}}}"#
        } else if path.contains("/accounts/") {
            body = #"{"account":{"@type":"/cosmos.auth.v1beta1.BaseAccount","account_number":"1","sequence":"2"}}"#
        } else {
            body = #"{"balances":[{"denom":"rune","amount":"7"}],"pagination":{"next_key":null}}"#
        }
        let headers = path.contains("/accounts/") || path.contains("/balances/")
            ? ["Grpc-Metadata-X-Cosmos-Block-Height": "12345678"]
            : [:]
        return (
            Data(body.utf8),
            HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!
        )
    }
}
