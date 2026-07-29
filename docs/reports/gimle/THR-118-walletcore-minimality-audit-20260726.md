# Gimle reliability report: THR-118-20260726-walletcore-minimality-audit

- Task: THR-118-walletcore-minimality-audit
- Workflow/phase: evidence_audit / complete
- Trust: **YELLOW**
- Repository: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50
- Base HEAD: 8a63bfda028dd8543115b26dd777235a53304311
- Final HEAD: 8a63bfda028dd8543115b26dd777235a53304311
- Gimle runtime: n/a
- Indexed commit: n/a

## Metrics

- Calls: 3 (success 0, warning 0, error 3, false-success 0)
- Useful-call rate: 0.0%
- Response-byte coverage: 0/3; total n/a
- Duration coverage: 3/3; total 900000 ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 3
- Analog slices/candidates: 0/0

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 0 | 0 | 1 | 0 |
| palace.health.status | 0 | 0 | 1 | 0 |
| palace.memory.list_projects | 0 | 0 | 1 | 0 |

Bug classes: {'environment_drift': 3}
Bug severities: {'medium': 3}
Bug statuses: {'workaround': 3}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | timeout | error | n/a/n/a | n/a | 300000 | no | 44136fa355b3678a | Timed out awaiting tools/call after 300 seconds. |
| E-0002 | evidence | palace.memory.list_projects | timeout | error | n/a/n/a | n/a | 300000 | no | 44136fa355b3678a | Timed out awaiting tools/call after 300 seconds. |
| E-0003 | evidence | palace.code.list_passthrough_projects | timeout | error | n/a/n/a | n/a | 300000 | no | 44136fa355b3678a | Timed out awaiting tools/call after 300 seconds. |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-001 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | WalletCore's established token-support and adapter-routing analog identifies native assets by the (BlockchainType, TokenType) pair; isNativeThorChainRune is a new redundant meta... |
  - Serena: Serena located isNativeThorChainRune and all seven production call sites; AccountType and AdapterFactory current-tree declarations show pair matching for Ethereum, Tron, and Ton.
  - rg: Targeted rg found no other static isNative-chain identity helper and confirmed cases (.tron/.ton/.ethereum, .native) and (.native, .tron/.ton/.ethereum).
  - Anchors: packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift:245
| F-002 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The EnabledWalletCache migration preservation change is unrelated to enabling THORChain; it was deliberately added because the earlier S1-07 spec expanded scope to repair a pre-... |
  - Serena: n/a
  - rg: git diff shows only generic EnabledWalletCache/StorageMigrator changes; S1-07 spec lines 43, 74, 99, and 112 explicitly require preservation, while the migration contains no THORChain branch.
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Storage/StorageMigrator.swift:831
| F-003 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChain manager/factory endpoint-provider, kit-factory, kit-interface, diagnostic-logger, endpoint-record, and runtime allowlist seams exceed the Tron/Ton manager analog and a... |
  - Serena: Serena shows ThorChainKitManager depends on three injected protocols plus CacheIdentity and validate(); ThorChainKitFactory.swift defines four test seams and endpoint record/config wrappers.
  - rg: Current-tree rg shows these seams are heavily referenced by 539 lines of ThorChainKitManagerTests; TronKitManager/TonKitManager store concrete kit types and construct them directly without equivalent endpoint/factory/diagnostic protocols.
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift:7
| F-004 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChainAdapter contains speculative lifecycle locking and custom precision/overflow machinery absent from adapter analogs, despite existing WalletCore BigUInt-to-Decimal helpers. |
  - Serena: Serena body shows two NSRecursiveLocks, stopped gating, serialized active calls, conversionFailure state, and a 38-digit round-trip conversion routine.
  - rg: Targeted rg found lifecycleLock/kitCallLock only in ThorChainAdapter and found existing Token.decimalValue plus EVM/TRON/TON conversions using Decimal(sign:exponent:significand:).
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift:8
| F-005 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The WalletCore THORChain address parser is premature in Sprint 1 because send is not integrated, and its addition forced a compensating AddressEventHandler rejection path. |
  - Serena: Serena shows ThorChainAddressParser only validates/handles THORChain mainnet addresses and AddressParserFactory registers it.
  - rg: Current-tree diff adds the parser while AddressEventHandler immediately rejects any parsed allowedBlockchainTypes containing .thorChain; Receive obtains its address directly from IDepositAdapter.
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift:5

## Adversarial decisions


## Verification and acceptance

- A-001 acceptance/passed: Exact current-tree analog uses direct BlockchainType/TokenType tuple matching; no peer isNative-chain metadata helper exists.
- V-001 verification/passed: Migration has no THORChain dependency; S1-07 explicitly imported this generic pre-existing cache bug into the slice.
- V-002 verification/passed: Endpoint/provider/factory/kit/logger protocols and runtime self-validation exceed the concrete manager analog; three endpoint families remain essential.
- V-003 verification/passed: Two adapter-owned locks, stopped gate, and bespoke precision state have no adapter analog and duplicate kit/existing conversion responsibilities.
- V-004 verification/passed: Receive does not require the parser; current slice adds the parser and immediately adds a generic rejection path because send is absent.
- U-001 unrun/not_run: All three Gimle/Palace calls timed out after 300 seconds; fallback evidence was codebase-memory plus independent Serena/Git/rg verification.
- R-001 residual_risk/accepted_risk: Evidence trust remains YELLOW solely because Gimle/Palace was unavailable; no Gimle payload was used and all load-bearing claims were independently verified.

## Bugs and limitations

### GIMLE-AUDIT-001: Palace health call timed out

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.health.status / E-0001 / n/a
- Reproduction: Call palace.health.status with no arguments.
- Expected: Runtime identity and reachability returned within the MCP timeout.
- Actual: No payload; tools/call timed out after 300 seconds.
- Impact: Gimle/Palace cannot be used for this audit; no Palace result may influence conclusions.
- Workaround: Use codebase-memory for indexed discovery and independently verify every conclusion with Serena, Git, and targeted rg in the active worktree.
- Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50

### GIMLE-AUDIT-002: Palace project discovery timed out

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0002 / n/a
- Reproduction: Call palace.memory.list_projects with no arguments.
- Expected: Registered projects and repository mappings returned within the MCP timeout.
- Actual: No payload; tools/call timed out after 300 seconds.
- Impact: Gimle/Palace cannot be used for this audit; no Palace result may influence conclusions.
- Workaround: Use codebase-memory for indexed discovery and independently verify every conclusion with Serena, Git, and targeted rg in the active worktree.
- Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50

### GIMLE-AUDIT-003: Palace code routing discovery timed out

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.code.list_passthrough_projects / E-0003 / n/a
- Reproduction: Call palace.code.list_passthrough_projects with no arguments.
- Expected: Native/delegated routing and code coverage returned within the MCP timeout.
- Actual: No payload; tools/call timed out after 300 seconds.
- Impact: Gimle/Palace cannot be used for this audit; no Palace result may influence conclusions.
- Workaround: Use codebase-memory for indexed discovery and independently verify every conclusion with Serena, Git, and targeted rg in the active worktree.
- Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
