import Foundation

public struct EndpointFamilyDescriptor: Hashable, Sendable {
    public let id: String
    public let cosmosRestURL: URL
    public let cometBftURL: URL

    public init(id: String, cosmosRestURL: URL, cometBftURL: URL) throws {
        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedId.isEmpty,
              normalizedId.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else {
            throw EndpointConfigurationError.invalidFamilyId
        }
        try Self.validateURL(cosmosRestURL)
        try Self.validateURL(cometBftURL)
        self.id = normalizedId
        self.cosmosRestURL = cosmosRestURL
        self.cometBftURL = cometBftURL
    }

    static func validateURL(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https", url.host?.isEmpty == false else {
            throw EndpointConfigurationError.insecureURL
        }
        guard url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil
        else {
            throw EndpointConfigurationError.urlContainsCredentialsQueryOrFragment
        }
    }
}
