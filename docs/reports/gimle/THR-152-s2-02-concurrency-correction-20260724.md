# THR-152 S2-02 Concurrency and Codec Provenance Correction

## Binding

- Slice: S2-02 height-pinned send preflight only; no S2-03 work.
- Correction: release `CompletionGate` before resuming its continuation, and add a bounded cancellation/completion race regression.
- Closure: discovery 0/2; closure 3/5.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Swift syntax parse | PASS | `swiftc -parse Sources/ThorChainKit/Network/EndpointOperationRunner.swift Tests/ThorChainKitTests/Send/Preflight/EndpointOperationRunnerTests.swift` exited 0. |
| Diff whitespace | PASS | `git diff --check` exited 0. |
| Bounded race regression | PASS | `testCancellationAndCompletionRaceDoesNotDeadlock`, 1/1, `/tmp/thr152-focused.lDhXB3/Regression-correction.xcresult`. |
| Focused classes | PASS | `EndpointOperationRunnerTests` + `SendPreflightCoordinatorTests`, 21/21, `/tmp/thr152-focused.lDhXB3/Focused-correction-no-flags.xcresult`. |
| Full `ThorChainKitTests` | PASS | 208/208 with `testDuplicateStart`, `testStoppedRefresh`, and `testDuplicateStop` skipped, `/tmp/thr152-focused.lDhXB3/Ordinary-correction-no-flags.xcresult`. |
| Codec determinism and provenance | PASS | `Scripts/generate-query-codec.sh`; Xcode 26.3 build `17C529`, Apple Swift 6.2.4, plugin SHA-256 `e5908e3c8d1504ca39ad14c38503b313a84b87def21d5f7dc4d0ce4e3709b8e0`. |
| Warning-flag full gate | BLOCKED BY UPSTREAM DIAGNOSTICS | With `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO`, Xcode 26.3 promotes six existing `swift-crypto` `_CryptoExtras` `@_implementationOnly` diagnostics to errors before tests; `/tmp/thr152-focused.lDhXB3/ordinary-correction-warning-flags.log`. |

## Gimle trust and limitations

Trust remains **YELLOW**. Codebase-memory was queried first but did not expose `CompletionGate`; Serena and targeted `rg` verified the current-tree implementation and test call sites. The warning-flag limitation is confined to the checked-out upstream dependency and does not waive the requested flags; the ordinary gate was also run with both flags retained and recorded as blocked before XCTest execution.
