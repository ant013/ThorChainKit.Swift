# THR-164 — PendingTransactionRepository strict-concurrency correction

**Revision:** 1 — discovery 1/2; closure 0/5

## Goal

Remove the two Swift complete-concurrency diagnostics reported at
`PendingTransactionRepository.swift:77` and `:92` in the canonical ThorChainKit
host build, with the smallest behavior-preserving capture-boundary correction.

## Evidence and assumptions

- The approved base is `origin/main` at
  `922a5badac5a9b80361a02dff5c75711f00da53c`.
- The canonical host reproduction is recorded in the issue evidence log
  `/tmp/thr160-s207-post-6172.hAp2js/xcodebuild-canonical-board-frozen.log`.
  It reaches ThorChainKit compilation and reports only the two named
  `PendingTransactionRepository.installObservation()` captured-`self`
  diagnostics for this prerequisite.
- Current source lines 70–107 increment and compare an observation generation,
  cancel the previous observation, dispatch changes/errors to the serial
  `stateQueue`, acknowledge/fail the publication barrier, publish status, and
  reinstall after a current-generation error. The two inner async closures are
  the only source lines in scope.
- Current focused tests cover projection, degraded cached-state behavior,
  committed observation publication, publication-barrier acknowledgement, and
  stale-callback rejection followed by replacement recovery.
- `KitFactory` and `SendRuntime` compose and consume the repository with a
  shared `PendingPublicationBarrier`; no composition or public API change is
  allowed.
- EvmKit's current `WebSocketRpcSyncer` uses explicit `[weak self]` capture on
  dispatched closures and is a syntax supporting analog only. ThorChainKit's
  `AccountSyncer` strong-binds `self` inside a concurrent task and is rejected
  for this slice because weak deallocation must remain observable.
- Serena is unavailable and Palace/Gimle has no registered ThorChainKit
  project. Targeted `rg`, narrow source reads, Git history, and
  codebase-memory are the independent evidence fallback; Gimle trust remains
  RED and the mapping defect is recorded in the run state/report.

## Scope

In scope:

- `Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift`;
- the smallest focused regression test needed to prove weak deallocation at
  the observation callback boundary;
- the strict Swift 5 compiler probe and canonical Xcode 26.6 ThorChainKit
  host compilation;
- focused pending/lifecycle tests and the required evidence/spec/review/QA
  artifacts.

Out of scope:

- broad concurrency migration, `@unchecked` or `@preconcurrency` additions,
  warning suppression, dependency changes, public API changes, or lifecycle
  redesign;
- Unstoppable application source, live transactions, GitHub Actions, mutants,
  simulator/Maestro acceptance, and unrelated diagnostics that appear after
  these two errors are removed.

## Proposed source delta

Keep the outer callbacks weak and make the dispatched closure's capture
boundary explicit without binding `self` strongly before the asynchronous
boundary. The implementer must probe the smallest syntax that compiles under
the exact strict-concurrency settings; the likely candidate is an explicit
`[weak self]` capture on each inner `stateQueue.async` closure. The final choice
must preserve:

- weak repository lifetime when the observation source retains callbacks;
- all repository state mutation on `stateQueue`;
- the `observationGeneration == generation` guard for both change and error;
- broadcasting-generation barrier acknowledgement/failure;
- degraded status and replacement observation after current-generation error;
- the existing public API and retry/reinstall behavior.

No source edit is authorized until this revision receives explicit approval.
## Acceptance criteria

1. The canonical host reproduction remains the exact baseline and identifies
   lines 77 and 92 before the correction.
2. The final source diff is limited to the two callback capture boundaries and
   contains no suppression, unchecked-conformance, dependency, or unrelated
   concurrency change.
3. Focused pending/lifecycle tests pass, including the existing generation,
   degraded/reinstall, publication-barrier, and committed-transition tests,
   plus a weak-deallocation regression if required to distinguish the safe
   capture from a strong pre-boundary bind.
4. A Swift 5 complete-concurrency, warnings-as-errors probe and the canonical
   Xcode 26.6 ThorChainKit host compilation no longer report the two named
   lines. Any unrelated diagnostic is reported separately.
5. The exact verified merge SHA is handed to THR-160 so it can update its four
   local pin locations and resume the same warmed S2-07 Development build.

## Review questions

- Does the selected capture list remove the diagnostic without retaining the
  repository through an outstanding observation callback?
- Are both callbacks still serialized on `stateQueue`, including generation
  filtering before any barrier, subject, or reinstall mutation?
- Does the error callback preserve the current-generation failure/reinstall
  path and reject stale callbacks exactly as before?
- Does the regression test fail for a strong pre-boundary capture and pass for
  the accepted weak boundary?
- Can the same compiler result be achieved with fewer changed lines?
