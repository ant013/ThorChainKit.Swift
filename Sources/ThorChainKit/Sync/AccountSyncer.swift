import Foundation

actor AccountSyncer: AccountSyncing {
    private let address: Address
    private let storageKey: StorageKey
    private let reader: any AccountReading
    private let storage: any AccountStateStorage
    private let gate: LifecycleGate
    private let schedule: SyncSchedule

    private var running = false
    private var generation: UInt64?
    private var loopTask: Task<Void, Never>?
    private var refreshInFlight = false

    init(
        address: Address,
        storageKey: StorageKey,
        reader: any AccountReading,
        storage: any AccountStateStorage,
        gate: LifecycleGate,
        schedule: SyncSchedule = .default
    ) {
        self.address = address
        self.storageKey = storageKey
        self.reader = reader
        self.storage = storage
        self.gate = gate
        self.schedule = schedule
    }

    func start(generation: UInt64) async {
        precondition(!running, "S105_INVARIANT_DUPLICATE_START")
        running = true
        self.generation = generation

        do {
            if let cached = try await storage.load(key: storageKey) {
                gate.acceptCachedIfCurrent(generation: generation, record: cached)
            }
        } catch is CancellationError {
            return
        } catch {
            gate.publishFailureIfCurrent(SyncFailure(
                generation: generation,
                address: address.raw,
                networkChainId: address.network.expectedChainId,
                error: .storageUnavailable
            ))
        }

        let task = Task { [weak self] in
            guard let self else { return }
            await self.runLoop(generation: generation)
        }
        loopTask = task
    }

    func stop(generation: UInt64) async {
        precondition(running, "S105_INVARIANT_DUPLICATE_STOP")
        precondition(self.generation == generation, "S105_INVARIANT_GENERATION")
        running = false
        self.generation = nil
        loopTask?.cancel()
        await loopTask?.value
        loopTask = nil
        refreshInFlight = false
    }

    func cancelStop() async {
        guard running else { return }
        running = false
        generation = nil
        loopTask?.cancel()
        await loopTask?.value
        loopTask = nil
        refreshInFlight = false
    }

    func refresh() async {
        precondition(running, "S105_INVARIANT_STOPPED_REFRESH")
        guard !refreshInFlight else { return }
        refreshInFlight = true
        defer { refreshInFlight = false }
        guard let generation else { return }

        do {
            try Task.checkCancellation()
            gate.publishSyncingIfCurrent(generation: generation)
            let read = try await reader.read(address: address)
            try Task.checkCancellation()
            let record = try StorageRecord(read: read, address: address, storageKey: storageKey)
            let committed = try await storage.saveIfCurrent(
                record,
                key: storageKey,
                expectedGeneration: generation
            )
            guard committed, running, self.generation == generation else { return }
            gate.acceptIfCurrent(generation: generation, record: record)
        } catch is CancellationError {
            return
        } catch {
            guard running, self.generation == generation else { return }
            gate.publishFailureIfCurrent(SyncFailure(
                generation: generation,
                address: address.raw,
                networkChainId: address.network.expectedChainId,
                error: Self.map(error)
            ))
        }
    }

    private func runLoop(generation: UInt64) async {
        await refresh()
        while running, self.generation == generation, !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(schedule.normalInterval * 1_000_000_000))
            } catch {
                return
            }
            await refresh()
        }
    }

    private static func map(_ error: Error) -> SyncError {
        if let error = error as? SyncError { return error }
        guard let error = error as? ThorNodeReadError else { return .nodeUnavailable }
        switch error {
        case .transport: return .noConnection
        case .httpStatus(_, 429, _): return .rateLimited
        case .httpStatus: return .nodeUnavailable
        case .unsupportedAccountType, .invalidAccount, .heightMismatch,
             .invalidDenom, .invalidAmount, .duplicateDenom, .paginationCycle,
             .pageLimitExceeded, .absentAccountWithBalances, .attemptsExhausted,
             .malformedResponse: return .invalidResponse
        case .staleLease: return .nodeUnavailable
        case .cancelled: return .internalInvariant
        }
    }
}
