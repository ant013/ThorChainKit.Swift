# S1-07 — Unstoppable RUNE address/balance/deposit surface

**Status:** design ready, implementation blocked pending approval.
**Risk:** high/cross-repository product path.
**Observable outcome:** RUNE is available in Manage Wallets and the restore flow; mainnet address/balance/receive work through the S1-06 adapter, and the wallet and kit are reconstructed correctly after terminate/relaunch.

## Goal

Complete the real user journey. S1-06 proves the adapter on a manually constructed wallet; S1-07 adds MarketKit metadata, the address parser/factory, and the existing discovery/storage/restart consumers.

## Hard dependency gate

The current MarketKit `3.6.12` does not contain THORChain. S1-07 cannot be considered complete through a change to the Unstoppable checkout alone.

Before the host merge, the following must exist:

1. an agreed MarketKit UID;
2. a released MarketKit version with `BlockchainType.thorChain`;
3. backend/cache blockchain record;
4. native RUNE coin/token, decimals `8`;
5. explorer URL template;
6. a WalletCore dependency bump to this release.

The recorded UID proposal is `thorchain`; the backend owner must implement this exact contract before release. It is not equal to the Cosmos chain ID `thorchain-1`, and the two are not used interchangeably.

## Scope

Included:

- MarketKit chain/token metadata contract;
- WalletCore `BlockchainType` support/order/description/block time;
- native token routing;
- `ThorChainAddressParser` and the parser chain/factory;
- balance/deposit consumers;
- create → manual enable flow;
- import/restore flow;
- persistence/relaunch reconstruction;
- explorer metadata, but not a transaction adapter/history UI.

Excluded:

- RUNE as the default wallet for a new account;
- URI/deeplink scheme;
- transaction history/explorer action;
- token denoms other than native RUNE;
- send/swap;
- stagenet UI.

## Host acceptance boundary

No `.maestro`, UI-test target, runner scripts, acceptance fixtures, DEBUG transport, test-only factory, or launch-argument branches are added to Unstoppable. Automated host verification lives only in the existing `AppTests`; the observable product path additionally passes a manual checklist in the `Development` app. Maestro is used exclusively in `ThorChainKit/iOS Example`.

## MarketKit changes

### Files

- `MarketKit.Swift/Sources/MarketKit/Classes/Models/BlockchainType.swift:1`
- `MarketKit.Swift/Sources/MarketKit/Classes/Models/Blockchain.swift:1`
- `MarketKit.Swift/Sources/MarketKit/Classes/Models/TokenType.swift:1`
- `MarketKit.Swift/Package.swift:1` — add a `MarketKitTests` target.
- `Tests/MarketKitTests/BlockchainTypeTests.swift`
- `Tests/MarketKitTests/ThorChainMetadataTests.swift`
- backend/cache fixtures/tests at the exact current paths found before implementation.

### Contract

```swift
public enum BlockchainType {
    case thorChain
}

public extension BlockchainType {
    var uid: String {
        case .thorChain: "thorchain"
    }
}
```

Native RUNE:

```text
blockchainType = .thorChain
tokenType      = .native
coin code      = RUNE
token code     = RUNE
decimals       = 8
```

The explorer template is `https://thorchain.net/tx/$ref`; the URL was confirmed against current transaction pages at the time of the spec. It flows through MarketKit metadata rather than remaining a hardcoded swap-only branch.

### MarketKit tests

- `Package.swift` contains `.testTarget(name: "MarketKitTests", dependencies: ["MarketKit"])`;
- UID encode/decode round-trip;
- backend/cache decode chain + native token;
- native `TokenQuery(.thorChain, .native)` resolution;
- decimals exact `8`;
- explorer `$ref` replacement;
- release consumer test from WalletCore.

## WalletCore metadata changes

`unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Extensions/BlockchainType.swift:8`:

- add `.thorChain` to `supported`;
- place `.thorChain` immediately after `.tron` in `supported` and `order`;
- description Sprint 1 — `RUNE`;
- add an exhaustive `blockTime` of approximately `6` seconds only after confirmation from the current protocol source; do not use it as a sync timeout;
- `supports(accountType:)`: Sprint 1 supports mnemonic only. If the current generic branch automatically allows all mnemonic chains, add explicit tests rather than a duplicate case;
- `defaultTokenQuery/nativeTokenQueries` must return `.native` automatically; a test pins this behavior.

Localizations are added only for the user-facing chain description/name, not for low-level kit errors.

## Address parser

### New file

```text
packages/WalletCore/Sources/WalletCore/Core/Address/ThorChainAddressParser.swift
```

```swift
final class ThorChainAddressParser: IAddressParserItem {
    private let network: ThorChainKit.Network

    init(network: ThorChainKit.Network = .mainnet)

    var blockchainType: BlockchainType { .thorChain }
    func handle(address: String) -> Single<Address>
    func isValid(address: String) -> Single<Bool>
}
```

Behavior:

1. `handle` performs `try ThorChainKit.Address(address, network: network)` and returns `Single.just(Address(raw: validated.raw, blockchainType: blockchainType))`.
2. A strict-decode error is returned through `Single.error` rather than hidden as `nil`.
3. `isValid` returns `Single.just((try? ThorChainKit.Address(address, network: network)) != nil)`.
4. The host `Address` is created only after strict decoding; the raw value is canonical lowercase.
5. Do not add ENS/TNS/async resolution.
6. The mainnet parser rejects `sthor`, `cthor`, and `tthor`.

### Factory/chain files

- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Factories/AddressParserFactory.swift:1` — `.thorChain → ThorChainAddressParser()`.

`AddressParserChain.swift` does not change: the factory already supplies an array of `IAddressParserItem`, and the chain calls `isValid/handle` generically.

The parser must not intercept arbitrary Bech32 addresses from other Cosmos chains: the exact HRP and a 20-byte payload are mandatory.

## Balance/deposit consumers

The S1-06 `ThorChainAdapter` already implements `IBalanceAdapter` and `IDepositAdapter`.

Verify without additional THOR branches:

- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/Wallet/WalletAdapterService.swift:28` — receives `BalanceData`;
- the wallet list shows the RUNE amount using 8-decimal metadata;
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/Wallet/Receive/Address/BaseReceiveAddressService.swift:28` receives a simple `DepositAddress`;
- copying the address returns the exact canonical `thor1…`;
- there are no activation/gasless warnings.

`unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift:84` adds `.thorChain` to the existing non-EVM adapter `statusInfo` switch. This provides a manual diagnostic surface through Settings → About → App Status without a new THOR-specific debug screen.

The exact paths are refreshed before implementation; the stale Gimle path is not used for editing.

## Create flow

`unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/CreateAccount/CreateAccountViewModel.swift:36` currently enables only BTC and ETH automatically. S1-07 preserves this behavior.

Acceptance:

1. Create a mnemonic account.
2. Open Manage Wallets.
3. RUNE/THORChain is present among searchable native assets.
4. Enable RUNE manually.
5. WalletManager publishes the wallet; AdapterFactory creates the adapter; the generic lifecycle starts.
6. The address and live balance are available.

Automatically enabling RUNE by default requires a separate product decision and spec delta.

## Import/restore flow

- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreCoins/RestoreCoinsViewModel.swift:43` receives the native tokens of all supported chains.
- The user can select RUNE.
- The single-chain path in `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Modules/RestoreAccount/RestoreHelper.swift:4` handles `.thorChain` through the generic metadata route.
- The current flow saves the account, restore marker, and wallet sequentially through three `Void` calls; this is not an atomic transaction, and the spec does not call it atomic.
- The derived address is compared with an independent fixture.

THORChain integration does not add a network call between these three saves and does not degrade the existing order. The successful path verifies the presence of the account, restore marker, and wallet after cold reconstruction. Cross-system restore crash atomicity is an existing general WalletCore risk and is not masked by THORChain tests; if implementation affects this flow beyond generic metadata routing, a separate cross-wallet recovery spec is required.

## Relaunch flow

```text
WalletStorage loads TokenQuery(.thorChain, .native)
  → MarketKit resolves released chain/token metadata
    → WalletManager publishes wallet
      → AdapterManager asks AdapterFactory
        → ThorChainKitManager reconstructs address/Kit
          → adapter.start
            → cached stale state
              → live fresh state
```

Key files:

- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Storage/WalletStorage.swift:25`
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Managers/WalletManager.swift:41`

If the MarketKit backend/cache does not know the UID after cold launch, the wallet must not be silently deleted. This is a hard failure for S1-07 acceptance.

## Explorer

- Chain metadata contains the transaction URL template.
- `unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Extensions/Blockchain.swift:11` replaces `$ref`.
- S1-07 does not add `ITransactionsAdapter`; therefore, the explorer link is verified by a model-level test and is not displayed through the transaction screen.
- History Sprint 3 activates the real transaction explorer consumer.

## Tests before implementation

### MarketKit

- UID round-trip and backend fixture;
- native RUNE query/decimals/explorer;
- cache/cold-load reconstruction.

### AppTests unit/integration

- `.thorChain` present in supported/order/description/blockTime exhaustiveness;
- account-type policy supports mnemonic and rejects unsupported types from S1-06;
- `IAddressParserItem` contract: `handle/isValid` for a valid fixture, bad checksum, wrong HRP, malformed input, mixed case, and canonical uppercase input;
- factory route only `.native/.thorChain`;
- adapter balance/deposit consumers need no special branches;
- WalletStorage round-trip preserves token query.
- App Status shows sanitized THORChain sync/height/endpoint-family fields and does not expose credentials/seed/raw error bodies.

### Real user flows

- create → search → enable → address/live balance;
- import fixed mnemonic → expected full address/live balance;
- terminate/relaunch → wallet present → same address → cached stale → live fresh;
- offline relaunch → wallet/address/cached balance retained with error state;
- remove RUNE wallet → adapter stop and no orphan task;
- reinstall/no cache → metadata fetched and RUNE discoverable.

`AppTests` verify metadata/parser/storage/factory/lifecycle through the existing dependency seams. The manual checklist verifies create/import/enable/Receive/terminate/relaunch/App Status on a public no-funds test account. The test runtime is not embedded in the Unstoppable production or Development targets.

### Mandatory manual checklist

Each run records the app commit/configuration, device or simulator + OS, timestamp, account provenance, endpoint family, observed address/height/balance, and the pass/fail result of each step. The mnemonic is not recorded.

1. **Baseline:** clean launch → create or import a public no-funds account → manually enable RUNE → open Receive → record the exact `thor1…` → wait for a fresh balance and verify App Status.
2. **Offline relaunch:** after a fresh state, terminate the process completely → disable the network through the device/simulator controls → launch without clearing app data → verify that the wallet, the same address, and the cached balance are preserved, while state is explicitly `stale/error`, not `fresh/zero`.
3. **Recovery:** restore the network → foreground/refresh → wait for a fresh state → verify that the address did not change, the error disappeared, the accepted height is valid, and the adapter was not duplicated.
4. **Remove wallet:** remove the RUNE wallet while the adapter is active → verify that the UI/Receive disappears and there are no subsequent THORChain state updates; at the same time, `AppTests` proves exactly one `stop`, cancellation, and no orphan publication through the `IThorChainKit` spy.
5. **Reinstall/no cache:** delete app data on the dedicated test device/simulator → clean install/launch → create or import the test account → verify that MarketKit metadata loads without the old cache, RUNE is available in Manage Wallets, and enabling it produces the same independent address.

Offline/reinstall steps use only external control of the test device and the production network path. They do not add a fixture transport, launch arguments, or acceptance-only source to Unstoppable.

## Telemetry/privacy

- Do not log the mnemonic/seed/private key.
- Address and balance telemetry follow the existing app policy only; do not add new events by default.
- The live test account must be created specifically for testing and must not contain user funds.
- Manual verification does not record or publish the mnemonic or private material.

## Acceptance criteria

- A released MarketKit version, backend/cache metadata, and WalletCore bump exist.
- RUNE is discoverable and opt-in, not enabled by default.
- The strict mainnet parser works through the ThorChainKit codec.
- Balance and Receive use generic consumers.
- Create/import/relaunch/offline-relaunch flows are proven.
- `AppTests` are green; the manual `Development` checklist is completed and recorded separately from the Example Maestro evidence.
- Unstoppable contains no Maestro/acceptance-only files or runtime hooks.
- The full address is stable and matches the independent fixture.
- Decimals are exactly `8`, with BigUInt conversion that does not use `Double`.
- There is no URI, history, send, swap, or non-native-token support.

## Recorded decisions

1. The MarketKit UID is `thorchain`; the explorer template is `https://thorchain.net/tx/$ref`. Backend/release must implement the exact values before the host merge.
2. Product placement is immediately after TRON; the Sprint 1 description is `RUNE`; block time is 6 seconds.
3. `AppTests` cover host package integration; the real create/import/relaunch/App Status flows undergo manual product acceptance. Maestro is limited to `ThorChainKit/iOS Example`.
