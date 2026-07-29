# S3-01 — Tron-style account and sync storage

**Status:** proposed revision 1  
**Branch:** `feature/storage-analog-conformance`  
**Base:** `origin/main` at `61544c4`

## Goal

Replace the account/sync half of the current monolithic persistence seam with
the same ownership shape used by TronKit:

```text
Kit.instance
  -> SyncerStorage + AccountInfoStorage
  -> AccountInfoManager + Syncer
  -> Kit synchronous state and publishers
```

The observable result is that account state and sync checkpoints are held by
purpose-named storages, directly composed by `Kit.instance`, instead of by
`GrdbAccountStateStorage`, `LifecycleGate`, and a shared storage façade.

## Evidence and analog family

| Role | Selected evidence | Why it is used |
|---|---|---|
| Primary storage spine | TronKit `SyncerStorage` and `AccountInfoStorage` | Private `DatabasePool`, local migrator, `databaseDirectoryUrl`/`databaseFileName` initializer, synchronous purpose-named accessors. |
| Composition | TronKit `Kit.instance` | Directly creates `syncer-state-storage-<id>`, `account-info-storage-<id>`, and `transactions-storage-<id>`, then injects them into domain managers. |
| Independent support | EvmKit `TransactionSyncerStateStorage` | Confirms that state checkpoint storage is a purpose-specific collaborator rather than a global runtime service. |
| Tests | Current account-storage and Kit composition tests | They identify the existing snapshot, lifecycle, and factory behavior that must be replaced with direct storage tests. |
| Rejected counterexample | Current `DatabaseRuntime` + `GrdbAccountStateStorage` | A process-wide writer registry and a generic record store are not the selected kits' storage/composition pattern. |

The verified revisions are TronKit `aa691bcd` and EvmKit `be028631`.
Gimle/Palace located the candidates, but its project-freshness metadata is
incomplete; all selected facts were checked in the corresponding Git trees.

## Assumptions

- There are no released ThorChainKit clients and no cache that must be
  migrated. Existing development cache files may be discarded.
- `Kit.instance` receives a stable wallet/network namespace and Unstoppable
  owns one active Kit instance for that namespace. This slice does not add a
  second cross-instance registry for account/sync databases.
- The existing SHA-256 namespace remains the filename suffix. Raw wallet IDs
  must not appear in any database filename.
- Cosmos send reservation, signed bytes, and journal transitions remain in the
  existing send database for this slice. Their single database transaction is
  not split or otherwise changed here.

## Scope

### In scope

1. Add internal `SyncerStorage` and `AccountInfoStorage` in
   `Sources/ThorChainKit/Storage`.
2. Give each storage the selected-kit shape:
   `init(databaseDirectoryUrl:databaseFileName:)`, a private pool, a local
   migrator, and methods named for the state they persist.
3. Store only sync checkpoints in `SyncerStorage` and only account/balance
   snapshots in `AccountInfoStorage`.
4. Replace `GrdbAccountStateStorage`, `AccountStateStorage`, `StorageKey`, and
   generic `StorageRecord` plumbing where it exists solely to support the
   account/sync cache.
5. Replace the account/sync use of `LifecycleGate` and
   `LifecycleCommandBridge` with a directly owned `Syncer` lifecycle. Keep an
   in-memory stale-result generation only where async THOR reads require it;
   it is not persisted and is not a second façade queue.
6. Rename `AccountStateManager` to `AccountInfoManager` and make it the
   in-memory owner/publisher of the loaded account state and RUNE balance.
7. Compose both storages visibly in `Kit.instance` and the fixture factory,
   using `syncer-state-<hashed-namespace>` and
   `account-info-<hashed-namespace>` database names.
8. Replace the affected unit tests with direct storage, manager, syncer, and
   factory-contract tests.

### Explicitly out of scope

- `SendRuntime`, `SendJournal`, `SequenceReservationStore`, pending
  transactions, broadcast/retry, and their existing database transaction.
- A `TransactionStorage` refactor. That follows in the transaction/history
  slice, when its complete sender/consumer family is changed together.
- A production migration, cache import, rollback path, or compatibility shim.
- A new database opener/alias registry, lifecycle façade queue, teardown
  mechanism, or test-only safety abstraction not present in the selected
  analogues.
- Network endpoint/provider behavior and Unstoppable adapter changes.

## Required design

### Storage responsibilities

| Type | Owns | Required API style | Must not own |
|---|---|---|---|
| `SyncerStorage` | last accepted block/read checkpoint and any sync cursor metadata that is currently cache state | `lastBlockHeight`, `save(lastBlockHeight:)`, and explicit cursor/checkpoint accessors | account balances, account sequence, send journal, lifecycle command dispatch |
| `AccountInfoStorage` | account existence, account number, sequence, balances, accepted height, provider ID, and observation time | `accountInfo`, `save(accountInfo:)`, and account/balance-named accessors | sync timer/lifecycle commands, endpoint selection, send reservations |
| `AccountInfoManager` | loaded in-memory account state and its Combine publication | direct manager state/read access in the same style as TronKit's account manager | SQL, endpoint reads, timer ownership |
| `Syncer` | start, stop, refresh, read scheduling, cancellation, and stale async-result rejection | direct `start()`, `stop()`, and `refresh()` lifecycle | generic façade command bridging or public persistence records |

`AccountInfoStorage` commits the complete account snapshot (account fields,
balances, accepted height, provider family, observation time) in one database
transaction. A refresh may publish only after that write succeeds. The syncer
keeps its active in-memory generation solely to reject a completion belonging
to a stopped or superseded asynchronous read.

The two account/sync files are intentionally independent, as in TronKit. No
operation in this slice needs an atomic transaction spanning them. The existing
send journal remains on its existing writer precisely because its reservation
and journal state do need one transaction.

### Factory and lifecycle

`Kit.instance` and `Kit.fixture` derive the existing hashed namespace once,
obtain the database directory, then construct named account/sync storages
directly. The factory visibly constructs `AccountInfoManager`, `Syncer`, and
the read/provider collaborators. `Kit.start()`, `stop()`, and `refresh()`
delegate directly to the syncer; no `LifecycleGate` or
`LifecycleCommandBridge` remains on this path.

The send runtime may continue to use its current writer in this slice. That is
an explicitly bounded transitional difference, not a reason to inject that
writer into account/sync storage.

### Error behavior

TronKit commonly treats local storage failures as fatal (`try!`). This Kit
already exposes async sync errors, so storage failures remain explicit and are
published as the existing storage-unavailable sync failure. No error is hidden,
and no new error taxonomy is added.

## Delta matrix

| Slice | Analog family | Invariants to preserve | Required delta | Rejected delta | Tests before code | Verification |
|---|---|---|---|---|---|---|
| S3-01-A storage | TronKit `SyncerStorage` + `AccountInfoStorage`; EvmKit transaction-sync state storage | private pool, local migration, purpose-named methods/files | THOR account snapshot fields and throwing errors | generic `StorageRecord`, raw wallet filename, migration shim | independent account and sync storage round trips; atomic account snapshot | focused XCTest storage classes |
| S3-01-B state/lifecycle | TronKit account manager + syncer lifecycle | manager owns published state; syncer owns start/stop/refresh | in-memory generation rejects late async THOR reads | persisted façade generation, command bridge, second dispatcher | stop/restart/late-result tests; storage-failure publication | focused syncer/lifecycle XCTest classes |
| S3-01-C composition | TronKit `Kit.instance`; EvmKit `Kit` storage setup | readable direct construction and hashed filename suffix | retain current namespace derivation and fixture injection | account/sync `DatabaseRuntime`, alias barrier, raw wallet ID filename | factory creates expected named files and retains direct lifecycle path | factory XCTest + public API check |

## Affected areas

- `Sources/ThorChainKit/Core/KitFactory.swift`
- `Sources/ThorChainKit/Core/Kit.swift` and dependency composition as required
- `Sources/ThorChainKit/Storage/` (replace account/sync storage implementation)
- `Sources/ThorChainKit/State/AccountStateManager.swift`
- `Sources/ThorChainKit/Sync/AccountSyncer.swift`, lifecycle collaborators, and
  scheduling only where required by direct syncer ownership
- focused tests currently named `AccountStateStorageTests`, `AccountSyncerTests`,
  `KitLifecycleTests`, and `KitCompositionTests`

`Sources/ThorChainKit/Send/**` is not modified except for compilation-only
dependency adjustments that are demonstrably required by the removed account
storage injection.

## Acceptance criteria

1. Account and sync persistence have separate, internal, purpose-named types
   and separate hashed database filenames.
2. `Kit.instance`/fixture compose those types directly; account/sync creation
   does not receive `DatabaseRuntime.pool`.
3. `AccountInfoStorage` atomically restores the complete accepted account
   snapshot, including balances and read provenance.
4. `SyncerStorage` alone owns persisted sync checkpoint/cursor data.
5. `AccountInfoManager` is the only in-memory account-state publisher and
   `Syncer` is the direct lifecycle owner for account refresh.
6. A stopped or superseded async read cannot save or publish after a later
   generation, and storage errors preserve the existing sync failure contract.
7. The send journal/reservation transaction remains unchanged and all existing
   focused send storage tests still pass.
8. No storage migration/import/compatibility code or new global account/sync
   database registry is introduced.

## Verification plan

Run, in order:

1. `swift test --filter AccountInfoStorageTests`
2. `swift test --filter SyncerStorageTests`
3. `swift test --filter AccountSyncerTests`
4. `swift test --filter KitLifecycleTests`
5. `swift test --filter KitCompositionTests`
6. `swift test --filter SendJournalOrderingTests`
7. `swift test --filter SendJournalRestartTests`
8. the repository's existing public API and package verification command after
   the focused tests are green.

The implementation review additionally compares every changed file against the
delta matrix. Tests asserting account/sync `DatabaseRuntime` alias sharing are
removed rather than retained as a non-analogue requirement; send-runtime tests
remain unchanged.

## Adversarial review

- **Primary coherence:** TronKit remains the storage/lifecycle spine. EvmKit
  only confirms the separate checkpoint-store pattern; it does not redefine
  THOR account semantics.
- **Dangerous counterexample:** retaining `DatabaseRuntime` for account/sync
  would preserve the global-registry architecture the change is meant to
  remove. It is rejected for this path.
- **Protocol difference:** THOR reads are asynchronous and may complete after
  cancellation, so one in-memory generation check is retained in `Syncer`.
  This is a necessary transport difference, not an extra public subsystem.
- **Atomicity:** no account/sync operation crosses into the send journal; the
  existing send transaction is deliberately outside the change.
- **Smaller alternative rejected:** merely renaming `GrdbAccountStateStorage`
  would retain its mixed responsibility and writer injection, so it would not
  meet the selected analogue's ownership or composition shape.

## Open questions

None for this slice. Transaction/pending storage ownership is intentionally
deferred to its own analog-driven slice.
