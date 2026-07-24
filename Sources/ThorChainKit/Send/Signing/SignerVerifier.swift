import Foundation
import secp256k1

struct SignerVerifier: Sendable {
    private let publicKeyValidator: Secp256k1PublicKeyValidator

    init(publicKeyValidator: Secp256k1PublicKeyValidator = Secp256k1PublicKeyValidator()) {
        self.publicKeyValidator = publicKeyValidator
    }

    func verify(signature: Data, digest: Data, publicKey: Data) throws -> CompactSignature {
        guard digest.count == 32 else { throw SendError.invalidSignature }
        do {
            try publicKeyValidator.validate(publicKey)
        } catch {
            throw SendError.invalidPublicKey
        }
        let compact = try CompactSignature(signature)
        let context = try secp256k1.Context.create(.verify)
        defer { secp256k1_context_destroy(context) }
        var parsedKey = secp256k1_pubkey()
        let keyStatus = publicKey.withUnsafeBytes { bytes -> Int32 in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return secp256k1_ec_pubkey_parse(context, &parsedKey, baseAddress, publicKey.count)
        }
        var parsedSignature = secp256k1_ecdsa_signature()
        let signatureStatus = secp256k1_ecdsa_signature_parse_compact(
            context,
            &parsedSignature,
            Array(compact.rawValue)
        )
        let valid = digest.withUnsafeBytes { bytes -> Int32 in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return secp256k1_ecdsa_verify(context, &parsedSignature, baseAddress, &parsedKey)
        }
        guard keyStatus == 1, signatureStatus == 1, valid == 1 else {
            throw SendError.invalidSignature
        }
        return compact
    }
}
