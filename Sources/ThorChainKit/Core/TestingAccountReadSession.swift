import Foundation

@_spi(Testing) public protocol TestingHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

@_spi(Testing) public struct TestingAccountReadProjection: Equatable, Sendable {
    public let accountExists: Bool
    public let accountNumber: UInt64?
    public let sequence: UInt64?
    public let runeAmountDecimal: String
    public let acceptedHeight: Int64
    public let providerFamilyId: String
}

@_spi(Testing) public struct TestingAccountReadSession: Sendable {
    private let address: Address
    private let configuration: EndpointConfiguration
    private let transport: any TestingHTTPTransport

    public init(
        address: Address,
        configuration: EndpointConfiguration,
        transport: any TestingHTTPTransport
    ) {
        self.address = address
        self.configuration = configuration
        self.transport = transport
    }

    public func read() async throws -> TestingAccountReadProjection {
        let adapter = TestingHTTPTransportAdapter(transport: transport)
        let probe = LiveNodeProbe(configuration: configuration, transport: adapter)
        let pool = EndpointPool(network: address.network, configuration: configuration, probe: probe)
        let client = LiveThorNodeClient(
            transport: adapter,
            requestTimeout: configuration.requestTimeout,
            clientId: configuration.clientId,
            maximumBalancePageCount: configuration.policy.maximumBalancePageCount
        )
        let coordinator = ReadOperationCoordinator(
            pool: pool,
            client: client,
            configuration: configuration
        )
        let result = try await coordinator.read(address: address)
        let rune = result.balances.first(where: { $0.denom == .rune })?.amountDecimal ?? "0"
        return TestingAccountReadProjection(
            accountExists: result.account != nil,
            accountNumber: result.account?.accountNumber,
            sequence: result.account?.sequence,
            runeAmountDecimal: rune,
            acceptedHeight: result.acceptedHeight,
            providerFamilyId: result.familyId
        )
    }
}

private struct TestingHTTPTransportAdapter: HTTPTransporting {
    let transport: any TestingHTTPTransport

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await transport.data(for: request)
    }
}
