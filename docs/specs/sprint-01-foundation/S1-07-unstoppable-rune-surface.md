# S1-07 — Unstoppable RUNE discovery, address, balance, and restart

**Status:** design revision 6; the targeted corrections from the exact-head bounded review are addressed, but implementation remains blocked pending fresh bounded review and explicit approval of this exact revision. The released metadata artifact remains a hard final-delivery gate, not a blocker to approved local implementation against the pinned adjacent MarketKit checkout.
**Risk:** high, cross-repository product path.

## Goal

Make native mainnet RUNE a real opt-in wallet in Unstoppable Wallet: discoverable in Manage Wallets, selectable during restore, strictly parsed, visible through the existing balance/receive/status surfaces, and reconstructed with the same address after terminate/relaunch.

S1-06 owns the THORChain adapter lifecycle composition. S1-07 owns the metadata/discovery and host-consumer integration that makes that adapter reachable through the existing wallet lifecycle.

## Assumptions, scope, and open question

- The exact Unstoppable base is `version/0.50` at `8a63bfda028dd8543115b26dd777235a53304311`; S1-06's uncommitted local lifecycle composition remains fixed input.
- Approved implementation uses the adjacent MarketKit checkout at `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` and remains local and uncommitted in Unstoppable until final operator delivery authorization.
- Scope is limited to native mainnet RUNE discovery, strict address parsing, generic balance/receive/status, durable restore/relaunch behavior, and fail-closed suppression of unsupported RUNE Send/Swap ingress. Native send/swap implementation is not part of S1-07.
- Open question owned by the MarketKit release owner: the exact released version and decoded explorer template. That artifact is required before final acceptance/commit, but it does not block approved local test-first implementation and deterministic tests against the pinned checkout.

## Acceptance criteria

1. Before final acceptance/commit, a released MarketKit version, backend/cache record, native RUNE metadata, and WalletCore dependency bump exist. The contract is UID `thorchain`, native RUNE, decimals exactly `8`, and the explorer template decoded from the released fixture. Until that artifact exists, local implementation and deterministic tests use only the pinned adjacent checkout and cannot claim the final release gate.
2. RUNE is searchable and manually enabled in Manage Wallets; it is not automatically enabled for a new account. The existing `CreateAccountViewModel.activateDefaultWallets` behavior remains unchanged (BTC BIP84 plus ETH native), while normal mnemonic import is owned by `RestoreCoinsViewModel` and saves the selected native RUNE token through its existing sequential restore path.
3. The host parser accepts only strict mainnet `ThorChainKit.Address` values, returns canonical lowercase raw addresses, rejects invalid checksum/HRP/length/mixed-case inputs, and routes through `AddressParserFactory`.
4. Balance and Receive use the generic adapter consumers; amount conversion remains exact and does not use `Double`. Each of the five prohibited Send/Swap ingress families is guarded for native RUNE: WalletView row actions, WalletView SendTokenList/Swap buttons, WalletTokenViewModel buttons, token-seeded MultiSwap, and QR/deep-link-to-Send. Generic non-THOR routes remain unchanged.
5. App Status includes THORChain in the existing non-EVM status surface and sanitizes endpoint/error output using current app conventions.
6. AppTests cover metadata, supported/order policy, parser vectors, factory routing, storage round-trip, generic lifecycle, exact RUNE identity, all prohibited ingress guards, and recovery/unavailable state. Manual Development acceptance proves create → enable, import/restore, terminate/relaunch, offline cached state, recovery, remove, and reinstall/no-cache.
7. The full address is stable and matches an independent fixture. No mnemonic, private key, provider credential, or host-local absolute path is recorded.
8. No URI/deeplink, history, send, swap, non-native token, stagenet, Maestro, acceptance-only runtime hook, or new host test target is added.

## Evidence base and current boundary

Evidence was collected from the exact assigned worktrees, with current-tree Serena and targeted `rg`/Git verification after codebase-memory lookup.

| Evidence | Current fact | Design consequence |
| --- | --- | --- |
| ThorChainKit `bed49c5` | S1-06 lifecycle design is the current repository boundary; this checkout also contains pre-existing local S1-06 report files. | S1-07 does not replace the lifecycle owner; any identity guard required at the host factory is part of this slice, while adapter lifecycle remains S1-06-owned. |
| UW v0.50 checkout `8a63bfd` | The adjacent branch has uncommitted S1-06 manager/factory/adapter/address-provider work, plus generic storage/reload and direct `WalletView` action paths. | Treat S1-06 lifecycle code as fixed input, but cover the existing generic storage/recovery and WalletView ingress because they are current acceptance paths. No commit, push, or PR to UW is authorized in this design phase. |
| MarketKit feature `2c32745`, based on tag `3.6.12` | Native THORChain metadata exists locally, but no released version or explorer/cache fixture was verified. | Use this exact checkout for approved local implementation/tests; keep final acceptance/commit blocked until the owner supplies the release/cache artifact and dependency-resolution evidence. |
| `ManageWalletsViewModel` / `ManageWalletsTokenFetcher` | Discovery enumerates supported blockchains and native token queries generically. | Add policy/metadata; do not add a THOR-specific Manage Wallets branch. |
| `RestoreCoinsViewModel` / `RestoreHelper` | `RestoreCoinsViewModel.loadBlockchains()` queries supported native tokens and `restore()` saves the account, restore markers, and selected wallets sequentially. | Test the actual import owner; preserve order and do not claim atomic restore. |
| `WalletStorage` / `WalletManager` / `WalletData` / `WalletService` / `WalletListViewModel` | `WalletStorage` binds concrete `MarketKit.Kit`, drops unresolved records, and `WalletManager` publishes an empty list on query failure; `WalletService` forwards only resolved wallets and `WalletListViewModel` falls back to zero. `WalletManager.delete(wallets:)` accepts only concrete `Wallet` values. | Add the injectable `WalletQuerying` seam, a `WalletLoadResult` with resolved wallets plus display-only `UnavailableWallet` rows, exact diagnostics, retry, and an identity-keyed delete seam `(accountId, tokenQueryId)` that removes terminal unavailable rows and clears their publication without constructing a `Wallet`. |
| `WalletView` / downstream selectors | Row context actions can open Send and token-seeded MultiSwap independently of the top-level button policy. `RegularMultiSwapView` forwards its seed to `MultiSwapViewModel`, which assigns it directly, while `SendTokenListViewModel` and `MultiSwapTokenSelectViewModel` enumerate active-wallet tokens. | Guard the direct seed owner, row actions, shared/downstream Send and Swap selectors, token buttons, and QR/deep-link Send for unsupported native RUNE; preserve mixed BTC/ETH-plus-RUNE generic routes. |
| `EnabledWalletCache` / `StorageMigrator` | Migration `Update EnabledWalletCache scheme` receives legacy `balance`/`balanceLocked`, drops that table, and creates current `total`/`available` without copying rows. | Preserve each composite-key row using the old runtime mapping `total = balance`, `available = balance`; keep a non-zero `balanceLocked` sentinel to prove it is not silently reinterpreted. |
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

Before final operator delivery or any Unstoppable commit, the MarketKit/backend contract must be released and consumable: UID `thorchain` (not Cosmos chain ID `thorchain-1`), `.thorChain`, native RUNE, code `RUNE`, decimals `8`, and an explorer template decoded from the released fixture. The MarketKit owner must provide the exact release tag/version, cache decode, and literal template as a durable artifact. Until then local implementation may proceed only against exact pinned head `2c327452237cfbbdc4d87bcd5dd417d1da46a61e`; its results cannot close the release gate.

## Minimal implementation delta

The following files are the only intended host changes unless a test demonstrates a generic-route failure:

- `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`: add `.thorChain` to `supported` immediately after `.tron`, to `order` at the same position, description `RUNE`, and the protocol-confirmed block time. Keep mnemonic policy and native-token query behavior generic and test them.
- `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`: add a strict parser using `ThorChainKit.Address` and `ThorChainKit.Network.mainnet`.
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift`: import ThorChainKit if needed and route `.thorChain` to the parser; retain generic chain behavior.
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift` and `Core/Adapters/ThorChain/ThorChainAdapter.swift`: enforce the exact native identity `blockchain.uid == thorchain`, `coin.uid == thorchain`, `coin.code == RUNE`, `token.type == .native`, `token.decimals == 8` at the `.native/.thorChain` composition case and adapter initializer.
- `packages/WalletCore/Sources/WalletCore/Models/AccountType.swift`: add `.thorChain/.native` to the existing `.mnemonic` `supports(token:)` policy; do not add an account-type enum case.
- `packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift`: add `.thorChain` to the existing non-EVM status case.
- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift`, `Core/Managers/WalletManager.swift`, `WalletData`, `Modules/Wallet/WalletService.swift`, and `Modules/Wallet/WalletListViewModel.swift`: inject `WalletQuerying`; publish `WalletLoadResult(resolvedWallets, unavailableWallets)` where `UnavailableWallet` retains account/token-query/cached display identity and one of the exact codes `invalid_stored_token_query` (terminal), `token_metadata_unavailable` (retryable), or `blockchain_metadata_unavailable` (retryable). Empty or missing nonthrowing token/blockchain metadata uses the corresponding fail-closed code. The exact identity predicate runs before every `Wallet` construction, including resolved and cached-fallback paths; a validly decoded but mismatched RUNE identity is terminal `invalid_stored_token_query`. The WalletList consumer renders a display-only unavailable row with no `Wallet`, balance, adapter, Send, or Swap action; resolved rows remain available. `preloadWallets()` retries only retryable records. Add an identity-keyed delete seam by `accountId + tokenQueryId`; terminal unavailable-row removal deletes the durable enabled record and removes the row/publication without requiring a `Wallet`.
- `packages/WalletCore/Sources/WalletCore/Core/Storage/StorageMigrator.swift`: preserve existing `enabled_wallet_caches` rows during `Update EnabledWalletCache scheme`.
- `packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsTokenFetcher.swift`, `RestoreAccount/RestoreCoins/RestoreCoinsViewModel.swift`, `Modules/Wallet/WalletView.swift`, `WalletViewModel.swift`, `Wallet/Token/WalletTokenViewModel.swift`, `Wallet/SendTokenListViewModel.swift`, `Modules/MultiSwap/RegularMultiSwapView.swift`, `Modules/MultiSwap/MultiSwapViewModel.swift`, `Modules/MultiSwap/TokenSelect/MultiSwapTokenSelectViewModel.swift`, and `Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift`: apply one exact RUNE capability predicate to preferred-token discovery, restore selection, WalletStorage reconstruction, the direct MultiSwap seed owner, shared selectors, row actions, token buttons, and QR/deep-link Send; mixed BTC/ETH-plus-RUNE fixtures must leave generic non-THOR routes usable.
- Existing AppTests and the exact MarketKit test target: add contract tests only where the current targets already provide a seam; use existing injected MarketKit/adapter/endpoint test doubles, not an acceptance-only runtime hook.

S1-06 lifecycle-owned files remain out of scope: `ThorChainKitManager`, `ThorChainKitFactory`, `AccountAddress`, `AccountAddressProvider`, and their existing lifecycle tests. `ThorChainAdapter` may receive only the exact-RUNE initializer guard required by AC4; `AdapterFactory` may receive only the matching composition guard. `WalletStorage`, `WalletManager`, `WalletData`, `WalletService`, `WalletListViewModel`, `WalletView`, and existing receive/balance consumers are in scope only for the generic recovery/action paths explicitly listed above, not for speculative THOR branches.

Parser contract: `handle` performs strict construction and returns `Single.error` on failure; `isValid` returns the corresponding boolean. The host address is created only after validation, with canonical lowercase raw text. The mainnet parser rejects `sthor`, `cthor`, and `tthor`, arbitrary Cosmos HRPs, malformed input, mixed-case input, and non-20-byte payloads. URI/deeplink parsing is not part of this slice.

## Lifecycle and safety behavior

The intended path is:

```text
released MarketKit metadata
  → supported/native query discovery
  → WalletStorage `WalletQuerying` reconstruction
  → WalletManager `WalletLoadResult` publication
  → WalletService unavailable-row forwarding
  → WalletListViewModel display-only unavailable row
  → existing AdapterFactory/S1-06 manager and adapter
  → generic balance/receive/status consumers
```

Restore preserves the existing sequential account → restore-marker → wallet saves. It does not add a THOR network call or claim cross-store atomicity. Cold launch must preserve the wallet and address. `WalletStorage` receives a production `WalletQuerying` wrapper around `MarketKit.Kit`; AppTests inject a deterministic fake that can return, return empty, omit a matching record, or throw independently from `tokens(queries:)` and `blockchains(uids:)`. If `TokenQuery(id:)` cannot decode a stored identity, `WalletStorage` emits `invalid_stored_token_query` (terminal). A thrown, empty, or missing token metadata result emits `token_metadata_unavailable` (retryable); a thrown, empty, or missing blockchain metadata result emits `blockchain_metadata_unavailable` (retryable). After metadata resolution, the exact predicate `blockchain.uid == thorchain && coin.uid == thorchain && coin.code == RUNE && token.type == .native && token.decimals == 8` runs before every `Wallet` construction, including cached fallback; any validly decoded mismatch emits `invalid_stored_token_query` (terminal), never a wallet, balance, adapter, or generic fallback. The durable `EnabledWallet` identity (accountId, tokenQueryId, and cached coin fields) remains stored for all three. `WalletManager` publishes a `WalletLoadResult` containing resolved wallets and sanitized `UnavailableWallet` values; `WalletService` forwards both; `WalletListViewModel` renders unavailable rows without constructing a `Wallet`, zero balance, or adapter. `WalletManager.preloadWallets()` retries only retryable records. The identity-keyed delete seam removes an unavailable `(accountId, tokenQueryId)` record and publication; tests cover terminal-row removal without a `Wallet`. AppTests must assert each input, exact code, durable identity, intact resolved rows, no fabricated state, terminal removal, and successful next deterministic retry.

The cache contract is explicit: `Update EnabledWalletCache scheme` receives the legacy `EnabledWalletCache_v_0_36` table with `(tokenQueryId, accountId, balance, balanceLocked)`; `total` and `available` do not exist until the new table is created. The old model's `balanceData` exposes `balance` as both total and available and does not expose `balanceLocked`, so the truthful mapping is `new.total = old.balance` and `new.available = old.balance`; `balanceLocked` is read only to prove the old-schema fixture and is not silently reinterpreted as current total. The migration must read the old rows before dropping the table, create the new `(tokenQueryId, accountId, total, available)` table, and insert that mapping with the same composite key. The fixture must include a non-zero `balanceLocked` sentinel to prove the mapping follows the old runtime contract, plus the exact native RUNE row and non-zero integer balance, and assert exact decimal preservation after migration. No intentional invalidation or post-migration reseeding substitutes for preservation. The storage test injects deterministic `WalletQuerying` results and separately returns empty/missing and throws at both query methods; no network timing or live cache is used to prove recovery.

The exact identity invariant is enforced at preferred-token discovery, supported-token discovery, restore selection, WalletStorage reconstruction, direct MultiSwap seed initialization, shared selectors, and adapter composition: blockchain.uid == thorchain, coin.uid == thorchain, coin.code == RUNE, token.type == .native, and token.decimals == 8. The predicate runs after metadata resolution and before any preferred token is prepended or any `Wallet` is constructed; a malformed preferred row or cached fallback cannot bypass it. A validly decoded mismatch is terminal `invalid_stored_token_query`; throwing, empty, or missing metadata remains retryable under its corresponding code. `AccountType.supports(token:)` explicitly permits only `.mnemonic/.thorChain/.native`; `AdapterFactory` and `ThorChainAdapter.init` each reject `thorchain/thorchain/RUJI/native/8`, `thorchain/thorchain/TCY/native/8`, wrong coin UID, wrong blockchain UID, custom token types, and wrong decimals. Negative RUJI/TCY/custom-token records must not appear in Manage Wallets, restore selection, direct MultiSwap seed state, or adapter composition. The S1-06 adapter remains the lifecycle owner; S1-07 must not rely on its broader metadata acceptance as proof of the host identity invariant.

Balance verification uses the existing exact integer/BigUInt path and pins decimals to `8`; no `Double` conversion is permitted. Receive displays the canonical `thor1…` address. Offline relaunch preserves the cached row and publishes an explicit stale/error or unavailable diagnostic, never a fresh zero balance; recovery returns to fresh state without duplicate adapter publication. Removing either a resolved or unavailable RUNE identity stops/removes its adapter or stored enabled record and leaves no orphan publication.

## Delta matrix

| Slice | Primary analog and coverage | Invariants | Required difference / rejected difference | Failure modes | Tests before code | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| Discovery | Manage Wallets plus `CreateAccountViewModel` and `RestoreCoinsViewModel`; responsibility, boundary, dependencies, lifecycle, state errors | supported/order/native query are consistent; create defaults unchanged; restore owns import selection | add `.thorChain` metadata; exact-RUNE filter; reject default enable and special discovery branch | absent search result, RUJI/TCY leakage, accidental default | supported/order/native-query, create-default, restore-owner tests | released fixture decode + AppTests Manage Wallets/restore path |
| Parser | AddressParserFactory + strict Tron parser; responsibility, boundary, lifecycle, state errors, trust | codec owns validity; host receives canonical address only after validation | use THOR codec/HRP; reject URI parser and generic Cosmos fallback | wrong HRP, checksum, length, case, hidden error | valid and invalid vectors through factory | targeted AppTests and exact `rg`/test output |
| Balance/Receive/Status/Ingress | Monero adapter + BaseReceive + App Status + WalletView/WalletViewModel/WalletTokenViewModel/SendTokenListViewModel/RegularMultiSwapView/MultiSwapViewModel/MultiSwapTokenSelectViewModel/AddressEventHandler; responsibility, boundary, lifecycle, trust | generic consumers, exact 8 decimals, sanitized diagnostics, no unsupported ingress | add status/recovery guards, one shared capability predicate, direct-seeded initialization guards, and all five Send/Swap ingress guards; reject activation warnings and THOR UI | stale/fresh confusion, row/top-level/token/QR/MultiSwap bypass, mixed-wallet filtering regression, duplicate updates, secret leakage | adapter spy, BigUInt/metadata, mixed BTC/ETH-plus-RUNE selector and direct-seed tests, each ingress guard, status sanitization | AppTests plus Development manual checklist |
| Restore/Relaunch | WalletStorage/WalletManager/WalletData/WalletService/WalletListViewModel + RestoreCoinsViewModel + cache migration; lifecycle, dependencies, state errors, trust | identity durable; unavailable row observable; address stable; exact cache survives | preserve sequential saves; add injectable seam, exact post-resolution predicate, terminal/retryable diagnostics, identity-keyed unavailable removal, value-preserving old-to-new migration; reject atomicity claim and backup shortcut | silent deletion, empty publication, fabricated zero, malformed preferred row, changed address, orphan adapter, stale zero | empty/missing/throwing query tests, terminal unavailable removal/publication cleanup, old-schema fixture with balance/balanceLocked mapping, offline/recovery/duplicate-adapter tests | AppTests command below plus terminate/offline/recovery/remove/reinstall manual runs |

## Tests before implementation

MarketKit tests must pin UID encode/decode, released backend/cache chain and native token decode, native RUNE query, decimals `8`, the literal explorer template from the released fixture, and the released dependency version. The implementation cannot claim this check while the release/cache artifact is missing. WalletCore AppTests must pin supported/order/description/block-time policy, unchanged create defaults, `.mnemonic` `AccountType.supports`, `RestoreCoinsViewModel` import ownership, exact identity with RUJI/TCY/custom-token negatives, native query and preferred-token filtering, strict parser vectors, factory routing, WalletStorage mismatch failure, direct MultiSwap seed rejection, mixed BTC/ETH-plus-RUNE downstream selector compatibility, every prohibited Send/Swap ingress, exact amount conversion without `Double`, value-preserving old-schema cache migration (`balance`/`balanceLocked` → `total`/`available`), storage round-trip, malformed identity plus empty/missing and throwing query sites, exact unavailable diagnostics and retry, terminal unavailable-row removal/publication cleanup, no fabricated wallet/balance/adapter, generic adapter lifecycle, duplicate-adapter count, and sanitized App Status.

Manual Development acceptance uses a public no-funds test account and records app commit/configuration, device/OS, timestamp, endpoint family, observed address/height/balance/state code, and per-step result without recording the mnemonic. Run from the exact v0.50 UW checkout on the MacBook:

```sh
export UW_WORKTREE="${UW_WORKTREE:?set to the exact v0.50 UW checkout}"
test "$(git -C "$UW_WORKTREE" rev-parse --show-toplevel)" = "$UW_WORKTREE"
test "$(git -C "$UW_WORKTREE" rev-parse HEAD)" = "8a63bfda028dd8543115b26dd777235a53304311"
git -C "$UW_WORKTREE" status --short -- packages/WalletCore/Package.swift Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved
git -C "$UW_WORKTREE" status --short --ignored -- Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved packages/WalletCore/Package.resolved
test -f "$UW_WORKTREE/Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved"
rg -n 'MarketKit.Swift|ThorChainKit.Swift' "$UW_WORKTREE/packages/WalletCore/Package.swift"
! rg -n 'package\(name: "MarketKit.Swift", path:' "$UW_WORKTREE/packages/WalletCore/Package.swift"
rg -n 'package\(name: "MarketKit.Swift", url:' "$UW_WORKTREE/packages/WalletCore/Package.swift"
export MARKETKIT_RELEASE_VERSION="${MARKETKIT_RELEASE_VERSION:?owner-supplied released MarketKit version}"
export UW_PACKAGE_RESOLVED_SHA256="${UW_PACKAGE_RESOLVED_SHA256:?owner-supplied resolved package digest}"
test "$(shasum -a 256 "$UW_WORKTREE/Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved" | awk '{print $1}')" = "$UW_PACKAGE_RESOLVED_SHA256"
jq -e --arg version "$MARKETKIT_RELEASE_VERSION" 'any(.pins[]; (.identity | ascii_downcase) == "marketkit.swift" and .state.version == $version)' "$UW_WORKTREE/Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved"
xcodebuild -project "$UW_WORKTREE/Unstoppable/Unstoppable.xcodeproj" -scheme Development -showdestinations
export UW_DESTINATION="${UW_DESTINATION:?set to one available iOS Simulator destination printed above}"
xcodebuild test -project "$UW_WORKTREE/Unstoppable/Unstoppable.xcodeproj" -scheme Development -destination "$UW_DESTINATION" -only-testing:AppTests
```

The preflight is a final-delivery check and is expected to fail while the approved local implementation still uses the pinned MarketKit path; it must pass before final acceptance/commit and must prove both a released manifest declaration and the owner-supplied resolved-file digest/version. The Development checklist is: create → Manage Wallets search → manual RUNE enable → Receive/live balance; import/restore with RUNE selected; terminate and relaunch; record the same canonical `thor1…` address; disable network before relaunch and record the cached row as stale/error or an exact unavailable code (never fresh/zero); restore network and record fresh recovery; record exactly one RUNE adapter after each reload by observing `Core.shared.adapterManager.adapterDataReadyObservable` and counting `adapterData.adapterMap.keys` whose token identity is exact RUNE; exercise and confirm blocked Send/Swap row, top-level, token, direct MultiSwap seed, and QR/deep-link paths; remove; relaunch; uninstall/reinstall and confirm no RUNE row without re-enable. No Maestro suite is applied to Unstoppable.

## Adversarial review and approval gate

Discovery remains frozen at `discovery 1/2`; closure remains `closure 0/5`. The next review must recheck the seven allowlisted IDs `D-S107-REV-001` through `D-S107-REV-007` against design revision 6 and direct regressions only; it must not reopen broad discovery. The current evidence has one Gimle freshness warning with an explicit current-tree workaround; it does not override independent local verification.

Implementation may begin only after the operator approves this exact spec revision and linked plan and authorizes a separately assigned implementation phase. Approval acknowledges that local work uses exact MarketKit head `2c327452237cfbbdc4d87bcd5dd417d1da46a61e`; it does not waive the still-open released MarketKit/backend/cache gate required before final acceptance/commit. Until approval, this repository contains documentation only for S1-07.

## Non-goals

No default enable, URI/deeplink support, history, explorer UI, native RUNE send/swap implementation, non-native THOR assets, stagenet, new host test target, Maestro, fixture transport, launch argument, acceptance-only source, secret material, or changes to the S1-06 lifecycle composition.
