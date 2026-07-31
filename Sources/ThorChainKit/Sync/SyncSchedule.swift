import Foundation

struct SyncSchedule: Sendable {
    let normalInterval: TimeInterval
    let failureBackoff: TimeInterval

    static let `default` = SyncSchedule(normalInterval: 15, failureBackoff: 60)
}

protocol ISyncClock: Sendable {
    var now: Date { get }
}

struct SystemSyncClock: ISyncClock {
    var now: Date { Date() }
}
