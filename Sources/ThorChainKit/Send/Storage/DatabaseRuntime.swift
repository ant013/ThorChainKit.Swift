import Foundation
import GRDB

final class DatabaseRuntime: @unchecked Sendable {
    let location: DatabaseLocation
    let pool: DatabasePool

    private init(location: DatabaseLocation) throws {
        self.location = location
        pool = try DatabasePool(path: location.url.path)
        guard location.stillResolvesToSameIdentity() else { throw DatabaseLocationError.unavailable }
        try ThorChainMigrations.migrator().migrate(pool)
        guard location.stillResolvesToSameIdentity() else { throw DatabaseLocationError.unavailable }
    }

    static func open(path: String) throws -> DatabaseRuntime {
        let location = try DatabaseLocation.resolve(path: path)
        let entry: DatabaseRuntimeRegistry.Entry
        registry.lock.lock()
        if let existing = registry.entries[location.identity] {
            entry = existing
        } else {
            let initializing = DatabaseInitializationTask { try DatabaseRuntime(location: location) }
            let created = DatabaseRuntimeRegistry.Entry.initializing(initializing)
            registry.entries[location.identity] = created
            initializing.start()
            entry = created
        }
        registry.lock.unlock()

        do {
            let runtime: DatabaseRuntime
            switch entry {
            case let .ready(existing): runtime = existing
            case let .initializing(task): runtime = try task.wait()
            }
            registry.lock.lock()
            if case let .initializing(task) = entry,
               case let .initializing(current) = registry.entries[location.identity],
               current === task {
                registry.entries[location.identity] = .ready(runtime)
            }
            registry.lock.unlock()
            return runtime
        } catch {
            registry.lock.lock()
            if case let .initializing(task) = entry,
               case let .initializing(current) = registry.entries[location.identity],
               current === task {
                registry.entries.removeValue(forKey: location.identity)
            }
            registry.lock.unlock()
            throw error
        }
    }

    private static let registry = DatabaseRuntimeRegistry()
}

private final class DatabaseRuntimeRegistry: @unchecked Sendable {
    enum Entry {
        case ready(DatabaseRuntime)
        case initializing(DatabaseInitializationTask)
    }

    let lock = NSLock()
    var entries = [DatabaseFileIdentity: Entry]()
}

private final class DatabaseInitializationTask: @unchecked Sendable {
    private let group = DispatchGroup()
    private let stateQueue = DispatchQueue(label: "ThorChainKit.DatabaseInitialization")
    private var result: Result<DatabaseRuntime, Error>?
    private let operation: @Sendable () throws -> DatabaseRuntime

    init(operation: @escaping @Sendable () throws -> DatabaseRuntime) {
        self.operation = operation
        group.enter()
    }

    func start() {
        Task.detached { [self] in
            let result: Result<DatabaseRuntime, Error>
            do {
                result = .success(try operation())
            } catch {
                result = .failure(error)
            }
            stateQueue.sync { self.result = result }
            group.leave()
        }
    }

    func wait() throws -> DatabaseRuntime {
        group.wait()
        return try stateQueue.sync { try result!.get() }
    }
}
