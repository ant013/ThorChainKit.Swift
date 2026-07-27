# Gimle reliability report: THR-162-20260727-1125

- Task: dae5f039-b019-4ec0-827a-f9657b8c9b82
- Workflow/phase: analog_change / awaiting_approval
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 162cc3165cfbf1023bcb9c7111cc1d059a2fcded
- Final HEAD: n/a
- Gimle runtime: native-dev
- Indexed commit: n/a

## Metrics

- Calls: 4 (success 1, warning 3, error 0, false-success 0)
- Useful-call rate: 0.0%
- Response-byte coverage: 0/4; total n/a
- Duration coverage: 0/4; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 7
- Analog slices/candidates: 1/9

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.search_code | 0 | 1 | 0 | 0 |
| palace.code.search_graph | 0 | 1 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 0 | 1 | 0 | 0 |

Bug classes: {'mapping_bug': 1, 'coverage_gap': 2, 'environment_drift': 4}
Bug severities: {'high': 4, 'medium': 3}
Bug statuses: {'workaround': 6, 'open': 1}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | reachable | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.get_project_overview | 200 | warning | n/a/0 | n/a | n/a | no | 33297f6293db6631 | unknown_project |
| E-0003 | preflight | palace.code.search_graph | 200 | warning | n/a/0 | n/a | n/a | no | cdbcc501fd163f8a | project_not_found |
| E-0004 | preflight | palace.code.search_code | 200 | warning | n/a/0 | n/a | n/a | no | e49126529d16e235 | project_not_found |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| THR-162-completion-gate | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-THR162-THR152 | C-THR162-GATE, C-THR162-RUNNER, C-THR162-LIFECYCLE, C-THR162-POOL, C-THR162-CONSUMER, C-THR162-TEST, C-THR162-THR152-TEST | C-THR162-EVM-COUNTER |
  - Conflict: THR-152 historical gate correction verifies release-before-resume, while current THR-162 proposes only a transfer-boundary annotation.; resolution: Use THR-152 for lifecycle/race/verification precedent; require a new compiler proof for the narrower sending delta; preserve current source behavior and existing tests.
  - Conflict: EndpointPool actor ownership and EvmKit direct forwarding differ from the lock-owned CompletionGate.; resolution: Keep EndpointOperationRunner/CompletionGate ownership as the spine; use EndpointPool only for delivery boundary support and reject EvmKit as the counterexample.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-THR162-GATE | THR-162-completion-gate | kept | F-THR162-GATE | implementation | responsibility | known_current | Sources/ThorChainKit/Network/EndpointOperationRunner.swift |
| C-THR162-RUNNER | THR-162-completion-gate | supporting | F-THR162-RUNNER | composition | boundary | known_current | Sources/ThorChainKit/Network/EndpointOperationRunner.swift |
| C-THR162-LIFECYCLE | THR-162-completion-gate | supporting | F-THR162-RUNNER | lifecycle_error | lifecycle | known_current | Sources/ThorChainKit/Network/EndpointOperationRunner.swift |
| C-THR162-POOL | THR-162-completion-gate | supporting | F-THR162-POOL | contract | dependencies | known_current | Sources/ThorChainKit/Network/EndpointPool.swift |
| C-THR162-CONSUMER | THR-162-completion-gate | supporting | F-THR162-RUNNER | consumer | state_errors | known_current | Sources/ThorChainKit/Send/Preflight/SendPreflightCoordinator.swift |
| C-THR162-TEST | THR-162-completion-gate | supporting | F-THR162-TESTS | test | tests | known_current | Tests/ThorChainKitTests/Send/Preflight/EndpointOperationRunnerTests.swift |
| C-THR162-EVM-COUNTER | THR-162-completion-gate | rejected | F-THR162-EVM | counterexample | trust | known_current | /Users/ant013/Ios/HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Api/Core/WebSocketRpcSyncer.swift |
| C-THR162-THR152 | THR-162-completion-gate | kept | F-THR162-THR152 | implementation | lifecycle | known_current | docs/reports/gimle/THR-152-s2-02-concurrency-correction-20260724.md |
| C-THR162-THR152-TEST | THR-162-completion-gate | supporting | F-THR162-THR152 | test | tests | known_current | docs/reports/gimle/THR-152-s2-02-concurrency-correction-20260724.md |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-THR162-RUNNER | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | EndpointOperationRunner owns the Sendable generic operation boundary, cancellation/deadline/lifecycle race, orphan-ticket accounting, and the only CompletionGate construction. |
  - Serena: Serena unavailable; command -v serena returned no executable.
  - rg: rg EndpointOperationRunner\|CompletionGate in Sources/ThorChainKit/Network/EndpointOperationRunner.swift at lines 35-102 and 210-231; exact source read confirms one gate construction and four finish paths.
  - Anchors: Sources/ThorChainKit/Network/EndpointOperationRunner.swift:35-102
| F-THR162-GATE | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | CompletionGate serializes exactly-once completion under NSLock, releases its lock before resuming CheckedContinuation, and currently accepts an unconstrained Result<T, Error> in... |
  - Serena: Serena unavailable; command -v serena returned no executable.
  - rg: rg and sed verify private final class CompletionGate<T> at lines 210-231; completed is set under NSLock before continuation.resume(with: result).
  - Anchors: Sources/ThorChainKit/Network/EndpointOperationRunner.swift:210-231
| F-THR162-TESTS | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | EndpointOperationRunnerTests observe cancellation, deadline, lifecycle invalidation, orphan-cap release, and the cancellation/completion race; no test currently asserts strict-c... |
  - Serena: Serena unavailable; command -v serena returned no executable.
  - rg: rg and sed verify EndpointOperationRunnerTests.swift lines 1-220, including testCancellationAndCompletionRaceDoesNotDeadlock at lines 198-220.
  - Anchors: Tests/ThorChainKitTests/Send/Preflight/EndpointOperationRunnerTests.swift:1-220
| F-THR162-POOL | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | EndpointPool is the closest in-repository continuation-delivery analog: an actor stores CheckedContinuation<EndpointLease, Error>, evaluates results, then delivers resume(with:)... |
  - Serena: Serena unavailable; command -v serena returned no executable.
  - rg: rg and sed verify EndpointPool.swift lines 1-208 and Waiter at lines 442-448; deliveries.forEach resumes stored continuations with Result.
  - Anchors: Sources/ThorChainKit/Network/EndpointPool.swift:116-208
| F-THR162-EVM | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | EvmKit WebSocketRpcSyncer forwards success/error callbacks directly into a CheckedThrowingContinuation and is not a safe primary for CompletionGate race ownership. |
  - Serena: Serena unavailable in active ThorChainKit workspace; codebase-memory resolved WebSocketRpcSyncer class but omitted the continuation body.
  - rg: rg and sed verify EvmKit WebSocketRpcSyncer.swift lines 185-196 use direct continuation.resume(returning:) and resume(throwing:) without a gate or orphan accounting.
  - Anchors: /Users/ant013/Ios/HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Api/Core/WebSocketRpcSyncer.swift:185-196
| F-THR162-THR152 | 2 | yes | MATCH | yes | rg | n/a | valid | known_current | THR-152 is the closest in-repository historical CompletionGate correction and verification precedent: it introduced the same gate, corrected release-before-resume ordering, adde... |
  - Serena: n/a
  - rg: sed -n 1,23p docs/reports/gimle/THR-152-s2-02-concurrency-correction-20260724.md; git show 754fcc8 -- Sources/ThorChainKit/Network/EndpointOperationRunner.swift Tests/ThorChainKitTests/Send/Preflight/EndpointOperationRunnerTests.swift
  - Anchors: docs/reports/gimle/THR-152-s2-02-concurrency-correction-20260724.md:1-23; git commit 754fcc8

## Adversarial decisions

- THR162-REV-001@3 ACCEPT: Revision 3 accepts the exact full-host A/B as the causal proof for this slice.
- THR162-REV-002@3 ACCEPT: Revision 3 preserves the package-only S2-06 regression ownership.
- THR162-REV-003@3 ACCEPT: Revision 3 preserves THR-152 as the primary historical CompletionGate analog.

## Verification and acceptance

- THR162-PROOF-EXACT acceptance/passed: Board-accepted exact full-host A/B: baseline log contains EndpointOperationRunner.swift:231; after disposable sending variant contains no EndpointOperationRunner diagnostics. After log separately names PendingTransactionRepository.swift:77:31 and :92:31 as unrelated latent errors.
- THR162-PROOF-CANARY acceptance/failed: Free-function, detached-task, and gate-class canaries all exited 0 before and after; required boundary reproduction unavailable.
- THR162-NO-SOURCE-EDIT verification/passed: No Sources/ or Tests/ files were changed; only approved documentation/evidence commits exist.
- THR162-FOCUSED-TESTS verification/passed: Executed 11 tests with 0 failures; cancellation, deadline, lifecycle, orphan, and completion-race coverage passed.
- THR162-S206-REGRESSIONS verification/passed: Executed 11 tests with 0 failures: 8 BroadcastRetryTests, 1 focused fixture composition test, and 2 SendJournalRestartTests.
- THR162-DIFF-SCOPE verification/passed: Only Sources/ThorChainKit/Network/EndpointOperationRunner.swift is changed by implementation; exact one-line sending annotation.

## Bugs and limitations

### G-001: ThorChainKit code/memory project is not registered in Palace

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0002 / n/a
- Reproduction: Request project overview for Users-ant013-Data-AI-thorchain, then list registered projects.
- Expected: The ThorChainKit project identity is registered and resolves to the active repository.
- Actual: Palace returns unknown_project; registered projects omit Users-ant013-Data-AI-thorchain and git_repos_available omits ThorChainKit.Swift.
- Impact: Gimle cannot provide project-scoped current-tree analog evidence for this slice.
- Workaround: Use codebase-memory for indexed discovery and independently verify all load-bearing facts with the active worktree; retain this limitation in the report.
- Anchors: n/a

### G-002: Codebase-memory index lacks current CompletionGate source

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: codebase-memory / E-0004 / n/a
- Reproduction: Search the ready Users-ant013-Data-AI-thorchain graph by exact CompletionGate name and source pattern.
- Expected: The current source symbol or a current indexed commit is discoverable.
- Actual: Exact search_code returns zero; name search returns unrelated generated/artifact completion symbols, with no ThorChainKit CompletionGate.
- Impact: Indexed discovery cannot establish the current call graph or analog; it may only suggest artifact noise.
- Workaround: Use targeted rg and Git on feature/THR-162-completion-gate-concurrency at origin/main 162cc3165cfbf1023bcb9c7111cc1d059a2fcded.
- Anchors: n/a

### G-003: Required ThorChain workflow and Serena executable are unavailable

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: local-workspace / n/a / n/a
- Reproduction: Resolve paperclips/projects/thorchain/WORKFLOW.md and command -v serena in the assigned workspace.
- Expected: The required workflow file and Serena navigation entrypoint are available.
- Actual: No WORKFLOW.md is present in the instructed workspace/repository and command -v serena returns no executable.
- Impact: The target-local ownership workflow and independent Serena lane cannot be executed verbatim.
- Workaround: Follow the loaded AGENTS.md contract, use exact git/rg verification, and report the missing substrate.
- Anchors: n/a

### G-004: Gimle graph search unavailable for ThorChainKit project

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.code.search_graph / E-0003 / n/a
- Reproduction: Search Palace code graph for CompletionGate scoped to Users-ant013-Data-AI-thorchain.
- Expected: The query returns scoped graph coverage or a coverage envelope for the target project.
- Actual: Palace returns project_not_found for the target project.
- Impact: Gimle graph cannot supply a current analog candidate for this slice.
- Workaround: Use codebase-memory and exact local rg/Git verification; do not treat unrelated artifact matches as analogs.
- Anchors: n/a

### G-005: Strict package gate is blocked by dependency flags and an unrelated baseline concurrency error

- Class/severity/confidence/status: environment_drift / high / confirmed / workaround
- Tool/events/claims: xcodebuild / n/a / n/a
- Reproduction: xcodebuild -scheme ThorChainKit -destination generic/platform=iOS -derivedDataPath /tmp/thr162-strict2-dd -skipPackageUpdates SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete SWIFT_SUPPRESS_WARNINGS=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=NO CODE_SIGNING_ALLOWED=NO build
- Expected: ThorChainKit strict-concurrency compilation reaches the CompletionGate diagnostic or completes
- Actual: The warnings-as-errors invocation stops in dependencies on conflicting -warnings-as-errors and -suppress-warnings flags; the no-suppress fallback reaches ThorChainKit and stops at PendingTransactionRepository.swift:77,92 for captured self. No CompletionGate diagnostic appears in the fallback log.
- Impact: The exact package-level acceptance command and independent diagnostic reproduction are not yet closed; claiming a green strict gate would be false.
- Workaround: Use the issue-provided S2-07 diagnostic as the reproduction premise and require a narrow compiler probe or isolated ThorChainKit compilation before implementation; report package-baseline failures separately.
- Anchors: n/a

### G-006: Exact CompletionGate diagnostic is not reproducible in the isolated Swift 5 probe

- Class/severity/confidence/status: environment_drift / high / confirmed / workaround
- Tool/events/claims: xcrun.swiftc / n/a / n/a
- Reproduction: Run xcrun --sdk iphoneos swiftc -typecheck -parse-as-library -target arm64-apple-ios13.0 -swift-version 5 -strict-concurrency=complete -warn-concurrency -warnings-as-errors on the current EndpointOperationRunner.swift, then repeat after a temporary one-line sending Result<T, Error> substitution.
- Expected: The unchanged source fails at EndpointOperationRunner.swift:231 and the sending variant passes.
- Actual: Both unchanged and sending variants exit 0 with no diagnostic; the package gate instead stops in dependencies or at unrelated PendingTransactionRepository captured-self diagnostics.
- Impact: The proposed one-line delta cannot yet be called compiler-proven; implementation must remain gated by exact A/B evidence or the reduced canary defined in revision 2.
- Workaround: Record the non-reproduction explicitly and require a bounded exact or reduced A/B compiler proof before any source edit.
- Anchors: Xcode 26.6; Apple Swift 6.3.3; current head 430415e

### G-007: Reduced CompletionGate transfer canaries do not reproduce the reported diagnostic

- Class/severity/confidence/status: environment_drift / high / confirmed / open
- Tool/events/claims: xcrun.swiftc / n/a / n/a
- Reproduction: Compile exact-source A/B and reduced generic canaries under Xcode 26.6 Apple Swift 6.3.3: -strict-concurrency=complete -warn-concurrency -warnings-as-errors, with Swift 5 and Swift 6 language modes where applicable.
- Expected: The unconstrained Result<T, Error> transfer into CheckedContinuation.resume(with:) fails before and passes after sending Result<T, Error>.
- Actual: Exact source before=0 after=0; reduced free-function, detached-task, and @unchecked-Sendable gate canaries each before=0 after=0. No diagnostic or source line is produced.
- Impact: The approved sending delta cannot be compiler-proven in this environment. Implementing it would violate the explicit plan gate and could be an unverified change.
- Workaround: Stop without editing product source. Board/CTO must provide the exact failing S2-07 compiler invocation or authorize a new spec revision with a different evidence basis.
- Anchors: Xcode 26.6 / Build 17F113; Apple Swift 6.3.3; current HEAD 6bdc07c

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
