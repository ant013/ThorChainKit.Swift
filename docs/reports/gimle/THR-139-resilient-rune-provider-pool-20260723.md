# Gimle reliability report: THR-139-resilient-rune-provider-pool-20260723-r1

- Task: 13b614f7-ca87-4777-9694-15639e12c283
- Workflow/phase: analog_change / adversarial_review
- Trust: **RED**
- Repository: `$THORCHAINKIT_ROOT`
- Base HEAD: 6462bec2604db4d3d05b3cfccde1ff5b768c86e0
- Final HEAD: fdb40d48f950140278a35ec0b091c4614fa79747
- Gimle runtime: native-dev:0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: 8a63bfda028dd8543115b26dd777235a53304311

## Metrics

- Calls: 16 (success 11, warning 5, error 0, false-success 0)
- Useful-call rate: 75.0%
- Response-byte coverage: 0/16; total n/a
- Duration coverage: 0/16; total n/a ms
- Gimle agreement: 75.0%
- Gimle contradiction: 25.0%
- Location validity: 75.0%; coverage 4/4
- Freshness coverage: 75.0%
- Replacement/fallback claims: 1
- Bugs: 4
- Analog slices/candidates: 1/5

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.get_code_snippet | 2 | 1 | 0 | 0 |
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.code.search_graph | 3 | 0 | 0 | 0 |
| palace.code.semantic_search | 0 | 3 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 2 | 1 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'stale_index': 1, 'coverage_gap': 3}
Bug severities: {'high': 1, 'medium': 3}
Bug statuses: {'workaround': 4}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | success | success | n/a/18 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0004 | evidence | palace.code.list_passthrough_projects | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0005 | evidence | palace.memory.get_project_overview | success | success | n/a/1 | n/a | n/a | yes | e40d2aa6fdce6b6f | n/a |
| E-0006 | evidence | palace.memory.get_project_overview | success | success | n/a/1 | n/a | n/a | yes | 04799ff4fb4e3a8b | n/a |
| E-0007 | evidence | palace.memory.get_project_overview | success | warning | n/a/1 | n/a | n/a | yes | 4282f54d43bbb349 | Project overview current-tree metadata conflicts with later EvmKit snippet freshness; retain for defect correlation only. |
| E-0008 | evidence | palace.code.semantic_search | success | warning | 18/10 | n/a | n/a | yes | 767f08c0d1b6efda | Result set truncated at 10 of 18; exact symbols independently verified with search_graph, Serena, rg, and Git. |
| E-0009 | evidence | palace.code.semantic_search | success | warning | 0/0 | n/a | n/a | yes | 3ee91233355194a0 | Semantic search returned no candidates despite exact local/search_graph symbols; treat as coverage gap and use local Serena, rg, and Git. |
| E-0010 | evidence | palace.code.semantic_search | success | warning | n/a/10 | n/a | n/a | yes | 55cf81a5ab9ab91c | Search was truncated/saturated and surfaced an unrelated multichain provider; exact UW symbols independently verified with Serena and rg. |
| E-0011 | evidence | palace.code.search_graph | success | success | n/a/1 | n/a | n/a | yes | ce5b5edd053a416b | n/a |
| E-0012 | evidence | palace.code.get_code_snippet | success | success | n/a/1 | n/a | n/a | yes | bd7fbd9dab004c94 | n/a |
| E-0013 | evidence | palace.code.search_graph | success | success | n/a/2 | n/a | n/a | yes | 61193aa7fdab7714 | n/a |
| E-0014 | evidence | palace.code.get_code_snippet | success | warning | n/a/2 | n/a | n/a | yes | aca207d78aac2aa3 | Returned snippet metadata is stale/contradictory: indexed commit 27f125be, stale=true, behind local tree by 3 while overview reports tree/index be028631 current. |
| E-0015 | evidence | palace.code.search_graph | success | success | n/a/1 | n/a | n/a | yes | d67f049029afee28 | n/a |
| E-0016 | evidence | palace.code.get_code_snippet | success | success | n/a/1 | n/a | n/a | yes | 0edaf24d4e884b4c | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| THR139-RUNE-PROVIDER-CONFIG | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-THR139-THOR-ENDPOINT-FAMILY | C-THR139-EVM-RPC-SOURCE, C-THR139-TRON-RPC-SOURCE, C-THR139-UW-PROVIDER | C-THR139-UW-LIQUIFY-TEST |
  - Conflict: EvmKit NodeApiProvider rotates individual requests recursively; ThorChainKit must retry the complete read operation and preserve height/identity acceptance.; resolution: Use EvmKit only for ordered source/failover shape; retain ThorChainKit EndpointPool and ReadOperationCoordinator as the lifecycle, safety, and fail-closed owner.
  - Conflict: TronKit RpcSource exposes multiple URLs but current Kit.instance consumes urls[0]; treating it as failover would be false analog transfer.; resolution: Use TronKit only for centralized provider-source ownership and composition boundary; do not copy its first-URL runtime behavior.
  - Conflict: UW v0.50 current provider/test encode one Liquify family, while THR-139 requires exactly three ordered families.; resolution: Treat the current Liquify implementation/test as the explicit rejected counterexample and update only after exact revision approval.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-THR139-EVM-RPC-SOURCE | THR139-RUNE-PROVIDER-CONFIG | supporting | F-THR139-EVM-RPCSOURCE | implementation, lifecycle_error | dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/EvmKit/Models/RpcSource.swift;Sources/EvmKit/Api/Core/NodeApiProvider.swift |
| C-THR139-TRON-RPC-SOURCE | THR139-RUNE-PROVIDER-CONFIG | supporting | F-THR139-TRON-RPCSOURCE | composition, contract | boundary, dependencies, responsibility, trust | known_current | Sources/TronKit/Models/RpcSource.swift;Sources/TronKit/Core/Kit.swift |
| C-THR139-UW-PROVIDER | THR139-RUNE-PROVIDER-CONFIG | supporting | F-THR139-UW-PROVIDER | composition, consumer, test | boundary, dependencies, responsibility, tests, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift |
| C-THR139-UW-LIQUIFY-TEST | THR139-RUNE-PROVIDER-CONFIG | rejected | F-THR139-UW-LIQUIFY-COUNTEREXAMPLE | counterexample, test | boundary, tests, trust | known_current | Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift |
| C-THR139-THOR-ENDPOINT-FAMILY | THR139-RUNE-PROVIDER-CONFIG | kept | F-THR139-THOR-KIT | contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | known_current | Sources/ThorChainKit/Models/EndpointConfiguration.swift;Sources/ThorChainKit/Network/EndpointPool.swift;Sources/ThorChainKit/Network/ReadOperationCoordinator.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-THR139-THOR-KIT | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChainKit owns endpoint-family validation and native failover semantics: EndpointConfiguration rejects empty and duplicate families, EndpointPool selects a healthy family usi... |
  - Serena: Serena verified Sources/ThorChainKit/Models/EndpointConfiguration.swift, Sources/ThorChainKit/Network/EndpointPool.swift, Sources/ThorChainKit/Network/ReadOperationCoordinator.swift and their focused tests on the exact target branch.
  - rg: Targeted rg and Git reads independently matched EndpointConfiguration, EndpointPool, ReadOperationCoordinator, EndpointPoolTests, and ReadOperationCoordinatorS1_04Tests at base 6462bec.
  - Anchors: Sources/ThorChainKit/Models/EndpointConfiguration.swift, Sources/ThorChainKit/Network/EndpointPool.swift, Sources/ThorChainKit/Network/ReadOperationCoordinator.swift, Tests/ThorChainKitTests/EndpointPoolTests.swift, Tests/ThorChainKitTests/ReadOperationCoordinatorS1_04Tests.swift
| F-THR139-UW-PROVIDER | 1 | yes | MATCH | yes | serena+rg | E-0015 | valid | known_current | The exact UW iOS v0.50 checkout currently owns native RUNE endpoint construction in ThorChainEndpointConfigurationProvider, with one Liquify family, paired REST/RPC URLs, and an... |
  - Serena: Serena verified the class and current body in packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift.
  - rg: Targeted rg/Git verified the exact path and current local checkout HEAD 8a63bfda; the worktree is dirty and therefore was not modified.
  - Anchors: Unstoppable/Packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift, Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift
| F-THR139-UW-LIQUIFY-COUNTEREXAMPLE | 1 | yes | MATCH | yes | serena+rg | E-0015 | valid | known_current | The existing UW production endpoint test asserts exactly one native RUNE family with Liquify REST/RPC URLs and the Liquify approved host. |
  - Serena: Serena verified ThorChainKitManagerTests.productionEndpointConfigurationUsesOfficialLiquifyPair.
  - rg: Targeted rg/Git verified the one-family assertions in Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift.
  - Anchors: Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift
| F-THR139-TRON-RPCSOURCE | 1 | yes | MATCH | yes | serena+rg | E-0012 | valid | known_current | TronKit RpcSource owns the provider URL source and Kit.instance composes the provider from that source into node, RPC, and syncer dependencies; its current Kit path consumes the... |
  - Serena: Serena verified TronKit RpcSource and Kit.instance source locations and composition.
  - rg: Targeted rg/sed and Git verified Sources/TronKit/Models/RpcSource.swift, Network provider protocols, and Sources/TronKit/Core/Kit.swift.
  - Anchors: TronKit/Sources/TronKit/Models/RpcSource.swift, TronKit/Sources/TronKit/Core/Kit.swift
| F-THR139-EVM-RPCSOURCE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | EvmKit RpcSource represents ordered HTTP URL arrays and NodeApiProvider owns bounded request-level rotation across those URLs after transport/RPC errors; this supplies the order... |
  - Serena: Serena verified EvmKit RpcSource and NodeApiProvider bodies in the exact local checkout at be028631.
  - rg: Targeted rg/sed and Git independently verified Sources/EvmKit/Models/RpcSource.swift, Sources/EvmKit/Api/Core/NodeApiProvider.swift, and Sources/EvmKit/Core/Kit.swift.
  - Anchors: EvmKit/Sources/EvmKit/Models/RpcSource.swift, EvmKit/Sources/EvmKit/Api/Core/NodeApiProvider.swift, EvmKit/Sources/EvmKit/Core/Kit.swift
| F-THR139-EVM-GIMLE-STALE | 1 | no | CONTRADICTED | no | none | E-0016 | unknown | contradictory | The Gimle EvmKit snippet metadata is current and load-bearing for the provider-source decision. |
  - Serena: n/a
  - rg: n/a
  - Anchors: EvmKit/Sources/EvmKit/Models/RpcSource.swift

## Adversarial decisions

- D-001@2 ACCEPT: Host cardinality and allowlist semantics
- D-002@2 ACCEPT: Exact approved-host equality
- D-003@2 ACCEPT: REST/RPC family pairing
- D-004@12 ACCEPT: Fixed three-family live invocations with bounded stored evidence
- D-005@2 ACCEPT: Test-first execution order
- D-006@12 ACCEPT: Repository-owned verifier artifacts and executable self-tests
- D-007@12 ACCEPT: Identity and static preflight precede PASS-capable gates
- D-008@10 ACCEPT: Existing S1-04 schema only
- D-009@5 ACCEPT: Revision delivery state
- D-010@2 ACCEPT: Direct identity/height verification coverage

## Verification and acceptance

### Revision 9 closure correction set

- Exact expected HEAD, clean worktree, `origin/main` equality, and base
  ancestry are checked before `verify-s1-02.sh`; `bash -n` and the existing
  `verify-s1-04.sh --source-only` and `--fixtures-only` modes precede Xcode.
- The two required UW verifier files each expose a runnable `--self-test`;
  `python3 -m py_compile` and both self-tests precede every UW Xcode command.
- The three live commands supply literal family/REST/RPC pairs. Stored S1-04
  JSON proves only its existing schema and network invariants, not URL-pair
  attestation. D-008 remains limited to that existing schema.
- Closure 5/5 is bounded to D-004, D-006, D-007, D-008, and direct regressions;
  discovery remains frozen at 2/2.


## Bugs and limitations

### B-EVM-FRESHNESS-001: EvmKit snippet freshness contradicts project overview

- Class/severity/confidence/status: stale_index / high / confirmed / workaround
- Tool/events/claims: palace.code.get_code_snippet / E-0007, E-0014 / n/a
- Reproduction: palace.memory.get_project_overview(evm-kit) reports indexed/tree head be028631 current, while palace.code.get_code_snippet for RpcSource/NodeApiProvider reports indexed 27f125be, stale=true, behind local tree by 3
- Expected: A load-bearing snippet must correspond to the verified current EvmKit tree head be028631
- Actual: Snippet metadata is stale and contradicts the project overview
- Impact: Gimle cannot be used as load-bearing EvmKit source evidence; accepting it could select obsolete provider behavior
- Workaround: Use exact local EvmKit checkout with Serena, targeted rg, and Git at be028631; retain Gimle result only as a rejected/stale event
- Anchors: EvmKit/Sources/EvmKit/Models/RpcSource.swift, EvmKit/Sources/EvmKit/Api/Core/NodeApiProvider.swift

### B-EVM-SEARCH-001: EvmKit semantic search misses exact provider-source symbols

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0009 / n/a
- Reproduction: semantic_search(evm-kit, RpcSource NodeApiProvider URL rotation) returns no candidates; exact symbols resolve through search_graph and local rg
- Expected: Semantic search should return the exact RpcSource and NodeApiProvider candidates or explicitly report coverage limits
- Actual: Empty result with no warning despite exact indexed/searchable symbols
- Impact: Discovery is incomplete unless exact-symbol and local fallbacks are mandatory
- Workaround: Use search_graph, exact qualified-name snippet, Serena, rg, and Git; do not infer absence from empty semantic results
- Anchors: EvmKit/RpcSource

### B-UW-SEARCH-001: UW semantic search saturates on unrelated provider family

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0010 / n/a
- Reproduction: semantic_search(uw-ios-app, ThorChainEndpointConfigurationProvider production endpoint configuration) returns a truncated/saturated unrelated multichain provider result
- Expected: Search should return the exact native RUNE configuration provider or disclose that the result set is incomplete
- Actual: Truncated/saturated result is not the requested ThorChain provider
- Impact: Exact-symbol verification is required to avoid selecting the existing multichain swap provider as the native RUNE owner
- Workaround: Use exact symbol search, Serena, rg, and the verified UW v0.50 checkout; retain multichain result as non-authoritative
- Anchors: Unstoppable/Packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift

### B-TRON-SEARCH-001: TronKit semantic search truncates provider-source discovery

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0008 / n/a
- Reproduction: semantic_search(tron-kit, RpcSource provider URL Kit instance) returns 10 of 18 candidates and truncates without a complete result set
- Expected: Discovery should either return all relevant candidates or disclose the bounded result set as incomplete
- Actual: Only the first 10 of 18 candidates were returned
- Impact: Exact-symbol lookup and independent local verification are required before selecting a provider-source analog
- Workaround: Use exact search_graph, Serena, rg, and Git; do not infer completeness from semantic results
- Anchors: TronKit/Sources/TronKit/Models/RpcSource.swift

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
