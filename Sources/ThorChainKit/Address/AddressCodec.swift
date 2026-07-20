import Foundation

public struct AddressCodec: Sendable {
    public init() {}

    public func encode(payload: Data, network: Network) throws -> Address {
        guard payload.count == 20 else {
            throw AddressError.invalidPayloadLength(expected: 20, actual: payload.count)
        }
        let words = try BitConversion.convert(
            Array(payload),
            fromBits: 8,
            toBits: 5,
            pad: true
        )
        let raw = Bech32Codec.encode(hrp: network.accountHrp, words: words)
        return try Address(raw, network: network)
    }

    public func decode(_ string: String, network: Network) throws -> Address {
        try Address(string, network: network)
    }
}
