import Foundation

struct CosmosAccountAddressDeriver: AccountAddressDeriving, Sendable {
    let validator: Secp256k1PublicKeyValidator

    init(validator: Secp256k1PublicKeyValidator = Secp256k1PublicKeyValidator()) {
        self.validator = validator
    }

    func address(compressedPublicKey: Data, network: Network) throws -> Address {
        try validator.validate(compressedPublicKey)
        let payload = AccountAddressHasher.hash160(compressedPublicKey)
        return try AddressCodec().encode(payload: payload, network: network)
    }
}
