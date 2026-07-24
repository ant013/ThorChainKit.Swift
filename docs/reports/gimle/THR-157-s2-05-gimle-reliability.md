# Gimle reliability report: thr-157-20260724-cto

- Task: THR-157
- Workflow/phase: analog_change / adversarial_review
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 3e8d103821a5c2388143a0ce8d99d4d7c674d9ed
- Final HEAD: n/a
- Gimle runtime: native-dev
- Indexed commit: n/a

## Metrics

- Calls: 11 (success 5, warning 6, error 0, false-success 0)
- Useful-call rate: 54.5%
- Response-byte coverage: 0/11; total n/a
- Duration coverage: 0/11; total n/a ms
- Gimle agreement: 50.0%
- Gimle contradiction: 0.0%
- Location validity: 75.0%; coverage 4/4
- Freshness coverage: 50.0%
- Replacement/fallback claims: 0
- Bugs: 8
- Analog slices/candidates: 1/10

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.semantic_search | 2 | 6 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1, 'environment_drift': 1, 'caller_error': 4, 'stale_index': 1, 'coverage_gap': 1}
Bug severities: {'high': 2, 'medium': 6}
Bug statuses: {'open': 8}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | 200 | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.health | 200 | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace.memory.list_projects | 200 | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0004 | evidence | palace.code.semantic_search | 200 | warning | 0/0 | n/a | n/a | no | b1c50020d7c43c1a | scope_excluded_count>0 and returned_count=0; current-tree fallback required |
| E-0005 | evidence | palace.code.semantic_search | 200 | warning | 0/0 | n/a | n/a | no | 3b5dabdc6a0bd33d | scope_excluded_count>0 and returned_count=0; current-tree fallback required |
| E-0006 | evidence | palace.code.semantic_search | 200 | warning | 0/0 | n/a | n/a | no | abd20cb94663eb5f | scope_excluded_count>0 and returned_count=0; current-tree fallback required |
| E-0007 | evidence | palace.code.semantic_search | 200 | warning | 0/0 | n/a | n/a | no | 2692ef204f21eef5 | scope_excluded_count>0 and returned_count=0; current-tree fallback required |
| E-0008 | evidence | palace.code.semantic_search | 200 | warning | 10/5 | n/a | n/a | yes | fd7cdbd5da26a8f6 | indexed_commit is null; freshness_state=unknown |
| E-0009 | evidence | palace.code.semantic_search | 200 | success | 5/5 | n/a | n/a | yes | 65a2b57df31217b6 | n/a |
| E-0010 | evidence | palace.code.semantic_search | 200 | success | 11/5 | n/a | n/a | yes | 939cf27c6def5448 | n/a |
| E-0011 | evidence | palace.code.semantic_search | 200 | warning | 0/0 | n/a | n/a | no | 353a885adf58fdaf | returned_count=0 with scope_excluded_count=10; exact local fallback required |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S2-05 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S205-BITCOIN | C-S205-THORCHAIN, C-S205-THORCHAIN-LIFECYCLE, C-S205-THORCHAIN-CONTRACT, C-S205-THORCHAIN-DEPENDENCY, C-S205-BITCOIN-TEST, C-S205-EVM, C-S205-TRON, C-S205-VULTISIG | C-S205-REMOTE-COUNTER |
  - Conflict: BitcoinCore persists before relay but is UTXO/P2P and lacks Cosmos CheckTx, sequence reservation, strict REST parsing, or shared-writer observation recovery.; resolution: Retain BitcoinCore only as lifecycle/persistence spine; implement THOR-specific journal schema, CheckTx classifier, exact hash equality, generation CAS, shared GRDB writer, pending publication barrier, retry policy, and repair.
  - Conflict: TronKit and Vultisig expose permissive/confirmation-centric behavior that can overwrite, log raw upstream data, or claim success without local hash proof.; resolution: Use them only for projection and endpoint vocabulary; reject try!, raw logging, permissive JSON, and remote identity. Fail closed as unknown and retain durable ownership.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-S205-THORCHAIN | S2-05 | supporting | F-157-000 | composition | boundary | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift; Sources/ThorChainKit/Core/Kit.swift; Sources/ThorChainKit/Send/Domain/PendingTransaction.swift |
| C-S205-BITCOIN | S2-05 | kept | F-157-001 | implementation | lifecycle | known_current | /Users/ant013/Ios/HorizontalSystems/BitcoinCore.Swift/Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift |
| C-S205-BITCOIN-TEST | S2-05 | supporting | F-157-001 | test | tests | known_current | /Users/ant013/Ios/HorizontalSystems/BitcoinCore.Swift/Tests/BitcoinCoreTests |
| C-S205-EVM | S2-05 | supporting | F-157-002 | contract | trust | known_current | /Users/ant013/Ios/HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Core/TransactionBuilder.swift |
| C-S205-TRON | S2-05 | supporting | F-157-003 | consumer | lifecycle | known_current | /Users/ant013/Ios/HorizontalSystems/TronKit.Swift/Sources/TronKit/Core/TransactionManager.swift |
| C-S205-VULTISIG | S2-05 | supporting | F-157-004 | contract | state_errors | known_current | /Users/ant013/Data/AI/thorchain/sources/vultisig-ios/VultisigApp/VultisigApp/Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift |
| C-S205-REMOTE-COUNTER | S2-05 | rejected | F-157-005 | counterexample | trust | known_current | /Users/ant013/Ios/HorizontalSystems/TronKit.Swift/Sources/TronKit/Core/TransactionSender.swift |
| C-S205-THORCHAIN-LIFECYCLE | S2-05 | supporting | F-157-000 | lifecycle_error | lifecycle | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift |
| C-S205-THORCHAIN-CONTRACT | S2-05 | supporting | F-157-000 | contract | responsibility | known_current | Sources/ThorChainKit/Send/Domain/PendingTransaction.swift |
| C-S205-THORCHAIN-DEPENDENCY | S2-05 | supporting | F-157-000 | composition | dependencies | known_current | Sources/ThorChainKit/Core/KitDependencies.swift; Sources/ThorChainKit/Core/KitFactory.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-157-000 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | At the S2-04 implementation base, ThorChainKit SendRuntime owns lifecycle admission/generation state and Kit exposes pending snapshot/status publishers that intentionally remain... |
  - Serena: Serena unavailable; exact current-tree rg used.
  - rg: Sources/ThorChainKit/Send/Internal/SendRuntime.swift:29-120; Sources/ThorChainKit/Core/Kit.swift:13-59; Tests/ThorChainKitTests/KitCompositionTests.swift:5-23; Tests/ThorChainKitTests/SendPublicApiTests.swift:7-34
  - Anchors: origin/main@3e8d103821a5c2388143a0ce8d99d4d7c674d9ed
| F-157-001 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | BitcoinCore stores a signed/created transaction through its pending processor before invoking the sender, and later reloads new pending transactions for transport. |
  - Serena: Serena unavailable for external checkout; exact local Git/rg used.
  - rg: BitcoinCore@5b49f424:TransactionCreator.swift:25-33,57; PendingTransactionProcessor.swift:132-145; TransactionSender.swift:145-160
  - Anchors: bitcoin-core@5b49f424
| F-157-002 | 1 | yes | MATCH | yes | serena+rg | E-0010 | valid | known_current | EvmKit derives the local transaction hash from the exact encoded signed transaction bytes and retains that identity in the transaction model. |
  - Serena: Serena unavailable; exact local Git/rg used.
  - rg: EvmKit@be028631:TransactionBuilder.swift:13-24,39-65
  - Anchors: evm-kit@be0286317c202084784c5a695928cdc985c4ff7b
| F-157-003 | 1 | yes | MATCH | yes | serena+rg | E-0009 | valid | known_current | TronKit persists externally supplied pending transaction hashes as unconfirmed rows, exposes pending projections, and avoids overwriting existing/confirmed rows through its tran... |
  - Serena: Serena unavailable; exact local Git/rg used.
  - rg: TronKit@aa691bcd:TransactionManager.swift:51-61,169-190; TransactionStorage.swift:184-191; TransactionManagerPendingTests.swift
  - Anchors: tron-kit@aa691bcd8c79d57a554d72a4996bec4d7e1afce5
| F-157-004 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Vultisig THORChain broadcasts through the Cosmos REST txs endpoint and currently treats CheckTx code 0 or code 19 as success, but uses permissive JSON decoding and raw upstream ... |
  - Serena: Serena unavailable; exact local Git/rg used.
  - rg: sources/vultisig-ios@d3123db:ThorchainBroadcastTransactionService.swift:14-52; TransactionBroadcastResponse.swift:8-33
  - Anchors: vultisig-ios@d3123db
| F-157-001-GIMLE | 1 | yes | PARTIAL | no | gimle | E-0008 | valid | unknown | Gimle semantic search identifies BitcoinCore TransactionCreator as a pre-broadcast persistence analog, but its indexed freshness is unknown. |
  - Serena: n/a
  - rg: n/a
  - Anchors: bitcoin-core semantic result E-0008
| F-157-005 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | TronKit TransactionSender can create/sign a transaction and then broadcast it, which is a rejected counterexample for S2-05 because it does not establish exact-byte durable reco... |
  - Serena: Serena unavailable; exact local Git/rg used.
  - rg: TronKit@aa691bcd:Sources/TronKit/Core/TransactionSender.swift:12-72; rg shows nodeApiProvider create/sign/broadcast sequence.
  - Anchors: tron-kit@aa691bcd
| F-157-005-GIMLE | 1 | yes | UNVERIFIABLE | no | gimle | E-0011 | unknown | unknown | Gimle returned no Unstoppable transaction lifecycle candidate for the bounded query; this is not evidence of absence. |
  - Serena: n/a
  - rg: n/a
  - Anchors: uw-ios-app semantic result E-0011

## Adversarial decisions

- D-157-01@1 ACCEPT: Freshness and identity are safe despite Gimle RED
- D-157-02@1 ACCEPT: BitcoinCore remains a coherent lifecycle spine
- D-157-03@1 ACCEPT: Vertical family is complete
- D-157-04@1 ACCEPT: Known inherited defects are excluded
- D-157-05@1 ACCEPT: Every requirement has a test and no excess scope
- D-157-06@1 ACCEPT: Failure and concurrency behavior is safe
- D-157-07@1 ACCEPT: Tests observe behavior rather than implementation detail
- D-157-08@1 ACCEPT: No smaller safe design was omitted

## Verification and acceptance


## Bugs and limitations

### G-157-001: ThorChainKit project is absent from Palace registry

- Class/severity/confidence/status: mapping_bug / high / confirmed / open
- Tool/events/claims: palace.memory.list_projects / n/a / n/a
- Reproduction: List registered Palace projects; no ThorChainKit or Users-ant013-Data-AI-thorchain project appears.
- Expected: A registered project maps the target repository to a code/memory/git identity.
- Actual: Target is available in codebase-memory only; Palace git_repos_unregistered includes no ThorChainKit entry and no target project overview can be resolved.
- Impact: Gimle/Palace analog discovery and freshness cannot be treated as load-bearing for this slice.
- Workaround: Use codebase-memory for graph discovery and exact current-tree Git/rg verification; keep Gimle trust RED/YELLOW and report the mapping defect.
- Anchors: n/a

### G-157-002: Serena workspace tool is unavailable in this run

- Class/severity/confidence/status: environment_drift / medium / confirmed / open
- Tool/events/claims: Serena / n/a / n/a
- Reproduction: Inspect enabled tools for Serena capability; no Serena tool is exposed.
- Expected: Serena is available for independent symbol navigation in the assigned workspace.
- Actual: No Serena tool is callable; no Serena activation or symbol result can be recorded.
- Impact: Independent symbol navigation is unavailable; exact Git/rg checks must cover load-bearing current-tree claims.
- Workaround: Use targeted rg and Git reads on the exact branch/head; do not claim Serena evidence.
- Anchors: n/a

### G-157-003: Application source scope excludes registered Swift project symbols

- Class/severity/confidence/status: caller_error / medium / confirmed / open
- Tool/events/claims: palace.code.semantic_search / E-0004 / n/a
- Reproduction: Semantic search with source_scopes=[application] on bitcoin-core, tron-kit, evm-kit, and uw-ios-app returned zero results while coverage reported dependency/project symbols and scope exclusions.
- Expected: A bounded semantic search should return relevant project symbols or report an explicit taxonomy mismatch.
- Actual: All four calls returned zero results with scope_excluded_count and no warning; exact local Git/rg found the expected symbols.
- Impact: Semantic search cannot be used as the candidate source for this run without relaxing scope; it reduces Gimle utility but does not invalidate local analog evidence.
- Workaround: Use exact local repository heads and targeted rg; retry Gimle only with verified source-scope vocabulary.
- Anchors: n/a

### G-157-004: BitcoinCore Gimle freshness is unknown

- Class/severity/confidence/status: stale_index / high / confirmed / open
- Tool/events/claims: palace.code.semantic_search / E-0008 / n/a
- Reproduction: Semantic search returned indexed_commit=null and freshness_state=unknown for bitcoin-core.
- Expected: Selected Gimle analog result has a known indexed commit matching the verified local checkout.
- Actual: BitcoinCore result has no indexed commit despite local checkout at 5b49f424.
- Impact: BitcoinCore can remain the primary only because exact local Git/rg verification independently establishes the fact; Gimle cannot prove freshness.
- Workaround: Use local Git head 5b49f424 and targeted rg as the decision basis; keep Gimle-backed claim rejected or partial.
- Anchors: n/a

### G-157-005: Unstoppable lifecycle query returns no candidate

- Class/severity/confidence/status: coverage_gap / medium / probable / open
- Tool/events/claims: palace.code.semantic_search / E-0011 / n/a
- Reproduction: Semantic search for TransactionManager pendingTransactions returned zero results with scope_excluded_count=10.
- Expected: Search either returns a relevant symbol or reports a complete absence with valid taxonomy coverage.
- Actual: No candidate returned; local rg finds no matching ValueObservation/pending storage in the scoped paths used.
- Impact: Unstoppable remains a non-load-bearing context check only; no design decision uses it.
- Workaround: Do not use Unstoppable as a selected analog for S2-05; follow repository policy and keep S2-07 out of scope.
- Anchors: n/a

### G-157-006: bitcoin-core source scope query returned zero

- Class/severity/confidence/status: caller_error / medium / confirmed / open
- Tool/events/claims: palace.code.semantic_search / E-0005 / n/a
- Reproduction: Semantic search with source_scopes=[application] returned zero candidates while registered project/dependency coverage existed.
- Expected: The bounded source scope returns relevant project symbols or explicitly reports that the taxonomy excludes them.
- Actual: returned_count=0 with scope_excluded_count>0 and no warning envelope.
- Impact: This query shape is unusable for candidate discovery; local exact-tree fallback is required.
- Workaround: Use semantic search without source_scopes and verify every candidate with local Git/rg.
- Anchors: n/a

### G-157-007: tron-kit source scope query returned zero

- Class/severity/confidence/status: caller_error / medium / confirmed / open
- Tool/events/claims: palace.code.semantic_search / E-0006 / n/a
- Reproduction: Semantic search with source_scopes=[application] returned zero candidates while registered project/dependency coverage existed.
- Expected: The bounded source scope returns relevant project symbols or explicitly reports that the taxonomy excludes them.
- Actual: returned_count=0 with scope_excluded_count>0 and no warning envelope.
- Impact: This query shape is unusable for candidate discovery; local exact-tree fallback is required.
- Workaround: Use semantic search without source_scopes and verify every candidate with local Git/rg.
- Anchors: n/a

### G-157-008: evm-kit source scope query returned zero

- Class/severity/confidence/status: caller_error / medium / confirmed / open
- Tool/events/claims: palace.code.semantic_search / E-0007 / n/a
- Reproduction: Semantic search with source_scopes=[application] returned zero candidates while registered project/dependency coverage existed.
- Expected: The bounded source scope returns relevant project symbols or explicitly reports that the taxonomy excludes them.
- Actual: returned_count=0 with scope_excluded_count>0 and no warning envelope.
- Impact: This query shape is unusable for candidate discovery; local exact-tree fallback is required.
- Workaround: Use semantic search without source_scopes and verify every candidate with local Git/rg.
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
