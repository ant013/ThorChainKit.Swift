# S1-05 — RUNE account sync lifecycle

**Status:** synchronized to S1-01 revision 9 after revision-8 adversarial REVISE; implementation blocked pending fresh review and approval.
**Risk:** high/concurrency, persistence, stale-state semantics.
**Observable outcome:** `Kit.start/refresh/stop` create one managed sync lifecycle; account/balances/height are published as a single snapshot, cached state survives reconstruction, and a cancelled/old generation cannot overwrite the new state.

## Goal

Connect the S1-02 endpoint policy and S1-04 read client in an actor-owned, read-only account synchronizer while preserving the familiar Horizontal Systems facade and Combine compatibility.

## Scope

Included:

- idempotent public-facade start/stop/refresh admission;
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
Scripts/test-s1-05-lifecycle-invariants.sh
iOS Example/Sources/Controllers/LifecycleController.swift
.maestro/flows/04-lifecycle-restart.yaml
```

## Architecture

```text
Kit synchronous facade
  ├─ sole desired-running owner ─▶ S1-01 facade dispatcher ─▶ LifecycleCommandBridge ─▶ AccountSyncer actor
  └─ getters/publishers ◀──────── shared facade dispatcher ◀── AccountStateManager
                                                               ▲
                                                               │ accepted snapshot only
AccountSyncer ─▶ ReadOperationCoordinator ─▶ EndpointPool + ThorNodeClient
      │
      └──────── atomic save ───▶ AccountStateStorage
```

`AccountSyncer` is the sole owner of the loop/current request/generation. `AccountStateManager` does not start network operations and does not accept partial values.

`LifecycleCommandBridge` becomes the concrete S1-05 collaborator behind S1-01's synchronized owner and facade dispatcher. It receives only already-linearized, monotonically sequenced effective commands. It neither stores `desiredRunning`, filters idempotent start/stop/refresh calls, nor assigns a second public-command sequence. Its task tail preserves the accepted command order while handing asynchronous actor work across the synchronous facade boundary; `start/stop/start` never create independent unordered `Task {}` instances. `AccountSyncer`'s loop/task presence is runtime ownership state, not a defensive idempotence filter: `start` while already running, or `stop`/`refresh` while stopped, is an internal invariant failure with a stable diagnostic marker. `Scripts/test-s1-05-lifecycle-invariants.sh` runs those three impossible actor-command sequences in isolated subprocesses and requires each to terminate nonzero with its exact marker. Every refresh reaching the bridge was already accepted while running; multiple valid running refresh commands may still coalesce network work without dropping or reordering lifecycle commands.

`LifecycleGate` introduces the first post-construction snapshot mutation interface and owns publication-turn admission on the S1-01 facade dispatcher; S1-01 deliberately defines neither. `acceptIfCurrent(generation:snapshot:)` admits the entire publication turn to that dispatcher before any pre-drain, checks the token, drains already-admitted lifecycle commands, sets getters, sends publishers, and drains every command admitted during synchronous delivery before yielding. Admission plus both drains are one dispatcher turn, so a competing publication cannot enter between reentrant command linearization and its drain. An ordinary external `stop()` completes only after its ordered bridge invocation establishes the generation/publication barrier. An effective `start`, `stop`, or `refresh` called synchronously by a subscriber follows S1-01's dispatcher-context append-and-return rule, and the active turn's post-drain completes it before any competing publication begins. A separate storage control row provides transaction-level compare-and-swap.

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

Public `Kit.start/stop/refresh` preserve synchronous completion for effective calls made outside the facade dispatcher. The S1-01 owner filters no-ops and establishes command order before invoking the bridge. `start/stop` synchronously invoke the short GRDB control transaction `advanceGeneration`, update the in-memory gate, and then append the actor command to the preceding command task. Stopped refresh never reaches the bridge; an accepted running refresh is appended/coalesced in established order. Dispatcher-context reentry uses the explicitly documented enqueue-and-return exception so subscriber delivery cannot wait on itself.

`stop()` may briefly block on the local GRDB writer, but after it returns, the old generation cannot commit/publish. Actor `stop()` cancels and awaits the owned task before the next FIFO `start()`.

## State model

S1-05 consumes the exact `AccountState`, `SyncState`, and `SyncError` declarations from S1-01; it does not redeclare them or add a BigUInt-containing `Sendable`/`@unchecked Sendable` conformance. The S1-01 optional publishers remain optional and replay current absence/state immediately.

Internal Provider/API/GRDB errors map to this sanitized stable enum; exact diagnostics are available to the internal logger/statusInfo. Cancellation has no case. On stop, state becomes `.idle(cached: lastAccepted != nil)` only for the active generation.

`AccountState` contains exactly the frozen S1-01 fields: `accountNumber`, `sequence`, full `[Denom: BigUInt]`, `acceptedHeight`, `fetchedAt`, `providerFamilyId`, and `exists`. Chain identity, generation, and persistence namespace remain in the internal accepted-snapshot/storage context and are not added to the public value. `Kit.runeBalance` is derived from `accountState.balances[.rune]` and defaults to zero only when no accepted account exists or a successful complete balance snapshot omits `rune`; it is not stored as additional `AccountState` content.

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

- the S1-01 owner has already filtered repeated start; actor receipt while already running is an internal invariant failure, never a no-op or coalesced command, and a bridge spy plus the isolated invariant harness exercise that boundary;
- atomically advance the persistent generation only for stopped→running;
- load cached state once; publish `.idle(cached:true)` before network access;
- create exactly one loop task;
- immediate refresh, then schedule.

### `refresh()`

- actor receipt while stopped is an internal invariant failure because S1-01 never forwards stopped refresh;
- if a request is running, set `refreshRequested=true` without starting a second full sync in parallel;
- after completion, perform at most one coalesced refresh;
- do not clear cached state on failure.

### `stop()`

- actor receipt while stopped is an internal invariant failure because S1-01 never forwards repeated stop;
- synchronously close in-memory gate and advance persistent generation in control transaction;
- cancel loop task, current request and pending sleep;
- await owned-task completion within the actor path;
- clear `refreshRequested`;
- do not delete persisted/cached state;
- late completion old generation is ignored before save/publication.

### Restart

- production composition passes the already-computed S1-01 `persistenceNamespace` into `StorageKey(persistenceNamespace:)`; a new `Kit` with the same S1-01 namespace receives the same key, and S1-05 accepts no wallet/network/preimage initializer for storage identity;
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

`StorageKey` is an internal wrapper around exactly the already-computed 64 lowercase-hex S1-01 `persistenceNamespace` (`SHA256(walletId UTF-8 || 0x00 || network.persistenceKey UTF-8)`). Its sole initializer is `StorageKey(persistenceNamespace:)`; it never accepts, stores, or reconstructs `walletId`, `Network`, `network.persistenceKey`, the preimage, or a `walletId-network` concatenation. For `wallet-01` on mainnet, production composition must pass exactly `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015` from S1-01 into that initializer.

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

Storage failure policy: the network result is not published as durably `.synced` when saving is mandatory. `.notSynced(.storageUnavailable, cached: previous)` is required; this prevents a UI success state that would disappear on relaunch.

## State publication

- `AccountStateManager.accept(_:)` is called only through `LifecycleGate.acceptIfCurrent` and accepts complete state.
- Synchronous getters and Combine subjects are updated on the shared S1-01 facade dispatcher.
- Order: internal snapshot set → publishers send. A consumer invoked by a publisher already sees the new getter value.
- An ordinary external `stop()` guarantees that no later publication turn sends after it returns. A dispatcher-context reentrant stop returns after enqueue so the current turn can unwind; its queued bridge completion is the barrier, and no later turn may overtake it.
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

- facade start/start forwards one actor start and creates one loop and one immediate request;
- the isolated invariant harness proves actor duplicate start, stopped refresh, and duplicate stop each fail nonzero with the exact internal marker rather than no-op/coalescing or masking a bridge defect;
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
- a bridge spy proves repeated start is filtered by S1-01 and no duplicate command reaches the bridge;
- with the real bridge/gate, subscriber delivery reenters effective `start`, `stop`, and `refresh` in separate barrier-controlled cases; each method returns so the current turn can post-drain its command in the S1-01 sequence;
- a deterministic `P0/C/P1` barrier admits `C` from `P0`, submits competing `P1` before releasing `P0`, and proves exact publication/command order `P0 → C → P1`;
- ordinary external effective start/stop/refresh calls cannot return before the corresponding bridge invocation completes;
- stop→start creates new generation and works;
- backoff clock deterministic; no fixed sleep.

`AccountStateStorageTests.swift`:

- round-trip max values and slash denoms;
- atomic replace removes stale denom;
- failed transaction leaves previous snapshot intact;
- `saveIfCurrent` mismatch leaves previous snapshot intact;
- generation control survives reconstruction and remains monotonic;
- the fixed S1-01 `wallet-01`/mainnet composition passes `StorageKey(persistenceNamespace: "e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015")`, persists that exact key, and reloads the same cache;
- different network/wallet isolated;
- stored `storage_key` is exactly the S1-01 oracle `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`; a guarded factory/source mutant that reconstructs from `walletId` plus `network.persistenceKey` fails the same composition test, and database bytes plus captured logs contain neither the raw wallet ID nor a concatenated/unhashed namespace preimage;
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

Before acceptance, S1-05 adds `Tests/ThorChainKitTests/Fixtures/S1-05-public-symbols.txt` and `Scripts/verify-s1-05.sh`; its CI job compares the generated public graph exactly with the S1-05 baseline and requires every canonical declaration in S1-01…S1-04 to remain an unchanged subset. New sync projections appear only in the S1-05 exact baseline; prior removal or signature mutation fails. The S1-05 script replaces the S1-01 inert-factory audit with an exact production composition allowlist for endpoint/read/storage/lifecycle components. Construction may create those approved dependencies but must not auto-start, open a request, launch a task, or begin polling; all other networking, database, task, timer, dispatch-source, file, and helper escapes remain forbidden by named temporary-copy canaries.

- One actor owns runtime lifecycle tasks; the bridge receives only S1-01-filtered commands and serializes actor work plus persistent generation barriers without a second desired-running state. Actor-state-inconsistent start/stop/refresh commands are invariant failures proven by the isolated nonzero subprocess harness, not defensive no-ops.
- Stop/restart/cancellation invariants are proven by deterministic tests.
- Account, balances, and height are saved/published through generation-CAS; the old generation cannot commit after stop has returned.
- Cached, stale, missing-account, zero-RUNE, and error states are distinguishable.
- One refresh performs one complete bank fetch, regardless of the number of denoms.
- The public facade remains byte-for-byte compatible with S1-01's frozen public models; chain identity stays internal and storage failures use `.storageUnavailable`.
- Persistence/relaunch and the controlled live read pass.

## Recorded decisions

1. Default foreground polling interval — 60 seconds, bounded failure backoff — 300 seconds.
2. The production factory uses mandatory durable GRDB storage: a save failure is not published as `.synced`. In-memory storage is available only through internal/test injection.
