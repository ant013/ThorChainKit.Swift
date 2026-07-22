# Gimle reliability report — THR-118 S1-07

**Date:** 2026-07-22  
**Workflow:** `analog_change`  
**Trust:** **YELLOW**  
**Run:** `175ff003-5687-4f0f-9a79-b348ff214a50`  
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

Discovery is frozen at `1/2`; closure is `0/5`. Implementation remains blocked pending explicit operator approval of the exact spec and plan revision.
