# THR-118 Minimal Wallet Integration Correction Plan

## Step 1 — Remove the speculative storage abstraction

Restore `WalletStorage` to direct `MarketKit.Kit` ownership and the upstream
v0.50 `wallets(account:)` flow. Delete `WalletQuerying.swift`,
`WalletLoadResult`, and recovery-only test spies.

## Step 2 — Remove unavailable-wallet state and UI

Delete `UnavailableWallet.swift` and remove its publication from
`WalletManager`, `WalletService`, and `WalletListViewModel`. Remove
`unavailableWalletsView()`, retry, and unavailable-row deletion from
`WalletView`.

## Step 3 — Restore the existing deletion contract

Remove `delete(accountId:tokenQueryId:)` across storage, manager, and view-model
layers. Preserve the original deletion of resolved `[Wallet]` values.

## Step 4 — Verify only real product behavior

Confirm no rejected symbols remain, compare the affected generic paths with
upstream v0.50, and locally verify normal native-RUNE plus existing-wallet
behavior. Explain the retained MarketKit changes, including why the dump needs
the single native `thorchain/thorchain/native/8` relation even though the
THORChain coin and blockchain records already existed. Do not add speculative
recovery tests, use GitHub Actions, or modify Unstoppable remotely.

## Dependency and stop conditions

- Preserve all real ThorChainKit/MarketKit integration work.
- Stop if removing the contour would require deleting a demonstrated
  normal-operation RUNE dependency; report that exact dependency instead.
- Do not commit or push the Unstoppable checkout without separate operator
  permission.
