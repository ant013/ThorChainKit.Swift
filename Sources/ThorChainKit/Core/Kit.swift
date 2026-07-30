import BigInt
import Combine
import Foundation

public final class Kit {
    public let address: Address
    public let network: Network

    private let syncer: Syncer
    let sendRuntime: SendRuntime
    let preflight: SendPreflightCoordinator?
    private let accountInfoManager: AccountInfoManager
    private let pendingTransactionsSubject: CurrentValueSubject<[PendingTransaction], Never>
    private let pendingTransactionsStatusSubject: CurrentValueSubject<PendingTransactionsStatus, Never>
    private var pendingCancellables = Set<AnyCancellable>()
    private let lifecycleLock = NSLock()
    private var activeGeneration: UInt64?
    let persistenceNamespace: String

    init(address: Address, syncer: Syncer, accountInfoManager: AccountInfoManager, sendRuntime: SendRuntime, preflight: SendPreflightCoordinator?, pendingRepository: PendingTransactionRepository?, persistenceNamespace: String, pendingTransactionsSubject: CurrentValueSubject<[PendingTransaction], Never> = CurrentValueSubject([]), pendingTransactionsStatusSubject: CurrentValueSubject<PendingTransactionsStatus, Never> = CurrentValueSubject(.degraded)) {
        self.address = address
        network = address.network
        self.syncer = syncer
        self.accountInfoManager = accountInfoManager
        self.sendRuntime = sendRuntime
        self.preflight = preflight
        self.persistenceNamespace = persistenceNamespace
        self.pendingTransactionsSubject = pendingTransactionsSubject
        self.pendingTransactionsStatusSubject = pendingTransactionsStatusSubject
        if let pendingRepository {
            _ = pendingRepository.refresh()
            self.pendingTransactionsSubject.send(pendingRepository.snapshot)
            self.pendingTransactionsStatusSubject.send(pendingRepository.status)
            pendingRepository.publisher.sink { [weak self] in self?.pendingTransactionsSubject.send($0) }.store(in: &pendingCancellables)
            pendingRepository.statusPublisher.sink { [weak self] in self?.pendingTransactionsStatusSubject.send($0) }.store(in: &pendingCancellables)
        }
    }

    public var lastBlockHeight: Int64? { syncer.lastBlockHeight }
    public var syncState: SyncState { syncer.state }
    public var accountState: AccountState? { accountInfoManager.accountState }
    public var runeBalance: BigUInt { accountState?.balances[.rune] ?? 0 }
    public var accountExists: Bool { accountState?.exists ?? false }
    public var pendingTransactions: [PendingTransaction] { pendingTransactionsSubject.value }
    public var pendingTransactionsPublisher: AnyPublisher<[PendingTransaction], Never> { pendingTransactionsSubject.eraseToAnyPublisher() }
    public var pendingTransactionsStatus: PendingTransactionsStatus { pendingTransactionsStatusSubject.value }
    public var pendingTransactionsStatusPublisher: AnyPublisher<PendingTransactionsStatus, Never> { pendingTransactionsStatusSubject.eraseToAnyPublisher() }
    public var lastBlockHeightPublisher: AnyPublisher<Int64?, Never> { syncer.lastBlockHeightPublisher }
    public var syncStatePublisher: AnyPublisher<SyncState, Never> { syncer.statePublisher }
    public var accountStatePublisher: AnyPublisher<AccountState?, Never> { accountInfoManager.accountStatePublisher }

    public func start() {
        let generation = syncer.start()
        lifecycleLock.lock()
        activeGeneration = generation
        lifecycleLock.unlock()
        Task { [weak self, sendRuntime] in
            guard self?.isCurrent(generation: generation) == true else { return }
            await sendRuntime.activate(generation: generation)
            if self?.isCurrent(generation: generation) != true {
                await sendRuntime.invalidate(generation: generation)
            }
        }
    }

    public func stop() {
        guard let generation = syncer.stop() else { return }
        lifecycleLock.lock()
        if activeGeneration == generation { activeGeneration = nil }
        lifecycleLock.unlock()
        sendRuntime.invalidateImmediately(generation: generation)
        Task { [sendRuntime] in await sendRuntime.invalidate(generation: generation) }
    }

    public func refresh() { syncer.refresh() }

    private func isCurrent(generation: UInt64) -> Bool {
        lifecycleLock.lock(); defer { lifecycleLock.unlock() }
        return activeGeneration == generation
    }
}
