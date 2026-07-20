# ThorChainKit — Main Roadmap

## Goal

Create a standalone Swift Package, `ThorChainKit`, that provides complete native THORChain support in Unstoppable Wallet iOS. Each sprint must conclude with an observable vertical outcome in the real app and on the real network; unit tests without host verification do not constitute sprint completion.

## Slicing Principle

```text
Protocol fact
  → standalone Kit behavior
    → Unstoppable adapter boundary
      → deterministic tests
        → opt-in live-network gate
          → real user scenario
```

## Major Milestones

| Sprint | In-app outcome | Core capabilities | Live gate |
|---|---|---|---|
| 1. Foundation + read-only RUNE | The user enables RUNE and sees the correct `thor1…` address and balance after restart | package, evolving SwiftUI `iOS Example`, Maestro acceptance, network identity, derivation/address, THORNode reads, account sync, UW manager/adapter/parser, MarketKit metadata | SwiftUI Example Maestro fixture suite + Unstoppable AppTests/manual create/import → enable RUNE → address/balance → terminate/relaunch/App Status → repeat sync |
| 2. Native RUNE send | The user sends RUNE and receives a tx hash | account number/sequence, fee, protobuf sign doc, signer boundary, broadcast, preflight validation | mainnet transfer between controlled accounts and inclusion confirmation |
| 3. Transaction history and status | The wallet displays inbound/outbound RUNE transactions and their statuses | Cosmos tx search, pagination, normalized transaction model, pending reconciliation, explorer | the transaction sent in Sprint 2 transitions from pending → success after relaunch |
| 4. Native THOR actions | The THOR-native deposit/memo operations required by the wallet are supported | `MsgDeposit`, memo validation, dynamic native fee, halt/Mimir/inbound checks, refund semantics | safe minimal mainnet action with outcome confirmation |
| 5. THOR assets and token model | The wallet correctly displays permitted THORChain denoms beyond native RUNE | opaque/slash denoms, metadata resolution, pagination, decimals, synth/trade-asset policy | one confirmed non-RUNE denom syncs and survives relaunch |
| 6. Provider reliability | User-supplied and public nodes work predictably | custom endpoints, health/identity probe, failover, rate limiting, backoff, telemetry, privacy policy | controlled wrong-chain/stale/429/503 scenarios and recovery without state loss |
| 7. Native swap v2 | The existing multichain swap provider gains an internal THOR-native implementation | quote/inbound/memo/streaming swap, no allowance for the native path, action tracking/refund | real small swap with quote → broadcast → Midgard final state |
| 8. Release hardening | The kit is ready for a separate public repository and release | API stability, migrations, fuzz/fixtures, performance, security review, final docs/demo polish, CI matrix | clean install, cold start, long-running sync, upgrade from prior cache schema |

## Version Boundaries

- `v1`: native RUNE account, send, history/status, basic THOR actions, production-grade provider behavior.
- `v2`: internal THOR-native swap. The existing multichain THORChain provider continues to operate until a separate migration decision is made.
- Vultisig MPC/TSS is outside the kit's public API: Unstoppable supplies a conventional signing boundary, while the kit does not store a seed/private key.

## UI and State-Publication Boundary

- The `ThorChainKit` library is UI-agnostic. It may publish state through Combine, but it imports neither UIKit nor SwiftUI.
- The repository-owned `iOS Example` uses the SwiftUI `App` lifecycle, SwiftUI views, and Combine-backed observation only. UIKit imports, lifecycle/view-controller types, and UIKit representable wrappers are prohibited.
- The library keeps its iOS 13 deployment floor. The UIKit-free Example targets iOS 14 or later.
- TronKit/EvmKit Example projects are topology and scenario references only; their UIKit application/view-controller implementation is not an implementation analog.
- Maestro continues to target only the ThorChainKit SwiftUI Example. Unstoppable remains under AppTests and manual product acceptance.

## Definition of Done for Any Sprint

- Every slice has an approved spec and acceptance criteria.
- All deterministic tests are green; network tests are separate and opt-in.
- Errors, cancellation, timeouts, and restarts are explicitly tested.
- Significant state is not published from a stale lifecycle generation.
- Integration goes through the standard Unstoppable adapter contract without a hidden special case, unless the spec explicitly proves otherwise.
- Repository-owned source passes the platform-boundary gate: no UIKit in the library or Example, no SwiftUI in the library, and only SwiftUI + Combine in the Example presentation path.
- A real user scenario is completed on a controlled account, with the endpoint, block height/tx ID, and outcome recorded.
- The Maestro acceptance flow for the added `iOS Example` scenario is green; fixture/live mode is distinguishable in artifacts. Maestro is neither added to nor run against Unstoppable.
- Gimle evidence is updated; remaining index defects and fallbacks are documented.

## Critical Cross-Repository Dependencies

`ThorChainKit` is created separately. However, the end-to-end release will require coordinated changes:

1. New `ThorChainKit.Swift` repository and release.
2. MarketKit: new `BlockchainType`, RUNE chain/token metadata, decimals `8`, explorer template, backend/cache support, release.
3. Unstoppable `WalletCore`: dependency bump, manager/wrapper/adapter/parser/factory/Core wiring.
4. App-level `AppTests` and manual product acceptance; UI for custom nodes and advanced THOR actions if needed. Maestro remains only in the kit repository.
