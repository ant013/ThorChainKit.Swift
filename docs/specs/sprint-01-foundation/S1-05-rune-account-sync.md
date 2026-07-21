# S1-05 — RUNE account sync lifecycle

**Status:** design revision 3 after discovery 2/2 REVISE; synchronized to S1-01 revision 12; implementation blocked pending fresh adversarial acceptance and explicit user approval.
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
Package.swift
Package.resolved
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
Sources/ThorChainKit/Core/KitDependencies.swift
Sources/ThorChainKit/Core/KitFactory.swift
Tests/ThorChainKitTests/AccountSyncerTests.swift
Tests/ThorChainKitTests/AccountStateStorageTests.swift
Tests/ThorChainKitTests/KitLifecycleTests.swift
Scripts/test-s1-05-lifecycle-invariants.sh
Scripts/test-s1-04-s1-05-isolation.sh
Scripts/test-s1-05-dependency-floor.sh
Scripts/verify-s1-05.sh
iOS Example/Sources/Presentation/LifecycleViewModel.swift
iOS Example/Sources/Views/LifecycleView.swift
iOS Example/Sources/Core/ExampleRuntime.swift
.maestro/flows/04-lifecycle-restart.yaml
```

## Architecture

```text
Kit synchronous facade
  ├─ sole desired-running owner ─▶ S1-01 facade dispatcher ─▶ LifecycleCommandBridge ─▶ AccountSyncer actor
  └─ getters/publishers ◀──────── shared facade dispatcher ◀── AccountStateManager
                                                               ▲
                                                               │ AccountState reconstructed here
                                                               │ from Sendable StorageRecord
AccountSyncer ─▶ ReadOperationCoordinator ─▶ EndpointPool + ThorNodeClient
      │
      └──────── atomic save ───▶ AccountStateStorage
```

`AccountSyncer` is the sole owner of the loop/current request and refresh
coalescing. `AccountStateManager` does not start network operations and does
not accept partial values.

### Generation ownership and bridge handshake

The facade dispatcher, through `LifecycleGate`, is the sole logical owner of
the active `SyncGeneration?`. `AccountSyncer` owns only the loop, current read,
coalescing flag, and cancellation; it receives an immutable generation token
and never creates, increments, or compares a second lifecycle generation.
`sync_control.generation` is the durable compare-and-swap authority and is
advanced by the gate's short GRDB control transaction. It is not an additional
in-memory owner. Every effective `start` and `stop` advances that row; a
running `refresh` does not.

The ordering for an effective command is fixed:

1. The S1-01 dispatcher linearizes the command and the gate closes or opens
   the active publication token. For `start`, the gate first obtains the next
   durable generation and installs it only after that transaction succeeds. For
   `stop`, the gate closes the token before attempting the durable increment.
2. The gate invokes the bridge with the already-linearized command and token
   (or a stop-cancellation command with no token when the durable stop
   increment failed).
   The bridge appends to one FIFO task tail and returns a completion barrier;
   it never synchronously waits for the actor or calls back into the facade
   dispatcher.
3. An off-dispatcher public call waits on its returned barrier only after the
   dispatcher turn has returned. A dispatcher-context reentrant call appends,
   returns immediately, and is completed by S1-01's active-turn post-drain.
   This is the only enqueue-and-return exception and prevents self-deadlock.

#### S1-01 collaborator boundary amendment

S1-05 changes only the internal S1-01 collaborator contract; the public
`Kit.start()`, `Kit.stop()`, `Kit.refresh()`, public models, and S1-01 public
symbol baseline remain unchanged. `Sources/ThorChainKit/Core/KitDependencies.swift`
owns these exact internal declarations:

```swift
protocol KitLifecycle: AnyObject {
    func start(sequence: UInt64) -> LifecycleCommandBarrier
    func stop(sequence: UInt64) -> LifecycleCommandBarrier
    func cancelStop() -> LifecycleCommandBarrier
    func refresh(sequence: UInt64) -> LifecycleCommandBarrier
}
```

`LifecycleCommandBarrier` is an internal one-shot completion object. The
bridge returns it after appending the command to its FIFO task tail and
signals it after the command's required work completes. A successful `stop`
signals only after the actor has cancelled and awaited its owned work. The
`cancelStop()` method is the explicit no-token representation of the
control-transaction failure path; it is never encoded as `stop(sequence: 0)`
or any other fabricated generation.

`Kit.submit(_:)` in `Sources/ThorChainKit/Core/Kit.swift` retains the barrier
returned by the effective collaborator invocation. An off-dispatcher caller
waits on that barrier after `facadeDispatcher.sync` returns. A dispatcher-
context reentrant caller does not wait; it returns after FIFO append and the
active turn post-drains the command. No-op commands return without a barrier
or collaborator call. `drainPendingLifecycleCommands()` returns the barrier
for the command it invokes, so a caller cannot accidentally wait on an
unrelated later command.

When `advanceGeneration` fails during stop, the gate remains closed, emits
the current-generation storage failure described below, invokes
`cancelStop()` with no generation token, and returns that cancellation
barrier to `Kit.submit`. Thus both successful stop and control-failure stop
have a concrete completion guarantee before an ordinary public call returns.

`stop` always cancels and awaits the actor-owned task before its off-dispatcher
barrier is signalled. The gate remains closed until a later successful start.
If the durable increment throws, the nonthrowing public facade fails closed:
it does not open/reuse a token, it still cancels and drains the old actor task,
it publishes `.notSynced(.storageUnavailable, cached: previous)` only after
that drain, and it returns only after the barrier. Thus a storage outage does
not claim durable invalidation or expose a successful stopped state, while no
old generation can publish or write after `stop` returns. A failed start stays
stopped, publishes the same sanitized storage error, and forwards no actor
command.

`LifecycleCommandBridge` becomes the concrete S1-05 collaborator behind S1-01's synchronized owner and facade dispatcher. It receives only already-linearized, monotonically sequenced effective commands. It neither stores `desiredRunning`, filters idempotent start/stop/refresh calls, nor assigns a second public-command sequence. Its task tail preserves the accepted command order while handing asynchronous actor work across the synchronous facade boundary; `start/stop/start` never create independent unordered `Task {}` instances. `AccountSyncer`'s loop/task presence is runtime ownership state, not a defensive idempotence filter: `start` while already running, or `stop`/`refresh` while stopped, is an internal invariant failure with a stable diagnostic marker. `Scripts/test-s1-05-lifecycle-invariants.sh` runs those three impossible actor-command sequences in isolated subprocesses and requires each to terminate nonzero with its exact marker. Every refresh reaching the bridge was already accepted while running; multiple valid running refresh commands may still coalesce network work without dropping or reordering lifecycle commands.

`LifecycleGate` introduces the first post-construction snapshot mutation interface and owns publication-turn admission on the S1-01 facade dispatcher; S1-01 deliberately defines neither. It is initialized with the immutable active address string and `address.network.expectedChainId`. `acceptIfCurrent(generation:record:)` admits the entire `Sendable` record and publication turn to that dispatcher before any pre-drain, checks the token and exact active identity, reconstructs the public snapshot there, drains already-admitted lifecycle commands, sets getters, sends publishers, and drains every command admitted during synchronous delivery before yielding. Admission plus both drains are one dispatcher turn, so a competing publication cannot enter between reentrant command linearization and its drain. An ordinary external `stop()` completes only after its ordered bridge invocation establishes the generation/publication barrier. An effective `start`, `stop`, or `refresh` called synchronously by a subscriber follows S1-01's dispatcher-context append-and-return rule, and the active turn's post-drain completes it before any competing publication begins. A separate storage control row provides transaction-level compare-and-swap.

The failure ingress is the sibling method
`publishFailureIfCurrent(_:)`. Its only cross-boundary value is:

```swift
struct SyncFailure: Sendable, Equatable {
    let generation: UInt64
    let address: String
    let networkChainId: String
    let error: SyncError
}
```

`publishFailureIfCurrent` admits one event turn onto the same facade
dispatcher, then requires all four checks before publication: the event
generation equals the active token, the event address equals the immutable
active address, the event chain ID equals `activeAddress.network.expectedChainId`,
and the active lifecycle has not closed publication. A rejected event is a
no-op. A current event never reconstructs or transports `BigUInt`; it reads
the manager's existing dispatcher-owned `AccountState`, builds
`.notSynced(event.error, cached: currentAccountState)`, updates the complete
snapshot/getters first, and sends the sync-state publisher afterward. It does
not call `accept`, mutate account/balances/height, or emit `.synced`. Save,
transport, and decode failures use this ingress. The same dispatcher FIFO
orders an already-admitted failure before a later stop turn; a failure
admitted after stop invalidation is rejected by generation/closed-token
checks.

## Contracts

```swift
protocol AccountSyncing: Sendable {
    func start(generation: UInt64) async
    func stop(generation: UInt64) async
    func cancelStop() async
    func refresh() async
}

actor AccountSyncer: AccountSyncing {
    func start(generation: UInt64) async
    func stop(generation: UInt64) async
    func cancelStop() async
    func refresh() async
}

protocol AccountStateStorage: Sendable {
    func load(key: StorageKey) async throws -> StorageRecord?
    func advanceGeneration(key: StorageKey) throws -> UInt64
    func saveIfCurrent(
        _ record: StorageRecord,
        key: StorageKey,
        expectedGeneration: UInt64
    ) async throws -> Bool
    func clear(key: StorageKey) async throws
}
```

`load(key:)` performs one `DatabasePool.read` transaction and fetches
`sync_control`, `account_state`, and all `balances` rows through that same
SQLite read snapshot. It returns either one complete record or `nil`; it never
assembles the account and balances from separate reads. `saveIfCurrent` and
`advanceGeneration` each use the same GRDB writer pool, so the writer lock
orders a save versus stop's invalidating increment.

### Isolation transfer contract

`AccountSyncer` receives only S1-04's `AccountReadTransport`, whose balances contain canonical decimal strings, and converts it to `StorageRecord`. `StorageRecord` is an internal `Sendable` value containing the exact validated address string, exact expected network chain ID, and only other `String`, integer, Boolean, `Date`, and arrays of the internal `Sendable` decimal balance record; it never stores `BigUInt`, `AccountState`, or `SyncState`. `AccountStateStorage.load/saveIfCurrent` cross async boundaries only with this record.

After a generation-valid save or cache load, `LifecycleGate.acceptIfCurrent(generation:record:)` carries that `Sendable` record to the S1-01 facade dispatcher. `StorageRecord.validated(from:)` performs the canonical decimal, `2^256 - 1`, account-existence, accepted-height, timestamp, provider-ID, address, and chain-ID validation before `saveIfCurrent` is called. Storage repeats the record validation and rejects it without mutation as defense in depth. Before any cache or fresh record can become public, the gate requires `record.address == activeAddress.raw` and `record.networkChainId == activeAddress.network.expectedChainId`. Inside that dispatcher turn it constructs `BigUInt` values and the frozen public `AccountState`, then passes the result directly to `AccountStateManager` before publisher delivery. A different-address row under the same wallet/network key, a tampered chain ID, an amount of `2^256`, malformed fresh input, or other invalid persisted data is a storage failure and is neither published nor coerced to zero. Cache identity failure maps to `.storageUnavailable`, publishes no cached snapshot, and does not prevent the running lifecycle from attempting a fresh read whose valid record may atomically replace the row. The BigUInt-backed value never leaves the dispatcher through an actor/async/storage boundary. `@unchecked Sendable` is forbidden. Actor/storage failures cross back only as `SyncFailure`; `LifecycleGate.publishFailureIfCurrent(_:)` owns cached-state lookup and publication.

Public `Kit.start/stop/refresh` preserve synchronous completion for effective calls made outside the facade dispatcher. The S1-01 owner filters no-ops and establishes command order before invoking the bridge. The gate performs the generation transaction and token admission described above, then the bridge appends the actor command to the preceding command task. Stopped refresh never reaches the bridge; an accepted running refresh is appended/coalesced in established order. Dispatcher-context reentry uses the explicitly documented enqueue-and-return exception so subscriber delivery cannot wait on itself.

`stop()` may briefly block on the local GRDB writer, but after it returns, the old generation cannot commit/publish. Actor `stop()` cancels and awaits the owned task before the next FIFO `start()`; the gate's pre-close plus actor drain also makes the failure path safe when the control transaction is unavailable.

## State model

S1-05 consumes the exact `AccountState`, `SyncState`, and `SyncError` declarations from S1-01; it does not redeclare them or add a BigUInt-containing `Sendable`/`@unchecked Sendable` conformance. The S1-01 optional publishers remain optional and replay current absence/state immediately.

Internal Provider/API/GRDB errors map to this sanitized stable enum; exact diagnostics are available to the internal logger/statusInfo. Cancellation has no case. On stop, state becomes `.idle(cached: lastAccepted != nil)` only for the active generation.

`AccountState` contains exactly the frozen S1-01 fields: `accountNumber`, `sequence`, full `[Denom: BigUInt]`, `acceptedHeight`, `fetchedAt`, `providerFamilyId`, and `exists`. Chain identity, generation, and persistence namespace remain in the internal accepted-snapshot/storage context and are not added to the public value. `Kit.runeBalance` is derived from `accountState.balances[.rune]` and defaults to zero only when no accepted account exists or a successful complete balance snapshot omits `rune`; it is not stored as additional `AccountState` content.

A transport/decode failure never creates a zero state.

## One-shot sync algorithm

```text
generation = FIFO bridge generation
publish .syncing(previous)
readTransport = ReadOperationCoordinator.read(address)
check cancellation + generation
construct and validate Sendable StorageRecord from complete readTransport
committed = storage.saveIfCurrent(record, expectedGeneration: generation)
guard committed
LifecycleGate.acceptIfCurrent(generation, record)
```

If the account is nil but balances are non-empty, this is an invariant violation: do not publish a contradictory snapshot. An empty/no account is valid `exists=false`, zero RUNE, and nil number/sequence.

`acceptedHeight` is the exact Cosmos REST height from the complete coordinator result: the account request and all balance pages were pinned to it and returned the same `x-cosmos-block-height`. Comet height remains diagnostic only. The accepted snapshot stores this one value in `AccountState.acceptedHeight`; the same value updates `Kit.lastBlockHeight` and `lastBlockHeightPublisher` in the same facade-dispatcher turn as the account, balances, `runeBalance`, and sync state. A publisher callback therefore observes the complete new getter snapshot, never a mixed height.

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
- synchronously close in-memory gate and attempt the persistent generation increment in the control transaction;
- cancel loop task, current request and pending sleep, then await the actor-owned task before the off-dispatcher barrier completes;
- clear `refreshRequested`;
- do not delete persisted/cached state;
- late completion old generation is ignored before save/publication.

If the control transaction fails, the closed gate and actor drain remain in
force; the facade publishes only the sanitized storage-unavailable state after
the drain and never reports durable invalidation as successful. A later start
must successfully advance the durable row before opening a new token.

### Restart

- production composition passes the already-computed S1-01 `persistenceNamespace` into `StorageKey(persistenceNamespace:)`; a new `Kit` with the same S1-01 namespace receives the same key, and S1-05 accepts no wallet/network/preimage initializer for storage identity;
- cache publication additionally requires the stored address and chain ID to equal the active `Address`; namespace equality alone is never sufficient;
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

Within one GRDB write transaction, `saveIfCurrent` first validates the record, then compares `sync_control.generation`; on mismatch, it returns `false` without changing account/balances. On match, it replaces the account and the entire balance set. If the save transaction acquires the writer first, `stop()` waits for it, then increments the generation and only then returns; if stop wins, the CAS save fails. Therefore, a write after stop has returned is impossible. BigUInt is stored as a canonical decimal string bounded to 256 bits. Stored address and `network_chain_id` are integrity fields that must exactly match the active Address before publication; they are not informational metadata. Migration `v1` is idempotent.

### Dependency and iOS-13 gate

S1-05 owns the first product dependency addition for GRDB. The implementation
must add `Package.swift` and `Package.resolved` to the approved change, use
`https://github.com/groue/GRDB.swift.git` with the Horizontal Systems-compatible
6.x requirement and lock GRDB at `6.29.1` (`dd6b98ce04eda39aa22f066cd421c24d7236ea8a`),
and add the `GRDB` product only to the library target that owns the storage.
`Scripts/test-s1-05-dependency-floor.sh` copies the package to a temporary
directory, resolves the committed manifest without rewriting the repository
lock, asserts the exact locked GRDB version/revision, and runs one clean
`xcodebuild -scheme ThorChainKit -destination 'generic/platform=iOS'` build
from that copy with fresh DerivedData and package directories at the iOS-13
deployment floor. Any
resolution or iOS-13 incompatibility is a failed gate and returns this design
for review; the deployment floor is never raised silently.

Storage failure policy: the network result is not published as durably `.synced` when saving is mandatory. `.notSynced(.storageUnavailable, cached: previous)` is required; this prevents a UI success state that would disappear on relaunch.

## State publication

- `AccountStateManager.accept(_:)` is called only inside `LifecycleGate.acceptIfCurrent`'s facade-dispatcher turn, after that turn reconstructs one complete `AccountState` from a validated `StorageRecord`.
- Synchronous getters and Combine subjects are updated on the shared S1-01 facade dispatcher.
- One `StateSnapshot` update carries `AccountState`, `runeBalance`,
  `lastBlockHeight == accountState.acceptedHeight`, and the sync-state/error
  value. The manager mutates all getters first and only then sends the related
  publishers in the pinned order; no individual balance or height update is
  observable between those operations.
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
- `KitLifecycleTests.testStopCompletionWaitsForSuccessAndControlFailureCancellation` runs both a successful stop and a control-transaction failure through the real `Kit.submit` path, proving the ordinary caller returns only after the corresponding barrier and, on failure, after no-token `cancelStop()` drains the old actor work;
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
- reconstructing the same wallet/network key with a different valid address rejects the old row before any cached publication, reports `.storageUnavailable`, then permits a fresh valid record to replace it;
- a row whose `network_chain_id` differs from `activeAddress.network.expectedChainId` is rejected before publication even when its storage key and address match;
- cached amount `2^256 - 1` is accepted, while exact `2^256` is rejected before public BigUInt reconstruction;
- stored `storage_key` is exactly the S1-01 oracle `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`; a guarded factory/source mutant that reconstructs from `walletId` plus `network.persistenceKey` fails the same composition test, and database bytes plus captured logs contain neither the raw wallet ID nor a concatenated/unhashed namespace preimage;
- schema v1 idempotent migration.

`Scripts/test-s1-04-s1-05-isolation.sh` first runs the actual package sources under `-swift-version 5 -strict-concurrency=complete -warnings-as-errors`, including the exact BigInt `5.0.0` temporary-resolution floor. It then makes independent guarded temporary copies: one changes the actual `AccountReading`/`ReadOperationCoordinator` result from `AccountReadTransport` to the frozen non-`Sendable` `AccountState`, and one changes the actual `AccountStateStorage` load/save boundary from `StorageRecord` to `AccountState`. Each mutant must fail compilation with a non-`Sendable` isolation diagnostic. The harness requires one baseline pass and exactly one guarded source transform per copy; a text-only grep does not satisfy this compiler regression.

`KitLifecycleTests.swift`:

- facade getter updated before publisher callback;
- lifecycle methods forward idempotently;
- successful stop and control-failure stop both honor the returned completion barrier;
- current-generation failure ingress preserves cached state and publishes `.notSynced` after getter mutation without `.synced`;
- runeBalance exact `.rune` projection;
- accountExists not inferred from balance error;
- deinit/stop releases owned task (leak sentinel).

### Exact verification protocols

The implementation test names are stable acceptance selectors, not prose
labels. `Scripts/verify-s1-05.sh` runs the following exact focused selectors
against the current implementation head, writes
`artifacts/s1-05/Test.xcresult`, and fails if any selector is missing:

```text
AccountSyncerTests.testRefreshUsesOneCompleteReadAndPublishesOneSnapshot
AccountSyncerTests.testStopRacingSaveEstablishesGenerationAndPublicationBarrier
AccountSyncerTests.testStopControlFailureFailsClosedAndDrainsOldGeneration
AccountSyncerTests.testReentrantStopDoesNotWaitOnFacadeDispatcher
AccountStateStorageTests.testLoadUsesOneConsistentReadSnapshot
AccountStateStorageTests.testInvalidFreshRecordIsRejectedBeforeSave
AccountStateStorageTests.testStorageSaveFailurePublishesStorageUnavailableWithoutSynced
KitLifecycleTests.testLastBlockHeightMatchesAcceptedHeightBeforePublisherDelivery
KitLifecycleTests.testRuneBalanceUsesExactRuneProjection
KitLifecycleTests.testStopCompletionWaitsForSuccessAndControlFailureCancellation
KitLifecycleTests.testCurrentGenerationFailureIngressPreservesCachedState
```

The script first asserts `git rev-parse HEAD` equals `S105_EXPECTED_HEAD`,
asserts the base is
`d35770a0430eee921fa1fe91b2f8812a8c0535ff`, and asserts the changed paths are
within the approved file list. It runs
`xcodebuild test -scheme ThorChainKit -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' -resultBundlePath artifacts/s1-05/Test.xcresult`
plus the focused selectors above, then reads the xcresult summary and requires
every selector to pass. The script never treats a missing result bundle or a
different commit as evidence.

`Scripts/test-s1-05-lifecycle-invariants.sh` is a bounded subprocess protocol:
the baseline build must pass; each of exactly three commands (`duplicate-start`,
`stopped-refresh`, `duplicate-stop`) is run in a fresh temporary copy with a
20-second timeout; each must exit nonzero, write exactly one stable marker
(`S105_INVARIANT_DUPLICATE_START`, `S105_INVARIANT_STOPPED_REFRESH`, or
`S105_INVARIANT_DUPLICATE_STOP`) to stderr, and produce no success marker. A
missing marker, zero exit, timeout, or extra command is failure.

`Scripts/test-s1-04-s1-05-isolation.sh` runs the real package baseline with
`swift test -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`,
then creates two independent temporary copies. Mutant A changes the unique
`AccountReading.read`/coordinator result boundary from `AccountReadTransport`
to frozen `AccountState`; mutant B changes the unique storage `load` and
`saveIfCurrent` record boundary from `StorageRecord` to `AccountState`. Each
transform requires an exact anchor count of one per declared replacement and
must fail compilation with a non-`Sendable` isolation diagnostic. Text grep,
an unmodified baseline, or a transform that touches any other declaration does
not satisfy the gate. The same script invokes the temporary GRDB 6.29.1/iOS-13
resolution floor and records its output.

The Example fixture seam is explicit: `ExampleRuntime.makeFixtureKit()` builds
the real `Kit` composition with `ExampleAccountReadTransport`, the production
`AccountSyncer`, a deterministic `ExampleClock`, and a fixture GRDB database
in the app's Application Support directory. The transport has a visible
request counter, an actor-controlled pending gate, and an offline switch; it
never opens a URL session. The fixture database is retained across app
relaunch and contains no wallet secret. `LifecycleViewModel` observes the
real Kit publishers and never performs a read or owns lifecycle state.

Maestro flow `04-lifecycle-restart.yaml` uses only accessibility-visible state
transitions and the fixture's request counter. It proves start/start
coalescing, stop during pending read, cached/stale relaunch, offline relaunch,
and recovery. A bounded simulator runner records JSONL with schema
`{"slice":"S1-05","head":"<sha>","mode":"fixture","events":[...],"final":{"syncState":"...","acceptedHeight":<int|null>,"lastBlockHeight":<int|null>,"rune":"<decimal>","requestCount":<int>},"passed":true}`;
missing fields, a mismatched head, or a bypassing fixture read is failure.

The live gate is opt-in only: `Scripts/verify-s1-05.sh --live` requires the
operator to provide a public THORNode endpoint through the process environment,
never a committed credential. It emits the same bounded JSON schema with
`mode:"live"`, endpoint family, chain ID, and sanitized accepted height/result;
the mandatory fixture gate remains the only offline acceptance evidence.

### Example/Maestro acceptance

`LifecycleViewModel` observes the kit's Combine publishers and provides `LifecycleView` with only explicit `Start`, `Stop`, and `Refresh` controls plus read-only state/counter diagnostics. It does not duplicate lifecycle admission or snapshot ownership. The Example remains SwiftUI-only and imports no UIKit. Flow `04-lifecycle-restart.yaml`:

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
- The internal S1-01 lifecycle collaborator returns a completion barrier for each effective command and exposes an explicit no-token `cancelStop()` path; `Kit.submit` waits only after leaving the facade dispatcher, while dispatcher-context reentry remains append-and-return with active-turn post-drain.
- Stop/restart/cancellation invariants are proven by deterministic tests.
- Account, balances, and height are saved/published through generation-CAS; the old generation cannot commit after stop has returned.
- Cached, stale, missing-account, zero-RUNE, and error states are distinguishable.
- A cache row is publishable only when its address and chain ID exactly match the active Address; different-address and tampered-chain rows are rejected before snapshot reconstruction.
- One refresh performs one complete bank fetch, regardless of the number of denoms.
- The public facade remains byte-for-byte compatible with S1-01's frozen public models; chain identity stays internal and storage failures use `.storageUnavailable`.
- Current-generation save/transport/decode failures enter through `LifecycleGate.publishFailureIfCurrent(SyncFailure)`, which checks generation plus exact address/chain identity and publishes `.notSynced(error, cached:)` from dispatcher-owned cached state after getter mutation and without `.synced`.
- Reader, synchronizer, and storage isolation boundaries carry only the exact internal `Sendable` decimal-string records; BigUInt-backed `AccountState` is reconstructed on the facade dispatcher, and the actual-source baseline plus both non-`Sendable` boundary mutants prove the transition under the declared compiler flags and BigInt floor.
- Persistence/relaunch and the controlled live read pass.

## Recorded decisions

1. Default foreground polling interval — 60 seconds, bounded failure backoff — 300 seconds.
2. The production factory uses mandatory durable GRDB storage: a save failure is not published as `.synced`. In-memory storage is available only through internal/test injection.

## Discovery-1 blocker closure map

| ID | Resolution in revision 2 | Acceptance evidence |
|---|---|---|
| `S105-ARCH-001` | Gate owns the logical token; actor owns tasks; `sync_control` is the durable CAS authority; start/stop ordering is enumerated. | Generation-race, stop/restart, and stale-save tests. |
| `S105-ARCH-002` | Package/lock files are in scope, GRDB is pinned to 6.29.1, and the temporary iOS-13 resolver/build gate is named. | `Scripts/test-s1-05-dependency-floor.sh` and exact lock assertions. |
| `S105-ARCH-003` | One `StateSnapshot` updates account, RUNE, sync state, and `lastBlockHeight == acceptedHeight` before any publisher. | `KitLifecycleTests.testLastBlockHeightMatchesAcceptedHeightBeforePublisherDelivery`. |
| `S105-SEC-001` | `load` reads control/account/all balances in one GRDB read transaction. | Concurrent load/write old-or-new completeness test. |
| `S105-SEC-002` | Stop closes admission and drains even if durable increment throws; facade maps failure to sanitized storage-unavailable state. | `testStopControlFailureFailsClosedAndDrainsOldGeneration`. |
| `S105-ARCH-004` | Bridge returns a barrier without waiting/callback; external callers wait after dispatcher exit; reentrant calls enqueue and return. | `testReentrantStopDoesNotWaitOnFacadeDispatcher` and FIFO post-drain trace. |
| `S105-ARCH-005` | Fresh record validation precedes save, with storage-side defense in depth. | `testInvalidFreshRecordIsRejectedBeforeSave`. |
| `S105-VOP-001` | Example uses the real Kit with fixture transport, deterministic clock, retained fixture GRDB, and visible controls/counters. | JSONL fixture evidence plus Maestro flow. |
| `S105-VOP-002` | Isolation baseline, exact transforms, compiler flags, and diagnostics are fixed. | Isolation script output and two mutant failures. |
| `S105-VOP-003` | Three fresh subprocess commands, exact markers, timeout, and exit protocol are fixed. | Invariant script output. |
| `S105-VOP-004` | Stable focused selectors, base/head assertions, xcresult path, simulator destination, and changed-file allowlist are fixed. | `Scripts/verify-s1-05.sh` output. |
| `S105-VOP-005` | Fixture and opt-in live JSONL schemas, inputs, retained storage, and fail-closed missing-evidence behavior are fixed. | Fixture mandatory; live only when explicitly enabled. |
| `S105-VOP-006` | Save failure maps to `.notSynced(.storageUnavailable, cached:)` without `.synced` publication. | `AccountStateStorageTests.testStorageSaveFailurePublishesStorageUnavailableWithoutSynced`. |
| `S105-ARCH-006` | Header and all plan references now bind S1-01 revision 12. | Exact `rg`/Git check against canonical S1-01. |
| `S105-ARCH-007` | The S1-01 internal `KitLifecycle` contract now returns `LifecycleCommandBarrier`; `Kit.submit` waits only after dispatcher exit, and `cancelStop()` is the explicit no-token control-failure command. | `KitLifecycleTests.testStopCompletionWaitsForSuccessAndControlFailureCancellation`; changed-path allowlist includes `Core/KitDependencies.swift` and `Core/Kit.swift`. |
| `S105-ARCH-008` | `LifecycleGate.publishFailureIfCurrent(SyncFailure)` is the defined failure ingress; it checks generation/address/chain identity, preserves dispatcher-owned cached state, and orders `.notSynced` publication after getter mutation without `.synced`. | `KitLifecycleTests.testCurrentGenerationFailureIngressPreservesCachedState` plus `AccountStateStorageTests.testStorageSaveFailurePublishesStorageUnavailableWithoutSynced`. |
