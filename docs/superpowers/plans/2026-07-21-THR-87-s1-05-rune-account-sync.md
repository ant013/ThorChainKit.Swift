# THR-87 — S1-05 RUNE account sync implementation plan

**Status:** design revision 3; discovery is frozen at 2/2 and implementation
is blocked until fresh adversarial acceptance and explicit user approval of the
revised spec.

**Spec:** [`docs/specs/sprint-01-foundation/S1-05-rune-account-sync.md`](../../specs/sprint-01-foundation/S1-05-rune-account-sync.md)

**Base:** `origin/main` at `d35770a0430eee921fa1fe91b2f8812a8c0535ff`

**Discovery:** 2/2 frozen. **Closure:** 0/5.

## Goal and boundaries

Connect the merged S1-04 complete account read to an actor-owned, restartable,
persisted RUNE account lifecycle. `Kit.start/refresh/stop` must publish one
atomic account/balance/height snapshot while preventing stale generations from
writing or publishing after stop.

In scope: facade command admission, one-shot and periodic refresh, refresh
coalescing, generation/CAS persistence, cached/stale/fresh/error state,
cancellation, exact `rune` projection, the S1-05 Example lifecycle flow, and
the required deterministic/isolation/public-surface gates.

Out of scope: send/sign/broadcast, sequence reservation, transaction history,
token discovery UI, reachability frameworks, background execution, Unstoppable
Wallet integration, and changes to the frozen S1-01 public model shape.

## Analog spine and invariants

- Primary: TronKit `Syncer` → account state manager → storage/publisher shape;
  its partial-save behavior is explicitly rejected.
- Supporting: EvmKit `RpcBlockchain` only for concurrent account reads; Vultisig
  only for THOR full-bank/native-`rune` evidence and fixtures.
- Rejected: EvmKit `NodeApiProvider` broad recursive URL rotation and mutable
  request state.
- Required corrections: the facade dispatcher/`LifecycleGate` owns the active
  generation token while one `AccountSyncer` actor owns every runtime task;
  `LifecycleCommandBridge` receives only S1-01-filtered ordered commands;
  `LifecycleGate` and storage generation CAS reject stale publication/writes;
  `StorageRecord` is the only async/storage boundary; `AccountState` and
  `BigUInt` are reconstructed on the facade dispatcher.

## Execution steps

### 1. Freeze contracts and red tests

**Owner:** ThorChainSwiftEngineer. **Depends on:** approved spec.

**Paths:** `Tests/ThorChainKitTests/AccountSyncerTests.swift`,
`Tests/ThorChainKitTests/AccountStateStorageTests.swift`,
`Tests/ThorChainKitTests/KitLifecycleTests.swift`, and the S1-05 fixture files.

**Acceptance:** tests cover idempotent facade admission, actor invariant
failures, refresh coalescing, complete-read success/error/cancellation,
generation races, reentrant publication ordering, restart/cache identity,
atomic height publication, stop-control failure, successful-stop and
control-failure completion barriers, current-generation failure ingress with
cached preservation, and exact public-surface compatibility. The new tests are
red before production implementation and preserve the S1-01…S1-04 public
declarations as an exact unchanged subset.

### 2. Implement the isolated storage record and CAS persistence

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 1.

**Paths:** `Package.swift`, `Package.resolved`,
`Scripts/test-s1-05-dependency-floor.sh`,
`Sources/ThorChainKit/Storage/StorageRecord.swift`,
`Sources/ThorChainKit/Storage/AccountStateStorage.swift`,
`Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift`,
`Sources/ThorChainKit/Storage/Migrations.swift`, and
`Sources/ThorChainKit/Sync/SyncGeneration.swift`.

**Acceptance:** one GRDB write transaction replaces the complete
account/balance snapshot only when the expected generation matches; a stale
generation leaves the prior row untouched. One GRDB read transaction returns
the complete control/account/balance record without torn reads. Fresh records
are validated before save and storage repeats validation without mutation. The
storage key accepts only the S1-01 namespace, stores canonical decimal strings
bounded to 256 bits, rejects address/chain identity mismatches before
publication, preserves stale denoms atomically, and has an idempotent v1
migration. The manifest/lock pin GRDB 6.29.1 at revision
`dd6b98ce04eda39aa22f066cd421c24d7236ea8a`, and the dependency-floor script
proves clean resolution and generic iOS compilation at the iOS-13 floor. No
`BigUInt`-backed value crosses an
async or storage boundary.

### 3. Implement the actor-owned lifecycle and publication gate

**Owner:** ThorChainSwiftEngineer. **Depends on:** Steps 1–2.

**Paths:** `Sources/ThorChainKit/Sync/AccountSyncer.swift`,
`Sources/ThorChainKit/Sync/AccountSyncing.swift`,
`Sources/ThorChainKit/Sync/SyncSchedule.swift`,
`Sources/ThorChainKit/Sync/LifecycleCommandBridge.swift`,
`Sources/ThorChainKit/Sync/LifecycleGate.swift`,
`Sources/ThorChainKit/State/AccountStateManager.swift`,
`Sources/ThorChainKit/State/StateSnapshot.swift`, and
`Sources/ThorChainKit/State/StatePublishing.swift`.

**Acceptance:** the facade dispatcher/`LifecycleGate` owns the active
generation token, `sync_control` is its durable CAS authority, and one actor
owns the loop, current request, refresh coalescing, and cancellation. Start
loads cache once, publishes stale/idle state, performs one complete S1-04 read,
and schedules bounded polling. Stop closes admission, attempts the durable
increment, cancels and drains owned work, and returns only after the
publication/write barrier is established; the control-failure path fails
closed. The bridge never waits on or calls back into the facade dispatcher.
The internal S1-01 `KitLifecycle` collaborator returns a
`LifecycleCommandBarrier` for each effective command; `Kit.submit` waits only
after leaving the facade dispatcher, and the control-failure path uses an
explicit no-token `cancelStop()` command rather than a fabricated generation.
`LifecycleGate.publishFailureIfCurrent(SyncFailure)` is the sole current-
generation error ingress; it checks generation, exact address, and chain ID,
preserves the dispatcher-owned cached state, and publishes `.notSynced` after
getter mutation without `.synced`. Account, RUNE, and height are one state
update with `lastBlockHeight` equal to `acceptedHeight`. Old generations
cannot save or publish. Transport, decode, storage, missing-account, zero-RUNE,
and cancellation outcomes remain distinct; cancellation is never surfaced as
a sync error or failover trigger.

### 4. Wire the existing facade and fixture Example

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 3.

**Paths:** `Sources/ThorChainKit/Core/Kit.swift`,
`Sources/ThorChainKit/Core/KitDependencies.swift`,
`Sources/ThorChainKit/Core/KitFactory.swift`,
`iOS Example/Sources/Core/ExampleRuntime.swift`,
`iOS Example/Sources/Presentation/LifecycleViewModel.swift`,
`iOS Example/Sources/Views/LifecycleView.swift`, and
`.maestro/flows/04-lifecycle-restart.yaml`.

**Acceptance:** construction creates only the approved endpoint/read/storage/
lifecycle dependencies and never starts work or polling. Existing S1-01 public
getters/publishers remain compatible; one `StateSnapshot` updates getters before
publisher delivery. `ExampleRuntime.makeFixtureKit()` uses the real Kit with a
fixture transport, deterministic clock, and retained fixture GRDB database;
the fixture transport has controlled pending/offline seams and no URL session.
The flow proves start/start coalescing, stop during a pending request,
cached/stale relaunch, offline relaunch, and fresh recovery without fixed
sleeps or UIKit imports.

### 5. Add isolation, surface, and forbidden-escape verifiers

**Owner:** ThorChainSwiftEngineer. **Depends on:** Steps 2–4.

**Paths:** `Scripts/test-s1-05-lifecycle-invariants.sh`,
`Scripts/test-s1-04-s1-05-isolation.sh`, `Scripts/verify-s1-05.sh`,
`Tests/ThorChainKitTests/Fixtures/S1-05-public-symbols.txt`, and related
fixture baselines.

**Acceptance:** strict-concurrency compilation passes for the actual sources;
the two guarded non-`Sendable` mutants fail for the exact prohibited
boundaries; impossible actor commands fail nonzero with stable markers and
20-second subprocess timeouts; the public graph and production composition
allowlists are exact; no construction path launches requests, tasks, timers,
dispatch sources, or file/network work outside the approved collaborators.

### 6. Verify the exact implementation head

**Owner:** ThorChainSwiftEngineer, then ThorChainCodeReviewer and
ThorChainQAEngineer independently. **Depends on:** Steps 1–5 and explicit
approval of the spec revision.

**Verification order:** syntax/fixture checks; dependency-floor script; the
exact focused selectors named in the spec; `Scripts/test-s1-04-s1-05-isolation.sh`;
full deterministic `ThorChainKitTests`; `Scripts/verify-s1-05.sh`; inherited
S1-01…S1-04 gates; Example build; guarded Maestro fixture flow; explicit
opt-in mainnet read; diff/roadmap audit. `verify-s1-05.sh` requires
`S105_EXPECTED_HEAD`, base `d35770a0430eee921fa1fe91b2f8812a8c0535ff`, the
approved changed-file allowlist, and a passing
`artifacts/s1-05/Test.xcresult`; missing selectors or mismatched heads fail.

**Acceptance:** all deterministic checks are green, the live read records the
endpoint family/chain/height and sanitized result, QA verifies the exact PR
head independently, and no hosted Actions run is used as S1-05 evidence.

### 7. Review, QA, roadmap marker, and merge gate

**Owner:** ThorChainCodeReviewer → ThorChainQAEngineer → ThorChainCTO.
**Depends on:** Step 6.

**Acceptance:** CodeReviewer posts the required Paperclip and GitHub review
checklist with green local/CI evidence; QA posts exact-head live evidence;
only after both gates and clean merge state does the CTO merge. Update the
canonical S1-05 roadmap row only after a real PR number/date exists. No
`Co-authored-by:` trailer and no direct release-branch push.

## Exact verification bindings

The engineer must implement these stable focused selectors and `verify-s1-05.sh`
must run them against `S105_EXPECTED_HEAD` in
`artifacts/s1-05/Test.xcresult`:

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

`test-s1-05-lifecycle-invariants.sh` runs exactly three fresh subprocesses
(`duplicate-start`, `stopped-refresh`, `duplicate-stop`), each with a 20-second
timeout; each exits nonzero and emits its matching `S105_INVARIANT_*` stderr
marker. `test-s1-04-s1-05-isolation.sh` runs the strict-concurrency baseline,
then only the two exact one-anchor replacements described in the spec; both
mutants must fail with a non-`Sendable` diagnostic. Any missing anchor,
additional transform, zero exit, timeout, or text-only check fails.

`ExampleRuntime.makeFixtureKit()` is the real Kit composition with a fixture
transport, deterministic clock, and retained app-sandbox GRDB database. The
transport controls pending/offline responses and counts requests without a URL
session. The fixture/Maestro runner emits bounded JSONL containing `slice`,
`head`, `mode`, `events`, `final.syncState`, `final.acceptedHeight`,
`final.lastBlockHeight`, `final.rune`, `final.requestCount`, and `passed`;
missing fields or a head mismatch is failure. `--live` is opt-in and may only
use an operator-provided public endpoint; no credential is committed.

## Required approval gate

The CodeReviewer must complete plan-first and adversarial review of the linked
spec/plan, resolve all high/critical findings, and bind acceptance to the final
spec digest. The CTO then requests explicit user approval of that exact design
revision. No implementation subtask may begin before that approval.
