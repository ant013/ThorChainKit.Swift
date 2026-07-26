# S1-07 Minimal Unstoppable Wallet Integration Correction

Status: Proposed correction; implementation is not authorized until this exact
revision is reviewed and approved.

## Goal

Keep the proven Unstoppable Wallet v0.50 lifecycle and storage behavior intact.
Integrate native RUNE through the same existing seams used by other kits, with
only the smallest THOR-specific differences required for the kit to work.

This correction supersedes only the `WalletQuerying`, `UnavailableWallet`,
unavailable-row retry/delete, and identity-keyed deletion requirements in
`S1-07-unstoppable-rune-surface.md`. All real native-RUNE integration
requirements remain in force.

## Assumptions

- Unstoppable Wallet v0.50 is a valid production baseline with 49 released
  versions and is the primary lifecycle and storage authority.
- MarketKit supplies valid token and blockchain metadata during normal app
  operation, as it does for existing kits.
- ThorChainKit is responsible for THORChain synchronization and adapter
  behavior; WalletCore should compose it like sibling kits rather than invent a
  second recovery subsystem.
- Existing generic failure behavior remains acceptable unless a reproduced
  product bug demonstrates otherwise.

## Verified analog decision

At upstream v0.50, `WalletStorage` owns `MarketKit.Kit` directly,
`wallets(account:)` reconstructs ordinary wallets, `WalletManager` uses the
existing generic failure path, `WalletView` renders only normal wallet rows,
and deletion operates on constructed `Wallet` values.

The current local THOR checkout adds an independent `WalletQuerying` protocol,
`UnavailableWallet` publication and UI, retry behavior, and deletion by
`accountId + tokenQueryId`. ThorChainKit itself does not require or expose that
recovery model. These additions are therefore rejected as unnecessary
divergence from the proven host lifecycle.

## Scope

Remove the complete uncommitted hypothetical recovery contour:

- Delete `WalletQuerying.swift` and restore direct `MarketKit.Kit` ownership in
  `WalletStorage`.
- Delete `UnavailableWallet.swift`, `WalletLoadResult`, and unavailable-wallet
  propagation through `WalletManager.WalletData`, `WalletService`, and
  `WalletListViewModel`.
- Remove `unavailableWalletsView()` and its call from `WalletView`.
- Remove unavailable-wallet retry and deletion actions.
- Remove identity-keyed `delete(accountId:tokenQueryId:)` from
  `EnabledWalletStorage`, `WalletStorage`, `WalletManager`, and
  `WalletListViewModel`.
- Remove tests and spies whose only purpose is the rejected hypothetical
  metadata-error/recovery model.
- Restore the original generic `wallets(account:)` reconstruction and normal
  resolved-wallet deletion path.

Preserve the actual native-RUNE integration:

- ThorChainKit dependency and its factory, manager, adapter, address parser,
  lifecycle composition, and provider behavior.
- MarketKit THORChain/native-RUNE metadata.
- Exact native-RUNE identity checks only where required to avoid constructing
  the wrong chain/token.
- Account support, discovery/restore integration, balance/receive/status
  surfaces, and existing Send/Swap availability rules.
- Real migrations required by the existing schema.
- Existing BTC, ETH, and other wallet behavior.

## Affected areas

- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Storage/EnabledWalletStorage.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Storage/WalletQuerying.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift`
- `packages/WalletCore/Sources/WalletCore/Models/UnavailableWallet.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletService.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletListViewModel.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletView.swift`
- THORChain tests that exist only for the removed recovery contour

No remote Unstoppable change, commit, push, or PR is authorized by this spec.

## Acceptance criteria

1. No `WalletQuerying`, `UnavailableWallet`, `WalletLoadResult`,
   `unavailableWalletsView`, unavailable retry, or identity-keyed delete symbol
   remains in the local Unstoppable change.
2. `WalletStorage` again owns `MarketKit.Kit` directly and follows the original
   v0.50 `wallets(account:)` flow.
3. `WalletView` renders the existing wallet list without a new technical-error
   row, raw diagnostic strings, hard-coded fallback `RUNE`, or `n/a`.
4. Existing resolved-wallet deletion remains unchanged.
5. Native RUNE remains discoverable and constructible through the normal
   MarketKit/WalletCore path and uses ThorChainKit for its adapter lifecycle.
6. Existing BTC/ETH and other wallet paths retain their original behavior.
7. The change contains no speculative retry, recovery, fallback, or persistence
   abstraction without a reproduced requirement.
8. All verification runs locally on the MacBook. GitHub Actions and
   Unstoppable remote operations are not used.
9. The completion handoff explains every retained MarketKit change and the
   bundled dump delta in plain language. It must state that MarketKit 3.6.12
   already contains the THORChain coin and blockchain records, while the local
   branch adds exactly one native token relation:
   `thorchain + thorchain + native + 8 decimals`. No dump-driven recovery logic
   is introduced.

## Verification plan

- Compare the final WalletStorage, WalletManager, WalletView, and deletion
  paths against upstream v0.50.
- Run targeted symbol searches proving the rejected contour is absent.
- Run focused WalletCore/App tests for normal native-RUNE discovery,
  construction, balance/receive/status composition, and existing wallet
  behavior.
- Build the local Unstoppable application only after the code correction is
  approved and implemented.
- Perform a manual happy-path RUNE check; do not add acceptance scenarios for
  hypothetical database or MarketKit corruption.
- Compare MarketKit `3.6.12..feature/THR-104-thorchain-metadata` and include a
  plain-language dump explanation in the final handoff.

## Open questions

None. The operator explicitly selected the minimal, normal-operation model.
