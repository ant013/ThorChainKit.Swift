import Foundation

protocol AccountAddressDeriving: Sendable {
    func address(compressedPublicKey: Data, network: Network) throws -> Address
}
