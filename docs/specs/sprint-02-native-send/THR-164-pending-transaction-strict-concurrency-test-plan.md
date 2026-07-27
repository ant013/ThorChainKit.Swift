# THR-164 — Test plan

**Revision:** 1

## Tests before implementation

1. Add a focused `PendingTransactionRepositoryTests` case using
   `TestObservationSource` that releases the repository while the source
   retains both callbacks, asserts the repository deallocates, and then emits
   callbacks to prove weak no-op behavior.
2. Keep the existing `testObservationPublishesCommittedTransition` and
   `testObservationAcknowledgesBroadcastingGeneration` as change-publication
   and barrier contracts.
3. Keep
   `testObservationErrorRejectsStaleCallbackAndInstallsReplacement` as the
   generation/error/reinstall contract, including the stale callback after the
   first source is replaced.
4. Keep `testRefreshFailurePreservesLastSnapshotAsDegraded` as the cached-state
   failure contract.

## Verification sequence

1. Run the focused test target/filter for `PendingTransactionRepositoryTests`.
2. Run a bounded Swift 5 complete-concurrency probe with warnings treated as
   errors against the two callback forms; record the diagnostic lines before
   and after.
3. Run the canonical Xcode 26.6 ThorChainKit host compilation from the THR-160
   Development configuration. Require the baseline to contain lines 77/92 and
   the corrected build to contain neither named diagnostic.
4. Run the directly affected ThorChainKit pending/send lifecycle test subset.
5. Audit `git diff --stat`, exact changed lines, and all residual diagnostics;
   do not expand scope for unrelated failures.

## Non-goals

No live transaction, simulator, Maestro, mutation, dependency, or hosted CI
verification is part of this slice.
