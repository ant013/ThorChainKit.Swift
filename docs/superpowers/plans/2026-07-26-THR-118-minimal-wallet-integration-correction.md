# THR-118 Minimal Wallet Integration Correction Plan — Revision 2

## Step 1 — Preserve the v0.50 host lifecycle

Keep the already applied removal of `WalletQuerying`, unavailable-wallet
state/UI/retry, identity-keyed deletion, and recovery-only tests. Recheck the
final host paths against `origin/version/0.50`.

## Step 2 — Restore direct native routing

Replace `isNativeThorChainRune` with direct `(.thorChain, .native)` account and
adapter routing. Use direct chain/type or existing capability checks at the few
temporary Send/Swap hiding call sites. Delete helper-only tests.

## Step 3 — Simplify manager and construction

Delete `ThorChainKitFactory.swift`. Put the existing Rorcual, IBS, and Keplr
values into one private static endpoint configuration in
`ThorChainKitManager`. Shape manager ownership/reuse like `TronKitManager` and
`TonKitManager`, calling `ThorChainKit.Kit.instance` directly. Update `Core` to
construct only the concrete manager.

## Step 4 — Simplify the adapter

Use the concrete kit, existing publishers, `Token.decimalValue`, receive
address, and direct lifecycle delegation. Remove locks, stopped/conversion
state, custom roundtrip conversion, and tests for those removed policies.

## Step 5 — Remove unrelated host changes

Restore `StorageMigrator` and `EnabledWalletCache` to v0.50 and remove their
migration-only tests. Delete `ThorChainAddressParser`, undo its factory
registration, and restore the generic `AddressEventHandler`. S2-07 owns the
future send parser.

## Step 6 — Verify the retained behavior

Run symbol/diff hygiene, focused WalletCore tests, and the smallest local build.
Verify all three provider families, normal RUNE discovery, adapter creation,
balance/status/receive, and existing wallet behavior. Do not add hypothetical
failure tests, use hosted CI, or modify Unstoppable remotely.

## Stop conditions

- Stop if a proposed removal is required by a reproduced normal RUNE
  balance/receive path; report the exact dependency before broadening scope.
- Do not change MarketKit dumps beyond the already established one native RUNE
  token relation.
- Do not implement SendNew or address parsing before S2-07.
- Do not commit or push the local Unstoppable checkout without separate
  operator permission.
