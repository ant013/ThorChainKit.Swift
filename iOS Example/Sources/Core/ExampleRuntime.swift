import ThorChainKit

struct ExampleRuntime {
    let kit: Kit

    init() throws {
        let network = Network.mainnet
        let address = try Address(Configuration.address, network: network)
        let family = try EndpointFamilyDescriptor(
            id: "fixture",
            cosmosRestURL: Configuration.cosmosRestURL,
            cometBftURL: Configuration.cometBftURL
        )
        let endpoints = try EndpointConfiguration(families: [family])
        kit = try Kit.instance(
            address: address,
            walletId: Configuration.fixtureIdentifier,
            endpoints: endpoints
        )
    }
}
