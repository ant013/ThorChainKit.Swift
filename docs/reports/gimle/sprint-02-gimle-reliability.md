# Gimle reliability report: SPRINT-02-NATIVE-SEND-ARCH-20260717

- Task: SPRINT-02-NATIVE-SEND-ARCH
- Workflow/phase: analog_change / awaiting_approval
- Trust: **YELLOW**
- Repository: /Users/ant013/Data/AI/thorchain-worktrees/sprint-02-architecture
- Base HEAD: 771bad30bb4ff20fa32ed0f4be260a7b934899e9
- Final HEAD: n/a
- Gimle runtime: 0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: n/a

## Metrics

- Calls: 32 (success 17, warning 1, error 14, false-success 0)
- Useful-call rate: 56.2%
- Response-byte coverage: 0/32; total n/a
- Duration coverage: 22/32; total 627400 ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 11/11
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 12
- Analog slices/candidates: 7/29

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 0 | 0 | 2 | 0 |
| palace.code.search_code | 1 | 1 | 0 | 0 |
| palace.code.semantic_search | 12 | 0 | 0 | 0 |
| palace.health.status | 1 | 0 | 9 | 0 |
| palace.memory.get_project_overview | 2 | 0 | 1 | 0 |
| palace.memory.health | 1 | 0 | 1 | 0 |
| palace.memory.list_projects | 0 | 0 | 1 | 0 |

Bug classes: {'environment_drift': 10, 'mapping_bug': 1, 'coverage_gap': 1}
Bug severities: {'medium': 7, 'high': 5}
Bug statuses: {'workaround': 7, 'fixed': 5}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 81000 | no | 44136fa355b3678a | Parallel preflight returned no envelope within 81 seconds and was terminated |
| E-0002 | preflight | palace.memory.health | cancelled_by_orchestrator | error | n/a/n/a | n/a | 81000 | no | 44136fa355b3678a | Parallel preflight returned no envelope within 81 seconds and was terminated |
| E-0003 | preflight | palace.memory.list_projects | cancelled_by_orchestrator | error | n/a/n/a | n/a | 81000 | no | 44136fa355b3678a | Parallel preflight returned no envelope within 81 seconds and was terminated |
| E-0004 | preflight | palace.code.list_passthrough_projects | cancelled_by_orchestrator | error | n/a/n/a | n/a | 81000 | no | 44136fa355b3678a | Parallel preflight returned no envelope within 81 seconds and was terminated |
| E-0005 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 60000 | no | 44136fa355b3678a | Isolated call returned no envelope within 60 seconds and was terminated |
| E-0006 | preflight | palace.code.list_passthrough_projects | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 44136fa355b3678a | Isolated call returned no envelope within 30 seconds and was terminated |
| E-0007 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 44136fa355b3678a | Third isolated health call returned no envelope within 30 seconds and was terminated |
| E-0008 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 44136fa355b3678a | No MCP response envelope after 30 seconds; call was terminated |
| E-0009 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 44136fa355b3678a | No MCP response envelope after 30 seconds; direct HTTP /healthz on configured port 8765 returned 200 with Neo4j reachable |
| E-0010 | preflight | palace.memory.get_project_overview | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 04799ff4fb4e3a8b | No MCP response envelope after 30 seconds because this Codex connector retained a dead StreamableHTTP session across Palace restart |
| E-0011 | preflight | palace.health.status | cancelled_by_orchestrator | error | n/a/n/a | n/a | 30000 | no | 44136fa355b3678a | Timed out after 30 seconds; fresh MCP sessions returned immediately, confirming a session-local stale connector rather than a Palace runtime failure |
| E-0012 | preflight | palace.health.status | success | success | n/a/n/a | n/a | 200 | yes | 44136fa355b3678a | n/a |
| E-0013 | preflight | palace.memory.get_project_overview | success | success | n/a/n/a | n/a | 1300 | yes | 04799ff4fb4e3a8b | n/a |
| E-0014 | preflight | palace.memory.get_project_overview | success | success | n/a/n/a | n/a | 1600 | yes | e40d2aa6fdce6b6f | n/a |
| E-0015 | preflight | palace.code.search_code | success | success | 5/5 | n/a | 100 | yes | 90bb39645db48b79 | n/a |
| E-0016 | preflight | palace.code.search_code | success | warning | 179/179 | n/a | 1200 | no | 81d4c37cd46d89cb | Open passthrough contract did not honor guessed limit/file_pattern keys: 179 mixed Swift and periphery JSON matches returned; result is not used as bounded evidence |
| E-0017 | preflight | palace.code.semantic_search | success | success | 20/5 | n/a | 1000 | yes | ce823d7ea4aeeccf | n/a |
| E-0018 | preflight | palace.code.semantic_search | success | success | 24/5 | n/a | 1000 | yes | 8fcf65d3e96dae47 | n/a |
| E-0019 | preflight | palace.code.semantic_search | success | success | 1/1 | n/a | 1000 | yes | 002b65d44137a28d | n/a |
| E-0020 | evidence | palace.memory.health | success | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0021 | evidence | palace.code.semantic_search | success | success | 18/5 | n/a | n/a | yes | ab9f1e68d8721549 | n/a |
| E-0022 | evidence | palace.code.semantic_search | success | success | 6/5 | n/a | n/a | yes | ebcd4e1e0c048865 | n/a |
| E-0023 | evidence | palace.code.semantic_search | success | success | 6/5 | n/a | n/a | yes | c39bd7c7abf4d26b | n/a |
| E-0024 | evidence | palace.code.semantic_search | success | success | 9/5 | n/a | n/a | yes | 205aced727f43864 | n/a |
| E-0025 | evidence | palace.code.semantic_search | success | success | 5/5 | n/a | n/a | yes | c362b6b7ed5828d4 | n/a |
| E-0026 | evidence | palace.code.semantic_search | success | success | 23/5 | n/a | n/a | yes | 381264efead2c36f | n/a |
| E-0027 | evidence | palace.code.semantic_search | success | success | 8/5 | n/a | n/a | yes | 209e2bc416407e8a | n/a |
| E-0028 | evidence | palace.code.semantic_search | success | success | 14/5 | n/a | n/a | yes | ef00201e5dbca8fa | n/a |
| E-0029 | evidence | palace.code.semantic_search | success | success | 50/5 | n/a | n/a | yes | b50c3c293732c201 | n/a |
| E-0030 | evidence | palace.health.status | no_payload_timeout | error | n/a/n/a | n/a | 25000 | no | 44136fa355b3678a | No MCP response envelope; operator terminated the isolated call after 25 seconds |
| E-0031 | design | palace.health.status | no_response_envelope | error | n/a/n/a | n/a | 11000 | yes | a6991a255cc1a53b | No payload after 11 seconds; execution terminated to preserve liveness |
| E-0032 | adversarial_review | palace.health.status | no_response_envelope | error | n/a/n/a | n/a | 20000 | no | 44136fa355b3678a | No payload after 20 seconds; execution was terminated while fresh Palace sessions remained healthy |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S2-01 | high | boundary, responsibility, state_errors, tests | composition, consumer, contract, counterexample, implementation, test | test | C-S201-HANDLER | C-S201-COMPOSITION | C-S201-PRIVATEKEY-COUNTER |
  - Conflict: Existing host data and BigUInt-based kit models are not proven Sendable under pinned Swift/BigInt, while the quote must cross async handler/client boundaries without becoming forgeable.; resolution: Store only Sendable Address/Data/string/integer quote snapshots, expose BigUInt as newly decoded read-only computed values, declare quote/submission identity Sendable, and forbid unchecked/preconcurrency suppression.
| S2-02 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S202-VULTISIG-PREFLIGHT | C-S202-THORNODE, C-S202-FIXTURE | C-S202-NONCE-COUNTER |
  - Conflict: Vultisig independently fetches chain/account/fee and relies on dependency cancellation; a non-cooperative operation can violate coherent snapshot liveness.; resolution: Use one provider family and accepted height per round, and route each lease/read/backoff operation through an owned deadline/cancellation/token race; start no subsequent call until the result re-enters the owning actor with a valid token.
| S2-04 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S204-UW-OWNER | C-S204-HSCRYPTO, C-S204-VULTISIG-VERIFY, C-S204-GOLDEN | C-S204-INTERNAL-COUNTER |
  - Conflict: Current chain signers are synchronous long-lived concrete objects and direct async H1/H2 awaits can retain ownership when dependencies ignore cancellation.; resolution: Keep signing capability host-owned and ephemeral, verify the compact signature in the kit, serialize by actor, and use the same exactly-once owned-operation result race for signer and each H1/H2 provider call.
| S2-05 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S205-BITCOIN-PREBROADCAST | C-S205-EVM-LOCAL, C-S205-TRON-PENDING, C-S205-VULTISIG-BROADCAST | C-S205-REMOTE-COUNTER |
  - Conflict: BitcoinCore is the closest pre-broadcast persistence/retry lifecycle but is UTXO/P2P; EvmKit owns local bytes/hash yet persists pending only after RPC success.; resolution: Use BitcoinCore as lifecycle primary, EvmKit only for local bytes/hash ownership, Tron for projection shape, and add the THOR-specific journal generation, shared-writer, observation-replacement and CheckTx deltas.
| S2-07 | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | test | C-S207-UW-HANDLER | C-S207-UW-CONTRACT, C-S207-UW-WRAPPER | C-S207-VULTISIG-COUNTER |
  - Conflict: Current WalletCore Void completion, shared SlideButton success callback, non-Sendable SendNew path, and same-type wrappers do not distinguish CheckTx completion, strict actor safety, or live-handle ownership.; resolution: Use proven Sendable string snapshots and SendQuote storage, private per-client owner identity, outcome-consumed completion shared by drag/accessibility, Debug-Dev complete diagnostics over every changed file, and literal nonparallel serialized global tests.
| S2-03 | critical | boundary, dependencies, responsibility, tests, trust | composition, consumer, contract, counterexample, implementation, test | composition | C-S203-VULTISIG-CODEC | C-S203-THOR-MSGSEND, C-S203-GOLDEN, C-S203-THOR-OFFICIAL-GAS | C-S203-GAS-COUNTER |
  - Conflict: Vultisig delegates encoding to WalletCore and defaults gas to 20,000,000; THORNode proto alone does not pin the native example gas or a deterministic signed transaction.; resolution: Implement the exact local direct-sign subset, pin official THORNode multisig documentation at a759cb4f with blob/file digest, and require the complete scalar-1 RFC6979 low-S 3,000,000-gas TxRaw vector plus verification.
| S2-06 | high | boundary, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | contract, implementation, test | C-S206-EXAMPLE | C-S206-UI | C-S206-SECRET-COUNTER |
  - Conflict: Existing kit Examples are live-first UIKit demos with plaintext mnemonic persistence and no UI-test target.; resolution: Keep the runnable project/workspace and adapter shape, but use fixture-first injected runtime, no committed secret, stable accessibility IDs, Maestro only in ThorChainKit Example, and separate opt-in live evidence.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-S201-HANDLER | S2-01 | kept | F-S201-HANDLER | consumer, contract, implementation, lifecycle_error | boundary, responsibility, state_errors, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/SendNew/*SendHandler.swift |
| C-S201-COMPOSITION | S2-01 | supporting | F-S201-COMPOSITION | composition, consumer, contract | boundary, responsibility, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendHandlerFactory.swift |
| C-S201-PRIVATEKEY-COUNTER | S2-01 | rejected | F-S201-PRIVATEKEY-COUNTER | counterexample | boundary, trust | known_current | Sources/EvmKit/Core/Signer/Signer.swift |
| C-S202-VULTISIG-PREFLIGHT | S2-02 | kept | F-S202-VULTISIG-PREFLIGHT | composition, consumer, contract, implementation | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | VultisigApp/VultisigApp/Core/Services/BlockChainService.swift |
| C-S202-THORNODE | S2-02 | supporting | F-S202-THORNODE-PREFLIGHT | contract, implementation, lifecycle_error | boundary, lifecycle, responsibility, state_errors, trust | known_current | x/thorchain/handler_send.go |
| C-S202-FIXTURE | S2-02 | supporting | F-S202-FIXTURE | consumer, test | dependencies, tests, trust | known_current | VultisigApp/VultisigAppTests/TestData/thorchain.json |
| C-S202-NONCE-COUNTER | S2-02 | rejected | F-S202-NONCE-COUNTER | counterexample | dependencies, state_errors, trust | known_current | Sources/EvmKit/Api/Core/NonceProvider.swift |
| C-S203-THOR-MSGSEND | S2-03 | supporting | F-S203-THOR-MSGSEND | contract | boundary, dependencies, responsibility, trust | known_current | proto/thorchain/v1/types/msg_send.proto |
| C-S203-VULTISIG-CODEC | S2-03 | kept | F-S203-VULTISIG-CODEC | consumer, implementation, lifecycle_error | boundary, dependencies, responsibility, tests, trust | known_current | VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift |
| C-S203-GOLDEN | S2-03 | supporting | F-S203-GOLDEN | test | tests, trust | known_current | VultisigApp/VultisigAppTests/TestData/thorchain.json |
| C-S203-GAS-COUNTER | S2-03 | rejected | F-S203-GAS-COUNTER | counterexample | responsibility, trust | known_current | VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift |
| C-S204-UW-OWNER | S2-04 | kept | F-S204-UW-SIGNER-OWNER | composition, consumer, contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift |
| C-S204-HSCRYPTO | S2-04 | supporting | F-S204-HSCRYPTO-COMPACT | contract, implementation | dependencies, responsibility, trust | known_current | Sources/HsCryptoKit/Crypto.swift |
| C-S204-VULTISIG-VERIFY | S2-04 | supporting | F-S204-VULTISIG-VERIFY | consumer, lifecycle_error | lifecycle, state_errors, trust | known_current | VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift |
| C-S204-GOLDEN | S2-04 | supporting | F-S203-GOLDEN | test | tests, trust | known_current | VultisigApp/VultisigAppTests/TestData/thorchain.json |
| C-S204-INTERNAL-COUNTER | S2-04 | rejected | F-S204-INTERNAL-SIGNER-COUNTER | counterexample | boundary, lifecycle, trust | known_current | Sources/EvmKit/Core/Signer/Signer.swift |
| C-S205-EVM-LOCAL | S2-05 | kept | F-S205-EVM-LOCAL | composition, consumer, contract, implementation | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/EvmKit/Core/TransactionBuilder.swift |
| C-S205-TRON-PENDING | S2-05 | supporting | F-S205-TRON-PENDING | consumer, implementation, lifecycle_error, test | lifecycle, responsibility, state_errors, tests | known_current | Sources/TronKit/Core/TransactionManager.swift |
| C-S205-VULTISIG-BROADCAST | S2-05 | supporting | F-S205-VULTISIG-BROADCAST | contract, implementation, lifecycle_error | boundary, dependencies, state_errors, trust | known_current | VultisigApp/VultisigApp/Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift |
| C-S205-REMOTE-COUNTER | S2-05 | rejected | F-S205-REMOTE-BUILD-COUNTER | counterexample | boundary, lifecycle, state_errors, trust | known_current | Sources/TronKit/Core/TransactionSender.swift |
| C-S206-EXAMPLE | S2-06 | kept | F-S206-EXAMPLE-COMPOSITION | composition, consumer | boundary, lifecycle, responsibility, tests, trust | known_current | iOS Example/Sources/Core/Manager.swift |
| C-S206-UI | S2-06 | supporting | F-S206-EXAMPLE-UI | consumer, lifecycle_error | lifecycle, responsibility, state_errors, tests | known_current | iOS Example/Sources/Controllers/SendController.swift |
| C-S206-SECRET-COUNTER | S2-06 | rejected | F-S206-SECRET-COUNTER | counterexample | lifecycle, tests, trust | known_current | iOS Example/Sources/Core/Manager.swift |
| C-S207-UW-HANDLER | S2-07 | kept | F-S207-UW-TRON-HANDLER | consumer, contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | known_current | packages/WalletCore/Sources/WalletCore/Modules/SendNew/TronSendHandler.swift |
| C-S207-UW-CONTRACT | S2-07 | supporting | F-S207-UW-CONTRACT | composition, consumer, contract | boundary, dependencies, responsibility, tests | known_current | packages/WalletCore/Sources/WalletCore/Core/Protocols.swift |
| C-S207-UW-WRAPPER | S2-07 | supporting | F-S207-UW-WRAPPER | composition, implementation, lifecycle_error | boundary, dependencies, lifecycle, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift |
| C-S207-VULTISIG-COUNTER | S2-07 | rejected | F-S207-VULTISIG-COUNTER | counterexample | boundary, dependencies, lifecycle, trust | known_current | VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift |
| C-S203-THOR-OFFICIAL-GAS | S2-03 | supporting | F-S203-THOR-OFFICIAL-GAS | contract, test | dependencies, responsibility, tests, trust | known_current | docs/cli/multisig.md |
| C-S205-BITCOIN-PREBROADCAST | S2-05 | kept | F-S205-BITCOIN-PREBROADCAST | implementation, lifecycle_error | lifecycle, responsibility, state_errors, tests | known_current | Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-S201-HANDLER | 1 | yes | MATCH | yes | combined | E-0018, E-0029 | valid | known_current | Current Unstoppable send handlers separate an expiring review-data phase from the final send call and carry validation errors in typed send data. |
  - Serena: n/a
  - rg: EvmSendHandler and TronSendHandler expose expirationDuration=10, sendData(...), typed data guards, and send(data:) in packages/WalletCore.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/EvmSendHandler.swift:26, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/TronSendHandler.swift:27
| F-S201-COMPOSITION | 1 | yes | MATCH | yes | combined | E-0029 | valid | known_current | Current Unstoppable composes chain send behavior through SendData cases and ordered SendHandlerFactory provider registration. |
  - Serena: n/a
  - rg: SendData contains evm/tron cases; SendHandlerFactory iterates registered providers and its unstoppableHandlers list registers EvmSendHandler and TronSendHandler.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendData.swift:12, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendHandlerFactory.swift:3
| F-S201-PRIVATEKEY-COUNTER | 1 | no | MATCH | no | rg | n/a | valid | known_current | EvmKit public Signer factories and Kit sign helpers accept seed or private-key bytes, which is incompatible with ThorChainKit signer isolation. |
  - Serena: n/a
  - rg: Signer.instance(seed:<redacted>, Signer.instance(privateKey:<redacted>, and Kit.sign(message:privateKey/seed:<redacted> are public/static entry points in current EvmKit.
  - Anchors: evm-kit@be028631:Sources/EvmKit/Core/Signer/Signer.swift:38, evm-kit@be028631:Sources/EvmKit/Core/Kit.swift:389
| F-S202-VULTISIG-PREFLIGHT | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Vultisig obtains THORChain chain identity, account number, sequence, and native fee before producing its chain-specific signing payload. |
  - Serena: n/a
  - rg: BlockChainService calls getTHORChainChainID, fetchAccountNumber, fetchFeePrice, validates account/sequence, then constructs THORChain chain-specific state.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Core/Services/BlockChainService.swift:534
| F-S202-THORNODE-PREFLIGHT | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | THORNode treats native transfer fee and halt/module-recipient rules as consensus-adjacent send preconditions, including conversion of a send to the THOR module address into MsgD... |
  - Serena: n/a
  - rg: SendAnteHandler deducts GetNativeTxFee; MsgSendValidate rejects other module accounts; MsgSendHandle rejects halted THORChain and converts the THOR module recipient to MsgDeposit.
  - Anchors: thornode@a759cb4f:x/thorchain/handler_send.go:125, thornode@a759cb4f:x/thorchain/handler_send.go:148
| F-S202-FIXTURE | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The pinned Vultisig THORChain fixture supplies an independently maintained native RUNE send vector with account number, sequence, public key, addresses, amount, and expected sig... |
  - Serena: n/a
  - rg: The first thorchain.json case is Send THORChain RUNE with account_number 123456, sequence 1, amount 100000000 and expected image hash 7e513b23...1ebf.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigAppTests/TestData/thorchain.json:1
| F-S202-NONCE-COUNTER | 1 | no | MATCH | no | combined | E-0022 | valid | known_current | EvmKit selects the maximum nonce returned by multiple providers, which must not be copied for Cosmos account sequence because it would mix provider snapshots. |
  - Serena: n/a
  - rg: NonceProvider loops over providers, ignores individual failures, and returns max(maxNonce, nonce).
  - Anchors: evm-kit@be028631:Sources/EvmKit/Api/Core/NonceProvider.swift:10
| F-S203-THOR-MSGSEND | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Pinned THORNode defines native transfer as protobuf package types.MsgSend with raw address bytes in fields 1 and 2 and repeated Cosmos Coin in field 3; SIGN_MODE_DIRECT is enabled. |
  - Serena: n/a
  - rg: msg_send.proto declares package types and exact fields; app/params/tx_config.go enables SIGN_MODE_DIRECT.
  - Anchors: thornode@a759cb4f:proto/thorchain/v1/types/msg_send.proto:2, thornode@a759cb4f:app/params/tx_config.go:19
| F-S203-VULTISIG-CODEC | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Pinned Vultisig builds a THORChain native-send signing input from raw from/to address bytes, lowercase rune denom, amount, account number, sequence and chain ID, then verifies t... |
  - Serena: n/a
  - rg: THORChainHelper buildThorchainSendMessage, getPreSignedInputData, and getSignedTransaction implement the complete WalletCore-based reference path.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:102, vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:186, vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:311
| F-S203-GOLDEN | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The pinned Vultisig native RUNE send vector provides a deterministic signing-image hash suitable as an external compatibility control. |
  - Serena: n/a
  - rg: thorchain.json first case fixes pubkey, addresses, amount, account number, sequence and expected image hash 7e513b23957b2e3caf77e796ba1412851be066cd77f96a7d196c3c856c641ebf.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigAppTests/TestData/thorchain.json:1
| F-S203-GAS-COUNTER | 1 | no | MATCH | no | rg | n/a | valid | known_current | Vultisig defaults THORChain fee gas to 20,000,000, while the official raw native MsgSend example uses 3,000,000; therefore the Vultisig gas constant is not copied. |
  - Serena: n/a
  - rg: THORChainHelper.getFee hardcodes gas 20_000_000 when no override exists; the design records official THOR Dev Docs 3_000_000 separately.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:393
| F-S204-UW-SIGNER-OWNER | 1 | yes | MATCH | yes | combined | E-0018, E-0029 | valid | known_current | Current Unstoppable manager wrappers own concrete chain signers and mediate raw transaction creation, signing, and kit send rather than exposing key material to UI handlers. |
  - Serena: n/a
  - rg: EvmKitWrapper and TronKitWrapper guard an owned signer and call the respective kit send API; handlers receive only wrappers through adapters.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Core/Managers/EvmKitManager.swift:142, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:140
| F-S204-HSCRYPTO-COMPACT | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Pinned HsCryptoKit can derive compressed secp256k1 public keys and produce normalized compact 64-byte ECDSA signatures from caller-owned private key material. |
  - Serena: n/a
  - rg: Crypto.publicKey supports compressed output; Crypto.sign normalizes the signature and compact=true serializes 64-byte r\|\|s.
  - Anchors: hscryptokit@7c11ad0e:Sources/HsCryptoKit/Crypto.swift:90, hscryptokit@7c11ad0e:Sources/HsCryptoKit/Crypto.swift:109
| F-S204-VULTISIG-VERIFY | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Vultisig treats signature verification against the expected public key as a required failure gate before compiling a THORChain transaction. |
  - Serena: n/a
  - rg: THORChainHelper constructs PublicKey, obtains the pre-signing hash, verifies the supplied signature, throws on failure, then compiles.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:186
| F-S204-INTERNAL-SIGNER-COUNTER | 1 | no | MATCH | no | combined | E-0024 | valid | known_current | EvmKit internal Signer owns a private key and its public factories accept seed/private key, so it is a counterexample for ThorChainKit public signer ownership and async hardware... |
  - Serena: n/a
  - rg: Signer.instance(seed/privateKey) constructs TransactionSigner and EthSigner with private key bytes.
  - Anchors: evm-kit@be028631:Sources/EvmKit/Core/Signer/Signer.swift:7
| F-S205-EVM-LOCAL | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | EvmKit locally encodes signed transaction bytes, derives the local transaction hash/model, broadcasts, and then inserts the result into transaction state. |
  - Serena: n/a
  - rg: TransactionBuilder.encode/transaction compute bytes and hash; RpcBlockchain.send broadcasts encoded bytes and returns the local model; Kit.send passes it to TransactionManager.
  - Anchors: evm-kit@be028631:Sources/EvmKit/Core/TransactionBuilder.swift:13, evm-kit@be028631:Sources/EvmKit/Api/Core/RpcBlockchain.swift:136, evm-kit@be028631:Sources/EvmKit/Core/Kit.swift:177
| F-S205-TRON-PENDING | 1 | yes | MATCH | yes | combined | E-0017, E-0025 | valid | known_current | TronKit persists a newly broadcast transaction as unconfirmed pending state and guards externally injected pending hashes from overwrite or confirmed-state downgrade. |
  - Serena: n/a
  - rg: Kit.send calls TransactionManager.handle(newTransaction:); handle(pendingHash:) checks existing storage; TransactionManagerPendingTests verifies insert once and no downgrade.
  - Anchors: tron-kit@aa691bcd:Sources/TronKit/Core/Kit.swift:197, tron-kit@aa691bcd:Sources/TronKit/Core/TransactionManager.swift:155, tron-kit@aa691bcd:Tests/TronKitTests/TransactionManagerPendingTests.swift:6
| F-S205-VULTISIG-BROADCAST | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Vultisig broadcasts THORChain tx bytes via Cosmos REST sync mode and treats CheckTx code 0 or code 19 already-in-mempool as idempotent success. |
  - Serena: n/a
  - rg: ThorchainBroadcastAPI posts /cosmos/tx/v1beta1/txs; broadcastTransaction accepts code 0 or 19 and returns txhash.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift:14
| F-S205-REMOTE-BUILD-COUNTER | 1 | no | MATCH | no | combined | E-0021 | valid | known_current | TronKit asks a remote node to construct the unsigned transaction and persists pending state only after broadcast returns, so this lifecycle is unsafe as the complete THORChain d... |
  - Serena: n/a
  - rg: TransactionSender receives createdTransaction from node API, validates the serialized contract, signs and broadcasts; Kit.handle(newTransaction:) runs only after sendTransaction returns.
  - Anchors: tron-kit@aa691bcd:Sources/TronKit/Core/TransactionSender.swift:12, tron-kit@aa691bcd:Sources/TronKit/Core/Kit.swift:197
| F-S206-EXAMPLE-COMPOSITION | 1 | yes | MATCH | yes | combined | E-0026, E-0027 | valid | known_current | TronKit provides a separate runnable iOS Example that composes Kit, signer and adapter against the root package and exposes native send as a real app surface. |
  - Serena: n/a
  - rg: Manager constructs Kit and TrxAdapter; TrxAdapter exposes send; Main/Send controllers expose native transfer; shared scheme builds and runs TronKit Demo.app.
  - Anchors: tron-kit@aa691bcd:iOS Example/Sources/Core/Manager.swift:1, tron-kit@aa691bcd:iOS Example/Sources/Adapters/TrxAdapter.swift:1, tron-kit@aa691bcd:iOS Example/Sources/Controllers/SendController.swift:1
| F-S206-EXAMPLE-UI | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The TronKit Example send controller exercises address parsing, amount validation, fee estimation, async send, success and error display through a real user-visible screen. |
  - Serena: n/a
  - rg: SendController updates fee asynchronously, validates address/positive amount, calls adapter.send in Task, then handles success or shows send failure.
  - Anchors: tron-kit@aa691bcd:iOS Example/Sources/Controllers/SendController.swift:1
| F-S206-SECRET-COUNTER | 1 | no | MATCH | no | rg | n/a | valid | known_current | The current kit Examples persist mnemonic words in UserDefaults and have empty scheme Testables, so their secret handling and lack of automated UI acceptance must not be copied. |
  - Serena: n/a
  - rg: Manager.save(words:) writes joined mnemonic to UserDefaults; iOS Example.xcscheme contains an empty Testables element.
  - Anchors: tron-kit@aa691bcd:iOS Example/Sources/Core/Manager.swift:65, tron-kit@aa691bcd:iOS Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme:25
| F-S207-UW-TRON-HANDLER | 1 | yes | MATCH | yes | combined | E-0029 | valid | known_current | Current Unstoppable TronSendHandler is the closest native account-chain host analog: it prepares review data with dynamic fee/send-max/balance errors and delegates final send th... |
  - Serena: n/a
  - rg: TronSendHandler.sendData estimates fees and adjusts send max; send validates TronSendData and calls TronKitWrapper.send.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/TronSendHandler.swift:6
| F-S207-UW-CONTRACT | 1 | yes | MATCH | yes | combined | E-0029 | valid | known_current | Current Unstoppable exposes chain send capability through a narrow adapter protocol, typed SendData case, and ordered handler/pre-handler factory registration. |
  - Serena: n/a
  - rg: ISendTronAdapter exposes tronKitWrapper; SendData has tron cases; SendHandlerFactory registers TronSendHandler and TronPreSendHandler.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Core/Protocols.swift:138, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendData.swift:18, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendHandlerFactory.swift:51
| F-S207-UW-WRAPPER | 1 | yes | MATCH | yes | combined | E-0018, E-0029 | valid | known_current | Current Unstoppable keeps chain signer ownership in the manager wrapper and makes the send handler consume that wrapper through an adapter, preserving host/kit separation. |
  - Serena: n/a
  - rg: TronKitWrapper owns optional Signer and delegates Kit.send; TronSendHandler resolves ISendTronAdapter and uses adapter.tronKitWrapper.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:140, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/TronSendHandler.swift:112
| F-S207-VULTISIG-COUNTER | 1 | no | MATCH | no | rg | n/a | valid | known_current | Vultisig routes signing through app-wide MPC/TSS payload and global services, which is a THORChain protocol reference but not an Unstoppable adapter or signer-ownership template. |
  - Serena: n/a
  - rg: THORChainHelper accepts KeysignPayload and TssKeysignResponse maps and compiles via WalletCore TransactionCompiler rather than a narrow account-kit signer protocol.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:102, vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:179
| F-S203-THOR-OFFICIAL-GAS | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Pinned official THORNode multisig documentation defines native RUNE /types.MsgSend with empty fee amount, denom rune and gas limit 3000000. |
  - Serena: n/a
  - rg: At THORNode a759cb4f99b1a13d5d94ace1dddcaf25c165641f, docs/cli/multisig.md lines 27-56 uses gas 3000000 and renders gas_limit 3000000; blob 537cac65592828fb0f10dbf2d75edf51eaa4be67, file SHA-256 27e39d943dee5744df87d87ef29828c8b34f51ae8bb4a7504fe4c98716d2649c.
  - Anchors: thornode@a759cb4f99b1a13d5d94ace1dddcaf25c165641f:docs/cli/multisig.md:27
| F-S205-BITCOIN-PREBROADCAST | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | BitcoinCore persists a created transaction and notifies pending listeners before transport, while its sender later reloads pending transactions for retry. |
  - Serena: Serena project activation was unavailable for this dirty source tree; exact source files were inspected directly and are clean relative to HEAD.
  - rg: TransactionCreator.processAndSend calls processCreated before send; PendingTransactionProcessor.processCreated stores and notifies; TransactionSender.sendPendingTransactions reloads transactionSyncer.newTransactions.
  - Anchors: bitcoin-core@5b49f424:Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift:25, bitcoin-core@5b49f424:Sources/BitcoinCore/Classes/Transactions/PendingTransactionProcessor.swift:132, bitcoin-core@5b49f424:Sources/BitcoinCore/Classes/Network/TransactionSender.swift:145
| F-S205-GRDB-OBSERVATION-ERROR | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | GRDB ValueObservation completes after an observation error, so recovery requires a new subscription rather than only a successful full reread. |
  - Serena: n/a
  - rg: Pinned GRDB v6.29.3 testErrorCompletesTheObservation proves completion after error; its external-connection test and documentation require cancel/restart or explicit notification for undetected writes.
  - Anchors: grdb@2cf6c756:Tests/GRDBTests/ValueObservationTests.swift:54, grdb@2cf6c756:GRDB/Documentation.docc/Extension/ValueObservation.md:204
| F-S207-UW-OUTCOME-ROUTES | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current Unstoppable presents RegularSendView directly from PreSendView on iOS 17, while unknown thrown errors render a generic sheet and MainActor-isolating SendHandlerFactory w... |
  - Serena: n/a
  - rg: Exact UW 8a63bfda PreSendView lines 74-79 and 183-194 use direct navigation; SendView lines 69-83 shows generic unexpected error; OpenCryptoPayManager:64 and OpenCryptoPaySendHandlerFactory:14 synchronously call SendHandlerFactory.
  - Anchors: uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/PreSendView.swift:74, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendView.swift:69, uw-ios-app@8a63bfda:packages/WalletCore/Sources/WalletCore/Core/OpenCryptoPay/OpenCryptoPayManager.swift:64
| F-S201-BIGINT-SENDABLE-BOUNDARY | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | BigInt 5.3.0 BigUInt is not Sendable; Data-backed amount/pending/error snapshots compile under Swift 5 complete checking while an Error case storing BigUInt fails. |
  - Serena: n/a
  - rg: Pinned BigInt module plus Xcode Swift 6.2.4 probes: revision7 Data-backed SendAmount/PendingTransaction/NativeFeeChange/SendError passes; InvalidSendError(previous: BigUInt,current: BigUInt) fails with the expected Sendable diagnostic.
  - Anchors: bigint@0ed110f7:Sources/BigUInt.swift:16, compiler-probe:/tmp/thor-s2-sendable.RdvsEf/revision7_probe.swift
| F-S202-LIVE-HEIGHT-PROOF | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | A send provider must prove each returned value by its own route-specific height mode; current official Liquify REST strips the Cosmos height response header on required successf... |
  - Serena: n/a
  - rg: Fresh independent live probes at height 27048835 returned HTTP 200 without x-cosmos-block-height for Liquify network, exact-key Mimir and spendable-bank routes; official THOR developer docs list Liquify API and paired RPC roles.
  - Anchors: https://gateway.liquify.com/chain/thorchain_api/thorchain/network?height=27048835@2026-07-17T22:09:15Z, thornode@a759cb4f:x/thorchain/module.go:299
| F-S202-LIVE-RECIPIENT-PROOF | 2 | yes | MATCH | yes | rg | n/a | valid | known_current | Liquify Comet proves required preflight values and recipient Account at exact height; exact sdk/22 Account absence at H=27049190 carries JSON value null, which is the zero-byte ... |
  - Serena: n/a
  - rg: At H=27049190 direct bounded probes returned exact response.height for Network, MimirWithKey, SpendableBalanceByDenom, Params, Version, absent Account sdk/22 with value:null, and ModuleAccount Any; bulk ModuleAccounts returned code 111222 height 0 and REST HTTP 500
  - Anchors: Liquify mainnet Comet/REST probes@2026-07-17T22:47Z-22:51Z
| F-S202-MODULE-VERSION-MANIFEST | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Official THORNode v3.19.0 through v3.19.3 tags have an identical IsModuleAccAddress function and module-name source, enabling an explicit version-gated forbidden-address manifest |
  - Serena: n/a
  - rg: Tags 5f2141c3,59a3e925,c6fa8caa,52e66ad9 share helpers.go SHA256 72ce4607... and keys.go SHA256 65f6e606... with the same nine module names; live Version current/querier is 3.19.3/3.19.0
  - Anchors: THORNode official v3.19.0-v3.19.3 tags
| F-S201-ERROR-GRAPH-COMPILE | 2 | yes | MATCH | yes | rg | n/a | valid | known_current | The revision-9 public SendError graph with internally validated read-only nonempty QuoteChanges is checked Sendable under Swift 5 complete mode, while an external consumer canno... |
  - Serena: n/a
  - rg: xcrun swiftc positive exact-graph probe exited 0; separately emitted Revision9Errors module made both external QuoteChanges(validating: []) and SendError.quoteChanged([]) fail compilation without suppression
  - Anchors: compiler-probe:/tmp/thor-s2-sendable.RdvsEf/revision9_error_probe.swift
| F-S205-LIVE-TX-LOOKUP | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Cosmos SDK v0.53.0 defines GET /cosmos/tx/v1beta1/txs/{hash}; current Liquify returns a bounded HTTP 200 with matching tx_response.txhash and positive height for an indexed tran... |
  - Serena: n/a
  - rg: Official Cosmos SDK v0.53.0 service.proto pins the route and x/auth/tx/service.go maps QueryTx not-found to gRPC NotFound; live 2026-07-17 probes returned 200/matching hash/height and 404/code5/details[]/exact hash-bearing message
  - Anchors: cosmos-sdk@bcaf7378:x/auth/tx/service.go:110,cosmos-sdk@bcaf7378:proto/cosmos/tx/v1beta1/service.proto:24,Liquify mainnet probes@2026-07-17T23:31Z
| F-S205-BROADCAST-WIRE | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Cosmos SDK v0.53.0 defines POST /cosmos/tx/v1beta1/txs with BroadcastTxResponse.tx_response, while Foundation JSONDecoder accepts conflicting duplicate code keys; terminal Check... |
  - Serena: n/a
  - rg: Official service.proto lines 27-32 and 153-158 pin the POST route and one tx_response field; an independent xcrun Swift probe decoded duplicate code 0/code 7 without error and selected 0.
  - Anchors: cosmos-sdk@bcaf7378:proto/cosmos/tx/v1beta1/service.proto:27, compiler-probe:xcrun-swift Foundation duplicate-code JSONDecoder@2026-07-18T00:13Z

## Adversarial decisions

- D-S2-001@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@2@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@2@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@2@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@3@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@3@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@3@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@4@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@4@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@4@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@5@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@5@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@5@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@6@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@6@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@6@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@7@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@7@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@7@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@8@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@8@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@8@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@9@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@9@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@9@2 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-001@10@3 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-002@10@3 ACCEPT: Historical review finding closed by canonical revision 10
- D-S2-003@10@3 ACCEPT: Historical review finding closed by canonical revision 10

## Verification and acceptance


## Bugs and limitations

### GIMLE-S2-PREFLIGHT-1: Parallel Gimle preflight did not return an envelope

- Class/severity/confidence/status: environment_drift / medium / possible / workaround
- Tool/events/claims: palace.health.status / E-0001 / n/a
- Reproduction: Invoke the four documented read-only preflight tools concurrently and await the combined result
- Expected: All four bounded read-only calls return independently
- Actual: Combined execution remained pending for 81 seconds and was terminated without payload
- Impact: Preflight identity cannot be inferred from this batch; no architecture decision uses it
- Workaround: Retry each read-only tool individually, record its own envelope, and continue bounded Gimle discovery
- Anchors: n/a

### GIMLE-S2-PREFLIGHT-2: Parallel Gimle preflight did not return an envelope

- Class/severity/confidence/status: environment_drift / medium / possible / workaround
- Tool/events/claims: palace.memory.health / E-0002 / n/a
- Reproduction: Invoke the four documented read-only preflight tools concurrently and await the combined result
- Expected: All four bounded read-only calls return independently
- Actual: Combined execution remained pending for 81 seconds and was terminated without payload
- Impact: Preflight identity cannot be inferred from this batch; no architecture decision uses it
- Workaround: Retry each read-only tool individually, record its own envelope, and continue bounded Gimle discovery
- Anchors: n/a

### GIMLE-S2-PREFLIGHT-3: Parallel Gimle preflight did not return an envelope

- Class/severity/confidence/status: environment_drift / medium / possible / workaround
- Tool/events/claims: palace.memory.list_projects / E-0003 / n/a
- Reproduction: Invoke the four documented read-only preflight tools concurrently and await the combined result
- Expected: All four bounded read-only calls return independently
- Actual: Combined execution remained pending for 81 seconds and was terminated without payload
- Impact: Preflight identity cannot be inferred from this batch; no architecture decision uses it
- Workaround: Retry each read-only tool individually, record its own envelope, and continue bounded Gimle discovery
- Anchors: n/a

### GIMLE-S2-PREFLIGHT-4: Parallel Gimle preflight did not return an envelope

- Class/severity/confidence/status: environment_drift / medium / possible / workaround
- Tool/events/claims: palace.code.list_passthrough_projects / E-0004 / n/a
- Reproduction: Invoke the four documented read-only preflight tools concurrently and await the combined result
- Expected: All four bounded read-only calls return independently
- Actual: Combined execution remained pending for 81 seconds and was terminated without payload
- Impact: Preflight identity cannot be inferred from this batch; no architecture decision uses it
- Workaround: Retry each read-only tool individually, record its own envelope, and continue bounded Gimle discovery
- Anchors: n/a

### GIMLE-S2-HEALTH-HANG: Palace health is available from a clean post-restart MCP session

- Class/severity/confidence/status: environment_drift / high / confirmed / fixed
- Tool/events/claims: palace.health.status / E-0005, E-0007, E-0012 / n/a
- Reproduction: Establish a new MCP session after the Palace restart and call palace.health.status with empty arguments
- Expected: Bounded runtime identity and reachability payload
- Actual: Fresh session returned in about 0.2 seconds with git_sha 0e9cf57c, git_dirty=false, Neo4j reachable, and no integrity warnings
- Impact: Earlier no-envelope observations are reclassified as dead client-session behavior and no longer prove a Palace runtime outage
- Workaround: Reconnect the MCP client after Palace restarts, then rerun health and a bounded known-slug query
- Anchors: n/a

### GIMLE-S2-ROUTING-HANG: Second isolated Gimle tool hangs after successful HTTP health

- Class/severity/confidence/status: environment_drift / high / probable / workaround
- Tool/events/claims: palace.code.list_passthrough_projects / E-0006 / n/a
- Reproduction: After healthz returns 200, invoke palace.code.list_passthrough_projects and wait 30 seconds
- Expected: Bounded routing map
- Actual: No MCP payload after 30 seconds while HTTP health remains healthy
- Impact: Failure is transport/tool-call wide rather than health-surface only; indexed results cannot yet be accepted
- Workaround: Keep server running for the active CTO, use codebase-memory and exact local trees now, and periodically retry Gimle calls
- Anchors: n/a

### GIMLE-S2-HEALTH-HANG-FIRST: Palace health is available from a clean post-restart MCP session

- Class/severity/confidence/status: environment_drift / high / confirmed / fixed
- Tool/events/claims: palace.health.status / E-0005, E-0012 / n/a
- Reproduction: Establish a new MCP session after the Palace restart and call palace.health.status with empty arguments
- Expected: Bounded runtime identity and reachability payload
- Actual: Fresh session returned in about 0.2 seconds with git_sha 0e9cf57c, git_dirty=false, Neo4j reachable, and no integrity warnings
- Impact: Earlier no-envelope observations are reclassified as dead client-session behavior and no longer prove a Palace runtime outage
- Workaround: Reconnect the MCP client after Palace restarts, then rerun health and a bounded known-slug query
- Anchors: n/a

### GIMLE-S2-HEALTH-HANG-RECHECK: Palace health is available from a clean post-restart MCP session

- Class/severity/confidence/status: environment_drift / high / confirmed / fixed
- Tool/events/claims: palace.health.status / E-0008, E-0012 / n/a
- Reproduction: Establish a new MCP session after the Palace restart and call palace.health.status with empty arguments
- Expected: Bounded runtime identity and reachability payload
- Actual: Fresh session returned in about 0.2 seconds with git_sha 0e9cf57c, git_dirty=false, Neo4j reachable, and no integrity warnings
- Impact: Earlier no-envelope observations are reclassified as dead client-session behavior and no longer prove a Palace runtime outage
- Workaround: Reconnect the MCP client after Palace restarts, then rerun health and a bounded known-slug query
- Anchors: n/a

### GIMLE-S2-CODEX-MCP-STALE-SESSION: Codex connector still retains a dead StreamableHTTP session after Palace restart

- Class/severity/confidence/status: environment_drift / high / confirmed / workaround
- Tool/events/claims: palace.health.status / E-0009, E-0010, E-0011, E-0030, E-0031, E-0032 / n/a
- Reproduction: From this long-lived Codex session call palace.health.status after the Palace restart; no response envelope arrives within 20 seconds, while a newly created MCP session returns immediately
- Expected: The connector recreates transport and returns the bounded health payload available to fresh sessions
- Actual: Historical health/overview probes and the latest isolated health probe remained silent; fresh sessions and direct HTTP health remain responsive
- Impact: This session cannot consume new Gimle payloads, but indexed evidence already obtained remains usable only with Serena and targeted rg verification
- Workaround: Recreate the MCP session, retry Gimle, then verify every load-bearing result with Serena and targeted rg; record any fallback
- Anchors: Paperclip THR-12 comment 9bda4006-fb79-4ffd-b34c-0c32ab35aef3

### GIMLE-S2-SEARCH-CODE-OPEN-BOUNDS: Open search_code passthrough cannot prove bounded or file-scoped execution

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.code.search_code / E-0016 / n/a
- Reproduction: Call palace.code.search_code for uw-ios-app with guessed limit=10 and file_pattern=*.swift under the deployed additionalProperties-only schema
- Expected: A typed contract either enforces the bound and Swift scope or rejects unsupported arguments
- Actual: Call returned ok=true with 179 mixed Swift and periphery JSON matches; the deployed schema does not declare limit or file_pattern
- Impact: This specific response cannot be used as bounded Swift-only evidence; typed semantic search and exact-tree verification remain available
- Workaround: Use palace.code.semantic_search with typed limit for discovery, then verify selected files through Serena and targeted rg
- Anchors: n/a

### GIM-SEMANTIC-ROW-FRESHNESS: Semantic result freshness now uses the authoritative indexed project commit

- Class/severity/confidence/status: mapping_bug / medium / confirmed / fixed
- Tool/events/claims: palace.code.semantic_search / E-0017, E-0018 / n/a
- Reproduction: Run bounded project-only semantic_search for tron-kit and uw-ios-app and inspect per-result freshness fields
- Expected: Rows report the authoritative indexed_commit, commits_behind_head=0, stale=false, and current_local_tree
- Actual: Both bounded searches returned those fields consistently for indexed commits aa691bcd and 8a63bfda
- Impact: The former high-severity freshness defect is fixed; residual risk is regression-only and remains covered by exact-tree verification
- Workaround: Continue mandatory Serena and targeted rg verification for load-bearing claims
- Anchors: n/a

### GIM-SEMANTIC-UNDERFILL: Multi-project semantic pagination envelope now reflects the post-filter result set

- Class/severity/confidence/status: coverage_gap / medium / confirmed / fixed
- Tool/events/claims: palace.code.semantic_search / E-0019 / n/a
- Reproduction: Search network provider endpoint across tron-kit, evm-kit, and uw-ios-app with limit 8 and include_context false
- Expected: Post-filter total and has_more describe returned scoped rows without impossible continuation
- Actual: returned=1, total=1, has_more=false, next_offset=null, truncated=false, warnings empty; scope_excluded_count=37 is exposed separately
- Impact: The old zero-row/has_more=true false continuation no longer reproduces; small result sets remain a relevance concern, not pagination corruption
- Workaround: Use query variants and exact-tree search when recall matters
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
