# Gimle reliability report: THR-32-swiftui-reconciliation-595122b8

- Task: THR-32
- Workflow/phase: analog_change / adversarial_review
- Trust: **YELLOW**
- Repository: `ThorChainKit.Swift`
- Base HEAD: 28c2852cbcf194971b755cc52c911ebd94890b3f
- Final HEAD: n/a
- Gimle runtime: 0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: n/a

## Metrics

- Calls: 8 (success 5, warning 3, error 0, false-success 0)
- Useful-call rate: 25.0%
- Response-byte coverage: 0/8; total n/a
- Duration coverage: 0/8; total n/a ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 1/1
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 3
- Analog slices/candidates: 1/6

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.code.semantic_search | 1 | 1 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 2 | 0 | 0 | 0 |
| palace.memory.health | 0 | 1 | 0 | 0 |
| palace.memory.list_projects | 0 | 1 | 0 | 0 |

Bug classes: {'mapping_bug': 1, 'coverage_gap': 1, 'caller_error': 1}
Bug severities: {'medium': 2, 'low': 1}
Bug statuses: {'workaround': 3}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | ok | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.health | ok | warning | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | Palace is healthy but exposes no thorchain memory or git project mapping; only external analog projects are available |
| E-0003 | preflight | palace.memory.list_projects | ok | warning | 18/18 | n/a | n/a | no | 44136fa355b3678a | No ThorChainKit project exists; registered analog projects report unknown freshness despite some indexed commits |
| E-0004 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 04799ff4fb4e3a8b | n/a |
| E-0005 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 4282f54d43bbb349 | n/a |
| E-0006 | preflight | palace.code.list_passthrough_projects | ok | success | n/a/7 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0007 | evidence | palace.code.semantic_search | ok | warning | 0/0 | n/a | n/a | no | f1a640c7fcb2449f | Caller supplied unsupported application source scope; payload reports project/dependency scopes and zero candidate population |
| E-0008 | evidence | palace.code.semantic_search | ok | success | 0/0 | n/a | n/a | no | 93f38a6be8db22c6 | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S102-UI-RECONCILE | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-MAIN-PLATFORM | C-S102-ENDPOINT, C-PLATFORM-GATE, C-TRON-TOPOLOGY | C-TRON-UIKIT, C-PR-UIKIT |
  - Conflict: The reviewed product head implements EndpointsController on the legacy UIKit lifecycle while current main requires EndpointsViewModel and SwiftUI views.; resolution: Preserve endpoint actors, SPI, diagnostics, fixtures, and acceptance unchanged; add the already-approved S1-01 migration prerequisite and implement all Example presentation through SwiftUI plus Combine.
  - Conflict: TronKit supplies the verified workspace topology but also demonstrates forbidden UIKit lifecycle ownership.; resolution: Carry over only xcodeproj/shared-scheme/workspace/root-package topology; reject AppDelegate, UIWindow, controllers, demo secrets, and lifecycle ownership.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-MAIN-PLATFORM | S102-UI-RECONCILE | kept | F-MAIN-UI-BOUNDARY | composition, consumer, contract, lifecycle_error | boundary, dependencies, lifecycle, responsibility, trust | known_current | docs/specs/platform/swiftui-combine-ui-boundary.md |
| C-S102-ENDPOINT | S102-UI-RECONCILE | supporting | F-S102-ENDPOINT-SPINE | consumer, implementation, lifecycle_error, test | lifecycle, responsibility, state_errors, tests, trust | known_current | docs/specs/sprint-01-foundation/S1-02-network-endpoint-policy.md |
| C-PLATFORM-GATE | S102-UI-RECONCILE | supporting | F-PLATFORM-TEST-GATE | test | tests, trust | known_current | docs/roadmap/sprint-01-foundation.md |
| C-TRON-TOPOLOGY | S102-UI-RECONCILE | supporting | F-TRON-TOPOLOGY-ONLY | composition | boundary, dependencies | known_current | iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata |
| C-TRON-UIKIT | S102-UI-RECONCILE | rejected | F-TRON-TOPOLOGY-ONLY | counterexample, implementation, lifecycle_error | lifecycle, trust | known_current | iOS Example/Sources/AppDelegate.swift |
| C-PR-UIKIT | S102-UI-RECONCILE | rejected | F-PR-UIKIT-COUNTEREXAMPLE | composition, consumer, counterexample, implementation | boundary, dependencies, lifecycle, trust | known_current | iOS Example/Sources/AppDelegate.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-MAIN-UI-BOUNDARY | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Current main requires a SwiftUI App lifecycle, SwiftUI views, Combine-backed observation, no UIKit in library or Example, library iOS 13, and Example iOS 14 or later. |
  - Serena: Exact target workspace search found the normative boundary and S1-02 EndpointsViewModel/EndpointsView anchors.
  - rg: Targeted rg found platform spec lines 7,21-31,55-84 and S1-02 lines 40-41,201 at 28c2852.
  - Anchors: docs/specs/platform/swiftui-combine-ui-boundary.md:7@28c2852cbcf194971b755cc52c911ebd94890b3f
| F-S102-ENDPOINT-SPINE | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The exact accepted S1-02 product head implements the revision-16 endpoint policy and verification surface, but its Example seam is named EndpointsController and must be presenta... |
  - Serena: n/a
  - rg: Targeted git show/grep at immutable 422043e confirmed revision-16 spec, accepted endpoint criteria, current S1-02 source/test paths, and controller-based Example seam.
  - Anchors: docs/specs/sprint-01-foundation/S1-02-network-endpoint-policy.md:1@422043e893f01237b4eca89b26676b356d31ab5c
| F-TRON-TOPOLOGY-ONLY | 1 | yes | MATCH | yes | combined | E-0004 | valid | known_current | Current TronKit preserves the separate Example project/workspace/package topology but its UIKit AppDelegate and controller lifecycle are unsafe as a ThorChainKit presentation an... |
  - Serena: Exact TronKit workspace search found AppDelegate, UIWindow, UIViewController, UINavigationController, and UITableViewController usage.
  - rg: Targeted rg independently found the same UIKit lifecycle/controller anchors; local HEAD equals aa691bcd.
  - Anchors: iOS Example/Sources/AppDelegate.swift:1@aa691bcd8c79d57a554d72a4996bec4d7e1afce5
| F-PR-UIKIT-COUNTEREXAMPLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | PR head 422043e and current main both retain UIKit AppDelegate/controllers, so merging or extending that Example without migration would directly violate the newly merged reposi... |
  - Serena: Exact target workspace search found AppDelegate.swift and DiagnosticsController/MainController UIKit symbols on current main.
  - rg: rg on main and git grep on 422043e found UIKit imports and lifecycle/controller symbols, including EndpointsController on the PR head.
  - Anchors: iOS Example/Sources/AppDelegate.swift:1@422043e893f01237b4eca89b26676b356d31ab5c
| F-PLATFORM-TEST-GATE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Current main already specifies the fail-closed platform scan, SwiftUI App requirement, library iOS 13 floor, Example iOS 14 floor, exact Example build, and Maestro rerun needed ... |
  - Serena: Exact target workspace search found the platform-contract acceptance and verification clauses.
  - rg: Targeted rg found roadmap migration steps 1-5, S1-01 plan step 5A, and test-plan lines 16,80,105,140.
  - Anchors: docs/roadmap/sprint-01-foundation.md:39@28c2852cbcf194971b755cc52c911ebd94890b3f

## Adversarial decisions

- ARCH-001@1 REVISE: Testing SPI ownership is contradictory
- VER-001@1 REVISE: Ordered final verifier cannot pass
- VER-002@1 REVISE: Combine-backed observation is required but unproved
- VER-003@1 REVISE: Cancellation and stale-result suppression are required but unproved

## Verification and acceptance


## Bugs and limitations

### GIMLE-MAP-THORCHAIN: ThorChainKit has no Palace project mapping

- Class/severity/confidence/status: mapping_bug / medium / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0003 / n/a
- Reproduction: Call palace.memory.health and palace.memory.list_projects; no thorchain slug or git mount is returned
- Expected: A ThorChainKit project mapped to the active repository or an explicit unsupported-project envelope
- Actual: Healthy substrate lists external analog projects only; ThorChainKit is absent
- Impact: Gimle cannot supply target-repository evidence or freshness for the reconciliation
- Workaround: Use codebase-memory first, exact-worktree Serena, targeted rg, and Git reads; use Palace only for mapped external analog identities
- Anchors: `ThorChainKit.Swift@28c2852cbcf194971b755cc52c911ebd94890b3f`

### GIMLE-COVERAGE-THORCHAIN: Healthy Palace substrate has no ThorChainKit coverage

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.memory.health / E-0002 / n/a
- Reproduction: Call palace.memory.health and inspect projects, entity_counts_per_project, and git_repos_available
- Expected: ThorChainKit appears with code, memory, or git coverage
- Actual: ThorChainKit is absent while external Horizontal Systems projects are present
- Impact: No target-tree Gimle claim can drive the design
- Workaround: Treat Gimle trust as YELLOW and rely on independently verified exact target and analog worktrees
- Anchors: `ThorChainKit.Swift@28c2852cbcf194971b755cc52c911ebd94890b3f`

### GIMLE-CALL-SCOPE: Unsupported source scope eliminated the TronKit candidate population

- Class/severity/confidence/status: caller_error / low / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0007 / n/a
- Reproduction: Call semantic_search with source_scopes application while coverage advertises project and dependency
- Expected: Use an advertised scope and search project symbols
- Actual: Zero scope candidate population with no server warning
- Impact: First discovery call yielded no evidence and cannot support an absence conclusion
- Workaround: Repeat once with source_scopes project and record both events
- Anchors: tron-kit@aa691bcd8c79d57a554d72a4996bec4d7e1afce5

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
