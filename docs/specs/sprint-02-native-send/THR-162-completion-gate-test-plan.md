# THR-162 — Test and verification plan

**Revision:** 3 — discovery 1/2; closure 2/5

## Test-first sequence

1. Run the exact S2-07 full-host strict-concurrency build against the unchanged
   package checkout and capture the `EndpointOperationRunner.swift:231`
   diagnostic.
2. Run the same host build with a task-specific disposable package checkout
   containing only the one-line `sending` substitution. Require no
   `EndpointOperationRunner` diagnostic and record the unrelated
   `PendingTransactionRepository.swift:77,92` errors separately.
3. Apply the one-line source correction only after that A/B proof is captured,
   then re-run the focused tests and owned regressions. The isolated `swiftc`
   probe and reduced canaries are informative non-reproduction checks, not a
   substitute for the accepted host proof.
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
