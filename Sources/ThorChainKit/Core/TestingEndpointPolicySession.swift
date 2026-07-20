import Foundation

@_spi(Testing) public struct TestingEndpointPolicySnapshot: Equatable, Sendable {
    public struct Origin: Equatable, Sendable {
        public let scheme: String
        public let host: String
        public let port: Int?
    }

    public let selectedFamilyId: String?
    public let familyId: String
    public let cosmosOrigin: Origin
    public let cometOrigin: Origin
    public let expectedChainId: String
    public let identityClassification: String
    public let cosmosHeight: Int64?
    public let cometHeight: Int64?
    public let heightSkew: Int64?
    public let catchingUp: Bool
    public let rejectionReason: String?
}

@_spi(Testing) public struct TestingEndpointPolicySession: Sendable {
    public enum Script: String, CaseIterable, Sendable {
        case healthy
        case mixedIdentity
        case catchingUp
        case staleCosmos
    }

    private let network: Network
    private let configuration: EndpointConfiguration
    private let script: Script
    private let pool: EndpointPool

    public init(
        network: Network,
        configuration: EndpointConfiguration,
        script: Script
    ) {
        self.network = network
        self.configuration = configuration
        self.script = script
        pool = EndpointPool(
            network: network,
            configuration: configuration,
            probe: TestingEndpointProbe(script: script, expectedChainId: network.expectedChainId)
        )
    }

    public func snapshot() async -> TestingEndpointPolicySnapshot {
        let family = configuration.families[0]
        let cosmosOrigin = EndpointOrigin(url: family.cosmosRestURL)!
        let cometOrigin = EndpointOrigin(url: family.cometBftURL)!
        let heights = script.heights
        do {
            let lease = try await pool.lease(excludingFamilyIds: [])
            return TestingEndpointPolicySnapshot(
                selectedFamilyId: lease.family.id,
                familyId: family.id,
                cosmosOrigin: cosmosOrigin.testing,
                cometOrigin: cometOrigin.testing,
                expectedChainId: network.expectedChainId,
                identityClassification: "expected",
                cosmosHeight: lease.cosmosReadHeight,
                cometHeight: lease.cometReferenceHeight,
                heightSkew: Self.skew(lease.cosmosReadHeight, lease.cometReferenceHeight),
                catchingUp: false,
                rejectionReason: nil
            )
        } catch let error as ProviderError {
            let identity: String
            let reason: String
            switch error {
            case let .identityFailure(_, _, _, _, code):
                identity = code.rawValue
                reason = "identity_\(code.rawValue)"
            case .catchingUp:
                identity = "expected"
                reason = "catching_up"
            case .staleEndpoint:
                identity = "expected"
                reason = "stale"
            case .invalidResponse:
                identity = "expected"
                reason = "invalid_response"
            case .temporarilyUnavailable:
                identity = "expected"
                reason = "temporarily_unavailable"
            case .noEligibleFamily:
                identity = "expected"
                reason = "no_eligible_family"
            }
            return TestingEndpointPolicySnapshot(
                selectedFamilyId: nil,
                familyId: family.id,
                cosmosOrigin: cosmosOrigin.testing,
                cometOrigin: cometOrigin.testing,
                expectedChainId: network.expectedChainId,
                identityClassification: identity,
                cosmosHeight: heights.cosmos,
                cometHeight: heights.comet,
                heightSkew: Self.skew(heights.cosmos, heights.comet),
                catchingUp: script == .catchingUp,
                rejectionReason: reason
            )
        } catch {
            return TestingEndpointPolicySnapshot(
                selectedFamilyId: nil,
                familyId: family.id,
                cosmosOrigin: cosmosOrigin.testing,
                cometOrigin: cometOrigin.testing,
                expectedChainId: network.expectedChainId,
                identityClassification: "expected",
                cosmosHeight: nil,
                cometHeight: nil,
                heightSkew: nil,
                catchingUp: false,
                rejectionReason: "cancelled"
            )
        }
    }

    private static func skew(_ first: Int64, _ second: Int64) -> Int64 {
        first >= second ? first - second : second - first
    }
}

private struct TestingEndpointProbe: NodeProbing {
    let script: TestingEndpointPolicySession.Script
    let expectedChainId: String

    func probe(index: Int, family: EndpointFamilyDescriptor) async -> [IndexedProbeOutcome] {
        let cosmosOrigin = EndpointOrigin(url: family.cosmosRestURL)!
        let cometOrigin = EndpointOrigin(url: family.cometBftURL)!
        let identities = script.identities(expected: expectedChainId)
        let heights = script.heights
        return [
            IndexedProbeOutcome(
                index: .init(
                    familyIndex: index,
                    familyId: family.id,
                    role: .cosmosRest,
                    request: .cosmosNodeInfo
                ),
                cosmosOrigin: cosmosOrigin,
                cometOrigin: cometOrigin,
                result: .cosmosNodeInfo(.success(.init(chainId: identities.node)))
            ),
            IndexedProbeOutcome(
                index: .init(
                    familyIndex: index,
                    familyId: family.id,
                    role: .cosmosRest,
                    request: .cosmosLatestBlock
                ),
                cosmosOrigin: cosmosOrigin,
                cometOrigin: cometOrigin,
                result: .cosmosLatestBlock(.success(.init(
                    chainId: identities.block,
                    latestHeight: heights.cosmos
                )))
            ),
            IndexedProbeOutcome(
                index: .init(
                    familyIndex: index,
                    familyId: family.id,
                    role: .cometBft,
                    request: .cometStatus
                ),
                cosmosOrigin: cosmosOrigin,
                cometOrigin: cometOrigin,
                result: .cometStatus(.success(.init(
                    chainId: identities.comet,
                    latestHeight: heights.comet,
                    catchingUp: script == .catchingUp
                )))
            ),
        ]
    }
}

private extension TestingEndpointPolicySession.Script {
    func identities(expected: String) -> (node: String, block: String, comet: String) {
        switch self {
        case .mixedIdentity:
            (expected, "foreign-secret-chain", expected)
        default:
            (expected, expected, expected)
        }
    }

    var heights: (cosmos: Int64, comet: Int64) {
        switch self {
        case .staleCosmos: (80, 100)
        default: (100, 102)
        }
    }
}

private extension EndpointOrigin {
    var testing: TestingEndpointPolicySnapshot.Origin {
        TestingEndpointPolicySnapshot.Origin(scheme: scheme, host: host, port: port)
    }
}
