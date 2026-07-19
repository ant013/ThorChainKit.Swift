import Foundation

public struct Address: Hashable, Sendable, CustomStringConvertible {
    public let raw: String
    public let network: Network
    let payload: Data

    public init(_ raw: String, network: Network) throws {
        let decoded = try Bech32Codec.decode(raw)
        guard decoded.hrp == network.accountHrp else {
            throw AddressError.wrongHrp(expected: network.accountHrp, actual: decoded.hrp)
        }
        let payloadBytes = try BitConversion.convert(
            decoded.words,
            fromBits: 5,
            toBits: 8,
            pad: false
        )
        guard payloadBytes.count == 20 else {
            throw AddressError.invalidPayloadLength(expected: 20, actual: payloadBytes.count)
        }
        let canonical = Bech32Codec.encode(hrp: decoded.hrp, words: decoded.words)
        guard canonical == raw.lowercased() else {
            throw AddressError.invalidChecksum
        }
        self.raw = canonical
        self.network = network
        payload = Data(payloadBytes)
    }

    public var description: String { raw }
}
