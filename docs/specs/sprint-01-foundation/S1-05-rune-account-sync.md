# S1-05 — RUNE account sync lifecycle

**Status:** revised after adversarial review; implementation blocked pending approval.
**Risk:** high/concurrency, persistence, stale-state semantics.
**Observable outcome:** `Kit.start/refresh/stop` create one managed sync lifecycle; account/balances/height are published as a single snapshot, cached state survives reconstruction, and a cancelled/old generation cannot overwrite the new state.

## Goal

Connect the S1-02 endpoint policy and S1-04 read client in an actor-owned, read-only account synchronizer while preserving the familiar Horizontal Systems facade and Combine compatibility.

## Scope

Included:

- idempotent start/stop/refresh;
- one-shot sync and periodic polling;
- coalescing concurrent refresh;
- one complete `ReadOperationCoordinator.read` per refresh;
- atomic state/persistence publication;
- cached/stale/fresh/error distinctions;
- lifecycle generation and complete cancellation;
- RUNE projection from the exact `rune` denom.

Excluded:

- sequence reservation/send pending state;
- transaction/history sync;
- token discovery UI;
- reachability framework dependency;
- background execution entitlement.

## Files

```text
Sources/ThorChainKit/Sync/AccountSyncer.swift
Sources/ThorChainKit/Sync/AccountSyncing.swift
Sources/ThorChainKit/Sync/SyncSchedule.swift
Sources/ThorChainKit/Sync/SyncGeneration.swift
Sources/ThorChainKit/Sync/LifecycleCommandBridge.swift
Sources/ThorChainKit/Sync/LifecycleGate.swift
Sources/ThorChainKit/State/AccountStateManager.swift
Sources/ThorChainKit/State/StateSnapshot.swift
Sources/ThorChainKit/State/StatePublishing.swift
Sources/ThorChainKit/Storage/AccountStateStorage.swift
Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift
Sources/ThorChainKit/Storage/StorageRecord.swift
Sources/ThorChainKit/Storage/Migrations.swift
Sources/ThorChainKit/Core/Kit.swift
Sources/ThorChainKit/Core/KitFactory.swift
Tests/ThorChainKitTests/AccountSyncerTests.swift
Tests/ThorChainKitTests/AccountStateStorageTests.swift
Tests/ThorChainKitTests/KitLifecycleTests.swift
iOS Example/Sources/Controllers/LifecycleController.swift
.maestro/flows/04-lifecycle-restart.yaml
```

## Architecture

```text
Kit synchronous facade
  ├─ lifecycle commands ───────▶ FIFO LifecycleCommandBridge ─▶ AccountSyncer actor
  └─ getters/publishers ◀────── AccountStateManager
                                  ▲
                                  │ accepted snapshot only
AccountSyncer ─▶ ReadOperationCoordinator ─▶ EndpointPool + ThorNodeClient
      │
      └──────── atomic save ───▶ AccountStateStorage
```

`AccountSyncer` is the sole owner of the loop/current request/generation. `AccountStateManager` does not start network operations and does not accept partial values.

`LifecycleCommandBridge` becomes the concrete S1-05 implementation behind S1-01's single synchronized lifecycle owner; it does not introduce a second facade state machine. It serializes synchronous public commands into one FIFO task chain. It stores the desired running state for idempotence; `start/stop/start` never create independent unordered `Task {}` instances. Every running public refresh reaches the bridge once, after which the actor may coalesce redundant network work. `LifecycleGate` uses one serial publication queue: `acceptIfCurrent(generation:snapshot:)` checks the token, sets getters, and sends publishers in one queued block; `stop()` performs a queue barrier, so all earlier sends complete and later ones are rejected. A reentrant stop from a subscriber is detected by a queue-specific key and invalidates the token inline without deadlock. A separate storage control row provides transaction-level compare-and-swap.

## Contracts

```swift
protocol AccountSyncing: Sendable {
    func start(generation: UInt64) async
    func stop(generation: UInt64) async
    func refresh() async
}

actor AccountSyncer: AccountSyncing {
    func start(generation: UInt64) async
    func stop(generation: UInt64) async
    func refresh() async
}

protocol AccountStateStorage: Sendable {
    func load(key: StorageKey) async throws -> AccountState?
    func advanceGeneration(key: StorageKey) throws -> UInt64
    func saveIfCurrent(
        _ state: AccountState,
        key: StorageKey,
        expectedGeneration: UInt64
    ) async throws -> Bool
    func clear(key: StorageKey) async throws
}
```

Public `Kit.start/stop/refresh` preserve the synchronous host contract. Under the serial bridge, `start/stop` synchronously invoke the short GRDB control transaction `advanceGeneration`, update the in-memory gate, and then append the actor command to the preceding command task. `refresh` while stopped is a no-op; while running, it is enqueued/coalesced in FIFO order.

`stop()` may briefly block on the local GRDB writer, but after it returns, the old generation cannot commit/publish. Actor `stop()` cancels and awaits the owned task before the next FIFO `start()`.

## State model

S1-05 consumes the exact `AccountState`, `SyncState`, and `SyncError` declarations from S1-01; it does not redeclare them or add a BigUInt-containing `Sendable`/`@unchecked Sendable` conformance. The S1-01 optional publishers remain optional and replay current absence/state immediately.

Internal Provider/API/GRDB errors map to this sanitized stable enum; exact diagnostics are available to the internal logger/statusInfo. Cancellation has no case. On stop, state becomes `.idle(cached: lastAccepted != nil)` only for the active generation.

`AccountState` contains:

- `exists`;
- `accountNumber`, `sequence`, or nil only when `exists == false`;
- full `[Denom: BigUInt]`;
- `acceptedHeight`;
- `fetchedAt`;
- `providerFamilyId`, `network.expectedChainId`;
- `runeBalance` computed from exact `.rune`, defaulting to zero only if a successful complete balance snapshot does not contain `rune`.

A transport/decode failure never creates a zero state.

## One-shot sync algorithm

```text
generation = FIFO bridge generation
publish .syncing(previous)
read = ReadOperationCoordinator.read(address)
check cancellation + generation
construct full AccountState from complete read
committed = storage.saveIfCurrent(state, expectedGeneration: generation)
guard committed
LifecycleGate.acceptIfCurrent(generation, .synced(state))
```

If the account is nil but balances are non-empty, this is an invariant violation: do not publish a contradictory snapshot. An empty/no account is valid `exists=false`, zero RUNE, and nil number/sequence.

`acceptedHeight` is the exact Cosmos REST height from the complete coordinator result: the account request and all balance pages were pinned to it and returned the same `x-cosmos-block-height`. Comet height remains diagnostic only.

## Lifecycle state machine

### `start()`

- bridge desired state already running → no-op;
- atomically advance the persistent generation only for stopped→running;
- load cached state once; publish `.idle(cached:true)` before network access;
- create exactly one loop task;
- immediate refresh, then schedule.

### `refresh()`

- if stopped, no-op;
- if a request is running, set `refreshRequested=true` without starting a second full sync in parallel;
- after completion, perform at most one coalesced refresh;
- do not clear cached state on failure.

### `stop()`

- synchronously close in-memory gate and advance persistent generation in control transaction;
- cancel loop task, current request and pending sleep;
- await owned-task completion within the actor path;
- clear `refreshRequested`;
- do not delete persisted/cached state;
- late completion old generation is ignored before save/publication.

### Restart

- a new `Kit` receives the same `StorageKey(walletId, network.persistenceKey)`;
- the cached snapshot is published as stale/idle before a successful refresh;
- endpoint URL order does not change the storage key;
- a network identity change creates a different namespace.

## Scheduling

```swift
struct SyncSchedule: Sendable {
    let normalInterval: Duration
    let failureBackoff: BackoffPolicy
}
```

Clock and sleep are injected. The production default is 60 seconds while foreground/running; failures use exponential backoff of 60s → 120s → 240s → max 300s with injected deterministic jitter. Polling does not promise background execution; app refresh calls `refresh()`. The value accounts for the public limit of 50,000 requests/day and is reconsidered only through a separate metric/spec delta.

## Persistence schema

One GRDB transaction saves:

```text
account_state
  storage_key PRIMARY KEY
  network_chain_id
  address
  account_exists
  account_number NULLABLE
  sequence NULLABLE
  accepted_height
  fetched_at
  provider_family_id

sync_control
  storage_key PRIMARY KEY
  generation

balances
  storage_key
  denom
  amount_decimal_string
  PRIMARY KEY(storage_key, denom)
```

Within one GRDB write transaction, `saveIfCurrent` first compares `sync_control.generation`; on mismatch, it returns `false` without changing account/balances. On match, it replaces the account and the entire balance set. If the save transaction acquires the writer first, `stop()` waits for it, then increments the generation and only then returns; if stop wins, the CAS save fails. Therefore, a write after stop has returned is impossible. BigUInt is stored as a canonical decimal string. Migration `v1` is idempotent.

Storage failure policy: the network result is not published as durably `.synced` when saving is mandatory. `.notSynced(.storage, cached: previous)` is recommended; this prevents a UI success state that would disappear on relaunch.

## State publication

- `AccountStateManager.accept(_:)` is called only through `LifecycleGate.acceptIfCurrent` and accepts complete state.
- Synchronous getters and Combine subjects are updated on one serial publication queue.
- Order: internal snapshot set → publishers send. A consumer invoked by a publisher already sees the new getter value.
- The `stop()` publication barrier guarantees that no publisher sends occur after it returns; a reentrant stop does not deadlock.
- A repeated identical snapshot may not be published; the height/fetchedAt change policy must be pinned by a test.
- The external scheduler is not hardcoded to main; the UW adapter performs its own bridge to Rx/UI.

## Analog delta

| Source | Adopted | Corrected |
|---|---|---|
| Tron Syncer | coherent lifecycle spine, cached height/account publishers | actor ownership, all tasks tracked, restartable subscriptions |
| Evm RpcBlockchain | parallel balance+nonce idea | one accepted snapshot/generation; own tasks cancelled |
| Vultisig BalanceService | full-bank response and native `rune` lookup | one fetch per address, not per coin; explicit stale/error state |
| Vultisig pending | sequence availability | sequence is not used as transaction confirmation |

## Tests before implementation

`AccountSyncerTests.swift`:

- start/start creates one loop and one immediate request;
- concurrent refresh calls coalesce;
- account and balances use same lease;
- complete coordinator success emits syncing→synced once;
- empty account/empty balances valid;
- nil account/nonempty balances invariant failure;
- second bank page failure preserves previous cached state;
- internal provider/API error maps to stable public `SyncError`, not zero;
- cancellation during account/balance/page/sleep stops further work;
- stop before CAS makes old save return false;
- stop racing an already-started GRDB transaction returns only after save+generation invalidation and permits no later write/publication;
- immediate start/stop/start is processed in exact FIFO order with one final loop;
- publication queued before stop completes before stop returns; publication queued after invalidation is rejected;
- subscriber calling stop reentrantly does not deadlock and receives no later generation values;
- stop→start creates new generation and works;
- backoff clock deterministic; no fixed sleep.

`AccountStateStorageTests.swift`:

- round-trip max values and slash denoms;
- atomic replace removes stale denom;
- failed transaction leaves previous snapshot intact;
- `saveIfCurrent` mismatch leaves previous snapshot intact;
- generation control survives reconstruction and remains monotonic;
- same wallet/network reloads cache;
- different network/wallet isolated;
- schema v1 idempotent migration.

`KitLifecycleTests.swift`:

- facade getter updated before publisher callback;
- lifecycle methods forward idempotently;
- runeBalance exact `.rune` projection;
- accountExists not inferred from balance error;
- deinit/stop releases owned task (leak sentinel).

### Example/Maestro acceptance

`LifecycleController` provides only explicit `Start`, `Stop`, and `Refresh` controls plus read-only state/counter diagnostics. Flow `04-lifecycle-restart.yaml`:

- proves `start/start` coalescing through the visible request counter;
- performs stop during a controlled pending request and observes no late publication;
- relaunches the app without clearing state and receives a cached/stale snapshot before the fresh fixture response;
- performs an offline relaunch and preserves the address/balance while showing a failure/stale state;
- uses no fixed UI sleeps: waiting is based on accessibility-visible state transitions.

## Live gate

- First start: no cache → live synced state.
- Reconstruct Kit with same key: cached state immediately visible as stale, then fresh live state.
- Disable network between reconstruction and refresh: cached remains visible with `.notSynced`, not cleared/zeroed.
- Restore network and refresh: state fresh without recreating Kit.

## Acceptance criteria

- One actor owns runtime lifecycle tasks; the bridge only serializes public commands and persistent generation barriers.
- Stop/restart/cancellation invariants are proven by deterministic tests.
- Account, balances, and height are saved/published through generation-CAS; the old generation cannot commit after stop has returned.
- Cached, stale, missing-account, zero-RUNE, and error states are distinguishable.
- One refresh performs one complete bank fetch, regardless of the number of denoms.
- The public facade remains compatible with S1-01.
- Persistence/relaunch and the controlled live read pass.

## Recorded decisions

1. Default foreground polling interval — 60 seconds, bounded failure backoff — 300 seconds.
2. The production factory uses mandatory durable GRDB storage: a save failure is not published as `.synced`. In-memory storage is available only through internal/test injection.
