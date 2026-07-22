# Gimle reliability report: THR-S1-07-v050-20260722

- Task: S1-07
- Workflow/phase: analog_change / adversarial_review
- Trust: **YELLOW**
- Repository: /Users/ant013/Data/AI/thorchain-worktrees/s1-07-unstoppable-rune-surface
- Base HEAD: 0f572e455be07df798a233eff31bbc27bb0940c5
- Final HEAD: bfcff54
- Gimle runtime: 0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: 8a63bfda028dd8543115b26dd777235a53304311

## Metrics

- Calls: 12 (success 10, warning 1, error 1, false-success 0)
- Useful-call rate: 66.7%
- Response-byte coverage: 0/12; total n/a
- Duration coverage: 1/12; total 0 ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 4/4
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 2
- Analog slices/candidates: 3/14

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| codebase-memory.list_projects | 0 | 0 | 1 | 0 |
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.code.semantic_search | 2 | 0 | 0 | 0 |
| palace.health.status | 2 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 1 | 1 | 0 | 0 |
| palace.memory.health | 2 | 0 | 0 | 0 |
| palace.memory.list_projects | 2 | 0 | 0 | 0 |

Bug classes: {'environment_drift': 1, 'stale_index': 1}
Bug severities: {'medium': 2}
Bug statuses: {'workaround': 2}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | codebase-memory.list_projects | failed | error | n/a/n/a | n/a | 0 | no | 44136fa355b3678a | Transport closed; no indexed result available |
| E-0002 | preflight | palace.health.status | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace.memory.health | ok | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0004 | preflight | palace.memory.list_projects | ok | success | 18/18 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0005 | preflight | palace.code.list_passthrough_projects | ok | success | n/a/7 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0006 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | e40d2aa6fdce6b6f | n/a |
| E-0007 | preflight | palace.memory.get_project_overview | ok | warning | n/a/1 | n/a | n/a | no | 5261fcd5cef400c7 | indexed_commit unavailable; dominant commit is pre-S1-06 base and local branch changes are not represented |
| E-0008 | evidence | palace.health.status | reachable | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0009 | evidence | palace.memory.health | reachable | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0010 | evidence | palace.memory.list_projects | reachable | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0011 | evidence | palace.code.semantic_search | ok | success | 80/8 | n/a | n/a | yes | 4032908180f94a64 | n/a |
| E-0012 | evidence | palace.code.semantic_search | ok | success | 65/8 | n/a | n/a | yes | 34a64e42e1b19364 | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S107-A | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S107-A-MANAGE | C-S107-A-THOR, C-S107-A-RESTORE | C-S107-A-COUNTER |
  - Conflict: MarketKit local metadata is current but backend explorer URL is unresolved.; resolution: Use Manage Wallets and restore seams for discovery; require the MarketKit/backend release gate and preserve the S1-06 THOR manager as a fixed dependency; reject MultiSwap as a discovery analog; defer implementation until backend explorer is non-null and exact template is verified.
| S107-B | high | boundary, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S107-B-WALLET | C-S107-B-SWAP, C-S107-B-EVENT, C-S107-B-THOR | C-S107-B-COUNTER |
  - Conflict: Generic wallet and swap ingress currently expose RUNE to out-of-scope send/swap surfaces.; resolution: Keep receive/address and balance paths; suppress RUNE at every send/swap ingress, including generic buttons, send-list, QR-to-send event routing, and MultiSwap token selection.
| S107-C | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S107-C-STORAGE | C-S107-C-RESTORE, C-S107-C-THOR | C-S107-C-EMPTY |
  - Conflict: Existing storage and manager catch paths can make persisted wallets disappear on metadata/query failure.; resolution: Preserve durable enabled-wallet identity and expose unavailable/retry state on reconstruction failure; reject current catch-to-empty behavior as an unsafe persistence analog.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-S107-A-MANAGE | S107-A | kept | F-S107-001 | consumer, contract, implementation, lifecycle_error, test | boundary, lifecycle, responsibility, state_errors, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsTokenFetcher.swift |
| C-S107-A-THOR | S107-A | supporting | F-S107-005 | contract, implementation, lifecycle_error | boundary, lifecycle, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift |
| C-S107-A-MARKET | S107-A | supporting | F-S107-006 | contract, test | responsibility, tests, trust | known_current | Tests/MarketKitTests/ThorChainMetadataTests.swift |
| C-S107-A-COUNTER | S107-A | rejected | F-S107-004 | counterexample, implementation | boundary, lifecycle, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Modules/MultiSwap/TokenSelect/MultiSwapTokenSelectViewModel.swift |
| C-S107-B-WALLET | S107-B | kept | F-S107-003 | consumer, contract, implementation, lifecycle_error | boundary, lifecycle, responsibility, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletViewModel.swift |
| C-S107-B-SWAP | S107-B | supporting | F-S107-004 | consumer, test | boundary, responsibility, state_errors, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/MultiSwap/TokenSelect/MultiSwapTokenSelectViewModel.swift |
| C-S107-B-EVENT | S107-B | supporting | F-S107-003 | consumer, implementation | boundary, responsibility, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift |
| C-S107-B-COUNTER | S107-B | rejected | F-S107-004 | counterexample, implementation | boundary, lifecycle | known_current | packages/WalletCore/Sources/WalletCore/Modules/MultiSwap/TokenSelect/MultiSwapDefaultTokenResolver.swift |
| C-S107-C-STORAGE | S107-C | kept | F-S107-009@1 | consumer, contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift |
| C-S107-C-RESTORE | S107-C | supporting | F-S107-001 | composition, contract, test | dependencies, lifecycle, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreHelper.swift |
| C-S107-C-THOR | S107-C | supporting | F-S107-005 | implementation, lifecycle_error | lifecycle, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift |
| C-S107-C-EMPTY | S107-C | rejected | F-S107-009@1 | counterexample, implementation, lifecycle_error | lifecycle, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift |
| C-S107-A-RESTORE | S107-A | supporting | F-S107-001 | composition, contract, test | dependencies, lifecycle, tests | known_current | packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreHelper.swift |
| C-S107-B-THOR | S107-B | supporting | F-S107-005 | composition, contract, lifecycle_error | dependencies, lifecycle, tests, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-S107-001 | 1 | yes | MATCH | yes | serena+rg | E-0011 | valid | known_current | ManageWalletsTokenFetcher derives featured/native token queries from BlockchainType.supported and filters every result through AccountType.supports; ManageWalletsViewModel consu... |
  - Serena: Serena current UW symbols: ManageWalletsViewModel.reloadTokens/item/toggle; ManageWalletsTokenFetcher.fetch; AccountType.supports.
  - rg: ManageWalletsTokenFetcher.swift:6-29,46-75; ManageWalletsViewModel.swift:29-126,157-190.
  - Anchors: packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsTokenFetcher.swift:6-75, packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsViewModel.swift:29-190
| F-S107-002 | 1 | yes | MATCH | yes | serena+rg | E-0012 | valid | known_current | RestoreHelper restores a selected token through sequential account save, restore-state marker save, and wallet save; WalletStorage reconstructs enabled wallets from TokenQuery i... |
  - Serena: Serena current UW symbols: RestoreHelper.supportedTokens/restoreSingleBlockchain; WalletStorage.wallets; WalletManager._reloadWallets/wallets.
  - rg: RestoreHelper.swift:3-20; WalletStorage.swift:24-75; WalletManager.swift:35-65,76-101.
  - Anchors: packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreHelper.swift:3-20, packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift:24-75, packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift:35-101
| F-S107-003 | 1 | yes | MATCH | yes | serena+rg | E-0011 | valid | known_current | The current UW wallet and token surfaces expose send and swap buttons without a THOR capability guard, and AddressEventHandler routes recognized QR/address input to SendTokenLis... |
  - Serena: Serena current WalletViewModel.buttons and WalletTokenViewModel.buttons are unconditional for non-watch accounts; AddressEventHandler.handlerResult returns sendPage.
  - rg: WalletViewModel.swift:105-107; WalletTokenViewModel.swift:147-157; AddressEventHandler.swift:15,35-59,81-115; WalletView.swift:290-317.
  - Anchors: packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletViewModel.swift:105-107, packages/WalletCore/Sources/WalletCore/Modules/Wallet/Token/WalletTokenViewModel.swift:147-157, packages/WalletCore/Sources/WalletCore/Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift:35-115
| F-S107-004 | 1 | yes | MATCH | yes | serena+rg | E-0011 | valid | known_current | MultiSwapTokenSelectViewModel includes active, suggested, and featured tokens using AccountType.supports but has no THOR-specific exclusion; MultiSwapDefaultTokenResolver maps a... |
  - Serena: Serena current MultiSwapTokenSelectViewModel and MultiSwapDefaultTokenResolver bodies show active/suggested/featured aggregation and native-token stablecoin resolution.
  - rg: MultiSwapTokenSelectViewModel.swift:30-113; MultiSwapDefaultTokenResolver.swift:3-31.
  - Anchors: packages/WalletCore/Sources/WalletCore/Modules/MultiSwap/TokenSelect/MultiSwapTokenSelectViewModel.swift:30-113, packages/WalletCore/Sources/WalletCore/Modules/MultiSwap/TokenSelect/MultiSwapDefaultTokenResolver.swift:3-31
| F-S107-005 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | S1-06 current UW composition accepts only mnemonic accounts, derives a THOR address through AccountAddress, validates approved HTTPS endpoint hosts, caches wrappers by account/a... |
  - Serena: Serena current ThorChainKitManager.makeValidatedWrapper and ThorChainAdapter symbols; exact bodies inspected.
  - rg: ThorChainKitManager.swift:47-89; ThorChainAdapter.swift:20-114; ThorChainKitManagerTests.swift:24-140; ThorChainAdapterTests.swift:214-223.
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift:47-89, packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift:20-114
| F-S107-006 | 1 | no | MATCH | yes | rg | n/a | valid | known_current | The local MarketKit feature branch contains current THORChain metadata tests asserting BlockchainType.thorChain, UID thorchain, native RUNE, and decimals 8, but it is not a rele... |
  - Serena: MarketKit feature branch HEAD 2c327452; ThorChainMetadataTests.swift inspected by targeted rg.
  - rg: Tests/MarketKitTests/ThorChainMetadataTests.swift:4-18; BlockchainType.swift:24,51,80; BlockchainRecord.swift:9-30.
  - Anchors: /Users/ant013/Data/AI/MarketKit.Swift-THR-104/Tests/MarketKitTests/ThorChainMetadataTests.swift:4-18, /Users/ant013/Data/AI/MarketKit.Swift-THR-104/Sources/MarketKit/Classes/Models/BlockchainRecord.swift:9-30
| F-S107-007 | 1 | no | PARTIAL | no | none | n/a | not_applicable | unknown | The released MarketKit/backend/cache version and non-null THORChain explorer URL are not verifiable from the current local worktrees; treating the local feature branch as accept... |
  - Serena: No release identity or backend/cache fixture is present in the assigned local MarketKit/UW worktrees; only local feature metadata tests are present.
  - rg: MarketKit local source exposes optional Blockchain.explorerUrl and local ThorChainMetadataTests does not assert a released backend URL.
  - Anchors: /Users/ant013/Data/AI/MarketKit.Swift-THR-104/Sources/MarketKit/Classes/Models/Blockchain.swift:1-10, /Users/ant013/Data/AI/MarketKit.Swift-THR-104/Tests/MarketKitTests/ThorChainMetadataTests.swift:4-18
| F-S107-008@1 | 1 | yes | PARTIAL | no | serena+rg | n/a | valid | known_current | WalletManager converts storage reload failures to an empty published wallet set, while WalletStorage omits enabled wallets when token and chain reconstruction cannot be complete... |
  - Serena: S107-WALLET-RECOVERY
  - rg: S107-WALLET-RECOVERY
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift:24-75, packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift:35-101
| F-S107-009@1 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | WalletManager._reloadWallets catches storage errors and publishes WalletData with an empty wallet array, while WalletStorage.wallets can return no Wallet for an enabled record w... |
  - Serena: S107-WALLET-RECOVERY
  - rg: S107-WALLET-RECOVERY
  - Anchors: packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift:35-101, packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift:24-75

## Adversarial decisions


## Verification and acceptance


## Bugs and limitations

### ENV-CBM-S107-001: codebase-memory transport unavailable for S1-07 preflight

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: codebase-memory.list_projects / E-0001 / n/a
- Reproduction: Call list_projects once before architecture discovery
- Expected: Indexed project inventory returned
- Actual: MCP transport closed before payload
- Impact: Indexed discovery unavailable; no codebase-memory result may influence the S1-07 design
- Workaround: Use verified filesystem identity, Serena, targeted rg, and bounded Gimle only where independently cross-checked
- Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50@8a63bfda

### GIM-S107-MARKET-001: MarketKit index does not cover local THORChain metadata branch

- Class/severity/confidence/status: stale_index / medium / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0007 / n/a
- Reproduction: Request overview for market-kit while local implementation HEAD is 2c327452
- Expected: Indexed commit and local-tree comparison for the branch used by S1-07
- Actual: indexed_commit is unavailable; dominant symbol commit is 95c92c8 and local S1-06 branch HEAD is not represented
- Impact: Gimle MarketKit symbols cannot drive S1-07 design decisions
- Workaround: Verify MarketKit metadata and consumers directly in /Users/ant013/Data/AI/MarketKit.Swift-THR-104 with Serena and targeted rg/git
- Anchors: /Users/ant013/Data/AI/MarketKit.Swift-THR-104@2c327452

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
