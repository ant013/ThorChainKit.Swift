import Foundation

protocol AccountAddressDeriving: Sendable {
    func address(compressedPublicKey: Data, network: Network) throws -> Address
}

public enum AccountAddressFactory {
    public static func address(
        compressedPublicKey: Data,
        network: Network
    ) throws -> Address {
        try CosmosAccountAddressDeriver().address(
            compressedPublicKey: compressedPublicKey,
            network: network
        )
    }
}
