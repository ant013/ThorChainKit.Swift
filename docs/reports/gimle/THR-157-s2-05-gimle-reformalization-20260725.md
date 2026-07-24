# Gimle reliability report: thr-157-reformalize-20260725

- Task: THR-157
- Workflow/phase: analog_change / awaiting_approval
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 76e3a7195d68140dcd137a3f978ae37f6963b7f5
- Final HEAD: n/a
- Gimle runtime: native-dev
- Indexed commit: n/a

## Metrics

- Calls: 10 (success 8, warning 1, error 0, false-success 1)
- Useful-call rate: 100.0%
- Response-byte coverage: 0/10; total n/a
- Duration coverage: 0/10; total n/a ms
- Gimle agreement: 75.0%
- Gimle contradiction: 0.0%
- Location validity: 75.0%; coverage 4/4
- Freshness coverage: 75.0%
- Replacement/fallback claims: 0
- Bugs: 4
- Analog slices/candidates: 1/9

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.get_code_snippet | 1 | 0 | 0 | 1 |
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.code.search_graph | 3 | 1 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1, 'coverage_gap': 1, 'environment_drift': 1, 'caller_error': 1}
Bug severities: {'high': 1, 'medium': 3}
Bug statuses: {'workaround': 4}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | success | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | success | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | success | success | n/a/18 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0004 | evidence | palace.code.list_passthrough_projects | success | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0005 | evidence | palace.code.search_graph | success | success | n/a/5 | n/a | n/a | yes | 21153f8cf208772c | n/a |
| E-0006 | evidence | palace.code.search_graph | success | success | n/a/5 | n/a | n/a | yes | f0834150d7bd526d | n/a |
| E-0007 | evidence | palace.code.search_graph | success | success | n/a/5 | n/a | n/a | yes | dd383e37607e8886 | n/a |
| E-0008 | evidence | palace.code.search_graph | success | warning | n/a/0 | n/a | n/a | yes | 7a0bc19b69282778 | empty result without target-project coverage proof; current-tree fallback required |
| E-0009 | evidence | palace.code.get_code_snippet | success | success | n/a/1 | n/a | n/a | yes | 256fc826e8b1630f | n/a |
| E-0010 | evidence | palace.code.get_code_snippet | success | false_success | n/a/0 | n/a | n/a | yes | 2cbcbdb2cc46b9d1 | nested ok=false ambiguous_qualified_name |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S2-05 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S205-BITCOIN | C-S205-THORCHAIN, C-S205-THORCHAIN-CONTRACT, C-S205-THORCHAIN-TEST, C-S205-THORCHAIN-RESP, C-S205-TRON, C-S205-EVM, C-S205-VULTISIG | C-S205-REMOTE |
  - Conflict: BitcoinCore persistence/relay is UTXO/P2P and does not provide Cosmos CheckTx, sequence reservations, strict REST parsing, or shared-writer observation recovery.; resolution: Retain BitcoinCore only as the lifecycle/persistence spine; implement the approved THOR-specific journal, generation CAS, CheckTx classifier, reservation link, publication barrier, and repair semantics from the current S2-05 spec.
  - Conflict: TronKit/Vultisig permit confirmation-centric or permissive behavior that can claim remote success without local hash proof.; resolution: Use them only for pending projection and route vocabulary; reject permissive decoding, raw log propagation, and remote-only identity; fail closed as unknown.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-S205-BITCOIN | S2-05 | kept | F-157-101 | implementation | lifecycle | known_current | /Users/ant013/Ios/HorizontalSystems/BitcoinCore.Swift/Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift |
| C-S205-THORCHAIN | S2-05 | supporting | F-157-100 | composition | dependencies | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift; Sources/ThorChainKit/Send/Storage/DatabaseRuntime.swift; Sources/ThorChainKit/Send/Storage/SendRuntimeRegistry.swift |
| C-S205-THORCHAIN-CONTRACT | S2-05 | supporting | F-157-100 | contract | boundary | known_current | Sources/ThorChainKit/Send/Domain/PendingTransaction.swift |
| C-S205-THORCHAIN-TEST | S2-05 | supporting | F-157-100 | test | tests | known_current | Tests/ThorChainKitTests/KitCompositionTests.swift |
| C-S205-TRON | S2-05 | supporting | F-157-103 | consumer | lifecycle | known_current | /Users/ant013/Ios/HorizontalSystems/TronKit.Swift/Sources/TronKit/Core/TransactionManager.swift |
| C-S205-EVM | S2-05 | supporting | F-157-102 | contract | trust | known_current | /Users/ant013/Ios/HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Core/TransactionBuilder.swift |
| C-S205-VULTISIG | S2-05 | supporting | F-157-104 | lifecycle_error | state_errors | known_current | sources/vultisig-ios/VultisigApp/VultisigApp/Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift |
| C-S205-REMOTE | S2-05 | rejected | F-157-105 | counterexample | responsibility | known_current | /Users/ant013/Ios/HorizontalSystems/TronKit.Swift/Sources/TronKit/Core/TransactionSender.swift |
| C-S205-THORCHAIN-RESP | S2-05 | supporting | F-157-100 | contract | responsibility | known_current | Sources/ThorChainKit/Send/Internal/SendRuntime.swift; Sources/ThorChainKit/Send/Domain/PendingTransaction.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-157-IDENTITY | 1 | yes | UNVERIFIABLE | no | none | E-0001, E-0003 | unknown | unknown | The active ThorChainKit repository at main 76e3a719 is not represented by a registered Gimle/Palace project or source-bound runtime identity. |
  - Serena: n/a
  - rg: n/a
  - Anchors: /Users/ant013/Data/AI/thorchain@76e3a7195d68140dcd137a3f978ae37f6963b7f5
| F-157-100 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | At the exact S2-04 merged main head, ThorChainKit already has the lifecycle/composition spine that S2-05 must extend: actor-owned SendRuntime admission and generation state, sha... |
  - Serena: n/a
  - rg: Sources/ThorChainKit/Send/Internal/SendRuntime.swift:20-236; Sources/ThorChainKit/Send/Storage/DatabaseRuntime.swift:1-140; Sources/ThorChainKit/Send/Storage/SendRuntimeRegistry.swift:1-95; Sources/ThorChainKit/Send/Storage/SequenceReservationStore.swift:1-54; Sources/ThorChainKit/Send/Domain/PendingTransaction.swift:1-60; Sources/ThorChainKit/Core/Kit+Send.swift:1-30; Tests/ThorChainKitTests/KitCompositionTests.swift:5-141; Tests/ThorChainKitTests/SendPublicApiTests.swift:1-34
  - Anchors: HEAD@76e3a7195d68140dcd137a3f978ae37f6963b7f5
| F-157-101 | 1 | yes | MATCH | yes | rg | E-0009 | valid | known_current | BitcoinCore provides a coherent lifecycle/persistence analog: TransactionCreator verifies sendability, processes the created transaction into PendingTransactionProcessor storage... |
  - Serena: n/a
  - rg: BitcoinCore.Swift/Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift:4-39; PendingTransactionProcessor.swift:132-142; external git rev-parse HEAD=5b49f424f495904cf06519b1a7b861ef37b45b50
  - Anchors: bitcoin-core@5b49f424f495904cf06519b1a7b861ef37b45b50
| F-157-102 | 1 | yes | MATCH | yes | rg | E-0007 | valid | known_current | EvmKit derives transaction identity by hashing the exact encoded signed transaction bytes and stores that hash in its transaction model; this supports S2-05 local/remote hash-eq... |
  - Serena: n/a
  - rg: EvmKit.Swift/Sources/EvmKit/Core/TransactionBuilder.swift:13-16,39-77; external git rev-parse HEAD=be0286317c202084784c5a695928cdc985c4ff7b
  - Anchors: evm-kit@be0286317c202084784c5a695928cdc985c4ff7b
| F-157-103 | 1 | yes | MATCH | yes | rg | E-0006 | valid | known_current | TronKit supplies a supporting pending-projection contract: pending rows are persisted by hash, exposed through a manager, and confirmed rows are not downgraded when a duplicate ... |
  - Serena: n/a
  - rg: TronKit.Swift/Sources/TronKit/Core/TransactionManager.swift:50-51,59-79,161-200; Tests/TronKitTests/TransactionManagerPendingTests.swift:7-55; external git rev-parse HEAD=aa691bcd8c79d57a554d72a4996bec4d7e1afce5
  - Anchors: tron-kit@aa691bcd8c79d57a554d72a4996bec4d7e1afce5
| F-157-104 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The checked Vultisig THOR-specific broadcast service is a supporting protocol counterexample: it uses Cosmos REST broadcast and treats code 0 or 19 as success, but permissive Co... |
  - Serena: n/a
  - rg: sources/vultisig-ios/VultisigApp/VultisigApp/Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift:36-55; .../Blockchain/Cosmos/Models/TransactionManager/TransactionBroadcastResponse.swift:10-24; external git rev-parse HEAD=d3123dbe6ef1103937c272a8b1cd81f613af0acc
  - Anchors: vultisig-ios@d3123dbe6ef1103937c272a8b1cd81f613af0acc
| F-157-105 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | TronKit TransactionSender is a rejected counterexample: it creates a transaction, signs the returned transaction ID, and broadcasts in one flow without the S2-05 durable exact-b... |
  - Serena: n/a
  - rg: TronKit.Swift/Sources/TronKit/Core/TransactionSender.swift:12-66; external git rev-parse HEAD=aa691bcd8c79d57a554d72a4996bec4d7e1afce5
  - Anchors: tron-kit@aa691bcd8c79d57a554d72a4996bec4d7e1afce5

## Adversarial decisions

- ARCH-157-01@2 ACCEPT: Two-level runtime ownership is explicit and scoped
- ARCH-157-02@2 ACCEPT: Current-family retry capability is fail-closed
- SEC-157-01@2 ACCEPT: sequenceAdvanced has an explicit persisted pre-CAS/no-I-O retry guard
- SEC-157-02@2 ACCEPT: Redaction policy is internally consistent
- SEC-157-03@2 ACCEPT: Strict response authority remains hash-first and fail-closed
- VOP-157-01@2 ACCEPT: Use Apple xcrun Swift and discovery assertions
- VOP-157-02@2 ACCEPT: Every AC has a named observable
- VOP-157-03@2 ACCEPT: Restart evidence must cross process boundary
- VOP-157-04@2 ACCEPT: Observation/publication seam is deterministic
- VOP-157-05@2 ACCEPT: Live family compatibility is an explicit gate

## Verification and acceptance


## Bugs and limitations

### GIMLE-157-001: ThorChainKit is not registered in Gimle/Palace and runtime identity is not source-bound

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.health.status + palace.memory.list_projects / E-0001 / n/a
- Reproduction: Health returns runtime git_sha_label native-dev with source_checkout /Users/ant013/Android/Gimle-Palace-serving; project listing contains no ThorChainKit or Users-ant013-Data-AI-thorchain project.
- Expected: A registered project and source commit mapping for the target repository allow Gimle analog claims to be tied to the active worktree.
- Actual: No ThorChainKit project or git mount is registered; runtime exposes no target source SHA.
- Impact: Gimle cannot provide load-bearing target-repository evidence or freshness for this formalization.
- Workaround: Use codebase-memory project Users-ant013-Data-AI-thorchain plus targeted current-tree rg/git checks; keep Gimle trust RED and exclude any unverified Gimle claim.
- Anchors: /Users/ant013/Data/AI/thorchain@76e3a7195d68140dcd137a3f978ae37f6963b7f5,Gimle project list at 2026-07-25

### GIMLE-157-002: Unstoppable pending analog query has no coverage proof

- Class/severity/confidence/status: coverage_gap / medium / probable / workaround
- Tool/events/claims: palace.code.search_graph / E-0008 / n/a
- Reproduction: palace.code.search_graph(project=uw-ios-app,name_pattern=PendingTransactionManager,limit=5) returned zero rows.
- Expected: An empty result should carry sufficient project/extractor coverage to establish absence or be explicitly classified as incomplete.
- Actual: The result is empty without a completeness envelope; local repository policy keeps Unstoppable out of this slice.
- Impact: Unstoppable cannot be selected as a load-bearing S2-05 analog.
- Workaround: Keep S2-07 out of scope and use current-tree ThorChainKit plus verified external analogs only.
- Anchors: uw-ios-app project listing; current HEAD 76e3a7195d68140dcd137a3f978ae37f6963b7f5

### GIMLE-157-003: Serena navigation is unavailable in the assigned runtime

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: Serena / n/a / n/a
- Reproduction: Enabled tools expose codebase-memory and Palace code tools but no Serena activation or symbol-navigation tool.
- Expected: Serena is available for independent symbol navigation in the active ThorChainKit worktree.
- Actual: No Serena tool is callable in this run.
- Impact: Independent symbol navigation cannot be recorded; load-bearing claims require exact current-tree rg/git fallback.
- Workaround: Use targeted rg, git show, and codebase-memory snippets where available; do not claim Serena evidence.
- Anchors: Enabled tool inventory at 2026-07-25; current HEAD 76e3a7195d68140dcd137a3f978ae37f6963b7f5

### GIMLE-157-004: Mangled TronKit qualified-name lookup is ambiguous

- Class/severity/confidence/status: caller_error / medium / confirmed / workaround
- Tool/events/claims: palace.code.get_code_snippet / E-0010 / n/a
- Reproduction: Requesting qualified_name TronKit s%3A7TronKit17TransactionManagerC matched two symbols and returned nested ok=false ambiguous_qualified_name.
- Expected: A selected symbol lookup returns one source location or a bounded candidate list for refinement.
- Actual: The guessed qualified name is ambiguous and cannot be accepted as source evidence.
- Impact: This single Gimle lookup cannot verify the TronKit candidate.
- Workaround: Use exact local git HEAD aa691bcd and targeted rg anchors; retain TronKit only as supporting evidence from current-tree fallback.
- Anchors: tron-kit@aa691bcd8c79d57a554d72a4996bec4d7e1afce5

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
