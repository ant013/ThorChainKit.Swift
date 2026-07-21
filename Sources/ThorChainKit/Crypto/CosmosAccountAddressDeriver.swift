import Foundation
import HsCryptoKit

public enum AccountAddressError: Error, Equatable {
    case invalidCompressedPublicKeyLength(Int)
    case invalidCompressedPublicKeyPrefix(UInt8)
    case invalidSecp256k1Point
    case secp256k1ContextUnavailable
}

enum AccountAddressHasher {
    static func hash160(_ data: Data) -> Data {
        HsCryptoKit.Crypto.ripeMd160Sha256(data)
    }
}

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
