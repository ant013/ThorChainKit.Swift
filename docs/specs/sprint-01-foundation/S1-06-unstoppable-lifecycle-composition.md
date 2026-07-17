# S1-06 — Unstoppable lifecycle composition

**Status:** design ready, implementation blocked pending approval.
**Risk:** high/host integration.
**Observable outcome:** a manually constructed native RUNE wallet creates one `ThorChainKit`; the adapter owns its start/stop/refresh lifecycle, and the balance reaches the existing wallet consumer without THOR-specific branches in `AdapterManager.refresh`.

## Goal

Connect the standalone kit to the current WalletCore architecture along the verified TRON vertical, while correcting split lifecycle ownership: the manager only creates/caches the wrapper, and the adapter is the sole lifecycle owner.

This spec describes future Unstoppable changes, but does not create a branch, spec, or files in that repository now.

## Scope

Included:

- dependency/product import;
- address factory boundary for mnemonic accounts;
- manager/wrapper;
- native adapter `IAdapter + IBalanceAdapter + IDepositAdapter`;
- AdapterFactory routing;
- Core construction/injection;
- Combine→Rx bridge;
- manually constructed RUNE wallet integration test.

Excluded:

- MarketKit discovery/release and the real Manage Wallets flow (S1-07);
- signer/send/history;
- custom node UI/source manager;
- private-key/watch-only accounts;
- default-enable RUNE.

## New host files

```text
packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift
packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift
packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift
Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift
Unstoppable/Tests/ThorChain/ThorChainAdapterTests.swift
Unstoppable/Tests/ThorChain/ThorChainIntegrationTests.swift
```

The current WalletCore `Package.swift` has no test target. Host tests are added to the existing `AppTests` target under `Unstoppable/Tests/ThorChain`: this folder is already connected as a filesystem-synchronized group, and the shared `Development` scheme runs `AppTests` inside `Unstoppable.app`. No new speculative `WalletCoreTests` target is created in S1-06.

## Host files to modify

- `unstoppable-wallet-ios/packages/WalletCore/Package.swift:1` — dependency/product `ThorChainKit`.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift:1` — add `thorChainAddress(account:)` and a protocol requirement with a compatibility default.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Models/AccountAddressProvider.swift:5` — mnemonic→HdWallet public key→ThorChainKit address.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift:8` — manager injection, native route.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Core.swift:98` — property/construction/wiring; verify the exact current path before editing.

`AdapterManager` must not change for the THORChain lifecycle. If implementation requires a THOR-specific refresh case, the design returns for review.

## Manager

```swift
final class ThorChainKitManager {
    private weak var _wrapper: ThorChainKitWrapper?
    private var currentAccount: Account?
    private let queue: DispatchQueue
    private let endpointConfiguration: ThorChainKit.EndpointConfiguration
    private let kitFactory: IThorChainKitFactory

    func thorChainKitWrapper(account: Account) throws -> ThorChainKitWrapper
    var thorChainKitWrapper: ThorChainKitWrapper? { get }
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

    var lastBlockHeightPublisher: AnyPublisher<Int64, Never> { get }
    var syncStatePublisher: AnyPublisher<ThorChainKit.SyncState, Never> { get }
    var accountStatePublisher: AnyPublisher<ThorChainKit.AccountState, Never> { get }

    func start()
    func stop()
    func refresh()
}

extension ThorChainKit.Kit: IThorChainKit {}

protocol IThorChainKitFactory {
    func kit(
        address: ThorChainKit.Address,
        network: ThorChainKit.Network,
        walletId: String,
        endpoints: ThorChainKit.EndpointConfiguration
    ) throws -> any IThorChainKit
}

final class ThorChainKitFactory: IThorChainKitFactory {
    // delegates to production Kit.instance; never starts the kit
}
```

`IThorChainKit` is a regular internal production abstraction in WalletCore, not a test/DEBUG API or an extension to the public ThorChainKit API. The production conformance delegates to the exact public facade without adding behavior. `AppTests` pass a spy that implements the same protocol and verify lifecycle/publisher mapping without `@_spi(Testing)`, a fixture transport, or host launch arguments.

### `_thorChainKitWrapper(account:)`

1. Return cached wrapper if `currentAccount == account`.
2. Guard `.mnemonic` and available seed; other account types throw `.unsupportedAccount`.
3. `AccountAddress.thorChainAddress(account:)` derives canonical mainnet address.
4. Resolve production `EndpointConfiguration` from an injected provider/config, not global string concatenation.
5. Call injected `kitFactory.kit(address: address, network: .mainnet, walletId: account.id, endpoints: endpoints)`; production factory delegates to `ThorChainKit.Kit.instance`.
6. Construct wrapper, cache weak wrapper + account.
7. **Do not call `thorChainKit.start()`**.

No signer in Sprint 1 wrapper. It is added by send spec, so read-only boundary cannot accidentally retain private material.

### Cache semantics

- same `Account` → same live wrapper while strongly held by adapter;
- different account → new wrapper;
- wrapper lifetime belongs to adapter; manager weak reference avoids hidden lifetime;
- no `createdRelay` unless a proven consumer needs it;
- no node-source update observer in S1 because node-source UI excluded.

## Address host boundary

```swift
extension AccountAddress {
    static func thorChainAddress(account: Account) throws -> ThorChainKit.Address
}
```

- `AccountAddress.thorChainAddress` traverses registered `IAccountAddressProvider` instances in the same way as the EVM/TRON methods;
- `IAccountAddressProvider` gains `func thorChainAddress(account:) throws -> ThorChainKit.Address?`;
- the public protocol gains a default implementation returning `nil` to avoid source-level breakage for external/custom providers;
- the concrete `AccountAddressProvider` implements the mnemonic path;
- supports only `.mnemonic`;
- obtains mnemonic seed through existing `AccountType.mnemonicSeed`;
- derives default path 931 using approved S1-03 boundary;
- creates `HDWallet(seed:coinType:931,xPrivKey:HDExtendedKeyVersion.xprv.rawValue,purpose:.bip44,curve:.secp256k1)` and takes `.publicKey(account:0,index:0,chain:.external).raw`;
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

`isMainNet` is derived from `thorChainKitWrapper.thorChainKit.network == .mainnet`. `statusInfo` and `debugInfo` contain the sanitized sync state, accepted height, chain ID, and endpoint family ID, but no endpoint credentials, mnemonic, seed, or raw internal error body.

`IBalanceAdapter` already provides defaults for `spendMode`/`caution`, and `IDepositAdapter` provides defaults for `receiveAddressStatus`/publisher. The nonexistent `name`, `syncStateObservable`, `balanceStateObservable`, and `balanceDataObservable` are not added.

No empty methods. No manager-owned parallel refresh.

### State bridge

- Kit Combine publishers bridge to Rx without duplicate subscription owners.
- `SyncState` mapping is total/exhaustive.
- cached stale data remains in `BalanceData` while `AdapterState.notSynced` carries failure.
- `runeBalance` converts to `Decimal` only at host boundary using token decimals.
- Adapter initializer receives `Wallet` or `Token` metadata if required for decimals; assert token `.native`, chain `.thorChain`, decimals `8`.
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
    guard let wrapper = try? thorChainKitManager.thorChainKitWrapper(account: wallet.account) else {
        return nil
    }
    return ThorChainAdapter(thorChainKitWrapper: wrapper, wallet: wallet)
}
```

Add exact route:

```swift
case (.native, .thorChain):
    return thorChainAdapter(wallet: wallet)
```

Other token types on `.thorChain` return nil in Sprint 1.

`try?` in the factory matches the existing host shape, but the failure must be logged through an approved sanitized logger/diagnostic path; otherwise, an unsupported account appears to be a missing adapter. If the host contract does not permit a typed factory error, a test must prove the observable diagnostic.

## Core wiring

Add:

```swift
let thorChainKitManager: ThorChainKitManager
```

Construction order:

1. endpoint configuration provider;
2. production `ThorChainKitFactory`;
3. `ThorChainKitManager`;
4. inject into `AdapterFactory`;
5. `AdapterManager` receives only factory/wallet managers, not a new special-case manager.

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

| TRON host analog | ThorChain decision |
|---|---|
| `TronKitManager` cache/wrapper/factory shape | retained |
| manager calls `tronKit.start()` | prohibited |
| `TronAdapter.start/stop/refresh` empty | exact forwarding |
| `MoneroAdapter` real `IAdapter` lifecycle | supporting positive contract for exact signatures and non-empty lifecycle |
| `AdapterManager` special-case TRON refresh | no THOR case is added |
| signer in wrapper | deferred to Sprint 2 |
| activation-aware deposit | simple deposit address |

## Tests before implementation

`ThorChainKitManagerTests`:

- same account reuses wrapper while adapter holds it;
- different account replaces wrapper;
- mnemonic no seed and unsupported type typed errors;
- factory receives exact address/network/walletId/endpoints;
- injected kit factory is the only construction seam; production factory delegates once and does not start;
- Kit remains unstarted after manager returns wrapper;
- manager/wrapper release does not leak lifecycle task.
- normal `IThorChainKit` spy proves construction/lifecycle without importing `@_spi(Testing)` or adding DEBUG branches.

`ThorChainAdapterTests`:

- adapter `start/stop/refresh` forward exactly once;
- lifecycle spy records exact call order and proves no forwarding after adapter disposal;
- exact `IAdapter`/`IBalanceAdapter`/`IDepositAdapter` surface compiles against current WalletCore protocols;
- `balanceStateUpdatedObservable` and `balanceDataUpdatedObservable` map kit Combine publishers to Rx;
- stale cached balance retained with error state;
- RUNE BigUInt→8-decimal conversion exact;
- decimals != 8 produces invariant error in test/debug, not silent wrong amount;
- receive address exact canonical string;
- no activation semantics.

`ThorChainIntegrationTests`:

- manually construct `.native/.thorChain` wallet fixture;
- `AdapterFactory.adapter` returns `ThorChainAdapter`;
- AdapterManager start causes first sync;
- wallet removal causes stop/cancellation;
- refresh uses generic `adapter.refresh()`, with no manager direct call;
- other THOR token type unsupported.

## Verification

- Build WalletCore against local package revision.
- Narrow manager/adapter/factory tests.
- Compile `AppTests` with normal `import ThorChainKit`; fail if `@_spi(Testing)` appears anywhere under Unstoppable.
- Search/diff proves no `.thorChain` special-case added to `AdapterManager.refresh`.
- Run manually constructed wallet against controlled mainnet endpoint.
- Inspect lifecycle logs/counters: exactly one active kit per account.

## Acceptance criteria

- Host code compiles with standalone package product.
- `AppTests` compiles the exact current adapter protocol surface; no invented WalletCore test target is required.
- Host test doubles implement internal `IThorChainKit`; Unstoppable never imports ThorChainKit testing SPI.
- Manager never starts/stops/refreshes kit.
- Adapter implements all three lifecycle methods non-empty.
- Generic AdapterManager path is sufficient.
- Native RUNE wallet exposes sync/balance/deposit surfaces.
- No signer, history, swap or MarketKit discovery added in this slice.
- Tests and manual live constructed-wallet gate pass.

## Recorded decisions

1. Before implementation, the anchors are refreshed on the new host integration branch because the Gimle index is stale; the architectural targets remain `Models/AccountAddress.swift`, `Core/Core.swift`, `AdapterFactory`, and `AdapterManager`.
2. Standalone correctness remains in `ThorChainKitTests`; host manager/adapter/factory tests run in the existing `AppTests` target through the `Development` scheme.
