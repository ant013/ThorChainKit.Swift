import BigInt
import Combine
import Foundation

public final class Kit {
    public let address: Address
    public let network: Network

    private let dependencies: KitDependencies
    private let facadeDispatcher = DispatchQueue(label: "io.horizontalsystems.thorchain-kit.facade")
    private let dispatcherKey = DispatchSpecificKey<UInt8>()
    private let lastBlockHeightSubject = CurrentValueSubject<Int64?, Never>(nil)
    private let syncStateSubject = CurrentValueSubject<SyncState, Never>(.idle(cached: false))
    private let accountStateSubject = CurrentValueSubject<AccountState?, Never>(nil)
    private var desiredRunning = false
    private var nextLifecycleSequence: UInt64 = 0
    private var pendingLifecycleCommands = [PendingLifecycleCommand]()
    let persistenceNamespace: String

    init(
        address: Address,
        dependencies: KitDependencies,
        persistenceNamespace: String
    ) {
        self.address = address
        network = address.network
        self.dependencies = dependencies
        self.persistenceNamespace = persistenceNamespace
        facadeDispatcher.setSpecific(key: dispatcherKey, value: 1)
    }

    public var lastBlockHeight: Int64? {
        withOwnedState { lastBlockHeightSubject.value }
    }

    public var syncState: SyncState {
        withOwnedState { syncStateSubject.value }
    }

    public var accountState: AccountState? {
        withOwnedState { accountStateSubject.value }
    }

    public var runeBalance: BigUInt {
        accountState?.balances[.rune] ?? 0
    }

    public var accountExists: Bool {
        accountState?.exists ?? false
    }

    public var lastBlockHeightPublisher: AnyPublisher<Int64?, Never> {
        withOwnedState {
            lastBlockHeightSubject
                .receive(on: facadeDispatcher)
                .eraseToAnyPublisher()
        }
    }

    public var syncStatePublisher: AnyPublisher<SyncState, Never> {
        withOwnedState {
            syncStateSubject
                .receive(on: facadeDispatcher)
                .eraseToAnyPublisher()
        }
    }

    public var accountStatePublisher: AnyPublisher<AccountState?, Never> {
        withOwnedState {
            accountStateSubject
                .receive(on: facadeDispatcher)
                .eraseToAnyPublisher()
        }
    }

    public func start() {
        submit(.start)
    }

    public func stop() {
        submit(.stop)
    }

    public func refresh() {
        submit(.refresh)
    }

    private var isOnFacadeDispatcher: Bool {
        DispatchQueue.getSpecific(key: dispatcherKey) == 1
    }

    private func withOwnedState<T>(_ body: () -> T) -> T {
        if isOnFacadeDispatcher {
            return body()
        }
        return facadeDispatcher.sync(execute: body)
    }

    private func submit(_ kind: LifecycleCommandKind) {
        if isOnFacadeDispatcher {
            enqueueLifecycleCommand(kind)
            if pendingLifecycleCommands.count == 1 {
                drainPendingLifecycleCommands()
            }
            return
        }

        facadeDispatcher.sync {
            enqueueLifecycleCommand(kind)
            if pendingLifecycleCommands.count == 1 {
                drainPendingLifecycleCommands()
            }
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
        pendingLifecycleCommands.append(
            PendingLifecycleCommand(sequence: nextLifecycleSequence, kind: kind)
        )
    }

    private func drainPendingLifecycleCommands() {
        while let command = pendingLifecycleCommands.first {
            switch command.kind {
            case .start:
                dependencies.lifecycle.start(sequence: command.sequence)
            case .stop:
                dependencies.lifecycle.stop(sequence: command.sequence)
            case .refresh:
                dependencies.lifecycle.refresh(sequence: command.sequence)
            }
            pendingLifecycleCommands.removeFirst()
        }
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
