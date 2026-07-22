# S1-07 — Unstoppable RUNE discovery, address, balance, and restart

**Status:** design revision 2; implementation blocked pending adversarial review and explicit approval of this exact revision.
**Risk:** high, cross-repository product path.

## Goal

Make native mainnet RUNE a real opt-in wallet in Unstoppable Wallet: discoverable in Manage Wallets, selectable during restore, strictly parsed, visible through the existing balance/receive/status surfaces, and reconstructed with the same address after terminate/relaunch.

S1-06 owns the THORChain adapter lifecycle composition. S1-07 owns the metadata/discovery and host-consumer integration that makes that adapter reachable through the existing wallet lifecycle.

## Acceptance criteria

1. A released MarketKit version, backend/cache record, native RUNE metadata, and WalletCore dependency bump exist. The contract is UID `thorchain`, native RUNE, decimals exactly `8`, and the approved explorer template.
2. RUNE is searchable and manually enabled in Manage Wallets; it is not automatically enabled for a new account.
3. The host parser accepts only strict mainnet `ThorChainKit.Address` values, returns canonical lowercase raw addresses, rejects invalid checksum/HRP/length/mixed-case inputs, and routes through `AddressParserFactory`.
4. Balance and Receive use the generic adapter consumers; amount conversion remains exact and does not use `Double`.
5. App Status includes THORChain in the existing non-EVM status surface and sanitizes endpoint/error output using current app conventions.
6. AppTests cover metadata, supported/order policy, parser vectors, factory routing, storage round-trip, and the generic lifecycle. Manual Development acceptance proves create → enable, import/restore, terminate/relaunch, offline cached state, recovery, remove, and reinstall/no-cache.
7. The full address is stable and matches an independent fixture. No mnemonic, private key, provider credential, or host-local absolute path is recorded.
8. No URI/deeplink, history, send, swap, non-native token, stagenet, Maestro, acceptance-only runtime hook, or new host test target is added.

## Evidence base and current boundary

Evidence was collected from the exact assigned worktrees, with current-tree Serena and targeted `rg`/Git verification after codebase-memory lookup.

| Evidence | Current fact | Design consequence |
| --- | --- | --- |
| ThorChainKit `bed49c5` | S1-06 lifecycle design is the current repository boundary; this checkout also contains pre-existing local S1-06 report files. | S1-07 edits this spec/plan/report only and does not implement S1-06. |
| UW v0.50 checkout `8a63bfd` | The adjacent branch has uncommitted S1-06 manager/factory/adapter/address-provider work. | Treat those files as fixed S1-06 input; no commit, push, or PR to UW is authorized in this phase. |
| MarketKit feature `2c32745`, based on tag `3.6.12` | Native THORChain metadata exists locally but is not a released dependency. | Release/backend/cache metadata is a hard gate before host merge. |
| `ManageWalletsViewModel` / `ManageWalletsTokenFetcher` | Discovery enumerates supported blockchains and native token queries generically. | Add policy/metadata; do not add a THOR-specific Manage Wallets branch. |
| `RestoreCoinsViewModel` / `RestoreHelper` | Restore uses supported native queries and sequential account/marker/wallet saves. | Preserve generic routing and order; do not claim atomic restore. |
| `WalletStorage` / `WalletManager` | Stored token-query IDs are reconstructed through MarketKit and published by the normal queue. | Prove cold reconstruction; do not add a THOR-specific storage manager. |
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

Before the host can merge, the MarketKit/backend contract must be released and consumable: UID `thorchain` (not Cosmos chain ID `thorchain-1`), `.thorChain`, native RUNE, code `RUNE`, decimals `8`, and the approved explorer template `https://thorchain.net/tx/$ref`. The final released version and cache decode must be recorded in the implementation PR. A local feature branch is evidence of the proposed contract, not proof that this gate is closed.

## Minimal implementation delta

The following files are the only intended host changes unless a test demonstrates a generic-route failure:

- `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`: add `.thorChain` to `supported` immediately after `.tron`, to `order` at the same position, description `RUNE`, and the protocol-confirmed block time. Keep mnemonic policy and native-token query behavior generic and test them.
- `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`: add a strict parser using `ThorChainKit.Address` and `ThorChainKit.Network.mainnet`.
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift`: import ThorChainKit if needed and route `.thorChain` to the parser; retain generic chain behavior.
- `packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift`: add `.thorChain` to the existing non-EVM status case.
- Existing AppTests and the exact MarketKit test target: add contract tests only where the current targets already provide a seam.

S1-06-owned files are explicitly out of scope: `ThorChainKitManager`, `ThorChainKitFactory`, `ThorChainAdapter`, `AccountAddress`, `AccountAddressProvider`, and their existing local tests. Do not modify `AdapterFactory`, `WalletStorage`, `WalletManager`, `RestoreHelper`, or receive/balance consumers for speculative THOR branches.

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

Restore preserves the existing sequential account → restore-marker → wallet saves. It does not add a THOR network call or claim cross-store atomicity. Cold launch must preserve the wallet and address. If released metadata cannot resolve a stored `thorchain` query, the wallet must fail closed and remain diagnosable; it must not be silently deleted or replaced by a zero balance.

Balance verification uses the existing exact integer/BigUInt path and pins decimals to `8`; no `Double` conversion is permitted. Receive displays the canonical `thor1…` address. Offline relaunch preserves cached state as explicitly stale/error, never fresh/zero; recovery returns to fresh state without duplicate adapter publication. Removing the wallet stops the adapter and leaves no orphan publication.

## Delta matrix

| Slice | Primary analog and coverage | Invariants | Required difference / rejected difference | Failure modes | Tests before code | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| Discovery | Manage Wallets; responsibility, boundary, dependencies, lifecycle, state errors | supported/order/native query are consistent; opt-in only | add `.thorChain` metadata; reject default enable and special discovery branch | absent search result, wrong token type, accidental default | supported/order/native-query tests | MarketKit release decode + AppTests Manage Wallets path |
| Parser | AddressParserFactory + strict Tron parser; responsibility, boundary, lifecycle, state errors, trust | codec owns validity; host receives canonical address only after validation | use THOR codec/HRP; reject URI parser and generic Cosmos fallback | wrong HRP, checksum, length, case, hidden error | valid and invalid vectors through factory | targeted AppTests and exact `rg`/test output |
| Balance/Receive/Status | Monero adapter + BaseReceive + App Status; responsibility, boundary, lifecycle, trust | generic consumers, exact 8 decimals, sanitized diagnostics | add only enum/status routing; reject activation warnings and THOR UI | stale/fresh confusion, duplicate updates, secret leakage | adapter spy, BigUInt/metadata, status sanitization | AppTests plus Development manual checklist |
| Restore/Relaunch | WalletStorage/WalletManager + RestoreHelper; lifecycle, dependencies, state errors, trust | stored query reconstructs; address stable; missing metadata fails closed | preserve sequential saves; reject atomicity claim and backup shortcut | silent deletion, changed address, orphan adapter, stale zero | storage round-trip, restore, restart/offline tests | AppTests plus terminate/relaunch/remove/reinstall manual runs |

## Tests before implementation

MarketKit tests must pin UID encode/decode, backend/cache chain and native token decode, native RUNE query, decimals `8`, explorer `$ref` replacement, and the released dependency version. WalletCore AppTests must pin supported/order/description/block-time policy, mnemonic account policy, native query behavior, strict parser vectors, factory routing, exact amount conversion without `Double`, storage round-trip, generic adapter lifecycle, and sanitized App Status.

Manual Development acceptance uses a public no-funds test account and records app commit/configuration, device/OS, timestamp, endpoint family, observed address/height/balance, and per-step result without recording the mnemonic. It covers create → search → enable → Receive/live balance; import/restore; terminate/relaunch; offline cached stale/error state; network recovery; remove; and reinstall/no-cache. No Maestro suite is applied to Unstoppable.

## Adversarial review and approval gate

Discovery is frozen at `discovery 1/2`; closure begins at `closure 0/5`. The review must challenge freshness, identity, similarity, completeness, primary coherence, counterexample, conflicts, inherited defects, missing/excess delta, failure behavior, test validity, and the smaller safe alternative. The current evidence has one Gimle freshness warning with an explicit current-tree workaround; it does not override independent local verification.

Implementation may begin only after the operator approves this exact spec revision and the linked plan. The approval must also confirm the released MarketKit/backend/cache dependency gate and authorize a separately assigned implementation phase. Until then this repository contains documentation only for S1-07.

## Non-goals

No default enable, URI/deeplink, history, explorer UI, send, swap, non-native THOR assets, stagenet, new host test target, Maestro, fixture transport, launch argument, acceptance-only source, secret material, or changes to the S1-06 lifecycle composition.
