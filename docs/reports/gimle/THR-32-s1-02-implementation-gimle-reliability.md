# Gimle reliability report: THR-32-S1-02-implementation

- Task: THR-32
- Workflow/phase: analog_change / complete
- Trust: **YELLOW**
- Repository: assigned ThorChainKit.Swift worktree
- Base HEAD: 89e4e8efc1b034e920955a3ab9c7810f4e586230
- Final HEAD: 46a7b81ad8bbf7ce9db93ae6a94b8af6e2dd7f1e
- Gimle runtime: native-dev@0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: n/a

## Metrics

- Calls: 13 (success 10, warning 2, error 1, false-success 0)
- Useful-call rate: 61.5%
- Response-byte coverage: 0/13; total n/a
- Duration coverage: 0/13; total n/a ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 2/2
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 3
- Analog slices/candidates: 2/7

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 2 | 0 | 0 | 0 |
| palace.code.search_graph | 2 | 0 | 0 | 0 |
| palace.health.status | 2 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 2 | 0 | 1 | 0 |
| palace.memory.health | 2 | 0 | 0 | 0 |
| palace.memory.list_projects | 0 | 2 | 0 | 0 |

Bug classes: {'coverage_gap': 1, 'environment_drift': 2}
Bug severities: {'medium': 3}
Bug statuses: {'workaround': 3}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | ok | warning | 18/18 | n/a | n/a | yes | 44136fa355b3678a | ThorChainKit is absent; target truth requires codebase-memory plus Serena/rg fallback. |
| E-0004 | evidence | palace.code.list_passthrough_projects | ok | success | n/a/7 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0005 | evidence | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 04799ff4fb4e3a8b | n/a |
| E-0006 | evidence | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 4282f54d43bbb349 | n/a |
| E-0007 | evidence | palace.code.search_graph | ok | success | 2/2 | n/a | n/a | yes | 5322da49830f90e9 | n/a |
| E-0008 | evidence | palace.code.search_graph | ok | success | 2/2 | n/a | n/a | yes | ef38af6836a95ae2 | n/a |
| E-0009 | implementation | palace.health.status | success | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0010 | implementation | palace.memory.health | success | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0011 | implementation | palace.memory.list_projects | success | warning | 18/18 | n/a | n/a | no | 44136fa355b3678a | ThorChainKit remains absent from the 18 registered projects. |
| E-0012 | implementation | palace.memory.get_project_overview | success | error | n/a/n/a | n/a | n/a | no | fb8ad274c80ead38 | Payload returned ok=false error=unknown_project. |
| E-0013 | implementation | palace.code.list_passthrough_projects | success | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| endpoint-family-contract | high | boundary, dependencies, responsibility, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-TRON-RPC-SOURCE | C-TARGET-S1-01-FAMILY | C-EVM-BROAD-ROTATION-CONTRACT |
  - Conflict: Tron uses a broad URL array while S1-01 already defines paired typed family roles.; resolution: Preserve the target typed family contract; use Tron only for explicit configuration shape, never URL rotation or lifecycle.
| endpoint-pool-lifecycle | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-ZCASH-ACTOR-LIFECYCLE | C-VULTISIG-PROBE-SEAM, C-TARGET-S1-01-POOL-BOUNDARY | C-EVM-BROAD-ROTATION-LIFECYCLE |
  - Conflict: Zcash actor lifecycle has no per-waiter coalescing or network identity lock, while Vultisig is stateless.; resolution: Keep Zcash actor/reset/DI/test lifecycle as the spine; add only revision-16 waiter, generation, identity, monotonic-health, and lease deltas, with Vultisig limited to the injected THOR probe seam.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-TRON-RPC-SOURCE | endpoint-family-contract | kept | F-TRON-RPC-SOURCE | contract, implementation | boundary, dependencies, responsibility, trust | known_current | Sources/TronKit/Models/RpcSource.swift |
| C-TARGET-S1-01-FAMILY | endpoint-family-contract | supporting | F-TARGET-S1-01-ENDPOINTS | composition, consumer, lifecycle_error, test | boundary, dependencies, responsibility, tests, trust | known_current | Sources/ThorChainKit/Models/EndpointConfiguration.swift |
| C-EVM-BROAD-ROTATION-CONTRACT | endpoint-family-contract | rejected | F-EVM-BROAD-ROTATION | counterexample | boundary, responsibility, state_errors, trust | known_current | Sources/EvmKit/Api/Core/NodeApiProvider.swift |
| C-ZCASH-ACTOR-LIFECYCLE | endpoint-pool-lifecycle | kept | F-POOL-ZCASH-LIFECYCLE | composition, consumer, contract, implementation, lifecycle_error, test | boundary, dependencies, lifecycle, responsibility, state_errors, tests | known_current | Sources/ZcashLightClientKit/Providers/LatestBlocksDataProvider.swift |
| C-VULTISIG-PROBE-SEAM | endpoint-pool-lifecycle | supporting | F-VULTISIG-PROBE-SEAM | implementation, test | boundary, responsibility, tests, trust | known_current | VultisigApp/VultisigApp/Features/CustomRPC/Service/RPCHealthProbe.swift |
| C-TARGET-S1-01-POOL-BOUNDARY | endpoint-pool-lifecycle | supporting | F-TARGET-S1-01-ENDPOINTS | composition, consumer, contract | boundary, dependencies, tests, trust | known_current | Sources/ThorChainKit/Network/EndpointPolicy.swift |
| C-EVM-BROAD-ROTATION-LIFECYCLE | endpoint-pool-lifecycle | rejected | F-EVM-BROAD-ROTATION | counterexample | dependencies, lifecycle, state_errors, trust | known_current | Sources/EvmKit/Api/Core/NodeApiProvider.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-TARGET-S1-01-ENDPOINTS | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The pinned target tree contains the S1-01 typed endpoint configuration, policy, inert Kit boundary, and public tests that S1-02 must extend without changing ownership. |
  - Serena: n/a
  - rg: Exact rg located EndpointFamilyDescriptor, EndpointPolicy, EndpointConfiguration, Kit, and their PublicApiTests in the assigned worktree; codebase-memory independently indexed the same current target symbols/tests.
  - Anchors: Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift:3; Sources/ThorChainKit/Network/EndpointPolicy.swift:3; Sources/ThorChainKit/Models/EndpointConfiguration.swift:3; Sources/ThorChainKit/Core/Kit.swift:5; Tests/ThorChainKitTests/PublicApiTests.swift:57
| F-TRON-RPC-SOURCE | 1 | yes | MATCH | yes | serena+rg | E-0005, E-0007 | valid | known_current | Tron RpcSource is a current explicit endpoint-configuration contract analog, not lifecycle ownership. |
  - Serena: RpcSource struct resolved at 0-based lines 2-16 with urls, API keys, auth, and explicit initializer.
  - rg: Exact checkout aa691bcd contains public RpcSource and initializer at lines 3-15.
  - Anchors: TronKit.Swift@aa691bcd:Sources/TronKit/Models/RpcSource.swift:3
| F-VULTISIG-PROBE-SEAM | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Pinned Vultisig provides a THOR-specific injected probe seam, role split, and controlled probe tests, but not actor-owned pool lifecycle. |
  - Serena: RPCHealthProbe and ThorchainMainnetAPI resolve with injected HTTP client, THOR/Cosmos probe methods, and separate LCD/RPC hosts.
  - rg: Exact checkout d3123dbe anchors RPCHealthProbe, probeThorchain/probeStatus, separate hosts, and RPCHealthProbeTests controlled seams.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Features/CustomRPC/Service/RPCHealthProbe.swift:81; VultisigApp/VultisigAppTests/Services/RPCHealthProbeTests.swift:9
| F-EVM-BROAD-ROTATION | 1 | yes | MATCH | yes | serena+rg | E-0006, E-0008 | valid | known_current | Evm NodeApiProvider owns recursive URL retry and mutable request identity, which is an unsafe S1-02 pool counterexample. |
  - Serena: NodeApiProvider resolves currentRpcId, rpcResult, and retry members; RpcSource exposes broad URL lists.
  - rg: Exact checkout be028631 anchors currentRpcId, recursive indexed URL access, retry, and multi-URL sources.
  - Anchors: EvmKit.Swift@be028631:Sources/EvmKit/Api/Core/NodeApiProvider.swift:6
| F-POOL-ZCASH-LIFECYCLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Pinned Zcash LatestBlocksDataProvider is a coherent actor-owned contract/implementation/composition/consumer/test lifecycle spine with reset and injected substitution. |
  - Serena: LatestBlocksDataProvider protocol and actor implementation resolve with reset/update methods at current locations.
  - rg: Exact checkout ff526fa anchors actor implementation, singleton DI registrations, consumers, generated mock, and unit/network test substitutions.
  - Anchors: ZcashLightClientKit@ff526fa:Sources/ZcashLightClientKit/Providers/LatestBlocksDataProvider.swift:10; Sources/ZcashLightClientKit/Synchronizer/Dependencies.swift:136; Tests/TestUtils/Sourcery/GeneratedMocks/AutoMockable.generated.swift:661

## Adversarial decisions

- D-THR32-APPROVED-DESIGN-BINDING@1 ACCEPT: ACCEPT the unchanged revision-16 implementation design in this assigned worktree.

## Verification and acceptance

- S102-SEC-002 acceptance/passed: Invalid response now precedes catching-up/stale; HTTP 400/401/403/404 fail closed as invalid http envelopes while 408/429/502/503/504 remain temporary.
- S102-SEC-004 acceptance/passed: Int64.min in either role returns staleEndpoint without subtracting before positivity validation.
- S102-FULL-TESTS verification/passed: 41 tests passed with zero failures.
- S102-VERIFIER verification/passed: All S1-02 gates passed, including exact discovery, strict build/tests, public subset, inert factory, SPI boundary, and live-evidence mutants.
- S102-LIVE unrun/not_run: Provider environment absent; deterministic pool-only correction does not require a new live probe before exact-head review.
- S102-CI-POLICY verification/passed: Steady-state policy and all trigger/head/workflow mutants passed against the committed correction head.

## Bugs and limitations

### GIMLE-THR32-TARGET-COVERAGE: ThorChainKit is not mapped in Palace

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0003, E-0011, E-0012 / n/a
- Reproduction: Call palace.memory.list_projects, then palace.memory.get_project_overview with slug thorchain-kit.
- Expected: A target project mapping with indexed commit and freshness.
- Actual: No ThorChainKit project is present among 18 registered projects; direct overview returns ok=false unknown_project.
- Impact: Gimle cannot establish target-tree truth for this implementation correction.
- Workaround: Use codebase-memory project Users-ant013-Data-AI-thorchain first, then exact assigned-worktree Serena and targeted rg/Git reads.
- Anchors: ThorChainKit.Swift@33376bc

### GIMLE-THR32-CHECKPOINT-PATH-DRIFT: Approved checkpoint is bound to a moved operator checkout

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: validate_design_gate.py / n/a / n/a
- Reproduction: Validate /audit/runs/THR-13-S1-02/state.json after the operator checkout moved from the approved docs head.
- Expected: The approved design validator resolves the assigned implementation worktree or a stable approved artifact checkout.
- Actual: The prior checkpoint records the operator checkout on `docs/THR-13`, but that checkout later moved to `bootstrap/THR-20`; validation reports HEAD, branch, artifact, and fingerprint drift.
- Impact: The prior machine checkpoint cannot be reused as the current worktree validator without mutating the production checkout.
- Workaround: Preserve the approved checkpoint, create this fresh implementation-bound checkpoint, re-hash the unchanged approved artifacts, and bind the recorded Paperclip approval again.
- Anchors: THR-13-S1-02 revision 172; THR-32 assigned worktree

### SERENA-THR32-TARGET-LANGUAGE-CACHE: Target Serena registration has no Swift language index

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: serena.find_symbol / n/a / n/a
- Reproduction: Activate exact ThorChainKit.Swift assigned worktree at 33376bc and query EndpointPool, LiveNodeProbe, and EndpointPoolTests.
- Expected: Swift symbols and current source locations.
- Actual: Activation reports no programming language; all three bounded queries fail with No language servers available in the manager.
- Impact: Changed target symbols cannot be independently verified with Serena in this closure correction.
- Workaround: Use codebase-memory first and exact targeted rg/Git reads in the assigned worktree.
- Anchors: ThorChainKit.Swift@33376bc

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
