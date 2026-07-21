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
    private var refreshTask: Task<Void, Never>?
    private var refreshInFlight = false
    private var refreshRequested = false

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
        if running { invariantFailure("S105_INVARIANT_DUPLICATE_START") }
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
        if !running { invariantFailure("S105_INVARIANT_DUPLICATE_STOP") }
        if self.generation != generation { invariantFailure("S105_INVARIANT_GENERATION") }
        running = false
        self.generation = nil
        loopTask?.cancel()
        refreshTask?.cancel()
        await loopTask?.value
        loopTask = nil
        refreshInFlight = false
        refreshRequested = false
    }

    func cancelStop() async {
        guard running else { return }
        running = false
        generation = nil
        loopTask?.cancel()
        refreshTask?.cancel()
        await loopTask?.value
        loopTask = nil
        refreshInFlight = false
        refreshRequested = false
    }

    func refresh() async {
        if !running { invariantFailure("S105_INVARIANT_STOPPED_REFRESH") }
        if refreshInFlight {
            refreshRequested = true
            return
        }
        refreshInFlight = true
        defer {
            refreshInFlight = false
            refreshRequested = false
        }

        repeat {
            refreshRequested = false
            guard let generation, running else { return }
            let task = Task { [weak self] in
                guard let self else { return }
                await self.performRefresh(generation: generation)
            }
            refreshTask = task
            await task.value
            refreshTask = nil
        } while refreshRequested && running && !Task.isCancelled
    }

    func cancelRefresh() {
        loopTask?.cancel()
        refreshTask?.cancel()
    }

    private func performRefresh(generation: UInt64) async {
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
        guard running, self.generation == generation, !Task.isCancelled else { return }
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
        if error is StorageRecordError { return .storageUnavailable }
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

private func invariantFailure(_ marker: String) -> Never {
    FileHandle.standardError.write(Data((marker + "\n").utf8))
    preconditionFailure()
}
