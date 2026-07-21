import Foundation

enum EndpointRole: String, Sendable {
    case cosmosRest
    case cometBft
}

struct EndpointOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int?

    init(scheme: String, host: String, port: Int?) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased()
        else {
            return nil
        }
        self.init(scheme: scheme, host: host, port: components.port)
    }
}

enum ProbeRequestKind: Int, CaseIterable, Sendable {
    case cosmosNodeInfo
    case cosmosLatestBlock
    case cometStatus
}

struct ProbeRequestIndex: Equatable, Sendable {
    let familyIndex: Int
    let familyId: String
    let role: EndpointRole
    let request: ProbeRequestKind
}

struct CosmosNodeInfoObservation: Equatable, Sendable {
    let chainId: String
}

struct CosmosLatestBlockObservation: Equatable, Sendable {
    let chainId: String
    let latestHeight: Int64
}

struct CometObservation: Equatable, Sendable {
    let chainId: String
    let latestHeight: Int64
    let catchingUp: Bool
}

enum TransportFailureKind: Equatable, Sendable {
    case dns
    case connection
    case timeout
    case tls
    case offline
    case other
}

enum ProbeField: Equatable, Sendable {
    case httpEnvelope
    case nodeInfoNetwork
    case blockHeaderChainId
    case blockHeaderHeight
    case cometNetwork
    case cometHeight
    case cometCatchingUp
}

enum RoleProbeFailure: Error, Equatable, Sendable {
    case cancelled
    case transport(kind: TransportFailureKind)
    case httpStatus(code: Int, retryAfterSeconds: Int?)
    case invalidResponse(field: ProbeField)
}

enum ProbeRequestResult: Equatable, Sendable {
    case cosmosNodeInfo(Result<CosmosNodeInfoObservation, RoleProbeFailure>)
    case cosmosLatestBlock(Result<CosmosLatestBlockObservation, RoleProbeFailure>)
    case cometStatus(Result<CometObservation, RoleProbeFailure>)
}

struct IndexedProbeOutcome: Equatable, Sendable {
    let index: ProbeRequestIndex
    let cosmosOrigin: EndpointOrigin
    let cometOrigin: EndpointOrigin
    let result: ProbeRequestResult
}

protocol NodeProbing: Sendable {
    func probe(index: Int, family: EndpointFamilyDescriptor) async -> [IndexedProbeOutcome]
}
