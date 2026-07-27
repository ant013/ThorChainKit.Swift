# THR-162 — CompletionGate strict-concurrency correction

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
  `Result<T, Error>` at `CompletionGate.finish` as the failure. The current
  Xcode 26.6 package build could not independently reproduce that diagnostic:
  the warnings-as-errors invocation stops in dependencies with conflicting
  `-warnings-as-errors`/`-suppress-warnings` flags, and the fallback reaches
  ThorChainKit but stops at the unrelated captured-`self` errors in
  `PendingTransactionRepository.swift:77,92`.
- Current-tree inspection confirms that `CompletionGate` is private, is
  constructed only by `EndpointOperationRunner.run`, and is the only owner of
  the checked throwing continuation in that runner. The runner already has a
  `T: Sendable` boundary and releases its lock before resuming.
- The primary candidate is `sending Result<T, Error>` on `CompletionGate.finish`.
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
- focused `EndpointOperationRunner` race tests and a compile-level proof of the
  strict-concurrency diagnostic/correction;
- local strict Swift 5 verification and the S2-06 Example gates required by the
  issue;
- the Gimle reliability report, review, and exact-head handoff.

Out of scope:

- broad concurrency changes, `@unchecked Sendable` changes, `@preconcurrency`,
  warning suppression, dependency/version changes, or changes to
  `EndpointPool`;
- Unstoppable Wallet integration, GitHub Actions, mutants, simulator/Maestro,
  live network checks, and later roadmap slices.

## Proposed source delta

Change only the private method parameter from:

```swift
func finish(_ result: Result<T, Error>) -> Bool
```

to:

```swift
func finish(_ result: sending Result<T, Error>) -> Bool
```

The candidate is accepted only if a strict Swift 5 compiler probe reproduces
the pre-change failure and accepts the post-change source. If the probe does
not establish that result, implementation stops and the specification is
revised before any source change. No behavior or public API change is intended.

## Acceptance criteria

1. A bounded compiler/package command reproduces the reported diagnostic before
   the change and identifies the exact load-bearing source line.
2. The final source diff is the smallest compiler-proven transfer-boundary
   correction; it contains no suppression, unchecked-conformance, dependency,
   or unrelated concurrency change.
3. Focused `EndpointOperationRunnerTests` remain green, including cancellation,
   deadline, lifecycle, orphan, and completion-race coverage.
4. A local Swift 5 build with complete strict concurrency,
   `-warn-concurrency`, and warnings-as-errors is green for the relevant target.
   Any unrelated baseline failure is separately named and does not get hidden.
5. The S2-06 exact-version Example gates required by the issue pass locally.
6. The exact verified PR head and evidence are handed to THR-160; merge remains
   the CTO gate after independent CR and QA approval.

## Review questions

- Does `sending` accurately model the one-way transfer into the continuation,
  including both detached-task and watchdog callers?
- Does the private gate remain safe across the existing lock, completion latch,
  and resume-outside-lock ordering?
- Is a compile-level proof sufficient, or does the changed type boundary alter
  any focused runtime assertion?
- Are the package/dependency failures clearly separated from the THR-162
  diagnostic so verification cannot be reported as green prematurely?

