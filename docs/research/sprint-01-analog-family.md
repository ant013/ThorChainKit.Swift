# Sprint 1 — verified analog family

## Conclusion

The primary spine is TronKit and its vertical in Unstoppable Wallet. EvmKit is used only as a supporting source for provider injection and account/nonce sync. Vultisig provides THOR-specific API/HRP/fixture knowledge and strong counterexamples. HdWalletKit, HsCryptoKit, and BitcoinCore provide primitives, but do not define the lifecycle.

No analog is copied wholesale: the most dangerous inherited properties are incomplete cancellation, broad failover, split lifecycle ownership, and weak test coverage.

## Matrix

| Slice | Primary | Supporting | Rejected counterexample | ThorChainKit delta |
|---|---|---|---|---|
| S1-01 | TronKit `Package.swift` + `Kit` + `iOS Example` | UW consumers; EvmKit Example workspace | EvmKit without automated testTarget | preserve facade/local-package demo; add DI, XCTest, and Maestro from the first commit |
| S1-02 | Tron `Network`/`RpcSource` shape | Vultisig LCD/RPC/HRP environments | Evm broad failover, mutable `currentRpcId` | actor pool, atomic identity, typed role/freshness/cancellation |
| S1-03 | HdWalletKit + HsCrypto primitives | BitcoinCore generic Bech32 | Vultisig MPC/TSS helper and duplicate validators | coin type 931, Cosmos HASH160, THOR HRP, no key retention |
| S1-04 | Tron narrow async provider protocols | Vultisig THOR endpoints/envelopes | `try?`, zero coercion, ignored pagination | immutable DTO, cursor pagination, strict typed errors |
| S1-05 | Tron Kit→Syncer→storage→publisher spine | Evm concurrent balance/nonce | untracked tasks and incomplete stop | one actor, generation token, atomic snapshot, explicit stale |
| S1-06 | UW TRON manager/wrapper/adapter/factory | generic `AdapterManager` lifecycle | manager-owned start + empty adapter lifecycle | adapter alone owns start/stop/refresh; no special case |
| S1-07 | Tron parser/factory/balance/deposit | UW enable/restore/restart consumers | missing MarketKit chain + BTC/ETH-only defaults | released metadata is a hard gate; RUNE remains opt-in |

## Primary local anchors

### TronKit

- `TronKit.Swift@aa691bcd:Sources/TronKit/Core/Kit.swift:49` — public state/publishers and lifecycle.
- `TronKit.Swift@aa691bcd:Sources/TronKit/Core/Kit.swift:245` — composition factory.
- `TronKit.Swift@aa691bcd:Sources/TronKit/Core/Syncer.swift:25` — primary lifecycle spine.
- `TronKit.Swift@aa691bcd:Sources/TronKit/Core/AccountInfoManager.swift:17` — cached balance/account state.
- `TronKit.Swift@aa691bcd:Sources/TronKit/Network/INodeApiProvider.swift:3` — narrow async contract.

### EvmKit

- `EvmKit.Swift@be028631:Sources/EvmKit/Api/Core/ApiProtocols.swift:4` — public provider seam.
- `EvmKit.Swift@be028631:Sources/EvmKit/Api/Core/RpcBlockchain.swift:99` — concurrent balance/nonce supporting pattern.
- `EvmKit.Swift@be028631:Sources/EvmKit/Api/Core/NodeApiProvider.swift:26` — rejected broad rotation.

### Runnable Example apps

- `TronKit.Swift@aa691bcd:iOS Example` — primary manual/live app skeleton; the shared scheme contains no testables.
- `EvmKit.Swift@be028631:iOS Example` — supporting workspace/package linkage and native send example; the shared scheme also contains no testables.
- [`Example/UI acceptance analysis`](kit-example-apps-and-ui-acceptance.md) — exact targets, risks, and ThorChainKit flow matrix.

### Unstoppable Wallet

- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:58` — primary host composition.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:74` — generic lifecycle consumer.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Factories/AdapterFactory.swift:170` — routing.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Address/TronAddressParser.swift:5` — parser vertical.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Modules/ManageWallets/ManageWalletsViewModel.swift:44` — actual opt-in consumer.

### Crypto/address

- `HdWalletKit.Swift@1bc214b2:Sources/HdWalletKit/HDWallet.swift:10` — BIP44/path derivation.
- `HsCryptoKit.Swift:Sources/HsCryptoKit/Crypto.swift:90` — compressed secp256k1 public key.
- `BitcoinCore.Swift:Sources/BitcoinCore/Classes/SegWit/Bech32.swift:1` — generic checksum reference.

## Authoritative protocol anchors

- THORChain officially separates Midgard, THORNode, Cosmos REST, Tendermint/CometBFT RPC, and gRPC; stagenet URLs are not currently considered stable: [Connecting to THORChain](https://dev.thorchain.org/concepts/connecting-to-thorchain.html).
- Default HD path `m/44'/931'/0'/0/0` and 1e8 RUNE units are specified in the official transaction guide: [Sending Transactions](https://dev.thorchain.org/concepts/sending-transactions.html).
- Cosmos secp256k1 account address: compressed 33-byte public key → SHA-256 → RIPEMD-160 → Bech32; the validator must check the checksum, HRP, and 20-byte payload: [Cosmos Address Encoding](https://docs.cosmos.network/sdk/latest/guides/reference/bech32).
- The current THORNode source recognizes `thor`, `tthor`, `sthor`, `cthor`: [current `common/address.go`](https://gitlab.com/thorchain/thornode/-/raw/develop/common/address.go).
- Mainnet node configuration uses chain ID `thorchain-1`: [THORNode Docker documentation](https://gitlab.com/thorchain/thornode/-/tree/develop/build/docker).
- Coin type `931` is registered for THORChain/RUNE: [SLIP-0044 registry](https://github.com/satoshilabs/slips/blob/master/slip-0044.md).

## Why not use TronKit literally

- `RpcSource.urls` does not translate into an actual multi-provider policy.
- `Syncer` does not create every task as an owned task; `stop()` does not guarantee their cancellation.
- `SyncTimer.stop()` destroys subscriptions, and restart does not obviously restore them.
- some errors and token data are lost through `try?`.
- tests do not cover the provider, account sync, or lifecycle.

## Why not use EvmKit literally

- The EVM family manager/decorator architecture is excessive for a single native account chain.
- `NodeApiProvider` changes the endpoint on almost any error and does not know chain identity.
- The mutable RPC ID is not actor-isolated.
- The package contains no testTarget.
- A runnable `iOS Example` exists, but provides no automated correctness evidence and contains hardcoded demo secrets/legacy lifecycle patterns that will not be copied.

## Why Vultisig is supporting only

- THORChain code is embedded in the app target and mixes reads, swap, staking, yield, TNS, broadcast, and MPC/TSS.
- address derivation is hidden behind WalletCore/TSS instead of being implemented with transparent Swift primitives.
- network/HRP/chain ID policy is distributed across several services.
- endpoints, DTO fixtures, denom rules, and failure cases are useful; global singletons, SwiftData app models, and the signing/MPC boundary are unsuitable.
