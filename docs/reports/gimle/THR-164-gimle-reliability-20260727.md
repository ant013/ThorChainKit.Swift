# Gimle reliability report: THR-164-20260727

- Task: e3e1f446-e9af-4e67-aea8-56552e1b4b82
- Workflow/phase: analog_change / design
- Trust: **RED**
- Repository: ThorChainKit.Swift checkout (operator path omitted)
- Base HEAD: 922a5badac5a9b80361a02dff5c75711f00da53c
- Final HEAD: n/a
- Gimle runtime: n/a
- Indexed commit: n/a

## Metrics

- Calls: 4 (success 3, warning 0, error 0, false-success 1)
- Useful-call rate: 0.0%
- Response-byte coverage: 0/4; total n/a
- Duration coverage: 0/4; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 2
- Analog slices/candidates: 1/11

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.get_architecture | 0 | 0 | 0 | 1 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1, 'environment_drift': 1}
Bug severities: {'high': 1, 'medium': 1}
Bug statuses: {'workaround': 2}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.health | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace.memory.list_projects | success | success | n/a/18 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0004 | preflight | palace.code.get_architecture | success | false_success | n/a/1 | n/a | n/a | no | 43db317e2899ba6d | Nested semantic payload reported project_not_found although outer MCP envelope isError=false |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| THR164-S1 | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-THR164-001 | C-THR164-002, C-THR164-004, C-THR164-006, C-THR164-007, C-THR164-008, C-THR164-009, C-THR164-010, C-THR164-011 | C-THR164-005 |
  - Conflict: EvmKit weak queue capture has no observation-generation or publication-barrier lifecycle.; resolution: Use EvmKit only for explicit weak capture syntax at the GCD boundary; retain PendingTransactionRepository as the sole lifecycle/ownership spine and preserve its generation, error, barrier, and retry behavior.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-THR164-001 | THR164-S1 | kept | F-THR164-001 | lifecycle_error | lifecycle | known_current | Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift |
| C-THR164-002 | THR164-S1 | supporting | F-THR164-002 | test | tests | known_current | Tests/ThorChainKitTests/Send/Storage/PendingTransactionRepositoryTests.swift |
| C-THR164-003 | THR164-S1 | supporting | F-THR164-003 | consumer | boundary | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift |
| C-THR164-004 | THR164-S1 | supporting | F-THR164-004 | implementation | boundary | known_current | HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Api/Core/WebSocketRpcSyncer.swift |
| C-THR164-005 | THR164-S1 | rejected | F-THR164-005 | counterexample | lifecycle | known_current | Sources/ThorChainKit/Sync/AccountSyncer.swift |
| C-THR164-006 | THR164-S1 | supporting | F-THR164-001 | contract | responsibility | known_current | Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift |
| C-THR164-007 | THR164-S1 | supporting | F-THR164-001 | implementation | boundary | known_current | Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift |
| C-THR164-008 | THR164-S1 | supporting | F-THR164-001 | lifecycle_error | lifecycle | known_current | Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift |
| C-THR164-009 | THR164-S1 | supporting | F-THR164-001 | implementation | state_errors | known_current | Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift |
| C-THR164-010 | THR164-S1 | supporting | F-THR164-003 | composition | dependencies | known_current | Sources/ThorChainKit/Core/KitFactory.swift |
| C-THR164-011 | THR164-S1 | supporting | F-THR164-003 | consumer | boundary | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-THR164-001 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | At origin/main 922a5ba, PendingTransactionRepository.installObservation increments a generation, cancels the prior observation, and supplies two weak-self callbacks that dispatc... |
  - Serena: n/a
  - rg: rg -n and nl -ba on Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift:70-107; exact callback lines 75-103 and diagnostics anchors 77,92.
  - Anchors: Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift:70-107
| F-THR164-002 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The focused PendingTransactionRepositoryTests observe ready projection, refresh degradation with cached snapshot, committed transition publication, publication barrier acknowled... |
  - Serena: n/a
  - rg: nl -ba Tests/ThorChainKitTests/Send/Storage/PendingTransactionRepositoryTests.swift:6-124; tests explicitly exercise callbacks, generations, barrier, degraded state, and recovery.
  - Anchors: Tests/ThorChainKitTests/Send/Storage/PendingTransactionRepositoryTests.swift:6-124
| F-THR164-003 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | PendingTransactionRepository is composed with a shared PendingPublicationBarrier by KitFactory and SendRuntime, while SendRuntime owns the repository reference inside its actor;... |
  - Serena: n/a
  - rg: nl -ba Sources/ThorChainKit/Core/KitFactory.swift:51-67,157-174 and Sources/ThorChainKit/Send/Internal/SendRuntime.swift:59-112.
  - Anchors: Sources/ThorChainKit/Core/KitFactory.swift:51-67
| F-THR164-004 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current EvmKit WebSocketRpcSyncer uses queue.async closures with explicit [weak self] capture at the GCD transfer boundary, providing a verified syntax analog for retaining weak... |
  - Serena: n/a
  - rg: rg/nl on HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Api/Core/WebSocketRpcSyncer.swift:130-151 at checkout be0286317c202084784c5a695928cdc985c4ff7b.
  - Anchors: HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Api/Core/WebSocketRpcSyncer.swift:130-151
| F-THR164-005 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current ThorChainKit AccountSyncer uses weak self at Task creation but immediately binds a strong self inside the concurrent task, so it is a rejected counterexample for this sl... |
  - Serena: n/a
  - rg: nl -ba Sources/ThorChainKit/Sync/AccountSyncer.swift:54-57 and :101-104.
  - Anchors: Sources/ThorChainKit/Sync/AccountSyncer.swift:54-57

## Adversarial decisions


## Verification and acceptance


## Bugs and limitations

### GIMLE-THR164-001: ThorChainKit project is absent from Palace/Gimle project registry

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.code.get_architecture / E-0004 / n/a
- Reproduction: Call palace.code.get_architecture with project=Users-ant013-Data-AI-thorchain
- Expected: Architecture metadata resolves for the target repository or returns an explicit registered project mapping
- Actual: Outer call isError=false but nested payload reports error_code=project_not_found; list_projects has no ThorChainKit entry
- Impact: Gimle/Palace cannot provide target architecture, freshness, or source anchors; selected analogs must use codebase-memory and independent current-tree evidence
- Workaround: Use codebase-memory for target discovery and targeted rg/Git reads; keep Gimle trust RED and report the mapping defect
- Anchors: n/a

### ENV-THR164-001: Serena navigation tool is unavailable in the active environment

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: serena / n/a / n/a
- Reproduction: command -v serena and enabled MCP tool inventory return no Serena executable or Serena tool
- Expected: Serena independently resolves declarations and references in the assigned ThorChainKit workspace
- Actual: No Serena executable/tool is available; exact current-tree evidence must use targeted rg, nl, Git, and codebase-memory fallback
- Impact: Independent symbol navigation cannot be performed; analog claims require explicit targeted rg/Git anchors and remain below GREEN Gimle trust
- Workaround: Use current worktree rg/nl/git reads and codebase-memory search where available; do not claim Serena verification
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
