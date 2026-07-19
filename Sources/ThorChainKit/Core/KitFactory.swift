import CryptoKit
import Foundation

public extension Kit {
    static func instance(
        address: Address,
        walletId: String,
        endpoints: EndpointConfiguration
    ) throws -> Kit {
        guard !walletId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KitConfigurationError.invalidWalletId
        }

        var namespaceInput = Data(walletId.utf8)
        namespaceInput.append(0)
        namespaceInput.append(contentsOf: address.network.persistenceKey.utf8)
        let namespace = SHA256.hash(data: namespaceInput)
            .map { String(format: "%02x", $0) }
            .joined()

        return Kit(
            address: address,
            dependencies: KitDependencies(lifecycle: NoOpLifecycle()),
            persistenceNamespace: namespace
        )
    }
}
