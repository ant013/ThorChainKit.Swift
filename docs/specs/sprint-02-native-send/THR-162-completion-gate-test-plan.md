# THR-162 — Test and verification plan

## Test-first sequence

1. Run the bounded strict Swift 5 compiler probe/package command against the
   current source and capture the reported `CompletionGate` diagnostic. Check:
   the failure is at the continuation transfer, not a dependency or unrelated
   baseline error.
2. Apply the one-line approved source correction only after the probe is
   captured.
3. Re-run the same probe and require no `CompletionGate` strict-concurrency
   diagnostic.
4. Run the focused `EndpointOperationRunnerTests` suite. Require the existing
   cancellation/deadline/lifecycle/orphan and completion-race assertions to
   remain green; add no runtime test unless the approved source delta changes
   observable behavior.
5. Run the relevant local S2-06 Example gates, then record any unrelated
   baseline failure separately with its exact command and output.

## Required evidence

- exact command lines, Swift/Xcode version, and diagnostic before/after;
- `git diff --check` and a path-limited diff proving scope;
- focused test output with the summary line;
- local strict target/build output with no hidden warning suppression;
- S2-06 Example gate output;
- exact PR head for CR, QA, and CTO merge review.

## Stop conditions

- The primary `sending` candidate is not compiler-proven: stop and request a
  spec revision before changing source.
- Verification is blocked by the known dependency flag conflict or unrelated
  baseline error: report the exact blocker and continue only with a narrower
  compiler proof that preserves the acceptance claim.
- Any runtime race, orphan count, or continuation-delivery behavior changes:
  stop and return to design review.

