# THR-118 — S1-07 Unstoppable RUNE surface (design revision 7)

## Goal

Make native mainnet RUNE discoverable, strictly addressable, balance/receive-visible, restorable, and restart-stable in Unstoppable Wallet v0.50 through the existing S1-06 lifecycle composition.

## Current phase and approval gate

- [x] Evidence and analog selection completed (`discovery 1/2`); exact v0.50 checkout independently verified.
- [x] Design revision 7 and delta matrix written; exact-head review corrections for `D-S107-REV-003`, `006`, and `007` are addressed; `001`, `002`, `004`, and `005` are accepted.
- [ ] Fresh bounded adversarial review of revision 7 (`discovery 1/2`, closure `0/5`).
- [ ] Operator explicitly approves this spec and plan.
- [ ] Released MarketKit/backend/cache contract is available before final acceptance/commit; approved local work remains pinned to MarketKit head `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` until then.
- [ ] Implementation is authorized and assigned to the Swift engineer.

No implementation, UW commit, push, or PR is authorized by this plan revision.

## Assumptions and non-goals

Assumptions: approved local implementation uses exact MarketKit head `2c327452237cfbbdc4d87bcd5dd417d1da46a61e`; the MarketKit owner will provide a released UID `thorchain`, native RUNE with decimals `8`, and an authoritative explorer/cache fixture before final delivery; S1-06 remains the owner of `ThorChainKitManager`, factory, and address-provider lifecycle composition; existing WalletCore generic seams can carry a display-only unavailable row with the smallest compatible API delta; current migration behavior can be corrected to preserve cache rows using the legacy `balance`/`balanceLocked` contract.

Non-goals: default enable, URI/deeplink, history, send/swap, non-native THOR assets, stagenet, Maestro, fixture transport, launch arguments, acceptance-only runtime code, atomic restore migration, or changes to S1-06-owned files.

## Steps

### 1. Close the released metadata gate

**Owner:** CTO / MarketKit owner before final acceptance and commit.

**Affected paths:** released MarketKit package and backend/cache contract; `packages/WalletCore/Package.swift` only for the dependency bump.

**Acceptance:** release contains `.thorChain`, UID `thorchain`, native RUNE code, decimals `8`, and explorer metadata. The MarketKit owner must attach the exact release tag/version plus decoded cache fixture (including the literal explorer template) as the authoritative verification artifact; until then this step is blocked and a local feature branch is insufficient.

**Verification:** MarketKit UID/backend/cache/native-query tests, decoded release/cache artifact, `swift package dump-package` proves one canonical remote MarketKit dependency and no local file-system dependency, and `Package.resolved` proves the same remote identity/URL/released version/revision plus the owner-supplied SHA-256.

**Dependency:** blocks final acceptance/commit and Step 6 closure, but not approved local test-first Steps 2–5 against the exact pinned checkout.

### 2. Add host discoverability policy

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`, `Models/AccountType.swift`, `Modules/ManageWallets/ManageWalletsTokenFetcher.swift`, `Modules/RestoreAccount/RestoreCoins/RestoreCoinsViewModel.swift`, and the shared `Core/Policies/ThorChainRuneIdentityPolicy.swift`; existing Manage Wallets/AppTests seams.

**Acceptance:** `.thorChain` is supported and ordered immediately after `.tron`, is described as `RUNE`, uses generic native-token queries filtered by the shared `ThorChainRuneIdentityPolicy` only for THOR candidates after metadata resolution, leaves BTC/ETH discovery unchanged, applies the same THOR-only policy to preferred-token discovery, preserves create defaults, is selectable by `RestoreCoinsViewModel`, adds only `.mnemonic/.native` support in `AccountType.supports(token:)`, and is not default-enabled.

**Verification:** targeted AppTests for supported/order/description/native query/account policy plus Manage Wallets search → manual enable.

**Dependency:** pinned local MarketKit head for implementation; Step 1 for final acceptance. S1-06 composition remains unchanged.

### 3. Add strict address parsing

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`; `Core/Factories/AddressParserFactory.swift`; existing parser tests.

**Acceptance:** factory routes `.thorChain` to a mainnet parser backed by `ThorChainKit.Address`; valid addresses return canonical lowercase raw values, invalid values return `Single.error`/`false`, and non-THOR HRPs, mixed case, malformed length, and bad checksum are rejected.

**Verification:** parser AppTests through the factory with valid, checksum, HRP, length, case, and malformed vectors; `rg` confirms no URI/parser fallback.

**Dependency:** pinned local MarketKit head for implementation; Step 1 for final acceptance. Uses the S1-06 kit codec without duplicating it.

### 4. Enforce exact composition identity and all prohibited ingress guards

**Owner:** Swift engineer.

**Affected paths:** `Core/Policies/ThorChainRuneIdentityPolicy.swift`, `Core/Factories/AdapterFactory.swift`, `Core/Adapters/ThorChain/ThorChainAdapter.swift`, `Modules/Wallet/WalletView.swift`, `Modules/Wallet/WalletViewModel.swift`, `Modules/Wallet/Token/WalletTokenViewModel.swift`, `Modules/Wallet/SendTokenListViewModel.swift`, `Modules/MultiSwap/RegularMultiSwapView.swift`, `Modules/MultiSwap/MultiSwapViewModel.swift`, `Modules/MultiSwap/TokenSelect/MultiSwapTokenSelectViewModel.swift`, `Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift`, and existing AppTests.

**Acceptance:** the `.native/.thorChain` factory case and adapter initializer both require `thorchain/thorchain/RUNE/native/8`; RUJI, TCY, wrong coin/blockchain UID, custom-token, and wrong-decimal THOR records return no adapter. The shared `ThorChainRuneIdentityPolicy` is called only for THOR candidates, so mixed persisted/discovery/restore BTC/ETH records remain resolved and usable. One shared capability predicate is applied to the five ingress families—WalletView row actions, downstream top-level SendTokenList/Swap selectors, token buttons, token-seeded MultiSwap, and QR/deep-link Send—and direct token-seeded initialization cannot bypass it.

**Verification:** composition negatives, THOR-only policy negatives, persisted/discovery/restore BTC/ETH survival, native-RUNE direct-seed rejection, mixed non-THOR direct-seed compatibility, and one test per ingress family through existing AppTests seams; `rg` confirms every named route has the guard.

**Dependency:** Steps 2–3, pinned local MarketKit head, and S1-06 local lifecycle composition; Step 1 remains the final-delivery gate.

### 5. Prove generic balance, receive, status, restore, and restart

**Owner:** Swift engineer, then independent QA.

**Affected paths:** `AppStatusViewModel.swift`, `WalletStorage.swift`/`WalletManager.swift`/`WalletData`, `WalletService.swift`, `WalletListViewModel.swift`, `StorageMigrator.swift`, `EnabledWalletCache_v_0_36.swift` fixture seam, existing AppTests, and cache migration fixtures; no lifecycle rewrite in the S1-06 manager/factory/adapter.

**Acceptance:** exact 8-decimal balance, canonical `thor1…` receive address, sanitized status, restore selection, cold reconstruction, durable unavailable identity, exact terminal/retryable diagnostic codes for empty/missing and throwing metadata, display-only unavailable row, identity-keyed unavailable removal/publication cleanup, stale/error publication and retry, truthful value-preserving migration from legacy `balance`/`balanceLocked` to new `total`/`available` (`total = balance`, `available = balance` per the old runtime model), offline stale/error retention, recovery, one-adapter invariant, remove/stop, and reinstall/no-cache all work through generic seams. Missing token/chain or throwing token/blockchain queries fail closed without silent deletion or fabricated zero state.

**Verification:** AppTests with deterministic `WalletQuerying`/adapter/endpoint spies covering cache seed and old-schema value-preserving migration with a non-zero `balanceLocked` sentinel, persisted/discovery/restore BTC/ETH survival, malformed identity, empty/missing and both throwing query sites, unavailable-state retry, terminal identity-keyed removal/publication cleanup, exact THOR identity negatives, mixed BTC/ETH-plus-RUNE selector compatibility, one test per ingress family, offline/recovery transitions, and adapter count; manual Development checklist and exact `xcodebuild` command in the spec on a public no-funds account. Record app/configuration/device/OS/endpoint/observed values without mnemonic material. No Maestro.

**Dependency:** Steps 2–4 and S1-06 local lifecycle composition; Step 1 remains the final-delivery gate.

### 6. Mechanical review, adversarial review, and QA

**Owner:** target-local CodeReviewer → architect reviewer → QA engineer → CTO merge gate.

**Affected paths:** implementation PR only after approval; this plan and spec remain the source of truth.

**Acceptance:** tests and required CI are green; review covers the frozen blocker allowlist and changed-line regressions; QA cites the exact PR head and manual evidence; CTO merges only after required Paperclip approvals.

**Verification:** project-equivalent lint/typecheck/test output, `gh pr checks`, no conflict markers, exact plan references, and QA evidence in the PR.

**Dependency:** explicit operator approval plus completed Steps 1–5.

## Handoff and closure rules

The implementation phase is a separate authorized workflow. Unstoppable changes remain local and uncommitted until final operator delivery authorization. Every handoff records `discovery 1/2` and `closure 0/5` until closure starts. The seven discovery blockers are now the stable allowlist; closure rechecks only those IDs and changed-line regressions. Medium/low observations become backlog; a new blocker must cite a current acceptance criterion, exact repository evidence, and a concrete safety/implementation/verification failure. Once acceptance is satisfied, stop revising and hand off once.
