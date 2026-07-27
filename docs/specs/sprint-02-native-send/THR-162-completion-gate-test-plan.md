# THR-162 — Test and verification plan

**Revision:** 2 — discovery 1/2; closure 0/5

## Test-first sequence

1. Run the bounded strict Swift 5 compiler probe/package command against the
   current source. Capture the exact diagnostic if present; otherwise record
   the observed non-reproduction and the dependency/unrelated baseline stop.
2. If the exact source diagnostic is absent, run a reduced canary preserving
   `CompletionGate.finish(Result<T, Error>)` and
   `CheckedContinuation.resume(with:)`. It must fail before and pass after the
   `sending` annotation. If it cannot do so, stop before source edit.
3. Apply the one-line source correction only after one of those A/B proofs is
   captured, then re-run the same proof and require no relevant diagnostic.
4. Run the focused `EndpointOperationRunnerTests` suite. Require the existing
   cancellation/deadline/lifecycle/orphan and completion-race assertions to
   remain green; add no runtime test unless the approved source delta changes
   observable behavior.
5. Run only the THR-162-owned S2-06 package regressions: the focused fixture
   composition test, `BroadcastRetryTests`, and `SendJournalRestartTests`.
   Do not run simulator builds or Maestro in this slice.

## Required evidence

- exact command lines, Swift/Xcode version, and diagnostic before/after;
- `git diff --check` and a path-limited diff proving scope;
- focused test output with the summary line;
- local strict target/build output with no hidden warning suppression;
- S2-06 package-regression output; simulator/Maestro are explicitly unrun;
- exact PR head for CR, QA, and CTO merge review.

## Stop conditions

- The primary `sending` candidate is not compiler-proven: stop and request a
  spec revision before changing source.
- Verification is blocked by the known dependency flag conflict or unrelated
  baseline error: report the exact blocker and continue only with a narrower
  compiler proof that preserves the acceptance claim.
- Any runtime race, orphan count, or continuation-delivery behavior changes:
  stop and return to design review.
