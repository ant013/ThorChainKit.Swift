import Foundation

protocol IAddressProvider: Sendable {
    func address(compressedPublicKey: Data, network: Network) throws -> Address
}
