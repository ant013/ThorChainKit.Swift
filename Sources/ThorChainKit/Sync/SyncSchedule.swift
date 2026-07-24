import Foundation

struct SyncSchedule: Sendable {
    let normalInterval: TimeInterval
    let failureBackoff: TimeInterval

    static let `default` = SyncSchedule(normalInterval: 15, failureBackoff: 60)
}

protocol SyncClock: Sendable {
    var now: Date { get }
}

struct SystemSyncClock: SyncClock {
    var now: Date { Date() }
}
