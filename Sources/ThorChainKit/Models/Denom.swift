public struct Denom: Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) throws {
        let bytes = Array(rawValue.utf8)
        guard (3...128).contains(bytes.count),
              bytes.first.map(Self.isLetter) == true,
              bytes.dropFirst().allSatisfy(Self.isAllowed)
        else {
            throw KitConfigurationError.invalidDenom
        }
        self.rawValue = rawValue
    }

    public static let rune = try! Denom(rawValue: "rune")

    private static func isLetter(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }

    private static func isAllowed(_ byte: UInt8) -> Bool {
        isLetter(byte)
            || (48...57).contains(byte)
            || [47, 58, 46, 95, 45].contains(byte)
    }
}
