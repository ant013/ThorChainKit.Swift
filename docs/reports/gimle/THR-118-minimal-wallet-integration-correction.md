# Gimle Evidence Report — THR-118 Minimal Wallet Integration Correction R2

## Repository identity

- Exact checkout: adjacent local `unstoppable-wallet-ios-THR-104-v0.50`
- Origin: `horizontalsystems/unstoppable-wallet-ios`
- Local branch: `local/THR-104-thorchain-lifecycle-v0.50`
- HEAD and merge-base with `origin/version/0.50`:
  `8a63bfda028dd8543115b26dd777235a53304311`
- Working copy: dirty with the existing local native-RUNE integration.

## Verified component families

1. Native routing: `AccountType.supports` and `AdapterFactory` use direct
   blockchain/token-type tuples for Ethereum, Tron, and TON. The THOR-only
   identity helper is unsupported divergence.
2. Manager lifecycle: `TronKitManager` and `TonKitManager` retain concrete kits,
   current-account identity, and call `Kit.instance` directly. THOR can retain
   its three endpoint families without provider/factory/logger protocols or a
   self-derived allowlist.
3. Adapter behavior: EVM/Tron/TON adapters delegate lifecycle directly and use
   existing token conversion. No peer adapter has the THOR locks,
   stopped-state gate, or conversion-failure state machine.
4. Persistence boundary: the added `EnabledWalletCache` preservation migration
   has no THOR symbol or dependency and is outside the integration.
5. Address boundary: balance/receive needs `IDepositAdapter.receiveAddress`, not
   a send URI parser. S2-07 owns real SendNew integration.

The four new THOR production files currently total 550 lines before tests. Line
count is not itself a defect, but the verified differences identify which
abstraction contours are unnecessary.

## MarketKit boundary

MarketKit `3.6.12` already contains THORChain coin and blockchain records. The
local metadata branch adds one native token relation:
`thorchain + thorchain + native + 8 decimals`, its enum mapping, and a focused
metadata test. No dump-driven host recovery behavior is required.

## Gimle reliability

`codebase-memory.search_graph` returned the current `AccountType.supports` and
TON-manager symbols. `palace.code.search_graph` timed out after 300 seconds for
the exact manager query. The Palace result is not used. Load-bearing decisions
were independently confirmed with Serena and targeted `rg`/Git reads in the
exact checkout. Trust remains RED and the fallback is recorded as
`GIMLE-THR118-R2-001`.

## Selected design

- Keep ordinary v0.50 host lifecycle and direct native tuples.
- Keep concrete manager/adapter composition and all three endpoint families.
- Remove protocols, validation, locks, custom state, and tests that exist only
  for those abstractions.
- Restore unrelated cache and generic event-handler files to v0.50.
- Defer send parsing to S2-07.

## Adversarial review

Decision: ACCEPT for all five component families.

- Direct tuple routing retains the same metadata authority and capability
  boundaries as peer chains.
- Concrete construction retains all three providers; only self-derived or
  test-only layers are removed.
- Direct adapter lifecycle and shared conversion retain the host's established
  ownership model.
- Cache preservation is a separate generic concern, not a THOR integration
  requirement.
- Receive remains intact; only premature send parsing moves to S2-07.

Implementation remains blocked until the exact pushed revision is explicitly
approved.
