import Foundation

struct EndpointInstant: Comparable, Equatable, Sendable {
    let nanoseconds: UInt64

    static func < (lhs: EndpointInstant, rhs: EndpointInstant) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    func advanced(seconds: TimeInterval) -> EndpointInstant {
        EndpointInstant(nanoseconds: nanoseconds &+ UInt64(seconds * 1_000_000_000))
    }
}

protocol EndpointClock: Sendable {
    var now: EndpointInstant { get }
}

struct SystemEndpointClock: EndpointClock {
    var now: EndpointInstant { EndpointInstant(nanoseconds: DispatchTime.now().uptimeNanoseconds) }
}

enum EndpointFailure: Equatable, Sendable {
    case transport(retryNotBefore: EndpointInstant)
    case retryableStatus(code: Int, retryNotBefore: EndpointInstant)

    var retryNotBefore: EndpointInstant {
        switch self {
        case let .transport(value), let .retryableStatus(_, value): value
        }
    }
}

struct EndpointHealth: Equatable, Sendable {
    let retryNotBefore: EndpointInstant
}
