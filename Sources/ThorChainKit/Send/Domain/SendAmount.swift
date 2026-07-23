import BigInt
import Foundation

struct SendMagnitude: Sendable, Hashable {
    let data: Data

    init(_ value: BigUInt) {
        data = value == 0 ? Data() : value.serialize()
    }

    var value: BigUInt { data.isEmpty ? 0 : BigUInt(data) }
}

public struct SendAmount: Sendable {
    private enum Kind: Equatable, Sendable { case exact, maximum }

    private let kind: Kind
    private let exactMagnitude: Data?

    private init(kind: Kind, exactMagnitude: Data?) {
        self.kind = kind
        self.exactMagnitude = exactMagnitude
    }

    public static func exact(_ amount: BigUInt) -> SendAmount {
        SendAmount(kind: .exact, exactMagnitude: SendMagnitude(amount).data)
    }

    public static var maximum: SendAmount {
        SendAmount(kind: .maximum, exactMagnitude: nil)
    }

    public var exactAmount: BigUInt? {
        exactMagnitude.map { $0.isEmpty ? 0 : BigUInt($0) }
    }

    public var isMaximum: Bool { kind == .maximum }
}
