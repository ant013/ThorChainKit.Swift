# Gimle reliability report: THR-104-s1-06-v050-r2-20260722

- Task: 696d4946-ad62-4967-855f-56e84a42700b
- Workflow/phase: analog_change / verification
- Trust: **GREEN**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 407a3ce0ca564071a070276b60039d7bea1c3659
- Final HEAD: bed49c5694326bdf97cd213e7fd685a2543d2ab2
- Gimle runtime: 0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: 8a63bfda028dd8543115b26dd777235a53304311

## Metrics

- Calls: 5 (success 5, warning 0, error 0, false-success 0)
- Useful-call rate: 100.0%
- Response-byte coverage: 0/5; total n/a
- Duration coverage: 0/5; total n/a ms
- Gimle agreement: 100.0%
- Gimle contradiction: 0.0%
- Location validity: 100.0%; coverage 1/1
- Freshness coverage: 100.0%
- Replacement/fallback claims: 0
- Bugs: 1
- Analog slices/candidates: 1/6

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.git.log | 1 | 0 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 1 | 0 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'environment_drift': 1}
Bug severities: {'medium': 1}
Bug statuses: {'workaround': 1}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | ok | success | n/a/1 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | ok | success | 18/18 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | ok | success | 18/18 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0004 | evidence | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | e40d2aa6fdce6b6f | n/a |
| E-0005 | evidence | palace.git.log | ok | success | 1/1 | n/a | n/a | yes | bc07a8615e5efcad | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S1-06-LC-V050 | high | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-V050-TRON-MANAGER | C-V050-ADDRESS-PROVIDER, C-V050-CORE-FACTORY, C-V050-APPTESTS, C-V050-LOCAL-WORKSPACE | C-V050-NOOP-ADAPTER-LIFECYCLE |
  - Conflict: Manager-owned start conflicts with required adapter-owned lifecycle.; resolution: Construct/cache unstarted kit in the new manager; adapter alone implements start, stop, and refresh.
  - Conflict: The obsolete master patch uses a direct static address boundary, while version/0.50 owns provider registration.; resolution: Implement THOR address derivation through IAccountAddressProvider and keep version/0.50 composition intact.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-V050-TRON-MANAGER | S1-06-LC-V050 | kept | F-V050-LIFECYCLE | composition, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift |
| C-V050-ADDRESS-PROVIDER | S1-06-LC-V050 | supporting | F-V050-ADDRESS | contract, implementation | boundary, dependencies, responsibility, state_errors, trust | known_current | packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift |
| C-V050-CORE-FACTORY | S1-06-LC-V050 | supporting | F-V050-COMPOSITION | composition, consumer | boundary, dependencies, lifecycle, responsibility, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Core/Core.swift |
| C-V050-APPTESTS | S1-06-LC-V050 | supporting | F-V050-TESTS | test | boundary, tests | known_current | Unstoppable/Tests/AppTests.swift |
| C-V050-LOCAL-WORKSPACE | S1-06-LC-V050 | supporting | F-V050-LOCAL-WIRING | composition, consumer | boundary, dependencies, tests, trust | known_current | Wallet.xcworkspace/contents.xcworkspacedata |
| C-V050-NOOP-ADAPTER-LIFECYCLE | S1-06-LC-V050 | rejected | F-V050-LIFECYCLE | counterexample, implementation, lifecycle_error | lifecycle, responsibility, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Core/Adapters/Tron/TronAdapter.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-V050-IDENTITY | 1 | yes | MATCH | yes | rg | E-0004, E-0005 | valid | known_current | The authoritative local Unstoppable worktree is the official repository at clean origin/version/0.50 commit 8a63bfda028dd8543115b26dd777235a53304311, and Palace uw-ios-app index... |
  - Serena: n/a
  - rg: git remote, branch, rev-parse, and porcelain status confirm official origin, local-only branch, exact version/0.50 HEAD, and a clean worktree.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-LIFECYCLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At version/0.50, TronKitManager creates and starts its kit while TronAdapter IAdapter lifecycle methods are no-ops; this is the lifecycle ownership analog and the explicit split... |
  - Serena: TronKitManager[0] lines 8-111 contains tronKit.start(); TronAdapter[2] lines 20-32 contains no-op start/stop/refresh.
  - rg: Targeted rg confirms manager start at line 96 and adapter lifecycle declarations at lines 21-30.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift@8a63bfda028dd8543115b26dd777235a53304311, /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Core/Adapters/Tron/TronAdapter.swift@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-ADDRESS | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At version/0.50, AccountAddress is public, maintains registered IAccountAddressProvider instances, and resolves EVM/TRON addresses through that provider contract. |
  - Serena: AccountAddress overview reports providers/register/evmAddress/tronAddress and IAccountAddressProvider evmAddress/tronAddress.
  - rg: Targeted rg confirms public enum, register method, provider iteration methods, and public provider protocol at lines 5-35.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-COMPOSITION | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At version/0.50, Core constructs TronKitManager locally and injects it into AdapterFactory and AdapterManager; AdapterFactory routes wallets through chain-specific adapter creat... |
  - Serena: Core symbol overview and AdapterFactory overview confirm Core.init composition and manager/factory adapter boundaries.
  - rg: Targeted rg confirms local tronKitManager construction at Core lines 279-280 and injections at 356-376; AdapterFactory owns tronKitManager.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Core/Core.swift@8a63bfda028dd8543115b26dd777235a53304311, /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-TESTS | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The version/0.50 workspace exposes the existing AppTests target and file-synchronized Unstoppable/Tests group as the host integration test seam. |
  - Serena: n/a
  - rg: Development.xcscheme includes AppTests.xctest; project.pbxproj defines AppTests and a file-system synchronized Tests group; Unstoppable/Tests/AppTests.swift imports WalletCore.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/Unstoppable/Tests/AppTests.swift@8a63bfda028dd8543115b26dd777235a53304311, /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/Unstoppable/Unstoppable.xcodeproj/project.pbxproj@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-LOCAL-WIRING | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The tracked Wallet.xcworkspace already consumes packages/WalletCore as a local package, while WalletCore currently resolves MarketKit remotely; local ThorChainKit and MarketKit ... |
  - Serena: n/a
  - rg: Wallet.xcworkspace/contents.xcworkspacedata references group:packages/WalletCore; WalletCore Package.swift pins remote MarketKit 3.6.12 and has no ThorChainKit dependency.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/Wallet.xcworkspace/contents.xcworkspacedata@8a63bfda028dd8543115b26dd777235a53304311, /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Package.swift@8a63bfda028dd8543115b26dd777235a53304311
| F-V050-OLD-PATCH | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The master-based S1-06 patch is not mechanically applicable to version/0.50 and must not be cherry-picked or blindly applied. |
  - Serena: n/a
  - rg: git apply --check rejects packages/WalletCore/Package.swift and AccountAddress.swift; branch diff shows 0.50 retains IAccountAddressProvider while master removed it.
  - Anchors: /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Package.swift@8a63bfda028dd8543115b26dd777235a53304311, /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift@8a63bfda028dd8543115b26dd777235a53304311

## Adversarial decisions

- D-V050-001@1 ACCEPT: Correct Unstoppable base and evidence identity
- D-V050-002@1 ACCEPT: Preserve the version/0.50 public address-provider contract
- D-V050-003@1 ACCEPT: Keep Unstoppable integration strictly local
- D-V050-004@1 ACCEPT: Use one lifecycle owner
- D-V050-005@1 ACCEPT: Preserve trust and secret boundaries
- D-V050-006@1 ACCEPT: Use the smallest testable version/0.50 delta

## Verification and acceptance

- AC-TARGETED-THORCHAIN acceptance/passed: Final endpoint-corrected xcresult: 25 passed, 0 failed, 0 skipped on iPhone 17 Pro iOS 26.2 build 23C52.
- AC-APP-BUILD acceptance/passed: Final post-endpoint-correction Development application build completed with BUILD SUCCEEDED.
- AC-DIRECT-APPTESTS-PRODUCT acceptance/failed: Xcode 26.2 failed the existing static package graph at the transitive HsCryptoKit Crypto wrapper; experimental project entries were fully removed and AppTests use the working transitive WalletCore dependency.
- UNRUN-LIVE-NINEREALMS verification/passed: The original unrun was resolved: NineRealms has no A record, the approved provider was corrected to the working official Liquify pair, and AC-LIVE-LIQUIFY passed on the simulator.
- RISK-FULL-APPTESTS-BASELINE residual_risk/accepted_risk: 135 of 136 passed; the sole failure is the unchanged version/0.50 SwapRequestRefund actionRequired pending-status expectation outside S1-06.
- VER-STATIC-HYGIENE verification/passed: All static and hygiene checks passed; project.pbxproj and AdapterManager.swift remain unchanged.
- VER-DIFF-IDENTITY verification/passed: Base HEAD 8a63bfda028dd8543115b26dd777235a53304311; final endpoint-corrected local diff SHA-256 eafc62acc3dd67ededa4666540314fb51a19fa33f348cf616d793f6938b05fe4.
- VER-DIRECT-MODULES verification/passed: ThorChainKit ordinary tests 83 passed, invariant harness 3 passed, and MarketKit iOS tests 2 passed.
- AC-LIVE-LIQUIFY acceptance/passed: Real mainnet read passed: chain thorchain-1; Cosmos, CometBFT and accepted heights 27111362; raw and implementation RUNE amounts matched; absent account returned empty.

## Bugs and limitations

### ENV-CBM-001: codebase-memory transport closed during version/0.50 correction

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: codebase-memory/index_status / n/a / n/a
- Reproduction: index_status project=Users-ant013-Data-AI-thorchain returns Transport closed
- Expected: Indexed project status is returned
- Actual: MCP transport closed before a status payload
- Impact: No codebase-memory architecture evidence is available for the correction run
- Workaround: Use exact Git identity, Palace at matching commit, Serena on the version/0.50 worktree, and targeted rg/diff checks
- Anchors: /Users/ant013/Data/AI/thorchain@407a3ce0ca564071a070276b60039d7bea1c3659

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
