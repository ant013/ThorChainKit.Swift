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

    init() throws {
        network = .mainnet
        let address = try Address(Configuration.address, network: network)
        let family = try EndpointFamilyDescriptor(
            id: "fixture",
            cosmosRestURL: Configuration.cosmosRestURL,
            cometBftURL: Configuration.cometBftURL
        )
        endpointConfiguration = try EndpointConfiguration(families: [family])
        kit = try Kit.instance(
            address: address,
            walletId: Configuration.fixtureIdentifier,
            endpoints: endpointConfiguration
        )
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
            transport: ExampleAccountReadTransport()
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

private actor ExampleAccountReadTransport: TestingHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
            body = #"{"balances":[{"denom":"rune","amount":"340282366920938463463374607431768211456"}],"pagination":{"next_key":null}}"#
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
