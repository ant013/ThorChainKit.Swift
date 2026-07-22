# THR-118 — S1-07 Unstoppable RUNE surface (design revision 4)

## Goal

Make native mainnet RUNE discoverable, strictly addressable, balance/receive-visible, restorable, and restart-stable in Unstoppable Wallet v0.50 through the existing S1-06 lifecycle composition.

## Current phase and approval gate

- [x] Evidence and analog selection completed (`discovery 1/2`); exact v0.50 checkout independently verified.
- [x] Design revision 4 and delta matrix written; revision-3 review corrections addressed (`D-S107-REV-001` … `D-S107-REV-007`).
- [ ] Fresh bounded adversarial review of revision 4 (`discovery 1/2`, closure `0/5`).
- [ ] Operator explicitly approves this spec and plan.
- [ ] Released MarketKit/backend/cache contract is available.
- [ ] Implementation is authorized and assigned to the Swift engineer.

No implementation, UW commit, push, or PR is authorized by this plan revision.

## Assumptions and non-goals

Assumptions: the MarketKit owner will provide a released UID `thorchain`, native RUNE with decimals `8`, and an authoritative explorer/cache fixture; S1-06 remains the owner of `ThorChainKitManager`, factory, and address-provider lifecycle composition; existing WalletCore generic seams can carry a display-only unavailable row with the smallest compatible API delta; current migration behavior can be corrected to preserve cache rows.

Non-goals: default enable, URI/deeplink, history, send/swap, non-native THOR assets, stagenet, Maestro, fixture transport, launch arguments, acceptance-only runtime code, atomic restore migration, or changes to S1-06-owned files.

## Steps

### 1. Close the released metadata gate

**Owner:** CTO / MarketKit owner before host implementation.

**Affected paths:** released MarketKit package and backend/cache contract; `packages/WalletCore/Package.swift` only for the dependency bump.

**Acceptance:** release contains `.thorChain`, UID `thorchain`, native RUNE code, decimals `8`, and explorer metadata. The MarketKit owner must attach the exact release tag/version plus decoded cache fixture (including the literal explorer template) as the authoritative verification artifact; until then this step is blocked and a local feature branch is insufficient.

**Verification:** MarketKit UID/backend/cache/native-query tests, decoded release/cache artifact, and clean WalletCore dependency resolution against that released version.

**Dependency:** blocks Steps 2–5.

### 2. Add host discoverability policy

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`, `Models/AccountType.swift`; existing Manage Wallets/AppTests seams.

**Acceptance:** `.thorChain` is supported and ordered immediately after `.tron`, is described as `RUNE`, uses generic native-token queries filtered to exact RUNE identity, preserves create defaults, is selectable by `RestoreCoinsViewModel`, adds only `.mnemonic/.native` support in `AccountType.supports(token:)`, and is not default-enabled.

**Verification:** targeted AppTests for supported/order/description/native query/account policy plus Manage Wallets search → manual enable.

**Dependency:** Step 1; S1-06 composition remains unchanged.

### 3. Add strict address parsing

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`; `Core/Factories/AddressParserFactory.swift`; existing parser tests.

**Acceptance:** factory routes `.thorChain` to a mainnet parser backed by `ThorChainKit.Address`; valid addresses return canonical lowercase raw values, invalid values return `Single.error`/`false`, and non-THOR HRPs, mixed case, malformed length, and bad checksum are rejected.

**Verification:** parser AppTests through the factory with valid, checksum, HRP, length, case, and malformed vectors; `rg` confirms no URI/parser fallback.

**Dependency:** Step 1; uses the S1-06 kit codec without duplicating it.

### 4. Enforce exact composition identity and all prohibited ingress guards

**Owner:** Swift engineer.

**Affected paths:** `Core/Factories/AdapterFactory.swift`, `Core/Adapters/ThorChain/ThorChainAdapter.swift`, `Modules/Wallet/WalletView.swift`, `Modules/Wallet/WalletViewModel.swift`, `Modules/Wallet/Token/WalletTokenViewModel.swift`, `Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift`, and existing AppTests.

**Acceptance:** the `.native/.thorChain` factory case and adapter initializer both require `thorchain/thorchain/RUNE/native/8`; RUJI, TCY, wrong coin/blockchain UID, custom-token, and wrong-decimal records return no adapter. The five ingress families—WalletView row actions, top-level SendTokenList/Swap, token buttons, token-seeded MultiSwap, and QR/deep-link Send—cannot open unsupported RUNE flows; generic non-THOR routes are unchanged.

**Verification:** composition negatives and one test per ingress family through existing AppTests seams; `rg` confirms every named route has the guard.

**Dependency:** Steps 1–3 and S1-06 local lifecycle composition.

### 5. Prove generic balance, receive, status, restore, and restart

**Owner:** Swift engineer, then independent QA.

**Affected paths:** `AppStatusViewModel.swift`, `WalletStorage.swift`/`WalletManager.swift`/`WalletData`, `WalletService.swift`, `WalletListViewModel.swift`, `StorageMigrator.swift`, existing AppTests, and cache migration fixtures; no lifecycle rewrite in the S1-06 manager/factory/adapter.

**Acceptance:** exact 8-decimal balance, canonical `thor1…` receive address, sanitized status, restore selection, cold reconstruction, durable unavailable identity, exact terminal/retryable diagnostic codes, display-only unavailable row, stale/error publication and retry, value-preserving cache migration, offline stale/error retention, recovery, one-adapter invariant, remove/stop, and reinstall/no-cache all work through generic seams. Missing token/chain or throwing token/blockchain queries fail closed without silent deletion or fabricated zero state.

**Verification:** AppTests with deterministic `WalletQuerying`/adapter/endpoint spies covering cache seed and value-preserving migration, malformed identity, both throwing query sites, unavailable-state retry, exact identity negatives, one test per ingress family, offline/recovery transitions, and adapter count; manual Development checklist and exact `xcodebuild` command in the spec on a public no-funds account. Record app/configuration/device/OS/endpoint/observed values without mnemonic material. No Maestro.

**Dependency:** Steps 1–4 and S1-06 local lifecycle composition.

### 6. Mechanical review, adversarial review, and QA

**Owner:** target-local CodeReviewer → architect reviewer → QA engineer → CTO merge gate.

**Affected paths:** implementation PR only after approval; this plan and spec remain the source of truth.

**Acceptance:** tests and required CI are green; review covers the frozen blocker allowlist and changed-line regressions; QA cites the exact PR head and manual evidence; CTO merges only after required Paperclip approvals.

**Verification:** project-equivalent lint/typecheck/test output, `gh pr checks`, no conflict markers, exact plan references, and QA evidence in the PR.

**Dependency:** explicit operator approval plus completed Steps 1–4.

## Handoff and closure rules

The implementation phase is a separate authorized workflow. Every handoff records `discovery 1/2` and `closure 0/5` until closure starts. The seven discovery blockers are now the stable allowlist; closure rechecks only those IDs and changed-line regressions. Medium/low observations become backlog; a new blocker must cite a current acceptance criterion, exact repository evidence, and a concrete safety/implementation/verification failure. Once acceptance is satisfied, stop revising and hand off once.
