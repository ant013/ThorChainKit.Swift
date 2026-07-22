# S1-07 — Unstoppable Wallet RUNE surface

Status: design revision 3, pending exact-head adversarial review. The earlier
plan revision `4e83a731` and its approval request are superseded by the
operator correction on 2026-07-22; no implementation or approval is
authorized by this document.

## Goal

Make native THORChain RUNE discoverable and restorable in the exact Unstoppable
Wallet v0.50 integration while exposing only address, balance, and receive.
The enabled RUNE wallet must survive persistence and terminate/relaunch, and
metadata/query failures must not silently erase its durable identity.

## Acceptance criteria for implementation

1. A mnemonic account supports exactly `thorChain` + `native` RUNE. Non-native
   THOR assets, including RUJI and TCY, are rejected by token identity/type and
   never become discoverable or restorable.
2. RUNE appears in Manage Wallets and the create/import restore flow, with the
   existing S1-06 mnemonic/address/endpoint identity contract preserved.
3. A restored or enabled RUNE wallet surfaces the canonical `thor1` address,
   native balance, and receive flow using the existing THOR adapter.
4. RUNE is hidden from Wallet and token Send/Swap buttons, SendTokenList,
   QR/address-to-Send routing, and MultiSwap token-in selection. Send and Swap
   implementation remains out of scope.
5. Hermetic tests prove both fresh-cache discovery and migration from an
   existing v2 cache, followed by terminate/relaunch restoration.
6. Missing token, missing chain, and thrown metadata queries retain the
   persisted wallet identity and expose an unavailable/retry diagnostic state;
   they must not publish a silently empty wallet set or omit the enabled record.
7. The released MarketKit/backend/cache chain record has a non-null explorer
   URL with the exact approved template. A null or unverified URL is a hard
   dependency failure and cannot be accepted as passing.

## Scope and boundaries

In scope are native RUNE metadata consumption, mnemonic AccountType policy,
Manage Wallets discovery, create/import restore, receive/address/balance
presentation, persistence/restart, and send/swap ingress suppression for RUNE.

Out of scope are send transactions, swap transactions, RUJI/TCY support,
history, transaction construction, a new adapter protocol, changes to the
already implemented S1-06 THOR manager/factory/adapter/address provider,
stagenet, Maestro in Unstoppable, and any GitHub Actions execution. The
Unstoppable checkout remains local and uncommitted until operator delivery
authorization.

The library owns the chain behavior; Unstoppable owns the adapter and UI
integration. Existing auto-enable behavior remains unchanged unless a later
approved design explicitly changes it.

## Current-tree evidence and analog decisions

Authoritative evidence is recorded in
`/Users/ant013/Data/AI/gimle-skills/audit/runs/THR-S1-07-v050-20260722/state.json`.
The exact v0.50 checkout is at commit `8a63bfda`; it has intentional S1-06
uncommitted changes that are preserved. The local MarketKit branch is
`2c32745`. Codebase-memory had a recorded transport failure
`ENV-CBM-S107-001`; Serena plus targeted `rg` verification are the current
fallback. Gimle trust is `YELLOW` because this environment limitation and the
backend explorer contract remain visible.

| Concern | Current anchor | Decision |
| --- | --- | --- |
| Discovery and filtering | `ManageWalletsTokenFetcher.swift:6-75`, `ManageWalletsViewModel.swift:29-190` | Extend the generic discovery seam with the exact native AccountType rule. |
| Account and THOR identity | `AccountType.swift:81-163`, `AccountAddress.swift:32-40`, `ThorChainKitManager.swift:47-89` | Mnemonic-only native RUNE; preserve S1-06 identity and endpoint validation. |
| Restore and persistence | `RestoreHelper.swift:3-20`, `WalletStorage.swift:24-75`, `WalletManager.swift:35-101` | Add explicit durable unavailable/retry behavior; reject catch-to-empty as unsafe. |
| Send/swap ingress | `WalletViewModel.swift:105-107`, `WalletTokenViewModel.swift:147-157`, `SendTokenListViewModel.swift:6-114`, `AddressEventHandler.swift:35-115`, `MultiSwapTokenSelectViewModel.swift:30-113` | Suppress RUNE at each listed ingress, without implementing send/swap. |
| Native metadata | `Tests/MarketKitTests/ThorChainMetadataTests.swift:4-18`, `BlockchainRecord.swift:9-30` | Require released `thorchain`/native/RUNE/8 metadata and non-null explorer URL. |

The selected current-tree analogs are Manage Wallets, restore, THOR manager,
wallet UI, and persistence. MultiSwap discovery and WalletManager's
catch-to-empty path are recorded as rejected counterexamples, not patterns to
copy. Operator-provided v0.50 evidence names RUJI/TCY; because those fixtures
are absent from the local metadata branch, implementation tests must supply
typed/token-identity fixtures rather than claim local symbols exist.

## Required behavior by slice

### S107-A — native discovery and account enablement

The metadata gate must be satisfied first: the released MarketKit/backend/cache
must provide blockchain UID `thorchain`, native token UID `thorchain`, code
`RUNE`, type `native`, 8 decimals, and a non-null explorer URL with a verified
template. Until then the behavior is explicitly unavailable.

`AccountType.supports(token:)` must allow mnemonic + THOR native only. RUJI,
TCY, and every non-native THOR token must return false. Manage Wallets and
RestoreHelper must use this policy consistently for featured, preferred, native,
and search results.

### S107-B — receive-only RUNE surfaces

The existing S1-06 THOR adapter remains the address/balance source. RUNE UI
must retain chart/receive/address behavior where supported, but remove send and
swap buttons for both wallet-level and token-level presentations. A RUNE token
must not enter SendTokenList, and a recognized THOR address/QR event must not
produce a send page. MultiSwap must exclude RUNE from token-in selection and
default-token resolution. Generic non-THOR behavior remains unchanged.

### S107-C — cache, restart, and recovery

Tests must use isolated stores and deterministic MarketKit doubles. Cover an
empty/fresh cache and an existing v2 cache migration, then terminate/relaunch
and assert the same enabled wallet identity, `thor1` address, and balance path.

If token lookup is missing, chain lookup is missing, or either query throws,
retain the durable enabled-wallet record and account identity. Publish an
explicit unavailable/stale/retry state with a diagnosable error; never replace
the active wallet data with an indistinguishable empty list and never delete
the enabled record as recovery.

## Verification gate

Before implementation: `run_state.py validate --for-phase adversarial_review`,
`git diff --check`, and exact-head review of this spec, the plan, and the Gimle
report. After implementation, the engineer supplies focused AppTests and
manual MacBook evidence for the criteria above. No Unstoppable tests,
simulators, mutants, or Maestro runs are performed in GitHub Actions.

Approval is requested only after `ThorChainCodeReviewer` posts ACCEPT for the
exact docs commit and the operator accepts this superseding design revision.
