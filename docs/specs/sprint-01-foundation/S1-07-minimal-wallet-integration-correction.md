# S1-07 Minimal Unstoppable Wallet Integration Correction

Status: Proposed correction revision 2; implementation is not authorized until
this exact revision is reviewed and approved.

## Goal

Keep Unstoppable Wallet v0.50 behavior and style intact. Add native RUNE through
the same concrete seams used by Ethereum, Tron, and TON, changing generic
WalletCore code only where native THORChain support requires it.

This revision combines the already reviewed removal of the speculative
wallet-recovery contour with the remaining verified simplifications:

- direct `(.thorChain, .native)` routing instead of a THOR-only token helper;
- a concrete manager and kit construction path with all three endpoint
  families;
- a small balance/deposit adapter without a second lifecycle or numeric state
  machine;
- removal of the unrelated generic cache migration;
- deferral of send address parsing to S2-07.

## Assumptions

- `origin/version/0.50` at `8a63bfda` is the host behavior and style authority.
- MarketKit supplies valid blockchain/token metadata during normal operation.
- ThorChainKit owns synchronization and node failover. WalletCore composes it;
  WalletCore does not reproduce kit policy.
- S1-07 owns discovery, adapter lifecycle, balance, status, and receive.
- S2-07 owns real Unstoppable `SendNew` integration and THORChain send-address
  handling.
- A generic host behavior is not changed without a reproduced requirement
  specific to this integration.

## Verified analog design

### Native token routing

`AccountType.supports(token:)` expresses Ethereum, Tron, and TON support with
direct blockchain/token-type tuples. Native RUNE uses the same form:
`(.thorChain, .native)`. `AdapterFactory` routes that tuple directly.

Delete `BlockchainType.isNativeThorChainRune`. It duplicates already trusted
MarketKit metadata with coin UID, code, decimals, and blockchain checks and has
no sibling-chain analog. Where Send/Swap remains intentionally hidden until
S2-07, use the existing direct chain/type or capability checks rather than a
new helper.

### Manager and endpoints

`ThorChainKitManager` follows `TronKitManager`/`TonKitManager`:

- weakly retain the concrete `ThorChainKit.Kit`;
- retain the current account needed to decide reuse;
- construct the kit directly with `ThorChainKit.Kit.instance`;
- start it and return it through the serial manager queue.

Keep exactly the existing three mainnet endpoint families:

1. Rorcual;
2. IBS;
3. Keplr.

Store their concrete `ThorChainKit.EndpointConfiguration` as a private static
manager value. Delete the test-only endpoint-provider, kit, factory, and
diagnostic-logger protocols and implementations. Delete the endpoint-record
duplication, self-derived allowlists, runtime `validate`, and compound
endpoint/address `CacheIdentity`. `Core` constructs the manager directly.

### Adapter

`ThorChainAdapter` holds the concrete `ThorChainKit.Kit` and provides only the
established WalletCore surfaces:

- Combine-backed balance/status/debug publication;
- `Token.decimalValue(value:)` balance mapping;
- receive address;
- direct `start`, `stop`, and `refresh` delegation.

Delete both `NSRecursiveLock` instances, stopped-state gating,
`withActiveKitCall`, `conversionFailure`, the private 38-digit roundtrip
conversion policy, and their abstraction-only tests. The kit remains the
authority for synchronization state and thread safety.

### Host storage and UI

Restore the v0.50 host lifecycle:

- direct `MarketKit.Kit` ownership in `WalletStorage`;
- ordinary `[Wallet]` publication and normal wallet rows;
- deletion of resolved `Wallet` values;
- existing generic failure behavior.

Delete `WalletQuerying`, `WalletLoadResult`, `UnavailableWallet`, unavailable
retry/UI/deletion, and identity-keyed deletion. Also restore
`StorageMigrator` and `EnabledWalletCache` to v0.50: the added cache-preservation
migration is generic, has no THORChain dependency, and belongs in a separate
task only if independently required.

### Address parsing boundary

Keep `ThorChainAdapter.receiveAddress`; it needs no URI parser. Delete
`ThorChainAddressParser`, remove its `AddressParserFactory` registration, and
restore `AddressEventHandler` to v0.50. The current add-then-reject path is not
useful: it registers a THOR parser and then rejects `.thorChain` in the generic
event handler. S2-07 will add the real send parser with its SendNew behavior.

## Scope

### Remove

- `WalletQuerying.swift`, `UnavailableWallet.swift`, `WalletLoadResult`, their
  full propagation contour, retry/UI/actions, and recovery-only tests/spies.
- `delete(accountId:tokenQueryId:)` and its call sites.
- `BlockchainType.isNativeThorChainRune` and all call sites/tests.
- `ThorChainKitFactory.swift`; move only its three concrete provider families
  into a private static configuration in `ThorChainKitManager`.
- endpoint/factory/kit/logger protocols, runtime allowlist validation,
  endpoint-record duplication, and compound cache identity.
- adapter locks, stopped gate, custom numeric failure state, and tests that
  exist only for those policies.
- the `EnabledWalletCache` preservation migration/initializer and
  migration-only tests introduced by this integration.
- `ThorChainAddressParser.swift`, its factory registration, THOR-specific
  generic `AddressEventHandler` changes, and parser-only tests.

### Preserve

- the local ThorChainKit package dependency;
- MarketKit THORChain/native-RUNE metadata;
- `.thorChain` description, ordering, and block-time metadata;
- account-address derivation/provider behavior;
- direct `(.thorChain, .native)` account and adapter routing;
- all Rorcual, IBS, and Keplr endpoint values;
- concrete manager/adapter composition;
- balance, receive, status, debug, discovery, and restore surfaces;
- temporary direct Send/Swap hiding until S2-07;
- existing BTC, ETH, Tron, TON, and other wallet behavior.

No remote Unstoppable commit, push, or PR is authorized.

## Affected areas

- `packages/WalletCore/Sources/WalletCore/Core/Core.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Storage/StorageMigrator.swift`
- `packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift`
- `packages/WalletCore/Sources/WalletCore/Models/AccountType.swift`
- `packages/WalletCore/Sources/WalletCore/Models/EnabledWalletCache.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/Main/Workers/SendAppShowWorker/AddressEventHandler.swift`
- THOR-specific Wallet/ManageWallets capability call sites
- THOR tests that cover removed abstractions instead of retained behavior
- the previously reviewed recovery-contour files and call sites

## Acceptance criteria

1. No rejected recovery symbol or identity-keyed deletion remains.
2. No `isNativeThorChainRune` symbol remains; native RUNE routing is the direct
   `(.thorChain, .native)` tuple.
3. The concrete manager follows the Tron/Ton ownership and construction shape
   and retains Rorcual, IBS, and Keplr.
4. No endpoint-provider/factory/kit/logger protocol, self-derived allowlist,
   runtime validation, or compound cache identity remains.
5. The adapter has no locks, stopped gate, or custom numeric failure state and
   uses `Token.decimalValue(value:)`.
6. Balance, status/debug, receive address, and direct lifecycle delegation
   remain functional.
7. `StorageMigrator` and `EnabledWalletCache` contain no integration-owned
   generic cache-preservation change.
8. No THOR address parser or generic `AddressEventHandler` modification remains;
   receive remains available and send parsing is explicitly deferred to S2-07.
9. Existing non-THOR behavior is unchanged.
10. Focused local tests and a local WalletCore/package build pass. App build and
    manual RUNE balance/receive smoke run locally when the operator chooses to
    launch it. GitHub Actions is not used.
11. The completion handoff explains the retained MarketKit dump delta: the base
    already contains THORChain coin/blockchain rows; the local branch adds one
    `thorchain + thorchain + native + 8 decimals` token relation.

## Verification plan

- Prove rejected symbols and generic diffs are absent with targeted `rg` and
  `git diff`.
- Compare manager/adapter/routing shapes with exact Tron/Ton/EVM analogs.
- Verify all three endpoint families are present exactly once.
- Run focused WalletCore tests for direct account/adapter routing,
  manager reuse/account switching, balance/status/receive projection, and
  retained wallet discovery.
- Remove tests for deleted abstractions; do not replace them with speculative
  corruption or concurrency scenarios.
- Run the smallest local package/WalletCore build covering changed files.
- Perform app/manual RUNE balance and receive smoke only locally.
- Do not use hosted CI or modify Unstoppable remotely.

## Open questions

None. The operator selected the complete minimal-style correction.
