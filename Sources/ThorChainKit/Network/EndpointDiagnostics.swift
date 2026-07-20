import Foundation

enum IdentityFailureCode: String, Equatable, Sendable {
    case foreign
    case mixed
}

enum IdentityClassification: String, Equatable, Sendable {
    case expected
    case foreign
    case mixed
}

enum EndpointDiagnosticReason: Equatable, Sendable {
    case identity(IdentityFailureCode)
    case invalid(ProbeField)
    case transport(TransportFailureKind)
    case status(Int)
    case catchingUp
    case stale
}

struct EndpointDiagnostic: Equatable, Sendable, CustomStringConvertible {
    let familyId: String
    let role: EndpointRole
    let request: ProbeRequestKind
    let origin: EndpointOrigin
    let expectedChainId: String
    let identityClassification: IdentityClassification
    let reason: EndpointDiagnosticReason

    var description: String {
        "family=\(familyId) role=\(role.rawValue) request=\(request) "
            + "origin=\(origin.scheme)://\(origin.host)\(origin.port.map { ":\($0)" } ?? "") "
            + "expected=\(expectedChainId) identity=\(identityClassification.rawValue) reason=\(reason.code)"
    }
}

private extension EndpointDiagnosticReason {
    var code: String {
        switch self {
        case let .identity(code): "identity_\(code.rawValue)"
        case let .invalid(field): "invalid_\(field)"
        case let .transport(kind): "transport_\(kind)"
        case let .status(code): "http_\(code)"
        case .catchingUp: "catching_up"
        case .stale: "stale"
        }
    }
}

enum ProviderError: Error, Equatable, Sendable {
    case noEligibleFamily
    case identityFailure(
        expected: String,
        familyId: String,
        role: EndpointRole,
        request: ProbeRequestKind,
        code: IdentityFailureCode
    )
    case catchingUp
    case staleEndpoint(height: Int64, bestKnown: Int64)
    case invalidResponse(familyId: String, role: EndpointRole, field: ProbeField)
    case temporarilyUnavailable
}
