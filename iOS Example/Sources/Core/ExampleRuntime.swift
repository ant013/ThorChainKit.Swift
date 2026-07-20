@_spi(Testing) import ThorChainKit

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
