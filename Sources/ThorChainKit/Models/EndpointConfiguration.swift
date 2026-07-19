import Foundation

public struct EndpointConfiguration: Sendable {
    public let families: [EndpointFamilyDescriptor]
    public let clientId: String?
    public let requestTimeout: TimeInterval
    public let policy: EndpointPolicy

    public var effectiveMaximumAttempts: Int {
        policy.maximumAttempts ?? families.count
    }

    public init(
        families: [EndpointFamilyDescriptor],
        clientId: String? = nil,
        requestTimeout: TimeInterval = 15,
        policy: EndpointPolicy = .default
    ) throws {
        guard !families.isEmpty else {
            throw EndpointConfigurationError.emptyFamilies
        }
        var ids = Set<String>()
        for family in families where !ids.insert(family.id).inserted {
            throw EndpointConfigurationError.duplicateFamilyId(family.id)
        }

        let normalizedClientId = clientId?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedClientId?.unicodeScalars.allSatisfy({
            !CharacterSet.controlCharacters.contains($0)
        }) ?? true else {
            throw EndpointConfigurationError.invalidClientId
        }
        guard requestTimeout.isFinite, requestTimeout > 0 else {
            throw EndpointConfigurationError.invalidPolicyField("requestTimeout")
        }
        guard policy.maximumAttempts.map({ $0 <= families.count }) ?? true else {
            throw EndpointConfigurationError.invalidPolicyField("maximumAttempts")
        }

        self.families = families
        self.clientId = normalizedClientId?.isEmpty == false ? normalizedClientId : nil
        self.requestTimeout = requestTimeout
        self.policy = policy
    }
}

public enum EndpointConfigurationError: Error, Equatable {
    case emptyFamilies
    case duplicateFamilyId(String)
    case invalidFamilyId
    case invalidClientId
    case insecureURL
    case urlContainsCredentialsQueryOrFragment
    case invalidPolicyField(String)
}
