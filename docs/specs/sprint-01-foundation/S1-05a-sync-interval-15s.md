# S1-05a — 15-second foreground sync interval

Status: final design awaiting explicit approval

Branch: `fix/sync-interval-15s`

Base: `origin/main@db6c1d667c61f9778ec2605c0a60ac3be5f02227`

## Goal

Match the verified EvmKit foreground polling cadence by changing the
ThorChainKit production default account-sync interval from 60 seconds to
15 seconds.

Observable success is an immediate refresh on start followed by a new refresh
15 seconds after the preceding refresh completes while the kit remains running.

## Assumptions

- EvmKit is the product-selected primary cadence analog.
- Existing start, stop, foreground, manual-refresh, cancellation, coalescing,
  endpoint failover, `Retry-After`, and intra-operation retry behavior is
  already correct and remains unchanged.
- The existing `failureBackoff` value remains 60 seconds. Removing it or adding
  a new loop-level exponential backoff is outside this correction.
- iOS background execution behavior remains unchanged.

## Scope

Included:

- change `SyncSchedule.default.normalInterval` from `60` to `15`;
- preserve `SyncSchedule.default.failureBackoff` as `60`;
- verify the focused account-sync path and ordinary package tests locally.

Excluded:

- changes to `AccountSyncer.runLoop`;
- changes to `ReadOperationCoordinator`, provider retry, or endpoint failover;
- new timers, retry policies, dependencies, public API, persistence, UI, or
  Unstoppable Wallet changes;
- GitHub Actions test or mutant execution.

## Affected area

Implementation changes exactly one source line:

- `Sources/ThorChainKit/Sync/SyncSchedule.swift`

No production caller, test fixture, package manifest, lockfile, generated file,
or Unstoppable Wallet source is changed.

## Acceptance criteria

1. `SyncSchedule.default` is exactly
   `SyncSchedule(normalInterval: 15, failureBackoff: 60)`.
2. `AccountSyncer.runLoop` continues to consume `schedule.normalInterval`
   without any lifecycle or concurrency change.
3. `ReadOperationCoordinator` retains server `Retry-After`, short retry delay,
   and endpoint-family failover behavior unchanged.
4. Existing tests that inject explicit schedules remain unchanged.
5. Focused and ordinary package tests pass locally on the MacBook.
6. The implementation diff contains only the approved one-line source change.

## Analog delta matrix

| Field | Decision |
|---|---|
| Analog family | Primary: EvmKit `Chain.ethereum` → `ApiRpcSyncer.startTimer`; supporting: ThorChainKit `SyncSchedule.default`, `AccountSyncer.runLoop`, `ReadOperationCoordinator`, and current account-sync tests; rejected counterexample: TronKit 30-second `SyncTimer`. |
| Coverage | EvmKit supplies composition, implementation, and cadence lifecycle. Current ThorChainKit supplies consumer, retry/error boundary, and test coverage. All load-bearing locations were verified with Serena, targeted `rg`, and Git at their recorded heads. |
| Invariants to preserve | Immediate start refresh, periodic loop ownership, stop/cancellation, refresh coalescing, provider retry/failover, persistence, public API, and UI boundaries. |
| Required difference | Change only the production default normal interval from 60 seconds to 15 seconds. |
| Rejected differences | Do not adopt TronKit's 30 seconds; do not add `60 → 120 → 240 → 300` loop backoff; do not rewrite the async loop as a `Timer`; do not alter provider retry. |
| Failure modes | A value other than 15 breaks EvmKit parity. Changing both `60` values would accidentally alter the separate failure setting. Editing the loop could introduce cancellation or overlapping-refresh regressions. |
| Tests before code | Baseline observation: exact current source contains `normalInterval: 60, failureBackoff: 60`; existing account-sync tests inject schedules explicitly and do not assert the production default. |
| Verification | Exact source assertion, focused `AccountSyncerTests`, ordinary `swift test`, `git diff --check`, and diff allowlist against `origin/main`. |

## Test and verification plan

Run locally from the task worktree:

```bash
rg -n -F 'static let `default` = SyncSchedule(normalInterval: 15, failureBackoff: 60)' Sources/ThorChainKit/Sync/SyncSchedule.swift
swift test --filter AccountSyncerTests
swift test
git diff --check
git diff --name-only origin/main...HEAD
```

The final name-only diff must contain the approved spec and
`Sources/ThorChainKit/Sync/SyncSchedule.swift`; the implementation commit itself
must contain only the source file.

## Open questions

None. The user selected EvmKit's 15-second cadence and explicitly limited the
correction to the existing production default.
