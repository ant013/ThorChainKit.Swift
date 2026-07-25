import Foundation

public enum FixtureScenarioID: String, CaseIterable, Sendable {
    case quoteReview = "send-quote-review"
    case checkTxAccepted = "send-checktx-accepted"
    case unknown = "send-unknown"
    case retry = "send-retry"
    case restartPending = "send-restart-pending"
}

public struct FixtureScenario: Sendable {
    public let id: FixtureScenarioID
    public let namespace: String
    public let acceptedHeight: Int64
    public let expiresAt: Date

    public init(id: FixtureScenarioID, now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.id = id
        namespace = "thor-example/fixture/\(id.rawValue)"
        acceptedHeight = 12_345_678
        expiresAt = now.addingTimeInterval(60)
    }
}

public actor FixtureClock {
    public private(set) var now: Date

    public init(now: Date) { self.now = now }

    public func advanceToExpiry(of scenario: FixtureScenario) {
        now = scenario.expiresAt
    }
}
