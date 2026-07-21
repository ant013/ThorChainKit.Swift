# THR-87 — S1-05 RUNE account sync implementation plan

**Status:** design-only; implementation is blocked until the final S1-05 spec
revision receives adversarial acceptance and explicit user approval.

**Spec:** [`docs/specs/sprint-01-foundation/S1-05-rune-account-sync.md`](../../specs/sprint-01-foundation/S1-05-rune-account-sync.md)

**Base:** `origin/main` at `d35770a0430eee921fa1fe91b2f8812a8c0535ff`

**Discovery:** 1/2. **Closure:** 0/5.

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

- Primary: TronKit `Syncer` → account state manager → storage/publisher shape.
- Supporting: EvmKit `RpcBlockchain` only for concurrent account reads; Vultisig
  only for THOR full-bank/native-`rune` evidence and fixtures.
- Rejected: EvmKit `NodeApiProvider` broad recursive URL rotation and mutable
  request state.
- Required corrections: one `AccountSyncer` actor owns every runtime task;
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
generation races, reentrant publication ordering, restart/cache identity, and
exact public-surface compatibility. The new tests are red before production
implementation and preserve the S1-01…S1-04 public declarations as an exact
unchanged subset.

### 2. Implement the isolated storage record and CAS persistence

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 1.

**Paths:** `Sources/ThorChainKit/Storage/StorageRecord.swift`,
`Sources/ThorChainKit/Storage/AccountStateStorage.swift`,
`Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift`,
`Sources/ThorChainKit/Storage/Migrations.swift`, and
`Sources/ThorChainKit/Sync/SyncGeneration.swift`.

**Acceptance:** one GRDB transaction replaces the complete account/balance
snapshot only when the expected generation matches; a stale generation leaves
the prior row untouched. The storage key accepts only the S1-01 namespace,
stores canonical decimal strings bounded to 256 bits, rejects address/chain
identity mismatches before publication, preserves stale denoms atomically, and
has an idempotent v1 migration. No `BigUInt`-backed value crosses an async or
storage boundary.

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

**Acceptance:** one actor owns the loop, current request, refresh coalescing,
and cancellation. Start loads cache once, publishes stale/idle state, performs
one complete S1-04 read, and schedules bounded polling. Stop cancels and drains
owned work, advances generation, and returns only after the publication/write
barrier is established. Old generations cannot save or publish. Transport,
decode, storage, missing-account, zero-RUNE, and cancellation outcomes remain
distinct; cancellation is never surfaced as a sync error or failover trigger.

### 4. Wire the existing facade and fixture Example

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 3.

**Paths:** `Sources/ThorChainKit/Core/Kit.swift`,
`Sources/ThorChainKit/Core/KitFactory.swift`,
`iOS Example/Sources/Presentation/LifecycleViewModel.swift`,
`iOS Example/Sources/Views/LifecycleView.swift`, and
`.maestro/flows/04-lifecycle-restart.yaml`.

**Acceptance:** construction creates only the approved endpoint/read/storage/
lifecycle dependencies and never starts work or polling. Existing S1-01 public
getters/publishers remain compatible; getter state is updated before publisher
delivery. The fixture flow proves start/start coalescing, stop during a pending
request, cached/stale relaunch, offline relaunch, and fresh recovery without
fixed sleeps or UIKit imports.

### 5. Add isolation, surface, and forbidden-escape verifiers

**Owner:** ThorChainSwiftEngineer. **Depends on:** Steps 2–4.

**Paths:** `Scripts/test-s1-05-lifecycle-invariants.sh`,
`Scripts/test-s1-04-s1-05-isolation.sh`, `Scripts/verify-s1-05.sh`,
`Tests/ThorChainKitTests/Fixtures/S1-05-public-symbols.txt`, and related
fixture baselines.

**Acceptance:** strict-concurrency compilation passes for the actual sources;
the two guarded non-`Sendable` mutants fail for the exact prohibited
boundaries; impossible actor commands fail nonzero with stable markers; the
public graph and production composition allowlists are exact; no construction
path launches requests, tasks, timers, dispatch sources, or file/network work
outside the approved collaborators.

### 6. Verify the exact implementation head

**Owner:** ThorChainSwiftEngineer, then ThorChainCodeReviewer and
ThorChainQAEngineer independently. **Depends on:** Steps 1–5 and explicit
approval of the spec revision.

**Verification order:** syntax/fixture checks; focused sync/storage/lifecycle
tests; `Scripts/test-s1-04-s1-05-isolation.sh`; full deterministic
`ThorChainKitTests`; `Scripts/verify-s1-05.sh`; inherited S1-01…S1-04 gates;
Example build; guarded Maestro fixture flow; explicit opt-in mainnet read;
diff/roadmap audit.

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

## Required approval gate

The CodeReviewer must complete plan-first and adversarial review of the linked
spec/plan, resolve all high/critical findings, and bind acceptance to the final
spec digest. The CTO then requests explicit user approval of that exact design
revision. No implementation subtask may begin before that approval.
