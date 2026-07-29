# Gimle reliability report: storage-analog-conformance-20260729

- Task: storage-analog-conformance
- Workflow/phase: analog_change / awaiting_approval
- Trust: **YELLOW**
- Repository: ThorChainKit.Swift
- Base HEAD: 61544c438171c40265c6cde18eb841a6e7018675
- Final HEAD: n/a
- Gimle runtime: n/a
- Indexed commit: n/a

## Metrics

- Calls: 6 (success 4, warning 2, error 0, false-success 0)
- Useful-call rate: 83.3%
- Response-byte coverage: 0/6; total n/a
- Duration coverage: 0/6; total n/a ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 3/3
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 3
- Analog slices/candidates: 1/7

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| codebase-memory.search_code | 0 | 1 | 0 | 0 |
| palace.code.semantic_search | 2 | 0 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 0 | 1 | 0 | 0 |

Bug classes: {'environment_drift': 1, 'coverage_gap': 2}
Bug severities: {'medium': 2, 'high': 1}
Bug statuses: {'workaround': 3}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | ok | warning | 18/18 | n/a | n/a | yes | 44136fa355b3678a | Project freshness is unknown for TronKit and EvmKit despite known indexed commits. |
| E-0004 | evidence | codebase-memory.search_code | ok | warning | 0/0 | n/a | n/a | no | e84eac9083ec8526 | The ready index returned zero matches for source paths known to exist in the current worktree. |
| E-0005 | evidence | palace.code.semantic_search | ok | success | 24/10 | n/a | n/a | yes | 11230f3b2a6a5bd4 | n/a |
| E-0006 | evidence | palace.code.semantic_search | ok | success | 21/10 | n/a | n/a | yes | a60eb66c4e41aed1 | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S3-01-storage | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-tron-storage-contract | C-tron-storage-implementation, C-tron-storage-lifecycle_error, C-tron-composition, C-evm-transaction-state, C-target-tests | C-target-runtime |
  - Conflict: TronKit methods fail with try! while ThorChainKit persistence is currently throwing.; resolution: Preserve throwing internal errors where required by existing THOR async callers; copy ownership, naming, and direct composition only.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-tron-storage-contract | S3-01-storage | kept | F-001 | contract | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/TronKit/Storage/{SyncerStorage,AccountInfoStorage}.swift |
| C-tron-storage-implementation | S3-01-storage | kept | F-001 | implementation | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/TronKit/Storage/{SyncerStorage,AccountInfoStorage}.swift |
| C-tron-storage-lifecycle_error | S3-01-storage | kept | F-001 | lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/TronKit/Storage/{SyncerStorage,AccountInfoStorage}.swift |
| C-tron-composition | S3-01-storage | supporting | F-002 | composition | boundary, dependencies | known_current | Sources/TronKit/Core/Kit.swift |
| C-evm-transaction-state | S3-01-storage | supporting | F-003 | consumer | dependencies, lifecycle | known_current | Sources/EvmKit/Core/TransactionSyncerStateStorage.swift |
| C-target-tests | S3-01-storage | supporting | F-005 | test | state_errors, tests | known_current | Tests/ThorChainKitTests/{AccountStateStorageTests,KitCompositionTests}.swift |
| C-target-runtime | S3-01-storage | rejected | F-004 | counterexample | boundary, dependencies, lifecycle | known_current | Sources/ThorChainKit/{Send/Storage/DatabaseRuntime,Storage/GrdbAccountStateStorage}.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-001 | 1 | yes | MATCH | yes | rg | E-0005 | valid | known_current | TronKit separates sync and account state into private-pool purpose-specific storages with a databaseDirectoryUrl/databaseFileName initializer and named synchronous accessors. |
  - Serena: n/a
  - rg: Git HEAD aa691bcd; rg and narrow reads confirm Sources/TronKit/Storage/{SyncerStorage,AccountInfoStorage}.swift.
  - Anchors: TronKit.Swift@aa691bcd Sources/TronKit/Storage/SyncerStorage.swift:4-87; AccountInfoStorage.swift:5-76
| F-002 | 1 | yes | MATCH | yes | rg | E-0005 | valid | known_current | TronKit composes its SyncerStorage, AccountInfoStorage, and TransactionStorage directly in Kit.instance with purpose-specific file names derived from one unique identifier. |
  - Serena: n/a
  - rg: Git HEAD aa691bcd; Kit.swift lines 278-283 directly create the three named stores and inject AccountInfoStorage into AccountInfoManager.
  - Anchors: TronKit.Swift@aa691bcd Sources/TronKit/Core/Kit.swift:278-284
| F-003 | 1 | yes | MATCH | yes | rg | E-0006 | valid | known_current | EvmKit independently uses a named private-pool transaction sync state storage and direct Kit composition, supporting the same storage ownership grammar. |
  - Serena: n/a
  - rg: Git HEAD be028631; narrow reads confirm TransactionSyncerStateStorage and Kit direct construction lines 339-340.
  - Anchors: EvmKit.Swift@be028631 Sources/EvmKit/Core/TransactionSyncerStateStorage.swift:4-61; Kit.swift:339-340
| F-004 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Current ThorChainKit combines sync control and account snapshots in GrdbAccountStateStorage and injects a DatabaseRuntime shared writer through Kit.instance. |
  - Serena: Serena read GrdbAccountStateStorage and Kit.instance in active worktree.
  - rg: rg confirms storage, runtime, and factory anchors.
  - Anchors: Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift:4-105; Sources/ThorChainKit/Core/KitFactory.swift:23-24
| F-005 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Current storage and factory tests directly assert the monolithic record contract and DatabaseRuntime alias barrier, so a storage split must replace those tests with the new obse... |
  - Serena: Serena overview identifies GrdbAccountStateStorage and DatabaseRuntime APIs.
  - rg: Targeted rg locates AccountStateStorageTests and KitCompositionTests alias-barrier assertions.
  - Anchors: Tests/ThorChainKitTests/AccountStateStorageTests.swift:1-86; Tests/ThorChainKitTests/KitCompositionTests.swift:66-143

## Adversarial decisions

- D-001@1 ACCEPT: TronKit is a coherent primary storage and factory spine.
- D-002@1 ACCEPT: Do not preserve the account/sync DatabaseRuntime registry.
- D-003@1 ACCEPT: Keep the send writer/journal untouched in this slice.
- D-004@1 ACCEPT: Retain only an internal async stale-result guard.

## Verification and acceptance


## Bugs and limitations

### G-001: Runtime identity cannot be mapped to a committed Gimle source revision

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.health.status / E-0001 / n/a
- Reproduction: health.status returns git_sha_label=native-dev with a dirty source checkout
- Expected: A deployed runtime identity resolvable to a source SHA
- Actual: native-dev and dirty checkout prevent a reproducible runtime source mapping
- Impact: Indexed discovery is treated as non-authoritative and every selected analog needs local Git/Serena/rg verification.
- Workaround: Use bound source worktrees at recorded commits and current-tree checks.
- Anchors: palace.health.status 2026-07-29

### G-002: TronKit and EvmKit freshness metadata is unavailable

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0003 / n/a
- Reproduction: list_projects reports indexed_commit but freshness_state=unknown and identity_check=unchecked
- Expected: Freshness and repository identity for selected analog projects
- Actual: Neither analogue reports a verified tree head or freshness classification
- Impact: Palace results are candidate discovery only.
- Workaround: Verify each kept candidate directly in the mounted Git checkout at the reported revision.
- Anchors: palace.memory.list_projects tron-kit evm-kit

### G-003: ThorChainKit codebase-memory index does not expose current storage sources

- Class/severity/confidence/status: coverage_gap / high / confirmed / workaround
- Tool/events/claims: codebase-memory.search_code / E-0004 / n/a
- Reproduction: Ready project search for three current storage type names returns zero results
- Expected: Current authored storage sources discoverable in the indexed project
- Actual: No matches despite local files existing
- Impact: Target discovery uses Serena and rg instead of codebase-memory.
- Workaround: Use active worktree symbol navigation and targeted rg.
- Anchors: Sources/ThorChainKit/Storage

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
