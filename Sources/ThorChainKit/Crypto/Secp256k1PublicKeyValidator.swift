import Foundation
import secp256k1

protocol Secp256k1ContextProviding: Sendable {
    func makeContext() throws -> OpaquePointer
}

struct ProductionSecp256k1ContextProvider: Secp256k1ContextProviding, Sendable {
    func makeContext() throws -> OpaquePointer {
        try secp256k1.Context.create(.verify)
    }
}

struct Secp256k1PublicKeyValidator: Sendable {
    private let contextProvider: any Secp256k1ContextProviding

    init(contextProvider: any Secp256k1ContextProviding = ProductionSecp256k1ContextProvider()) {
        self.contextProvider = contextProvider
    }

    func validate(_ compressedPublicKey: Data) throws {
        guard compressedPublicKey.count == 33 else {
            throw AccountAddressError.invalidCompressedPublicKeyLength(compressedPublicKey.count)
        }
        guard let prefix = compressedPublicKey.first, prefix == 0x02 || prefix == 0x03 else {
            throw AccountAddressError.invalidCompressedPublicKeyPrefix(compressedPublicKey.first ?? 0)
        }

        let context: OpaquePointer
        do {
            context = try contextProvider.makeContext()
        } catch {
            throw AccountAddressError.secp256k1ContextUnavailable
        }
        defer { secp256k1_context_destroy(context) }

        var publicKey = secp256k1_pubkey()
        let status = compressedPublicKey.withUnsafeBytes { bytes -> Int32 in
            guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return secp256k1_ec_pubkey_parse(context, &publicKey, baseAddress, compressedPublicKey.count)
        }
        guard status == 1 else {
            throw AccountAddressError.invalidSecp256k1Point
        }
    }
}
