import Foundation
import GRDB

final class DatabaseRuntime: @unchecked Sendable {
    let location: DatabaseLocation
    let pool: DatabasePool

    private init(location: DatabaseLocation) throws {
        self.location = location
        pool = try DatabasePool(path: location.url.path)
        try ThorChainMigrations.migrator().migrate(pool)
    }

    static func open(path: String) throws -> DatabaseRuntime {
        let location = try DatabaseLocation.resolve(path: path)
        return try registry.withLock {
            if let existing = registry.values[location.identity] {
                return existing
            }
            let runtime = try DatabaseRuntime(location: location)
            registry.values[location.identity] = runtime
            return runtime
        }
    }

    private static let registry = LockedDatabaseRuntimeRegistry()
}

private final class LockedDatabaseRuntimeRegistry: @unchecked Sendable {
    var values = [DatabaseFileIdentity: DatabaseRuntime]()
    private let lock = NSLock()

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}
