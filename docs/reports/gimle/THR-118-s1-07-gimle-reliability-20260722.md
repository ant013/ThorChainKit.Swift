# Gimle reliability report — THR-118 S1-07

**Date:** 2026-07-22
**Workflow:** `analog_change`
**Trust:** **YELLOW**
**Run:** `THR-S1-07-v050-20260722`
**ThorChainKit base:** `bed49c5694326bdf97cd213e7fd685a2543d2ab2`
**UW v0.50 evidence head:** `8a63bfda028dd8543115b26dd777235a53304311`
**MarketKit evidence head:** `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` (feature branch, not release)

## Reliability summary

Three bounded Gimle calls were made: two graph searches succeeded and one semantic search returned a warning. All load-bearing claims were independently verified against the exact assigned worktrees with Serena and targeted `rg`/Git reads. Gimle discovery was useful, but its freshness envelope is not accepted as the sole authority.

| Measure | Result |
| --- | --- |
| Useful-call rate | 100% (3/3) |
| Warnings | 1 |
| Errors / false successes | 0 / 0 |
| Analog slices / candidates | 4 / 17 |
| Accepted load-bearing claims | F-THR118-001 through F-THR118-007, F-THR118-009 |
| Trust limitation | Semantic-search nested freshness metadata disagreed with its top-level indexed-commit metadata |

## Evidence and fallback

The selected analog families were Manage Wallets discovery, the AddressParserFactory plus strict non-EVM parser shape, the Monero adapter plus generic Receive/App Status consumers, and WalletStorage/WalletManager plus RestoreHelper. Current anchors were independently checked in the exact v0.50 tree, including:

- `packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsViewModel.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/MoneroAdapter.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift`

The adjacent MarketKit checkout was verified with Git and JSON inspection. It contains the proposed native THORChain metadata, but the plan keeps the released dependency/backend/cache contract as a hard gate.

## Known Gimle limitation

**`GIMLE-THR118-FRESHNESS-001` — suspected MCP bug, medium/probable, workaround active.** Semantic search reported `current_local_tree` and zero commits behind at the top level, while nested snippets reported `unknown` / `no_indexed_commit` and `usage_preview_unavailable`. The workaround is to use Gimle only for bounded discovery and require independent current-tree Serena/`rg`/Git verification for every load-bearing claim. This limitation keeps trust at YELLOW and does not block the design because the fallback evidence matched.

## Review outcome

- `D-THR118-ARCH@1` — ACCEPT: generic discovery/storage/lifecycle seams retained; S1-06 ownership boundary preserved.
- `D-THR118-SEC@1` — ACCEPT: strict mainnet codec, canonical output, fail-closed metadata, exact integer balance, and no secret material.
- `D-THR118-VERIFY@1` — ACCEPT: released metadata gate, AppTests, Development manual acceptance, and no Maestro in Unstoppable.

Discovery 1/2 requested changes. The authoritative state records seven `REVISE` decisions against the first recorded spec artifact; no one of those decisions is treated as accepted. Design revision 5 addresses all seven without reopening discovery. No closure review has been consumed; closure remains `0/5`. Gimle trust remains YELLOW because the freshness warning and current-tree workaround are unchanged. Implementation remains blocked pending the next fresh bounded review and explicit operator approval of the exact spec and plan. The MarketKit owner’s released metadata/cache artifact remains a separate hard final-acceptance/commit gate; approved local implementation may use only pinned head `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` until then.

## Revision 3 evidence updates

- `WalletStorage.wallets(account:)` currently compacts missing token queries and missing fallback metadata; `WalletManager._reloadWallets` publishes `WalletData(wallets: [], account:)` after either query failure. Revision 3 defines durable `EnabledWallet` identity, sanitized unavailable codes, the published `WalletData` state, `preloadWallets()` retry, and four exact AppTest failure/retry assertions.
- `RestoreCoinsViewModel.loadBlockchains()` and `restore()` are the normal mnemonic import owner/consumer path; `CreateAccountViewModel.activateDefaultWallets()` remains BTC BIP84 plus ETH native. Revision 3 tests both paths and exact RUNE-only filtering, including RUJI/TCY negatives.
- `WalletView.itemsView()` has direct Send and token-seeded MultiSwap context actions. Revision 3 makes that ingress part of the acceptance contract and requires RUNE rows to hide/block both actions.
- Current cache evidence is named rather than inferred: `EnabledWalletCache` uses `enabled_wallet_caches` with (tokenQueryId, accountId) primary key and `total`/`available` columns; `StorageMigrator` registers `Update EnabledWalletCache scheme`. Revision 3 requires a seeded native-RUNE row, expected post-migration values, and deterministic throwing query injection.
- The explorer URL literal remains unresolved because the local MarketKit feature branch is not a release and does not establish the backend/cache value. Step 1 final acceptance/commit is therefore explicitly blocked on a MarketKit owner artifact containing the exact release version, decoded fixture, and literal template; approved local implementation may remain pinned to the recorded feature head.
- Manual verification now requires offline relaunch with unchanged address, stale/error cached state rather than fresh/zero, recovery to fresh, and one-adapter evidence after reload.

## Revision 4 review disposition and revision 5 corrections

- `D-S107-REV-001` (REVISE → addressed): binds the still-unknown literal explorer template to an owner-supplied released version and decoded cache artifact; the gate blocks final acceptance/commit without blocking approved local work against the pinned checkout.
- `D-S107-REV-002` (REVISE → addressed): defines durable enabled identity, display-only unavailable publication, exact terminal/retryable codes, deterministic retry, and identity-keyed terminal removal without constructing a `Wallet`.
- `D-S107-REV-003` (REVISE → addressed): covers direct WalletView row ingress plus shared/downstream capability filtering and direct-seeded guards for SendTokenList, top-level Swap, token buttons, token-seeded MultiSwap, and QR/deep-link Send.
- `D-S107-REV-004` (REVISE → addressed): names `RestoreCoinsViewModel` as the normal mnemonic import/discovery owner, preserves sequential persistence, and keeps new-account defaults unchanged.
- `D-S107-REV-005` (REVISE → addressed): names deterministic metadata-query injection and the observed legacy `balance`/`balanceLocked` fixture contract; migration maps `total = balance` and `available = balance` and retains a non-zero locked sentinel.
- `D-S107-REV-006` (REVISE → addressed): applies the exact native-RUNE identity predicate after metadata resolution across discovery, restore/storage reconstruction, factory composition, and adapter initialization, with RUJI/TCY and malformed negatives.
- `D-S107-REV-007` (REVISE → addressed): requires offline relaunch with unchanged address, explicit stale/unavailable state, fresh recovery, and exactly one adapter after every reload, backed by deterministic AppTests and the manual checklist.

The prior handoff label `GIMLE-THR118-WORKTREE-001` is reconciled here as a non-separate alias for the canonical `GIMLE-THR118-FRESHNESS-001` limitation recorded above; no second defect is claimed.
