@_spi(Testing) import ThorChainKit

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
        script: TestingEndpointPolicySession.Script
    ) async -> TestingEndpointPolicySnapshot {
        await TestingEndpointPolicySession(
            network: network,
            configuration: endpointConfiguration,
            script: script
        ).snapshot()
    }
}
