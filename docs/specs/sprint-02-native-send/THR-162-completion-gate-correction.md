# THR-162 — CompletionGate strict-concurrency correction

**Revision:** 2 — discovery 1/2; closure 0/5

## Goal

Make the private `CompletionGate` delivery boundary compile under Swift 5
complete strict concurrency with warnings treated as errors, while preserving
the existing `EndpointOperationRunner` behavior: exactly one continuation
delivery, cancellation/deadline/lifecycle race handling, and orphan accounting.

This is a prerequisite correction for the S2-06 exact-version mirror. It is
limited to `EndpointOperationRunner.swift`, its focused tests if a test change
is proven necessary, and this evidence/specification set.

## Assumptions and evidence

- The approved base is `origin/main` at
  `162cc3165cfbf1023bcb9c7111cc1d059a2fcded`.
- The issue's S2-07 diagnostic identifies the transfer of an unconstrained
  `Result<T, Error>` at `CompletionGate.finish` as the failure. At this head,
  the bounded isolated Swift 5 strict probe passes for both the unchanged
  source and the one-line `sending` variant. The package warnings-as-errors
  invocation stops in dependencies with conflicting
  `-warnings-as-errors`/`-suppress-warnings` flags, and the fallback reaches
  ThorChainKit but stops at the unrelated captured-`self` errors in
  `PendingTransactionRepository.swift:77,92`. The exact issue diagnostic is
  therefore a recorded reproduction premise, not yet a local compiler proof.
- Current-tree inspection confirms that `CompletionGate` is private, is
  constructed only by `EndpointOperationRunner.run`, and is the only owner of
  the checked throwing continuation in that runner. The runner already has a
  `T: Sendable` boundary and releases its lock before resuming.
- THR-152 is the primary historical correction/verification analog: it
  introduced this gate, corrected release-before-resume ordering, and verified
  the cancellation/completion race plus focused callers. Its strict warning
  gate was blocked by upstream dependency diagnostics. The current
  `CompletionGate` source and tests are current-tree supporting evidence;
  `EndpointPool` supplies only a continuation-delivery boundary, and EvmKit
  remains a rejected simpler counterexample.
- The conditional source candidate is `sending Result<T, Error>` on
  `CompletionGate.finish`.
  The public `T: Sendable` constraint remains unchanged. Adding a constraint to
  `CompletionGate` itself is not approved by this specification; it must not be
  used as a substitute for proving the value-transfer boundary.

The source and analog evidence is persisted in
`audit/runs/THR-162-20260727-1125/state.json` and the rendered Gimle report.
Serena is unavailable in this environment and the Palace mapping for this
repository is absent; targeted repository reads and codebase-memory evidence
are therefore explicitly treated as RED trust until the reviewer classifies
the limitation.

## Scope

In scope:

- the smallest proven correction to the `CompletionGate.finish` transfer
  boundary;
- focused `EndpointOperationRunner` race tests and a bounded compiler proof of
  the strict-concurrency diagnostic/correction;
- local strict Swift 5 verification and the package-level S2-06 regressions
  owned by this slice;
- the Gimle reliability report, review, and exact-head handoff.

Out of scope:

- broad concurrency changes, `@unchecked Sendable` changes, `@preconcurrency`,
  warning suppression, dependency/version changes, or changes to
  `EndpointPool`;
- Unstoppable Wallet integration, GitHub Actions, mutants, simulator/Maestro,
  live network checks, and later roadmap slices.

The S2-06 Fixture/Live simulator builds and Maestro flow are not owned by this
prerequisite. The owned regression subset is the package-level fixture
composition test plus the existing `BroadcastRetryTests` and
`SendJournalRestartTests`; no simulator or Maestro result is required for
THR-162 closure.

## Proposed source delta

Change only the private method parameter from:

```swift
func finish(_ result: Result<T, Error>) -> Bool
```

to:

```swift
func finish(_ result: sending Result<T, Error>) -> Bool
```

The candidate is not implementation-approved by this revision. Before source
edit, the implementer must capture either (a) an exact repository A/B probe
that fails before and passes after, or (b) a reduced compiler canary that uses
the same `CompletionGate.finish(Result<T, Error>)` and
`CheckedContinuation.resume(with:)` transfer boundary and fails before while
the `sending` variant passes. If neither proof is reproducible, stop without
changing source and return the spec for another revision. No behavior or
public API change is intended.

## Acceptance criteria

1. A bounded compiler/package command is recorded. Closure requires an exact
   before/after proof as defined above; the already observed isolated probe
   result (exit 0 before and after) must be reported as non-reproduction rather
   than presented as proof.
2. The final source diff is the smallest compiler-proven transfer-boundary
   correction; it contains no suppression, unchecked-conformance, dependency,
   or unrelated concurrency change.
3. Focused `EndpointOperationRunnerTests` remain green, including cancellation,
   deadline, lifecycle, orphan, and completion-race coverage.
4. A local Swift 5 build with complete strict concurrency,
   `-warn-concurrency`, and warnings-as-errors is run for the relevant target;
   no `CompletionGate` diagnostic remains. Any dependency or unrelated
   baseline failure is separately named and does not get hidden.
5. The THR-162-owned S2-06 package regressions pass locally: the focused
   fixture composition test, `BroadcastRetryTests`, and
   `SendJournalRestartTests`. Fixture/Live simulator builds and Maestro remain
   out of scope.
6. The exact verified PR head and evidence are handed to THR-160; merge remains
   the CTO gate after independent CR and QA approval.

## Review questions

- Does `sending` accurately model the one-way transfer into the continuation,
  including both detached-task and watchdog callers?
- Does the private gate remain safe across the existing lock, completion latch,
  and resume-outside-lock ordering?
- If the exact diagnostic remains unreproducible, does the reduced canary
  faithfully preserve the task-isolated-to-continuation transfer boundary?
- Does the changed type boundary alter any focused runtime assertion?
- Are the package/dependency failures clearly separated from the THR-162
  diagnostic so verification cannot be reported as green prematurely?
