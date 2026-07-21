import BigInt
import Combine
import Foundation

public final class Kit {
    public let address: Address
    public let network: Network

    private let dependencies: KitDependencies
    private let facadeDispatcher: DispatchQueue
    private let dispatcherKey = DispatchSpecificKey<UInt8>()
    private let publishing: StatePublishing
    private var desiredRunning = false
    private var nextLifecycleSequence: UInt64 = 0
    private var pendingLifecycleCommands = [PendingLifecycleCommand]()
    let persistenceNamespace: String

    init(
        address: Address,
        dependencies: KitDependencies,
        persistenceNamespace: String,
        facadeDispatcher: DispatchQueue = DispatchQueue(label: "io.horizontalsystems.thorchain-kit.facade"),
        publishing: StatePublishing = StatePublishing()
    ) {
        self.address = address
        network = address.network
        self.dependencies = dependencies
        self.persistenceNamespace = persistenceNamespace
        self.facadeDispatcher = facadeDispatcher
        self.publishing = publishing
        facadeDispatcher.setSpecific(key: dispatcherKey, value: 1)
    }

    public var lastBlockHeight: Int64? { withOwnedState { publishing.snapshot.lastBlockHeight } }
    public var syncState: SyncState { withOwnedState { publishing.snapshot.syncState } }
    public var accountState: AccountState? { withOwnedState { publishing.snapshot.accountState } }
    public var runeBalance: BigUInt { withOwnedState { publishing.snapshot.runeBalance } }
    public var accountExists: Bool { withOwnedState { publishing.snapshot.accountState?.exists ?? false } }

    public var lastBlockHeightPublisher: AnyPublisher<Int64?, Never> {
        withOwnedState { publishing.lastBlockHeightSubject.eraseToAnyPublisher() }
    }

    public var syncStatePublisher: AnyPublisher<SyncState, Never> {
        withOwnedState { publishing.syncStateSubject.eraseToAnyPublisher() }
    }

    public var accountStatePublisher: AnyPublisher<AccountState?, Never> {
        withOwnedState { publishing.accountStateSubject.eraseToAnyPublisher() }
    }

    public func start() { submit(.start) }
    public func stop() { submit(.stop) }
    public func refresh() { submit(.refresh) }

    private var isOnFacadeDispatcher: Bool {
        DispatchQueue.getSpecific(key: dispatcherKey) == 1
    }

    private func withOwnedState<T>(_ body: () -> T) -> T {
        isOnFacadeDispatcher ? body() : facadeDispatcher.sync(execute: body)
    }

    private func submit(_ kind: LifecycleCommandKind) {
        if isOnFacadeDispatcher {
            let shouldDrain = pendingLifecycleCommands.isEmpty
            enqueueLifecycleCommand(kind)
            if shouldDrain, let barrier = drainPendingLifecycleCommands(), !barrier.isSuccessful {
                desiredRunning = false
            }
            return
        }

        var barrier: LifecycleCommandBarrier?
        facadeDispatcher.sync {
            let shouldDrain = pendingLifecycleCommands.isEmpty
            enqueueLifecycleCommand(kind)
            if shouldDrain { barrier = drainPendingLifecycleCommands() }
        }
        if barrier?.wait() == false {
            facadeDispatcher.sync { desiredRunning = false }
        }
    }

    private func enqueueLifecycleCommand(_ kind: LifecycleCommandKind) {
        switch kind {
        case .start:
            guard !desiredRunning else { return }
            desiredRunning = true
        case .stop:
            guard desiredRunning else { return }
            desiredRunning = false
        case .refresh:
            guard desiredRunning else { return }
        }

        nextLifecycleSequence += 1
        pendingLifecycleCommands.append(PendingLifecycleCommand(
            sequence: nextLifecycleSequence,
            kind: kind
        ))
    }

    private func drainPendingLifecycleCommands() -> LifecycleCommandBarrier? {
        var firstBarrier: LifecycleCommandBarrier?
        while let command = pendingLifecycleCommands.first {
            let barrier: LifecycleCommandBarrier
            switch command.kind {
            case .start: barrier = dependencies.lifecycle.start(sequence: command.sequence)
            case .stop: barrier = dependencies.lifecycle.stop(sequence: command.sequence)
            case .refresh: barrier = dependencies.lifecycle.refresh(sequence: command.sequence)
            }
            if firstBarrier == nil { firstBarrier = barrier }
            pendingLifecycleCommands.removeFirst()
        }
        return firstBarrier
    }
}

private struct PendingLifecycleCommand {
    let sequence: UInt64
    let kind: LifecycleCommandKind
}

private enum LifecycleCommandKind {
    case start
    case stop
    case refresh
}
