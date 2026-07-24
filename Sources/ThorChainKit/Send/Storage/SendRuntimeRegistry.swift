import Foundation

final class SendRuntimeRegistry: @unchecked Sendable {
    static let shared = SendRuntimeRegistry()

    private let lock = NSLock()
    private var runtimes = [String: SendRuntimeSharedState]()

    func state(for persistenceNamespace: String, runtimeIdentifier: String) -> SendRuntimeSharedState {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(runtimeIdentifier):\(persistenceNamespace)"
        if let state = runtimes[key] {
            return state
        }
        let state = SendRuntimeSharedState(persistenceNamespace: persistenceNamespace, runtimeIdentifier: runtimeIdentifier)
        runtimes[key] = state
        return state
    }
}

final class SendRuntimeSharedState: @unchecked Sendable {
    let persistenceNamespace: String
    let runtimeIdentifier: String
    private let lock = NSLock()
    private var activeClients = Set<UUID>()
    private var activeAccounts = Set<String>()
    private var signerFences = Set<String>()

    init(persistenceNamespace: String, runtimeIdentifier: String) {
        self.persistenceNamespace = persistenceNamespace
        self.runtimeIdentifier = runtimeIdentifier
    }

    func activate(clientID: UUID) {
        lock.lock()
        activeClients.insert(clientID)
        lock.unlock()
    }

    func invalidate(clientID: UUID) {
        lock.lock()
        activeClients.remove(clientID)
        lock.unlock()
    }

    func isActive(clientID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeClients.contains(clientID)
    }

    func beginAccount(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !activeAccounts.contains(key), !signerFences.contains(key) else { return false }
        activeAccounts.insert(key)
        return true
    }

    func endAccount(_ key: String) {
        lock.lock()
        activeAccounts.remove(key)
        lock.unlock()
    }

    func beginSignerFence(_ key: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !signerFences.contains(key) else { return false }
        signerFences.insert(key)
        return true
    }

    func endSignerFence(_ key: String) {
        lock.lock()
        signerFences.remove(key)
        lock.unlock()
    }
}
