# THR-118 — S1-07 Unstoppable RUNE surface

## Goal

Make native mainnet RUNE discoverable, strictly addressable, balance/receive-visible, restorable, and restart-stable in Unstoppable Wallet v0.50 through the existing S1-06 lifecycle composition.

## Current phase and approval gate

- [x] Evidence and analog selection completed (`discovery 1/2`); exact v0.50 checkout independently verified.
- [x] Design revision 2 and delta matrix written.
- [x] Adversarial review completed and recorded (`D-THR118-ARCH`, `D-THR118-SEC`, `D-THR118-VERIFY`).
- [ ] Operator explicitly approves this spec and plan.
- [ ] Released MarketKit/backend/cache contract is available.
- [ ] Implementation is authorized and assigned to the Swift engineer.

No implementation, UW commit, push, or PR is authorized by this plan revision.

## Assumptions and non-goals

Assumptions: MarketKit will release UID `thorchain`, native RUNE with decimals `8`, and the approved explorer template; S1-06 remains the owner of `ThorChainKitManager`, factory, adapter, and address-provider composition; existing WalletCore generic discovery/storage/lifecycle seams remain valid.

Non-goals: default enable, URI/deeplink, history, send/swap, non-native THOR assets, stagenet, Maestro, fixture transport, launch arguments, acceptance-only runtime code, atomic restore migration, or changes to S1-06-owned files.

## Steps

### 1. Close the released metadata gate

**Owner:** CTO / MarketKit owner before host implementation.

**Affected paths:** released MarketKit package and backend/cache contract; `packages/WalletCore/Package.swift` only for the dependency bump.

**Acceptance:** release contains `.thorChain`, UID `thorchain`, native RUNE code, decimals `8`, and explorer `$ref` metadata; WalletCore resolves the released version. A local feature branch alone is insufficient.

**Verification:** MarketKit UID/backend/cache/native-query tests and a clean WalletCore dependency resolution against the released version.

**Dependency:** blocks Steps 2–5.

### 2. Add host discoverability policy

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`; existing Manage Wallets/AppTests seams.

**Acceptance:** `.thorChain` is supported and ordered immediately after `.tron`, is described as `RUNE`, uses generic native-token queries, supports only the approved mnemonic policy, and is not default-enabled.

**Verification:** targeted AppTests for supported/order/description/native query/account policy plus Manage Wallets search → manual enable.

**Dependency:** Step 1; S1-06 composition remains unchanged.

### 3. Add strict address parsing

**Owner:** Swift engineer.

**Affected paths:** `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`; `Core/Factories/AddressParserFactory.swift`; existing parser tests.

**Acceptance:** factory routes `.thorChain` to a mainnet parser backed by `ThorChainKit.Address`; valid addresses return canonical lowercase raw values, invalid values return `Single.error`/`false`, and non-THOR HRPs, mixed case, malformed length, and bad checksum are rejected.

**Verification:** parser AppTests through the factory with valid, checksum, HRP, length, case, and malformed vectors; `rg` confirms no URI/parser fallback.

**Dependency:** Step 1; uses the S1-06 kit codec without duplicating it.

### 4. Prove generic balance, receive, status, restore, and restart

**Owner:** Swift engineer, then independent QA.

**Affected paths:** `AppStatusViewModel.swift` for the one status enum case; existing AppTests; no speculative edits to WalletStorage, WalletManager, RestoreHelper, adapter, or receive/balance consumers.

**Acceptance:** exact 8-decimal balance, canonical `thor1…` receive address, sanitized status, restore selection, cold reconstruction, offline stale/error retention, recovery, remove/stop, and reinstall/no-cache all work through generic seams. Missing metadata fails closed without silent deletion.

**Verification:** AppTests with adapter/storage spies; manual Development checklist on a public no-funds account. Record app/configuration/device/OS/endpoint/observed values without mnemonic material. No Maestro.

**Dependency:** Steps 1–3 and S1-06 local lifecycle composition.

### 5. Mechanical review, adversarial review, and QA

**Owner:** target-local CodeReviewer → architect reviewer → QA engineer → CTO merge gate.

**Affected paths:** implementation PR only after approval; this plan and spec remain the source of truth.

**Acceptance:** tests and required CI are green; review covers the frozen blocker allowlist and changed-line regressions; QA cites the exact PR head and manual evidence; CTO merges only after required Paperclip approvals.

**Verification:** project-equivalent lint/typecheck/test output, `gh pr checks`, no conflict markers, exact plan references, and QA evidence in the PR.

**Dependency:** explicit operator approval plus completed Steps 1–4.

## Handoff and closure rules

The implementation phase is a separate authorized workflow. Every handoff records `discovery 1/2` and `closure 0/5` until closure starts. Medium/low observations become backlog; a new blocker must cite a current acceptance criterion, exact repository evidence, and a concrete safety/implementation/verification failure. Once acceptance is satisfied, stop revising and hand off once.
