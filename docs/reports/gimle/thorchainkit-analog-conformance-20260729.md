# Gimle reliability report: thorchainkit-analog-conformance-spec-20260729

- Task: thorchainkit-analog-conformance-spec
- Workflow/phase: evidence_audit / complete
- Trust: **YELLOW**
- Repository: /Users/ant013/Data/AI/.worktrees/thorchain/analog-conformance-spec
- Base HEAD: 61544c438171c40265c6cde18eb841a6e7018675
- Final HEAD: 61544c438171c40265c6cde18eb841a6e7018675
- Gimle runtime: native-dev:0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: n/a

## Metrics

- Calls: 8 (success 2, warning 6, error 0, false-success 0)
- Useful-call rate: 75.0%
- Response-byte coverage: 0/8; total n/a
- Duration coverage: 0/8; total n/a ms
- Gimle agreement: 0.0%
- Gimle contradiction: 0.0%
- Location validity: 0.0%; coverage 4/4
- Freshness coverage: 0.0%
- Replacement/fallback claims: 0
- Bugs: 7
- Analog slices/candidates: 0/0

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.code.semantic_search | 0 | 4 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.health | 0 | 1 | 0 | 0 |
| palace.memory.list_projects | 0 | 1 | 0 | 0 |

Bug classes: {'environment_drift': 3, 'stale_index': 4}
Bug severities: {'medium': 2, 'high': 5}
Bug statuses: {'workaround': 7}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | success | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.health | success | warning | n/a/1 | n/a | n/a | no | 44136fa355b3678a | Global last-ingest metadata is older than the task and does not establish per-project freshness. |
| E-0003 | preflight | palace.memory.list_projects | success | warning | 18/18 | n/a | n/a | yes | 44136fa355b3678a | Project records expose indexed commits but freshness_state is unknown and identity_check is unchecked. |
| E-0004 | preflight | palace.code.list_passthrough_projects | success | success | n/a/7 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0005 | evidence | palace.code.semantic_search | success | warning | 32/5 | n/a | n/a | yes | b1641db7b389579b | Result freshness claims current_local_tree, conflicting with project overview freshness_state unknown; results are truncated by the requested bound. |
| E-0006 | evidence | palace.code.semantic_search | success | warning | 6/5 | n/a | n/a | yes | f4374bf04be04a84 | Result freshness claims current_local_tree, conflicting with project overview freshness_state unknown; results are truncated by the requested bound. |
| E-0007 | evidence | palace.code.semantic_search | success | warning | 9/6 | n/a | n/a | yes | 7957e57d17f5d365 | Result freshness claims current_local_tree, conflicting with project overview freshness_state unknown; results are truncated by the requested bound. |
| E-0008 | evidence | palace.code.semantic_search | success | warning | 74/8 | n/a | n/a | yes | cf9f08518aa3607a | Result freshness claims current_local_tree, conflicting with project overview freshness_state unknown; results are truncated by the requested bound. |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-001 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The local Unstoppable feature/THR-160-s2-07-unstoppable branch resolves ThorChainKit at ad9c748cc7d2952fba9ed4a64c13c07f8cb15bd5, so that revision is the sole current integratio... |
  - Serena: n/a
  - rg: WalletCore Package.swift, Wallet.xcworkspace Package.resolved, and Unstoppable.xcodeproj each pin ad9c748; the local warning-flags checkout resolves exactly to that commit.
  - Anchors: unstoppable-wallet-ios@c0bb5a1:packages/WalletCore/Package.swift:50, ThorChainKit-warning-flags@ad9c748
| G-002 | 1 | no | PARTIAL | no | none | E-0005 | unknown | contradictory | Palace discovery identifies TronKit Kit.swift and Syncer.swift as historical lifecycle candidates at aa691bcd. |
  - Serena: n/a
  - rg: n/a
  - Anchors: Palace E-0005
| G-003 | 1 | no | PARTIAL | no | none | E-0006 | unknown | contradictory | Palace discovery identifies TronKit TransactionManager.swift as a pending-lifecycle candidate at aa691bcd. |
  - Serena: n/a
  - rg: n/a
  - Anchors: Palace E-0006
| G-004 | 1 | no | PARTIAL | no | none | E-0007 | unknown | contradictory | Palace discovery identifies EvmKit Signer and NodeApiProvider candidates at be028631. |
  - Serena: n/a
  - rg: n/a
  - Anchors: Palace E-0007
| G-005 | 1 | no | PARTIAL | no | none | E-0008 | unknown | contradictory | Palace discovery identifies Unstoppable TronSendHandler as a host send candidate at 44d6df8. |
  - Serena: n/a
  - rg: n/a
  - Anchors: Palace E-0008
| F-002 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChainKit.Kit is the public facade and AccountSyncer is its lifecycle/read spine; TronKit.Kit and Syncer are the historical facade/lifecycle analogs, while ThorChainKit adds ... |
  - Serena: Integration-pinned ThorChainKit symbols show Kit state publishers/lifecycle methods and AccountSyncer start/stop/refresh.
  - rg: Pinned TronKit Kit forwards start/stop/refresh to Syncer; Syncer owns timer/task sync.
  - Anchors: ThorChainKit@ad9c748:Sources/ThorChainKit/Core/Kit.swift, TronKit@aa691bcd:Sources/TronKit/Core/Kit.swift:212
| F-003 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChainKit durable pending/send runtime has a legitimate lifecycle analog in TronKit TransactionManager but must remain protocol-specific because it stores exact Cosmos bytes ... |
  - Serena: Integration-pinned ThorChainKit exposes SendRuntime, SendCoordinator, SendJournal, PendingTransactionRepository, and SequenceReservationStore.
  - rg: Pinned TronKit TransactionManager owns pending storage projection and failed-pending transition.
  - Anchors: ThorChainKit@ad9c748:Sources/ThorChainKit/Send/Internal/SendRuntime.swift, TronKit@aa691bcd:Sources/TronKit/Core/TransactionManager.swift:169
| F-004 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | EvmKit supplies local construction-before-transport and provider-seam analogs, but its broad rotating NodeApiProvider is a rejected provider policy for ThorChainKit. |
  - Serena: Integration-pinned ThorChainKit contains DirectSignCodec, SigningRequestFactory, ThorNodeSendClient, and actor EndpointPool.
  - rg: Pinned EvmKit encodes signed bytes locally before send and retries every NodeApiProvider error across URLs.
  - Anchors: ThorChainKit@ad9c748:Sources/ThorChainKit/Protocol/DirectSignCodec.swift, EvmKit@be028631:Sources/EvmKit/Api/Core/NodeApiProvider.swift:26
| F-005 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The current local Unstoppable ThorChain integration uses the expected manager/wrapper/adapter/SendNew vertical, but its stored signer and manager-owned Kit.start are known devia... |
  - Serena: Current local ThorChainKitWrapper stores signer; ThorChainKitManager derives it and calls kit.start; ThorChainAdapter.start is empty.
  - rg: Current Unstoppable TRON vertical uses manager/wrapper/adapter/send-handler naming, but product roadmap requires ThorChain adapter-owned lifecycle and ephemeral signing.
  - Anchors: unstoppable feature/THR-160-s2-07-unstoppable:ThorChainKitManager.swift:92, unstoppable feature/THR-160-s2-07-unstoppable:ThorChainAdapter.swift:50

## Adversarial decisions


## Verification and acceptance

- spec-whitespace verification/passed: No whitespace errors in the new Markdown specification.
- integration-pin acceptance/passed: All three local Unstoppable dependency declarations resolve ThorChainKit to ad9c748cc7d2952fba9ed4a64c13c07f8cb15bd5.
- implementation-tests unrun/not_run: This deliverable is a read-only architecture/specification audit; no source implementation changed and no build/test command was warranted.

## Bugs and limitations

### B-001: No per-project freshness proof in preflight health

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.memory.health / E-0002 / n/a
- Reproduction: Call palace.memory.health; it exposes only one global latest ingest timestamp.
- Expected: Per-project freshness or an authoritative current-tree mapping for each analog.
- Actual: Global ingest metadata cannot establish freshness for tron-kit, evm-kit, or uw-ios-app.
- Impact: Historical index results cannot be treated as current without pinned Git/local verification.
- Workaround: Use Palace only for bounded discovery and verify every selected analog against the recorded commit using Git, Serena, and rg.
- Anchors: palace.memory.health 2026-07-29

### B-002: Analog project freshness and identity are unchecked

- Class/severity/confidence/status: environment_drift / high / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0003 / n/a
- Reproduction: Call palace.memory.list_projects; tron-kit, evm-kit, and uw-ios-app report freshness_state unknown and identity_check unchecked.
- Expected: Freshness and mount identity that can be compared directly to the source checkout.
- Actual: Indexed commit is present, but project records do not prove current worktree or origin relation.
- Impact: A stale or mismapped symbol could otherwise be selected as an implementation analog.
- Workaround: Treat indexed commits as historical pins only; independently open the mounted Git trees and retain the local integration pin as ThorChainKit authority.
- Anchors: palace.memory.list_projects 2026-07-29

### B-005: Conflicting freshness metadata for tron-kit

- Class/severity/confidence/status: stale_index / high / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0005 / n/a
- Reproduction: Compare palace.memory.list_projects freshness_state=unknown with palace.code.semantic_search freshness_state=current_local_tree for tron-kit.
- Expected: One consistent, independently auditable freshness state.
- Actual: Project overview and semantic result report incompatible freshness detail.
- Impact: Indexed discovery cannot determine the authoritative source version alone.
- Workaround: Use the query only to discover paths, then verify exact file and revision in the mounted Git checkout; do not rely on freshness metadata.
- Anchors: Palace tron-kit discovery 2026-07-29

### B-006: Conflicting freshness metadata for tron-kit

- Class/severity/confidence/status: stale_index / high / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0006 / n/a
- Reproduction: Compare palace.memory.list_projects freshness_state=unknown with palace.code.semantic_search freshness_state=current_local_tree for tron-kit.
- Expected: One consistent, independently auditable freshness state.
- Actual: Project overview and semantic result report incompatible freshness detail.
- Impact: Indexed discovery cannot determine the authoritative source version alone.
- Workaround: Use the query only to discover paths, then verify exact file and revision in the mounted Git checkout; do not rely on freshness metadata.
- Anchors: Palace tron-kit discovery 2026-07-29

### B-007: Conflicting freshness metadata for evm-kit

- Class/severity/confidence/status: stale_index / high / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0007 / n/a
- Reproduction: Compare palace.memory.list_projects freshness_state=unknown with palace.code.semantic_search freshness_state=current_local_tree for evm-kit.
- Expected: One consistent, independently auditable freshness state.
- Actual: Project overview and semantic result report incompatible freshness detail.
- Impact: Indexed discovery cannot determine the authoritative source version alone.
- Workaround: Use the query only to discover paths, then verify exact file and revision in the mounted Git checkout; do not rely on freshness metadata.
- Anchors: Palace evm-kit discovery 2026-07-29

### B-008: Conflicting freshness metadata for uw-ios-app

- Class/severity/confidence/status: stale_index / high / confirmed / workaround
- Tool/events/claims: palace.code.semantic_search / E-0008 / n/a
- Reproduction: Compare palace.memory.list_projects freshness_state=unknown with palace.code.semantic_search freshness_state=current_local_tree for uw-ios-app.
- Expected: One consistent, independently auditable freshness state.
- Actual: Project overview and semantic result report incompatible freshness detail.
- Impact: Indexed discovery cannot determine the authoritative source version alone.
- Workaround: Use the query only to discover paths, then verify exact file and revision in the mounted Git checkout; do not rely on freshness metadata.
- Anchors: Palace uw-ios-app discovery 2026-07-29

### B-009: Historical TronKit checkout has no active Swift language server

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: serena / n/a / n/a
- Reproduction: Activate /Users/Shared/Ios/Gimle-Repos/HorizontalSystems/TronKit.Swift and request symbols for Sources/TronKit/Core/Kit.swift.
- Expected: Symbol overview and declaration retrieval for the pinned Swift source.
- Actual: Serena reports active language servers: [].
- Impact: Serena cannot independently navigate the historical analog.
- Workaround: Use the exact checked-out Git revision and narrow rg source anchors; retain Serena verification for the integration-pinned ThorChainKit and current Unstoppable branch.
- Anchors: TronKit.Swift Serena activation 2026-07-29

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
