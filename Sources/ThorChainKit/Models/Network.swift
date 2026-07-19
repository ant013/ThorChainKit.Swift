import Foundation

public struct Network: Hashable, Sendable {
    public enum Environment: String, Hashable, Sendable {
        case mainnet
        case stagenet
        case chainnet
    }

    public let environment: Environment
    public let expectedChainId: String
    public let accountHrp: String
    public let coinType: UInt32

    public static let mainnet = try! Network(
        environment: .mainnet,
        expectedChainId: "thorchain-1",
        accountHrp: "thor"
    )

    public static func stagenet(expectedChainId: String) throws -> Network {
        try Network(
            environment: .stagenet,
            expectedChainId: expectedChainId,
            accountHrp: "sthor"
        )
    }

    public static func chainnet(expectedChainId: String) throws -> Network {
        try Network(
            environment: .chainnet,
            expectedChainId: expectedChainId,
            accountHrp: "cthor"
        )
    }

    var persistenceKey: String {
        environment.rawValue + "\0" + expectedChainId
    }

    private init(
        environment: Environment,
        expectedChainId: String,
        accountHrp: String
    ) throws {
        guard Self.isValid(chainId: expectedChainId) else {
            throw KitConfigurationError.invalidChainId
        }
        self.environment = environment
        self.expectedChainId = expectedChainId
        self.accountHrp = accountHrp
        coinType = 931
    }

    private static func isValid(chainId: String) -> Bool {
        let bytes = chainId.utf8.count
        return (1...50).contains(bytes)
            && !chainId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && chainId.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }
}
