# S1-07 — Unstoppable RUNE discovery, address, balance, and restart

**Status:** design revision 3; discovery 1/2 revision requested changes are addressed, but implementation remains blocked pending fresh adversarial review, explicit approval of this exact revision, and the released metadata artifact.
**Risk:** high, cross-repository product path.

## Goal

Make native mainnet RUNE a real opt-in wallet in Unstoppable Wallet: discoverable in Manage Wallets, selectable during restore, strictly parsed, visible through the existing balance/receive/status surfaces, and reconstructed with the same address after terminate/relaunch.

S1-06 owns the THORChain adapter lifecycle composition. S1-07 owns the metadata/discovery and host-consumer integration that makes that adapter reachable through the existing wallet lifecycle.

## Acceptance criteria

1. A released MarketKit version, backend/cache record, native RUNE metadata, and WalletCore dependency bump exist. The contract is UID `thorchain`, native RUNE, decimals exactly `8`, and the explorer template decoded from the released fixture. The literal template is intentionally unresolved until the MarketKit owner supplies the release/cache artifact named in the hard dependency gate; the feature branch is not evidence of release.
2. RUNE is searchable and manually enabled in Manage Wallets; it is not automatically enabled for a new account. The existing `CreateAccountViewModel.activateDefaultWallets` behavior remains unchanged (BTC BIP84 plus ETH native), while normal mnemonic import is owned by `RestoreCoinsViewModel` and saves the selected native RUNE token through its existing sequential restore path.
3. The host parser accepts only strict mainnet `ThorChainKit.Address` values, returns canonical lowercase raw addresses, rejects invalid checksum/HRP/length/mixed-case inputs, and routes through `AddressParserFactory`.
4. Balance and Receive use the generic adapter consumers; amount conversion remains exact and does not use `Double`. The `WalletView` row context-menu ingress is covered: a RUNE row does not expose or open unsupported Send or Swap actions, including token-seeded MultiSwap.
5. App Status includes THORChain in the existing non-EVM status surface and sanitizes endpoint/error output using current app conventions.
6. AppTests cover metadata, supported/order policy, parser vectors, factory routing, storage round-trip, generic lifecycle, exact RUNE identity, direct WalletView action guards, and recovery/unavailable state. Manual Development acceptance proves create → enable, import/restore, terminate/relaunch, offline cached state, recovery, remove, and reinstall/no-cache.
7. The full address is stable and matches an independent fixture. No mnemonic, private key, provider credential, or host-local absolute path is recorded.
8. No URI/deeplink, history, send, swap, non-native token, stagenet, Maestro, acceptance-only runtime hook, or new host test target is added.

## Evidence base and current boundary

Evidence was collected from the exact assigned worktrees, with current-tree Serena and targeted `rg`/Git verification after codebase-memory lookup.

| Evidence | Current fact | Design consequence |
| --- | --- | --- |
| ThorChainKit `bed49c5` | S1-06 lifecycle design is the current repository boundary; this checkout also contains pre-existing local S1-06 report files. | S1-07 does not replace the lifecycle owner; any identity guard required at the host factory is part of this slice, while adapter lifecycle remains S1-06-owned. |
| UW v0.50 checkout `8a63bfd` | The adjacent branch has uncommitted S1-06 manager/factory/adapter/address-provider work, plus generic storage/reload and direct `WalletView` action paths. | Treat S1-06 lifecycle code as fixed input, but cover the existing generic storage/recovery and WalletView ingress because they are current acceptance paths. No commit, push, or PR to UW is authorized in this design phase. |
| MarketKit feature `2c32745`, based on tag `3.6.12` | Native THORChain metadata exists locally, but no released version or explorer/cache fixture was verified. | Step 1 is explicitly blocked until the MarketKit owner supplies the release/cache artifact and dependency-resolution evidence. |
| `ManageWalletsViewModel` / `ManageWalletsTokenFetcher` | Discovery enumerates supported blockchains and native token queries generically. | Add policy/metadata; do not add a THOR-specific Manage Wallets branch. |
| `RestoreCoinsViewModel` / `RestoreHelper` | `RestoreCoinsViewModel.loadBlockchains()` queries supported native tokens and `restore()` saves the account, restore markers, and selected wallets sequentially. | Test the actual import owner; preserve order and do not claim atomic restore. |
| `WalletStorage` / `WalletManager` / `WalletData` | Stored enabled-wallet identity is durable, but unresolved token/chain records are dropped and reload errors publish an empty wallet list. | Add a generic unavailable/stale load result that preserves identity, publishes a sanitized diagnostic, and exposes retry without silently deleting RUNE. |
| `WalletView` | Row context actions can open Send and token-seeded MultiSwap independently of the top-level button policy. | Guard this ingress for unsupported native RUNE Send/Swap actions. |
| `EnabledWalletCache` / `StorageMigrator` | Current cache table is `enabled_wallet_caches` with tokenQueryId/accountId primary key and total/available columns; migration identifier is `Update EnabledWalletCache scheme`. | Pin the v2 cache schema, seed row, expected post-migration record, and deterministic throwing-query seam in tests. |
| `MoneroAdapter` / `BaseReceiveAddressService` | Non-EVM lifecycle and deposit presentation are generic adapter/consumer seams. | Prove the S1-06 adapter through existing consumers, with no activation warning branch. |
| `AppStatusViewModel` | The existing non-EVM status switch omits `.thorChain`. | Add one enum case to the existing sanitized status surface. |

Load-bearing current anchors are:

- `packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsViewModel.swift:4-153`
- `packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsTokenFetcher.swift:4-29`
- `packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreCoins/RestoreCoinsViewModel.swift:4-65`
- `packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreHelper.swift:2-21`
- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift:24-75`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift:6-112`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/MoneroAdapter.swift:8-153`
- `packages/WalletCore/Sources/WalletCore/Modules/Wallet/Receive/Address/BaseReceiveAddressService.swift:7-84`
- `packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift:3-215`

## Hard dependency gate

Before the host can merge, the MarketKit/backend contract must be released and consumable: UID `thorchain` (not Cosmos chain ID `thorchain-1`), `.thorChain`, native RUNE, code `RUNE`, decimals `8`, and an explorer template decoded from the released fixture. The MarketKit owner must provide the exact release tag/version, cache decode, and literal template as a durable artifact; until then this gate is blocked. A local feature branch is evidence of the proposed contract, not proof that this gate is closed.

## Minimal implementation delta

The following files are the only intended host changes unless a test demonstrates a generic-route failure:

- `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`: add `.thorChain` to `supported` immediately after `.tron`, to `order` at the same position, description `RUNE`, and the protocol-confirmed block time. Keep mnemonic policy and native-token query behavior generic and test them.
- `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`: add a strict parser using `ThorChainKit.Address` and `ThorChainKit.Network.mainnet`.
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift`: import ThorChainKit if needed and route `.thorChain` to the parser; retain generic chain behavior.
- `packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift`: add `.thorChain` to the existing non-EVM status case.
- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift`, `Core/Managers/WalletManager.swift`, and `WalletData`: preserve durable enabled identity and publish an unavailable load state rather than dropping records or publishing an empty set on reconstruction failure.
- `packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletView.swift`: prevent direct RUNE row actions from entering unsupported Send or Swap surfaces.
- Existing AppTests and the exact MarketKit test target: add contract tests only where the current targets already provide a seam; use existing injected MarketKit/adapter/endpoint test doubles, not an acceptance-only runtime hook.

S1-06 lifecycle-owned files remain out of scope: `ThorChainKitManager`, `ThorChainKitFactory`, `ThorChainAdapter`, `AccountAddress`, `AccountAddressProvider`, and their existing local tests. `AdapterFactory` may receive only the exact-RUNE composition guard required by AC7; `WalletStorage`, `WalletManager`, `WalletData`, `WalletView`, and existing receive/balance consumers are in scope only for the generic recovery/action paths explicitly listed above, not for speculative THOR branches.

Parser contract: `handle` performs strict construction and returns `Single.error` on failure; `isValid` returns the corresponding boolean. The host address is created only after validation, with canonical lowercase raw text. The mainnet parser rejects `sthor`, `cthor`, and `tthor`, arbitrary Cosmos HRPs, malformed input, mixed-case input, and non-20-byte payloads. URI/deeplink parsing is not part of this slice.

## Lifecycle and safety behavior

The intended path is:

```text
released MarketKit metadata
  → supported/native query discovery
  → WalletStorage token-query reconstruction
  → WalletManager publication
  → existing AdapterFactory/S1-06 manager and adapter
  → generic balance/receive/status consumers
```

Restore preserves the existing sequential account → restore-marker → wallet saves. It does not add a THOR network call or claim cross-store atomicity. Cold launch must preserve the wallet and address. If released metadata cannot resolve a stored `thorchain` query, the durable `EnabledWallet` identity (accountId, tokenQueryId, and cached coin fields) remains stored. `WalletStorage` classifies missing `TokenQuery`, a throwing `marketKit.tokens(queries:)`, missing blockchain, and a throwing `marketKit.blockchains(uids:)` as unavailable records; `WalletManager` publishes them in `WalletData` as a sanitized unavailable/stale load state with diagnostic codes and no fabricated wallet or zero balance. `WalletService`/wallet consumers render the state as unavailable, and `WalletManager.preloadWallets()` is the retry trigger after dependency refresh or a user retry. AppTests must assert that each of the four failure inputs preserves the durable identity, publishes the expected code, leaves available wallets intact, and succeeds on the next deterministic retry.

The cache contract is explicit: current `EnabledWalletCache` v2 is table `enabled_wallet_caches`, primary key (tokenQueryId, accountId), columns total and available, created by migration `Update EnabledWalletCache scheme` at the current StorageMigrator anchor. The test fixture seeds the exact native RUNE row (tokenQueryId for `.thorChain` + `.native`, a non-secret test account ID, and a non-zero integer balance); the expected post-migration record retains that key and exact decimal values. The storage test injects deterministic MarketKit query results and separately throws at `tokens(queries:)` and `blockchains(uids:)`; no network timing or live cache is used to prove recovery.

The exact identity invariant is enforced at discovery, restore, and adapter composition: blockchain.uid == thorchain, coin.uid == thorchain, coin.code == RUNE, token.type == .native, and token.decimals == 8. Negative RUJI/TCY/custom-token records must not appear in Manage Wallets, restore selection, or adapter composition. The S1-06 adapter remains the lifecycle owner; S1-07 must not rely on its broader metadata acceptance as proof of the host identity invariant.

Balance verification uses the existing exact integer/BigUInt path and pins decimals to `8`; no `Double` conversion is permitted. Receive displays the canonical `thor1…` address. Offline relaunch preserves cached state as explicitly stale/error, never fresh/zero; recovery returns to fresh state without duplicate adapter publication. Removing the wallet stops the adapter and leaves no orphan publication.

## Delta matrix

| Slice | Primary analog and coverage | Invariants | Required difference / rejected difference | Failure modes | Tests before code | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| Discovery | Manage Wallets plus `CreateAccountViewModel` and `RestoreCoinsViewModel`; responsibility, boundary, dependencies, lifecycle, state errors | supported/order/native query are consistent; create defaults unchanged; restore owns import selection | add `.thorChain` metadata; exact-RUNE filter; reject default enable and special discovery branch | absent search result, RUJI/TCY leakage, accidental default | supported/order/native-query, create-default, restore-owner tests | released fixture decode + AppTests Manage Wallets/restore path |
| Parser | AddressParserFactory + strict Tron parser; responsibility, boundary, lifecycle, state errors, trust | codec owns validity; host receives canonical address only after validation | use THOR codec/HRP; reject URI parser and generic Cosmos fallback | wrong HRP, checksum, length, case, hidden error | valid and invalid vectors through factory | targeted AppTests and exact `rg`/test output |
| Balance/Receive/Status | Monero adapter + BaseReceive + App Status + WalletView; responsibility, boundary, lifecycle, trust | generic consumers, exact 8 decimals, sanitized diagnostics, no unsupported row ingress | add status/recovery/action guards; reject activation warnings and THOR UI | stale/fresh confusion, Send/Swap bypass, duplicate updates, secret leakage | adapter spy, BigUInt/metadata, WalletView guard, status sanitization | AppTests plus Development manual checklist |
| Restore/Relaunch | WalletStorage/WalletManager/WalletData + RestoreCoinsViewModel + cache migration; lifecycle, dependencies, state errors, trust | identity durable; unavailable state observable; address stable; exact cache survives | preserve sequential saves; add retryable fail-closed state; reject atomicity claim and backup shortcut | silent deletion, empty publication, changed address, orphan adapter, stale zero | four throwing-query tests, cache seed/migration, offline/recovery/duplicate-adapter tests | AppTests plus terminate/offline/recovery/remove/reinstall manual runs |

## Tests before implementation

MarketKit tests must pin UID encode/decode, released backend/cache chain and native token decode, native RUNE query, decimals `8`, the literal explorer template from the released fixture, and the released dependency version. The implementation cannot claim this check while the release/cache artifact is missing. WalletCore AppTests must pin supported/order/description/block-time policy, unchanged create defaults, `RestoreCoinsViewModel` import ownership, exact identity with RUJI/TCY negatives, native query behavior, strict parser vectors, factory routing, direct WalletView Send/Swap guards, exact amount conversion without `Double`, cache migration/seed expectations, storage round-trip, each throwing query site, unavailable-state diagnostics and retry, generic adapter lifecycle, duplicate-adapter count, and sanitized App Status.

Manual Development acceptance uses a public no-funds test account and records app commit/configuration, device/OS, timestamp, endpoint family, observed address/height/balance, and per-step result without recording the mnemonic. It covers create → search → enable → Receive/live balance; import/restore; terminate/relaunch; offline relaunch with the same address and cached stale/error (not fresh/zero) state; network recovery to fresh state; one RUNE adapter after each reload; remove; and reinstall/no-cache. No Maestro suite is applied to Unstoppable.

## Adversarial review and approval gate

Discovery remains frozen at `discovery 1/2`; closure remains `closure 0/5`. The next review must recheck the seven allowlisted IDs `D-S107-REV-001` through `D-S107-REV-007` against this revision and direct regressions only; it must not reopen broad discovery. The current evidence has one Gimle freshness warning with an explicit current-tree workaround; it does not override independent local verification.

Implementation may begin only after the operator approves this exact spec revision and the linked plan. The approval must also confirm the released MarketKit/backend/cache dependency gate and authorize a separately assigned implementation phase. Until then this repository contains documentation only for S1-07.

## Non-goals

No default enable, URI/deeplink, history, explorer UI, send, swap, non-native THOR assets, stagenet, new host test target, Maestro, fixture transport, launch argument, acceptance-only source, secret material, or changes to the S1-06 lifecycle composition.
