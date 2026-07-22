# S1-06 — Unstoppable lifecycle composition

**Status:** design revision 5; implementation blocked pending adversarial review,
explicit approval, and a dedicated host feature worktree.
**Risk:** high/host integration.
**Base:** clean `origin/main` at
`0f572e455be07df798a233eff31bbc27bb0940c5`; discovery 2/2, closure 0/5.
**Observable outcome:** the approved host composition seam constructs one
unstarted `ThorChainKit` wrapper for a manually constructed native RUNE wallet
from exact consumable ThorChainKit and MarketKit revisions, and the adapter
owns start/stop/refresh with checked state bridging. The minimum
`.native/.thorChain` route is included; discovery, UI, import, relaunch, and
explorer surfaces remain S1-07.

## Goal

Connect the standalone kit to the current WalletCore architecture along the
verified composition and lifecycle analogs, while correcting split lifecycle
ownership: the manager only creates/caches the wrapper, and the adapter is the
sole lifecycle owner. S1-06 also supplies the smallest MarketKit identity and
native-RUNE metadata needed for the real manually constructed route. Discovery,
UI, import, relaunch, and explorer behavior remain S1-07 work.

This spec describes future Unstoppable changes, but does not create a branch,
spec, or files in that repository now. Phase 1 used only the detached clean
evidence worktree bound in the Gimle checkpoint, fetched `origin/master` at
`db86b99e9a12d758729a41c83a514b709df0a525`, with the official
`https://github.com/horizontalsystems/unstoppable-wallet-ios.git` origin and a
clean status. The pre-existing dirty Zcash checkout remains untouched and is
excluded from source evidence.

The existing reviewed S1-06 draft is the input to this revision, not approval
of it. Exact-head verification corrected two draft assumptions: the host has
no `AccountAddressProvider.swift` or `IAccountAddressProvider`; the mnemonic
boundary belongs in the existing `AccountAddress.swift`, and the host's
current `Core` construction uses a local manager value rather than a stored
`Core` property. The current `TronKitManager` starts its kit at the manager
boundary and the current `TronAdapter` lifecycle methods are empty; those are
the explicit deltas for this slice.

## Scope

Included:

- dependency/product import, including the package-manifest compatibility gate;
- address factory boundary for mnemonic accounts;
- manager/wrapper;
- native adapter `IAdapter + IBalanceAdapter + IDepositAdapter`;
- AdapterFactory native route;
- Core construction/injection;
- Combine→Rx bridge;
- manually constructed native RUNE wallet integration test.

Excluded:

- MarketKit discovery/release beyond the minimum identity/metadata commit and
  the real Manage Wallets flow (S1-07);
- signer/send/history;
- custom node UI/source manager;
- private-key/watch-only accounts;
- default-enable RUNE.

The Combine→Rx bridge is strictly an Unstoppable host integration boundary. It does not authorize UIKit in ThorChainKit or its repository-owned Example: the kit core stays UI-agnostic, and the Example stays SwiftUI + Combine.

## New host files

```text
packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift
packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift
packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift
Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift
Unstoppable/Tests/ThorChain/ThorChainAdapterTests.swift
Unstoppable/Tests/ThorChain/ThorChainIntegrationTests.swift
```

The current WalletCore `Package.swift` has no test target. Host tests are added
to the existing `AppTests` target under `Unstoppable/Tests/ThorChain`; the
exact origin/master checkout already contains `Unstoppable/Tests/AppTests.swift`
and the current Xcode test target is the host test seam. No new speculative
`WalletCoreTests` target is created in S1-06.

## Minimum MarketKit prerequisite

The adjacent clean MarketKit clone is the only implementation workspace for
this prerequisite:

```text
label `MarketKit.Swift-THR-104`
branch: feature/THR-104-thorchain-metadata
base: origin/master 95c92c876c3f40c28816e8e9891d6ffaf6eb0828
```

The change is limited to the public identity required by the host route:

- `Sources/MarketKit/Classes/Models/BlockchainType.swift` — add
  `.thorChain` and UID `thorchain` with round-trip tests;
- `Sources/MarketKit/Dumps/blockchains.json` — add the THORChain blockchain
  record required by the existing query path;
- `Sources/MarketKit/Dumps/coins.json` — add the native RUNE record with
  decimals `8` and the approved native token identifiers;
- `Tests/MarketKitTests/ThorChainMetadataTests.swift` and the minimal
  `Package.swift` test-target wiring — assert enum round-trip, native query,
  decimals, and token type without discovery or UI behavior.

The exact resulting MarketKit commit is a release input to the host branch and
must be pinned by exact `revision:` in `packages/WalletCore/Package.swift`
before the host PR is reviewable. The local path is never written into a
manifest or committed file; resolver output is external verification evidence.

## Host files to modify

- `unstoppable-wallet-ios/packages/WalletCore/Package.swift:1` — dependency/product `ThorChainKit`.
- `unstoppable-wallet-ios/Unstoppable.xcodeproj/project.pbxproj:1` — direct
  `ThorChainKit` product dependency for the existing `AppTests` target.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift:1` — add the direct `thorChainAddress(account:)` boundary alongside the existing EVM/TRON static address methods.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift:8` — manager injection, native route.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Core.swift:250-348` — construction/wiring; verify exact anchors before editing.

The package dependency uses the public ThorChainKit repository URL
`https://github.com/ant013/ThorChainKit.Swift.git` and product `ThorChainKit`.
The currently reviewed `0f572e455be07df798a233eff31bbc27bb0940c5` manifest is
not consumable as a remote WalletCore dependency because it places
`-warnings-as-errors` in target `unsafeFlags`. Before host resolution, a
separately reviewed ThorChainKit commit removes all target-level unsafe flags;
warnings-as-errors remain an explicit owned-target build/CI invocation. The
host pins that exact published SHA in `packages/WalletCore/Package.swift`. No tag, moving branch,
host-local path, or absolute operator path is committed.

`AdapterManager` must not change for the THORChain lifecycle. If implementation requires a THOR-specific refresh case, the design returns for review.

The exact MarketKit base is `origin/master` at
`95c92c876c3f40c28816e8e9891d6ffaf6eb0828` in the adjacent clean clone
label `MarketKit.Swift-THR-104` on branch
`feature/THR-104-thorchain-metadata`. S1-06 owns the smallest committed
MarketKit delta from that base: `BlockchainType.thorChain` with stable UID,
the native RUNE blockchain/token metadata and query result needed by the host
route, and focused public metadata tests. The resulting commit SHA is recorded
in the final Unstoppable `Package.swift`; during local development only, the
clean adjacent clone may be used as an uncommitted resolver override. No
temporary local enum or wrong-chain mapping is allowed. S1-07 owns discovery,
UI, import, relaunch, and explorer behavior above this identity layer.

## Manager

```swift
final class ThorChainKitManager {
    private weak var _wrapper: ThorChainKitWrapper?
    private var currentAccountId: String?
    private let queue: DispatchQueue
    private let endpointProvider: IThorChainEndpointConfigurationProvider
    private let kitFactory: IThorChainKitFactory

    func thorChainKitWrapper(account: Account) throws -> ThorChainKitWrapper
    var thorChainKitWrapper: ThorChainKitWrapper? { get }
}

protocol IThorChainEndpointConfigurationProvider {
    func configuration() throws -> ThorChainEndpointConfiguration
}

struct ThorChainEndpointConfiguration {
    let value: ThorChainKit.EndpointConfiguration
    let approvedMainnetHosts: Set<String>
}

final class ThorChainKitWrapper {
    let thorChainKit: any IThorChainKit
}

protocol IThorChainKit: AnyObject {
    var address: ThorChainKit.Address { get }
    var network: ThorChainKit.Network { get }
    var lastBlockHeight: Int64? { get }
    var syncState: ThorChainKit.SyncState { get }
    var accountState: ThorChainKit.AccountState? { get }
    var runeBalance: BigUInt { get }
    var accountExists: Bool { get }

    var lastBlockHeightPublisher: AnyPublisher<Int64?, Never> { get }
    var syncStatePublisher: AnyPublisher<ThorChainKit.SyncState, Never> { get }
    var accountStatePublisher: AnyPublisher<ThorChainKit.AccountState?, Never> { get }

    func start()
    func stop()
    func refresh()
}

extension ThorChainKit.Kit: IThorChainKit {}

protocol IThorChainKitFactory {
    func kit(
        address: ThorChainKit.Address,
        walletId: String,
        endpoints: ThorChainKit.EndpointConfiguration
    ) throws -> any IThorChainKit
}

final class ThorChainKitFactory: IThorChainKitFactory {
    // delegates to production Kit.instance; never starts the kit
}
```

`IThorChainKit` is a regular internal production abstraction in WalletCore, not
a test/DEBUG API or an extension to the public ThorChainKit API. The production
conformance delegates to the exact public facade without adding behavior.
`AppTests` use the existing `Unstoppable/Tests` target and pass a spy that
implements the same protocol; they do not import `@_spi(Testing)`, use a kit
fixture transport, or require host launch arguments.

### `_thorChainKitWrapper(account:)`

1. Guard `.mnemonic` and available seed; other account types throw
   `.unsupportedAccount` before consulting or returning the cache.
2. `AccountAddress.thorChainAddress(account:)` derives the canonical mainnet
   address.
3. Resolve configuration from the injected provider. It must be HTTPS mainnet
   configuration from the approved production source, and every endpoint host
   must be in `approvedMainnetHosts`; endpoint-reported identity never expands
   that allowlist. Reject an unapproved host before kit construction.
4. Form a non-secret cache identity from account ID, full derived address,
   network, and approved endpoint-family identity. Serialize validation, cache
   lookup, replacement, and factory construction on the manager queue. Return a
   cached wrapper only when the complete identity matches. A same-ID replacement
   with a changed or unsupported mnemonic/address/network must invalidate the
   prior cache and never receive the prior wrapper.
5. Call injected `kitFactory.kit(address: address, walletId: account.id, endpoints: endpoints.value)`;
   production factory delegates to `ThorChainKit.Kit.instance`, which derives
   its sole network from `address.network`.
6. Construct wrapper, cache weak wrapper plus the complete non-secret identity.
   The manager must
   not retain `Account`, `AccountType`, mnemonic, seed, or private material.
7. **Do not call `thorChainKit.start()`**.

No signer in Sprint 1 wrapper. It is added by send spec, so read-only boundary cannot accidentally retain private material.

### Cache semantics

- same complete identity → same live wrapper while strongly held by adapter;
- different account or changed address/network/endpoint identity → new wrapper;
- replacing an account invalidates the prior cache identity;
- same-ID replacement is validated before cache lookup and cannot reuse the
  prior wrapper;
- wrapper lifetime belongs to adapter; manager weak reference avoids hidden lifetime;
- no `createdRelay` unless a proven consumer needs it;
- no node-source update observer in S1 because node-source UI excluded.

## Address host boundary

```swift
extension AccountAddress {
    static func thorChainAddress(account: Account) throws -> ThorChainKit.Address
}
```

- `AccountAddress.thorChainAddress` is a direct static method in the existing `AccountAddress.swift`, matching the current EVM/TRON boundary; no provider protocol or new provider file is introduced;
- supports only `.mnemonic`;
- obtains mnemonic seed through existing `AccountType.mnemonicSeed`;
- uses `DerivationPath.defaultAccount.rawValue` through the approved S1-03
  derivation boundary; no path component or coin-type literal is added here;
- creates the approved S1-03 `HDWallet` shape and takes its default external
  public key;
- passes the compressed bytes to `ThorChainKit.AccountAddressFactory.address(compressedPublicKey:network:.mainnet)`;
- returns full validated `Address`, not raw `String`;
- errors: `.mnemonicNoSeed`, `.unsupportedAccount`, typed Thor address/derivation error;
- no empty-string fallback.

## Adapter

```swift
final class ThorChainAdapter: IAdapter, IBalanceAdapter, IDepositAdapter {
    private let thorChainKitWrapper: ThorChainKitWrapper
    private let wallet: Wallet
    private let disposeBag = DisposeBag()

    init(thorChainKitWrapper: ThorChainKitWrapper, wallet: Wallet)

    var isMainNet: Bool { get }
    var statusInfo: [(String, Any)] { get }
    var debugInfo: String { get }
    var balanceState: AdapterState { get }
    var balanceStateUpdatedObservable: Observable<AdapterState> { get }
    var balanceData: BalanceData { get }
    var balanceDataUpdatedObservable: Observable<BalanceData> { get }
    var receiveAddress: DepositAddress { get }

    func start()
    func stop()
    func refresh()
}
```

Lifecycle is exact forwarding:

```swift
func start() { thorChainKitWrapper.thorChainKit.start() }
func stop() { thorChainKitWrapper.thorChainKit.stop() }
func refresh() { thorChainKitWrapper.thorChainKit.refresh() }
```

`stop()` is an idempotent release barrier. Adapter removal invokes it exactly
once, it cancels the current kit generation, and no request or publisher event
may occur after the barrier. A terminal/replayed state already queued before
the barrier may be observed after stop, but no stale-generation request,
subscription admission, or network work may begin after it. `deinit` may call
the same idempotent stop as a safety net; the normal owner remains
`AdapterManager` removal.

`isMainNet` is derived from `thorChainKitWrapper.thorChainKit.network == .mainnet`. `statusInfo` and `debugInfo` contain the sanitized sync state, accepted height, chain ID, and endpoint family ID, but no endpoint credentials, mnemonic, seed, or raw internal error body.

`IBalanceAdapter` already provides defaults for `spendMode`/`caution`, and `IDepositAdapter` provides defaults for `receiveAddressStatus`/publisher. The nonexistent `name`, `syncStateObservable`, `balanceStateObservable`, and `balanceDataObservable` are not added.

No empty methods. No manager-owned parallel refresh.

### State bridge

- Kit Combine publishers bridge to Rx without duplicate subscription owners.
- `SyncState` mapping is total/exhaustive.
- cached stale data remains in `BalanceData` while `AdapterState.notSynced` carries failure.
- mapping is explicit and exhaustive:

  | Kit state/error | Host observable behavior |
  |---|---|
  | `idle(cached: false)` | idle/not synced, no balance |
  | `idle(cached: true)` | idle/not synced, retain cached balance |
  | `syncing(previous:)` | syncing, retain previous balance when present |
  | `synced(_)` | synced, publish exact balance |
  | `notSynced(error, cached:)` | not synced, retain cached balance and map the typed diagnostic |
  | each `SyncError` case | stable sanitized diagnostic code; no raw error body |

  The implementation test enumerates all four `SyncState` cases and all seven
  `SyncError` cases, so adding a kit case without a host mapping fails review.
- `runeBalance` converts to `Decimal` only at host boundary using token
  decimals. The conversion is checked: zero, one base unit, fractional values,
  maximum safe values, overflow, and decimal mismatch are distinguished; any
  overflow, precision loss, or mismatch preserves the cached balance and
  publishes an invariant error rather than zero.
- Adapter initializer receives the `Wallet`/`Token` metadata required for
  decimals and throws a production `ThorChainAdapterError.invalidTokenIdentity`
  before subscriptions or lifecycle admission unless the token is native, the
  chain is `.thorChain`, and decimals are exactly `8`. This is a throwing guard,
  not an assertion, so optimized builds fail closed.
- BigUInt→Decimal conversion must detect overflow/precision loss; no `Double` intermediate.

### Deposit

```swift
var receiveAddress: DepositAddress {
    DepositAddress(thorChainKitWrapper.thorChainKit.address.raw)
}
```

No `ActivatedDepositAddress`, activation warning or gasless semantics.

## Factory

```swift
private func thorChainAdapter(wallet: Wallet) -> IAdapter? {
    do {
        let wrapper = try thorChainKitManager.thorChainKitWrapper(account: wallet.account)
        return ThorChainAdapter(thorChainKitWrapper: wrapper, wallet: wallet)
    } catch {
        diagnosticLogger.log(.constructionFailed)
        return nil
    }
}
```

`constructionFailed` is a closed diagnostic value carrying only a stable error
code and no raw `Error`, URL/host, client ID, address, mnemonic, seed, or key.
The logger is injected and testable; factory failure is retryable on the next
explicit construction attempt.

Add exact route:

```swift
case (.native, .thorChain):
    return thorChainAdapter(wallet: wallet)
```

Other token types on `.thorChain` return nil in Sprint 1.

The factory catches construction failures only at the host adapter boundary and
logs the injected closed diagnostic value described above. It never logs the
raw error. A failed construction returns no adapter and the next explicit
construction attempt may retry.

## Core wiring

Construction order:

1. endpoint configuration provider;
2. production `ThorChainKitFactory`;
3. `ThorChainKitManager`;
4. inject into `AdapterFactory`;
5. `AdapterManager` receives only its existing generic dependencies, not a new
   THOR-specific manager or refresh branch. As in the current `Core` source,
   the manager may remain a local construction value held by `AdapterFactory`.

## Lifecycle sequence

```text
WalletManager publishes wallet set
  → AdapterManager._initAdapters
    → AdapterFactory.thorChainAdapter
      → manager returns unstarted wrapper
        → adapter strongly owns wrapper
          → AdapterManager calls adapter.start()

Wallet removed/account changed
  → AdapterManager calls adapter.stop()
    → kit cancels current generation
      → wrapper released
```

## Analog delta

The positive lifecycle primary is `MoneroAdapter`: its current adapter owns
non-empty start/stop/refresh behavior. The TRON vertical remains the primary
composition shape for manager cache, wrapper, factory, address boundary, and
Core wiring, but its split lifecycle is a rejected counterexample for this
dimension.

| TRON host analog | ThorChain decision |
|---|---|
| `TronKitManager` cache/wrapper/factory shape | retained |
| manager calls `tronKit.start()` | prohibited |
| `TronAdapter.start/stop/refresh` empty | rejected lifecycle counterexample |
| `MoneroAdapter` real `IAdapter` lifecycle | positive lifecycle contract for exact signatures and non-empty lifecycle |
| `AdapterManager` special-case TRON refresh | no THOR case is added |
| signer in wrapper | deferred to Sprint 2 |
| activation-aware deposit | simple deposit address |

## Tests before implementation

`ThorChainKitManagerTests`:

- same account reuses wrapper while adapter holds it;
- different account replaces wrapper;
- same-ID replacement with changed seed/address/network cannot reuse the prior
  wrapper;
- concurrent same-account construction is serialized and creates one live kit;
- mnemonic no seed and unsupported type typed errors;
- factory receives exact address/network/walletId/endpoints;
- deterministic full-address vector proves the S1-03 derivation boundary and
  guards against local path reconstruction;
- injected kit factory is the only construction seam; production factory delegates once and does not start;
- Kit remains unstarted after manager returns wrapper;
- manager retains only account ID and wrapper release does not leak lifecycle
  task;
- runtime-generated synthetic mnemonic material only; no literal mnemonic is
  committed;
- the synthetic mnemonic is derived from fixed non-secret test entropy using
  `SHA256("THR-104-S1-06-test-seed-v1")`; the expected full address is stored
  as a public test vector;
- approved endpoint configuration is accepted and an unapproved host is
  rejected before construction;
- normal `IThorChainKit` spy proves construction/lifecycle without importing `@_spi(Testing)` or adding DEBUG branches.

`ThorChainAdapterTests`:

- adapter `start/stop/refresh` forward exactly once;
- lifecycle spy records exact call order, one stop on removal, no request/event
  after stop except a terminal/replayed state already queued before the barrier,
  and weak wrapper/adapter leak sentinels;
- exact `IAdapter`/`IBalanceAdapter`/`IDepositAdapter` surface compiles against current WalletCore protocols;
- `balanceStateUpdatedObservable` and `balanceDataUpdatedObservable` map kit Combine publishers to Rx;
- exhaustive `SyncState`/`SyncError` mapping table has one assertion per case,
  including cached balance retention and `idle(cached:)`;
- stale cached balance retained with error state;
- RUNE BigUInt→8-decimal conversion covers zero, one base unit, fractional,
  maximum safe, overflow, and decimal mismatch cases exactly;
- decimals != 8 and precision/overflow loss preserve cached data and produce a
  typed invariant error, never silent zero;
- receive address exact canonical string;
- native/THOR/8-decimal mismatch each throws before any subscription or
  lifecycle call, including optimized-build behavior;
- no activation semantics.

`ThorChainIntegrationTests`:

- the adjacent MarketKit revision exposes `BlockchainType.thorChain` and the
  native RUNE metadata/query needed for the real `.native/.thorChain` route;
- a manually constructed native RUNE wallet reaches the `.native/.thorChain`
  route and the injected manager/adapter seam;
- AdapterManager start causes first sync;
- wallet removal causes stop/cancellation;
- refresh uses generic `adapter.refresh()`, with no manager direct call;
- other THOR token type unsupported.
- global and wallet-scoped refresh each invoke a THOR spy exactly once through
  the adapter, with no direct manager call;
- construction failure is retryable, concurrent same-account construction does
  not create two live kits, and account replacement cannot reuse the prior kit.

## Verification

- Build the ThorChainKit package after removing target-level unsafe flags and
  enforce `-warnings-as-errors` in the owned local verifier. Build WalletCore
  against the exact published ThorChainKit and MarketKit SHAs recorded in
  `Package.swift`; local development may temporarily resolve MarketKit from
  the adjacent clean clone only.
- Run the manager, adapter, and integration tests, including the real
  `.native/.thorChain` route and the MarketKit identity query.
- Compile `AppTests` with normal `import ThorChainKit` after adding the direct
  test-target product dependency; fail if `@_spi(Testing)` appears anywhere
  under Unstoppable.
- Run `xcodebuild test -workspace Wallet.xcworkspace -scheme Development`
  with stable `-only-testing:AppTests/ThorChainKitManagerTests`,
  `-only-testing:AppTests/ThorChainAdapterTests`, and
  `-only-testing:AppTests/ThorChainIntegrationTests` selectors, an explicitly
  named physical iPhone destination, and a result bundle path. Before and after
  the command, assert clean status, exact approved HEAD, zero skipped tests,
  exact dependency SHAs, and the implementation file allowlist; do not use a
  simulator.
- Search/diff proves no `.thorChain` special-case added to `AdapterManager.refresh`.
- Run the manually constructed native RUNE wallet against the approved
  controlled mainnet endpoint after both exact dependency SHAs resolve.
- Inspect injected lifecycle logs/counters: exactly one active kit per account,
  one stop on removal, and no post-stop work.

## Acceptance criteria

- Host manager/adapter code compiles with the standalone package product at
  the exact published manifest-compatible ThorChainKit SHA and exact resulting
  MarketKit SHA recorded in `Package.swift`; the reviewed unsafe-flag
  revision is rejected.
- `AppTests` has a direct ThorChainKit product dependency and compiles the
  exact current adapter protocol surface; no invented WalletCore test target is
  required.
- Host test doubles implement internal `IThorChainKit`; Unstoppable never imports ThorChainKit testing SPI.
- Manager never starts/stops/refreshes kit.
- Adapter implements all three lifecycle methods non-empty.
- Generic AdapterManager path is sufficient.
- Native RUNE composition exposes sync/balance/deposit surfaces through the
  real `.native/.thorChain` route using the minimum MarketKit identity delta.
- Discovery, UI, import, relaunch, explorer, signer, history, swap, and custom
  node behavior remain out of scope for S1-06.
- Tests and manual live constructed-wallet gate pass.

## Recorded decisions

1. Before implementation, the anchors are refreshed on the new host integration branch because the Gimle index is stale; the architectural targets remain `packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift`, `packages/WalletCore/Sources/WalletCore/Core/Core.swift`, `AdapterFactory`, and `AdapterManager`.
2. Standalone correctness remains in `ThorChainKitTests`; host manager/adapter/factory tests run in the existing `AppTests` target through the `Development` scheme.
