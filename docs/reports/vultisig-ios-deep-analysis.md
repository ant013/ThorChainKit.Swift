# Vultisig iOS as a ThorChainKit Reference

Analysis date: July 17, 2026
Source project: `vultisig/vultisig-ios`
Pinned commit: `d3123dbe6ef1103937c272a8b1cd81f613af0acc`
Commit: `chore(release): bump version to 1.42.67 (build 67) (#4833)`
License: Apache License 2.0

Pinned source: [GitHub tree at d3123dbe](https://github.com/vultisig/vultisig-ios/tree/d3123dbe6ef1103937c272a8b1cd81f613af0acc)

## 1. Executive summary

`vultisig-ios` is a highly valuable reference for THORChain behavior, but it is neither a ready-made Swift SDK nor a foundation that should be carried over wholesale.

The app implements nearly the entire user-facing THORChain surface:

- addresses and mainnet/chainnet/stagenet networks;
- balances for RUNE and Cosmos-denom tokens;
- native RUNE send;
- THORChain `MsgDeposit`, memo transactions, and CosmWasm execute;
- market and streaming swaps, inbound/router selection, halt checks;
- limit swaps through the advanced swap queue;
- LP, bond/unbond, TCY, RUJI, bRUNE, yRUNE/yTCY/ybRUNE, secured assets, and yield vaults;
- THORName;
- WalletCore transaction compilation and TSS-signature substitution;
- broadcast through Cosmos REST;
- local history of outgoing operations and status polling through Midgard;
- custom RPC configuration and explorer links.

The primary architectural conclusion is that THORChain is not structured here as a standalone kit. Its behavior is distributed across networking services, shared multichain models, WalletCore, MPC/TSS, SwiftData, swap orchestration, DeFi view models, and UI. Vultisig should therefore be used as:

1. a **behavior oracle** — which requests, messages, memos, and safety checks are required;
2. a **source of DTOs and pure algorithms** — after verifying the current official schemas;
3. a **set of negative lessons** — which app-specific dependencies and concurrency/error-handling decisions must not be repeated.

For Unstoppable Wallet, the most appropriate combination of references is:

- `TronKit` — the primary structural analog for synchronization, provider/storage boundaries, and the kit lifecycle;
- `EvmKit` — an analog for nonce/sequence coordination, transaction building, and the broadcast pipeline;
- `HsCryptoKit` — keys and local seed-based signing;
- `vultisig-ios` — an external THORChain protocol/product reference, but not an architectural template as a whole.

## 2. Method and analysis coverage

The audit was performed against a fixed checkout to prevent conclusions from mixing source versions. Three independent passes were conducted in parallel:

- THORChain network/API/DeFi and feature surface;
- transaction building, WalletCore, TSS/MPC, broadcast, and history;
- overall Swift architecture, concurrency, persistence, tests, and suitability for extracting a kit.

Checkout scale:

| Object | Count |
|---|---:|
| Swift files in the entire project | 1 816 |
| Total files | 2 831 |
| Swift files in `Blockchain/THORChain` | 48 |
| Lines of Swift in `Blockchain/THORChain` | 6 368 |
| THORChain function transaction files | 14 |
| Limit-swap files | 16 |
| Swift files with THOR/RUNE/TCY/RUJI relationships traced through dependencies | 352 |
| Swift test files | 337 |
| Test declarations in the entire project | 3 124 |
| THOR-related test files found by expanded search | 100 |

All 48 core THORChain files, 14 THORChain function-transaction files, and 16 limit-swap files were included in the direct audit. The rest of the project was analyzed in a dependency-driven manner: from THORChain symbols to calling services, builders, view models, persistence, and tests. This is more meaningful than literally reading every UI class that does not affect the protocol.

Serena and targeted `rg` were used for navigation. The `codebase-memory` index is unavailable for this checkout. The application source was not changed; the service directory created by Serena is not part of the product analysis.

## 3. Application architecture

### 3.1 Overall stack

The app uses:

- SwiftUI and MVVM;
- SwiftData for vaults, local history, DeFi positions, and limit orders;
- async/await for most network operations;
- `TargetType` + `HTTPClient` for HTTP;
- WalletCore/WalletCoreSwiftProtobuf for addresses and the transaction compiler;
- DKLS23/GG20/Schnorr TSS through the `Tss`, `godkls`, `goschnorr`, and `vscore` xcframeworks;
- XcodeGen: the Xcode project is generated from `project.yml`;
- local Swift package `Mediator` for MPC communication.

Key pinned dependencies in the checkout:

| Dependency | Version/state |
|---|---|
| WalletCore SPM fork | `vultisig/walletcore-spm` 4.7.1 |
| BigInt | 5.7.0 |
| CryptoSwift | 1.9.0 |
| SwiftProtobuf | 1.33.3 |
| Vultisig commondata | pinned commit `c91f…` |

Deployment targets: iOS 17 and macOS 15. The project settings target Swift 5 and Xcode 16.

Additional architectural metrics:

- 52 concrete `TargetType`;
- the HTTP client is used in 89 app files;
- 21 SwiftData `@Model` types, but no explicit `#Index`;
- 19 actor types and 196 files with `@MainActor`;
- both the new Observation (`@Observable`) and the old `ObservableObject` are used;
- four `DispatchGroup` instances, including three blocking `group.wait()` calls in THORChain mainnet/testnet services.

The repository describes a feature-first migration, but physically the app remains one large app target rather than a set of isolated Swift packages.

### 3.2 Where THORChain actually lives

```text
SwiftUI screen / ViewModel
        │
        ├── Send / FunctionTransaction / Swap / LimitSwap / DeFi
        │
        ├── shared app models: Coin, Chain, Vault, KeysignPayload
        │
        ├── ThorchainService / THORChainAPIService
        │       ├── Cosmos LCD
        │       ├── THORNode
        │       ├── Tendermint RPC
        │       ├── Midgard
        │       └── RUJI/TCY third-party endpoints
        │
        ├── THORChainHelper + WalletCore TransactionCompiler
        │       └── preimage → MPC/TSS signer → compiled transaction
        │
        └── broadcast → local SwiftData history → Midgard status polling
```

The strength is end-to-end feature coverage. The weakness is the absence of an independent domain boundary: transport, chain state, app policy, MPC, and UI are intertwined.

### 3.3 Two parallel API stacks

The project has both of the following:

1. `ThorchainService` + `ThorchainMainnetAPI` — balances, account, quote, fee, inbound, pools, token metadata, chain ID, broadcast;
2. `THORChainAPIService` + `THORChainAPI/BondsAPI/LPsAPI` — THORName, network/health/constants, bonds, and another LP flow.

Both layers use a similar `TargetType`, but have different caches, DTOs, and error semantics. This is architectural debt. They must not be carried into ThorChainKit as two parallel façades; clients should be separated by actual external systems: `ThorNodeClient`, `CosmosRESTClient`, `TendermintRPCClient`, and `MidgardClient`, with Rujira separated out.

## 4. Network, address, and asset model

### 4.1 Network type

In the Vultisig implementation, THORChain is a Cosmos-SDK/Tendermint-like account-based blockchain, not a UTXO chain like Bitcoin or an EVM account chain. In practice, this means:

- account number + monotonically increasing sequence;
- Cosmos transaction envelope;
- secp256k1 address/signature flow through WalletCore;
- Bech32 HRP;
- `MsgSend`, THORChain `MsgDeposit`, and CosmWasm execute messages;
- REST/LCD, Tendermint RPC, and separate THORNode/Midgard APIs.

### 4.2 Supported networks and HRPs

`Chain` includes:

- `.thorChain` — mainnet, HRP `thor`;
- `.thorChainChainnet` — HRP `cthor`;
- `.thorChainStagenet` — HRP `sthor`;
- `.mayaChain` — the same shared WalletCore/Cosmos branch, HRP `maya`, but a separate protocol.

The WalletCore coin type is `thorchain`; the default derivation path comes from WalletCore, coin type 931. `CoinFactory` changes the HRP for test networks, while `THORChainHelper.validateThorchainAddress` checks the corresponding prefix.

The actual canonical path is `m/44'/931'/0'/0/0`. WalletCore generates the mainnet address, while test networks change the Bech32 HRP. The chainnet validation-error text has a copy/paste error: it mentions stagenet. This is a UI defect, not an error in the address bytes.

A migration ambiguity was found: `Chain.removedChainMigrations` maps raw value `thorChainChainnet` to `.thorChain`, even though the chainnet case still exists. This behavior must not be copied when carrying over the model without checking persisted data: it could silently turn a test network into mainnet.

### 4.3 Native coin and tokens

The native asset is RUNE. Other balances are read as Cosmos bank denoms. Flow:

1. `/cosmos/bank/v1beta1/balances/{address}`;
2. native `rune` is processed as the primary coin;
3. `/cosmos/bank/v1beta1/denoms_metadata/{denom}` is requested for other denoms;
4. on failure, the general metadata list is used as a fallback;
5. followed by static metadata factory and `TokensStore` enrichment.

Yield/staking/receipt denoms such as yRUNE, yTCY, stCY, sRUJI, ybRUNE, and bRUNE are specifically recognized.

The metadata-resolution pipeline itself is useful for the kit, but the resulting `CoinMeta` is not: it is tied to the global `TokensStore` and product icon/price identifiers. A proper public kit model should store denom, symbol, display exponent, name, and provenance independently of the UI.

### 4.4 Secured, synth, and ecosystem assets

The code distinguishes:

- L1 assets and native RUNE;
- Cosmos denoms/receipt tokens;
- secured assets for SECURE+;
- synth flag in the `MsgDeposit` asset;
- Rujira/CosmWasm contracts and receipt denoms.

The static secured-asset catalog is useful only as an emergency UI fallback. It must not be treated as the protocol source of truth: the set of assets and contracts changes.

The current WalletCore protobuf `Asset` already has a trade flag, but Vultisig does not set it; `synth` is always `false`. A secured asset is identified heuristically by the presence of `-` in the contract/denom and exclusion of `x/`, rather than by a strict asset-notation parser. Consequently, new trade/synth/secured combinations are not fully covered. Official notation distinguishes synth `CHAIN/ASSET`, trade `CHAIN~ASSET`, and secured `CHAIN-ASSET`; the kit needs a canonical parser, not string heuristics: [THORChain Asset Notation](https://dev.thorchain.org/concepts/asset-notation.html).

## 5. Network layer and endpoints

### 5.1 Primary requests

`ThorchainMainnetAPI` and `ThorchainService` cover:

| Purpose | Endpoint |
|---|---|
| Balances | `/cosmos/bank/v1beta1/balances/{address}` |
| Account number/sequence | `/auth/accounts/{address}` |
| Denom metadata | `/cosmos/bank/v1beta1/denoms_metadata/{denom}` |
| Network/fee | `/thorchain/network` |
| Inbound vaults/routers/halt flags | `/thorchain/inbound_addresses` |
| Mimir | `/thorchain/mimir/key/{key}` |
| Pool | `/thorchain/pool/{asset}` |
| Pools | `/thorchain/pools` |
| Secured assets | `/thorchain/securedassets` |
| LP provider | `/thorchain/pool/{asset}/liquidity_provider/{address}` |
| Swap quote | `/thorchain/quote/swap` |
| Chain ID | Tendermint `/status` |
| Broadcast | `/cosmos/tx/v1beta1/txs` |
| THORName | Midgard `/v2/thorname/lookup/{name}` |
| Transaction action status | Midgard `/v2/actions?txid={hash}` |

The old/additional API stack adds THORName detail/reverse lookup, last block, Midgard pools/network/health/constants, bond/node/churn, and LP statistics.

### 5.2 Endpoint configuration

Default mainnet uses the Liquify gateway with different paths for THORChain API and RPC. The README still names Nine Realms, which is documentation drift.

`X-Client-ID: vultisig` is added to some requests. This is a product integration, not a protocol requirement.

The user-configured custom RPC override has a serious limitation: one URL is reused as both the LCD/THORNode host and the Tendermint RPC host. Real providers often publish them separately. In the kit, endpoints should be specified in separate typed fields.

### 5.3 Critical wrong-network risk

The custom-endpoint health probe checks for node info and sets `networkVerified = true`, but does not compare the actual chain ID with the expected one. The signing flow may then accept the chain ID returned by the server instead of strictly checking `thorchain-1`/the expected network.

This fail-open behavior is unacceptable for a wallet kit. Before balance/sign/broadcast, the provider must pass:

- exact chain-ID validation;
- expected HRP/network mapping;
- minimum height/freshness check;
- consistency between LCD and RPC endpoints;
- prohibition on automatic switching between mainnet and test networks.

### 5.4 Caching

The project uses two approaches:

- `THORChainAPICache` — actor with a 5-minute TTL;
- several `ThreadSafeDictionary` caches in `ThorchainService`.

Fee/inbound/pools/secured assets are cached for approximately 5 minutes, LP positions for 2 minutes, and chain ID effectively indefinitely.

The actor cache is a good structural reference, but signing-critical data must not use a regular UI TTL policy. Inbound/halt/Mimir must have explicit freshness and mandatory bypass/revalidation before signing.

The shared core also has a more mature `TTLCache`: actor isolation, per-key TTL, in-flight request coalescing, last-good snapshot, injectable time, and separate cancellation semantics. It is better suited to the new kit than the THOR-specific cache, but requires testing: the internal unstructured `Task` may continue the fetch after all callers are cancelled.

### 5.5 Retry and fail-soft semantics

Some pool/secured calls retry up to three times with delays, but retry all errors, including non-retryable 4xx errors. Other methods swallow the error and return `[]`, `0`, or partial results.

The future kit needs three explicit categories:

- **strict safety API** — fail closed, for signing;
- **best-effort presentation API** — may return stale/partial data with warnings;
- **typed transport/protocol errors** — do not disguise network/decode failures as business errors.

The app has no actual health-aware endpoint failover.

Another completeness risk: the fallback request for general denom metadata sets `pagination.limit=1000`, but does not handle the continuation token. If the catalog exceeds the limit, metadata discovery will silently become incomplete.

### 5.6 Privacy logging

The shared HTTP client can log URLs, headers, and small request/response bodies. Even without private keys, quote URLs reveal addresses, pairs, amounts, and affiliate data, while the broadcast body reveals transaction metadata.

By default, the kit must redact:

- addresses and transaction bodies;
- memo;
- query amounts/destinations;
- provider credentials/client identifiers.

## 6. Balances, account state, and synchronization

### 6.1 What is implemented

`BalanceService` selects `ThorchainService` through a factory and reads bank balances. Account number, sequence, and native fee are assembled by `BlockChainService.fetchSpecific` immediately before creating `BlockChainSpecific.THORChain`.

The balance/account/metadata DTOs are mostly small and suitable as references or for direct reuse after:

- conversion to immutable `Sendable` structs;
- versioned decoding;
- preservation of raw denom/base units;
- testing against current official fixtures.

### 6.2 Legacy account endpoint

Account number/sequence are read from `/auth/accounts/{address}` using a legacy response shape. The kit needs a modern Cosmos auth endpoint and a versioned fallback decoder. A stable public API must not be built around a single legacy JSON shape.

### 6.3 Sequence handling

The sequence obtained from the node is included in the payload to be signed. However, no dedicated actor/queue was found that serializes outgoing transactions for one address and reserves the sequence.

Consequently, two concurrent sends may take the same sequence, after which one will be rejected. This is one of the main gaps in Vultisig as a reference for a standalone kit.

ThorChainKit must have an `AccountSequenceManager` actor:

1. fresh account query;
2. reservation within a per-address critical section;
3. commit after an accepted CheckTx;
4. invalidate/refetch on sequence mismatch;
5. recovery after app restart.

### 6.4 Local-only history

Vultisig has no complete account-wide history synchronization. `TransactionHistoryRecorder` records only operations broadcast by the app itself: sends, swaps, and approvals. `TransactionHistoryStorage` reads SwiftData, while a poller updates status.

Therefore, after importing a vault or restoring the app, the user will not see:

- incoming transfers;
- old transactions;
- operations from another wallet/device;
- a complete chain activity feed.

ThorChainKit needs a separate remote-history sync through Midgard actions-by-address and/or Cosmos tx events, with cursor/checkpoint storage and reconciliation with locally created transactions.

## 7. Transaction building and signing

### 7.1 Complete flow

```text
Send / Function / Swap builder
        → BlockChainService.fetchSpecific
        → KeysignPayload
        → KeysignMessageFactory
        → THORChainHelper + WalletCore CosmosSigningInput
        → TransactionCompiler.preImageHashes
        → DKLS/GG20/Schnorr TSS signature
        → TransactionCompiler.compileWithSignatures
        → serialized transaction + deterministic tx hash
        → ThorchainService.broadcastTransaction
```

This is a sound separation at the conceptual level: the builder creates a semantic transaction, the compiler emits a preimage, the signer signs the hash, and the compiler assembles the bytes. However, the concrete implementation depends deeply on Vultisig MPC.

### 7.2 MsgSend

A regular native/token transfer is created as a custom WalletCore THORChain send message:

- from/to are converted to raw address bytes through `AnyAddress`;
- amount is stored as a base-units string;
- denom — native ticker or lowercased contract/denom;
- the message is packed into the Cosmos signing input.

This shape should become the golden-parity reference for ThorChainKit, but the code must not be carried over without independent deterministic vectors.

### 7.3 MsgDeposit

THORChain-native protocol actions and native RUNE swaps use `MsgDeposit`, not a bank send to the Asgard address. The asset contains:

- chain;
- symbol;
- ticker;
- synth flag;
- secured flag;
- amount and decimals;
- memo.

This is the most important difference from an EVM/Tron-like transaction builder. In the kit, `Deposit` should be a distinct domain operation, not a hidden `isDeposit` Boolean.

### 7.4 CosmWasm

RUJI, merge/unmerge, liquid staking, and yield operations use a generic Wasm execute message. The message shapes themselves are useful integration references, but contracts, the affiliate proxy, and receipt denom must be configured with network/version provenance.

### 7.5 Cosmos signing input

`THORChainHelper` sets:

- chain ID;
- public key;
- account number;
- sequence;
- sync broadcast mode;
- WalletCore signing mode;
- messages;
- gas/fee.

If dApp `SignData` is absent, fee gas is set to `20_000_000`, but in the regular path, live `native_tx_fee_rune` does not become an explicit Cosmos `Fee.amount`. It is mainly displayed/reserved by the product. This contract must be verified against golden fixtures and official node behavior; it must not be copied blindly.

WalletCore generates custom type URLs `/types.MsgSend` and `/types.MsgDeposit`; Cosmos `Fee.amount` is empty, while the high gas limit is not charged as a regular Cosmos gas fee. The native THORChain fee is charged separately by the network. This is confirmed by the official documentation, which also requires obtaining a fresh `native_tx_fee_rune` and checking `balance >= amount + fee`: [THORChain Sending Transactions](https://dev.thorchain.org/concepts/sending-transactions.html), [CLI MsgSend example](https://dev.thorchain.org/cli/overview.html).

Vultisig uses `UInt64(native_tx_fee_rune) ?? 0`; consequently, a malformed fee response turns the mandatory balance reserve into zero. For a wallet, this must be a fail-closed parse error.

### 7.6 Synchronous async bridge

`ensureTHORChainChainID()` starts an async task and blocks through `DispatchGroup.wait()`. This is an anti-pattern:

- risk of deadlock/starvation;
- unstructured cancellation;
- chain ID fetch is hidden inside a synchronous factory;
- difficult testability.

In the kit, the entire preparation path must remain async up to the signer boundary.

### 7.7 MPC/TSS

Vultisig supports DKLS, GG20, and Schnorr; selects a committee; exchanges encrypted messages through the mediator; signs preimage hashes; and passes the signatures back to the WalletCore compiler.

This layer is **not carried over** to Unstoppable Wallet: UW is a local seed-based wallet and already has its own cryptographic infrastructure. Only the interface idea is carried over:

```swift
protocol ThorChainSigner {
    func sign(digests: [Data], account: Account) async throws -> [Signature]
}
```

The concrete implementation must use HsCryptoKit/existing UW keys, not the Vultisig vault, parties, TSS sessions, and mediator.

### 7.8 Peer payload, QR, and relay

Vultisig `KeysignPayload` is a peer-visible transaction intent: coin, destination, raw amount, chain-specific account/sequence/fee, memo, swap/approve payloads, vault identifiers, and TSS library type. The SwiftProtobuf payload is compressed with LZMA and encoded in Base64.

For small payloads, the QR code contains the data directly. Large payloads are uploaded to the relay, and the QR code conveys a content ID/hash. On download, `PayloadService.getPayload(hash:)` does not recompute the SHA-256 of the received bytes or compare it with the requested content ID. The peer then independently recomputes the transaction preimages, which will often detect tampering, but the stated content-addressed boundary is still violated.

The joining device additionally verifies the vault/public key, a different local share, and the TSS library type. DKLS setup contains the exact 32-byte digest, committee IDs, keyshare ID, and derivation path; the peer rejects a message mismatch. This is a strong Vultisig MPC safeguard, but the entire QR/relay/session protocol remains outside ThorChainKit.

The top-level keysign timeout is shorter than the theoretical maximum of the internal DKLS retries, so cancellation may interrupt a late retry attempt. This orchestration is unnecessary for UW's local signer.

## 8. Broadcast, idempotency, and status

### 8.1 Broadcast

Signed JSON is sent to `/cosmos/tx/v1beta1/txs`. Response code `0` is considered success; code `19` (“already in mempool”) is also treated as success.

Useful properties:

- the deterministic hash is computed before/during compilation;
- a retry can recognize an already-known transaction;
- Vultisig stores previous keysign attempts and checks status before retrying.

Drawbacks:

- response/error values are returned too raw;
- there is no complete typed ABCI/CheckTx model;
- transport failure, rejected CheckTx, and already-known are not distinguished;
- the broadcast policy does not define the mode explicitly enough;
- blind POST retry is dangerous without a deterministic idempotency contract.

### 8.2 PendingTransactionManager

The manager considers a THOR transaction confirmed if the account sequence has become greater than the original value. This is an invalid general criterion: another transaction may have increased the sequence.

Additional issues:

- pending state primarily lives in memory;
- cleanup after approximately 10 minutes may lose a slow transaction;
- an explicit check exists for `.thorChain`, but not for chainnet/stagenet;
- the code uses `print()` instead of the adopted OSLog.

This component is classified as rejected for the kit.

### 8.3 Midgard action status

`THORChainTransactionStatusProvider` requests `/v2/actions?txid=` and maps:

- `success` → confirmed;
- `pending`/unknown → pending;
- `refund` → failed with reason/code/memo;
- empty result/404 → not found.

The incorrect part is that HTTP 429 and 5xx are mapped to terminal failed. Indexer unavailability is not an on-chain failure.

Midgard action is also not an ideal status source for a regular bank send and may lag behind source-chain acceptance. A reliable tracker should combine:

1. Cosmos tx lookup for native-transaction inclusion;
2. THORChain `/thorchain/tx/status/{hash}` for stages, planned/out tx, and refund;
3. Midgard as an indexed/history view;
4. destination-chain finality for a cross-chain swap.

## 9. Market and streaming swaps

### 9.1 Quote pipeline

The shared `SwapService`:

1. calls available providers in parallel;
2. filters providers that support an external recipient;
3. converts the amount to THORChain fixed-point 1e8 representation;
4. calls `/thorchain/quote/swap`;
5. checks expected output and recommended minimum input;
6. stores the node-provided memo, inbound address, and router;
7. compares provider results by net output.

The quote passes `from_asset`, `to_asset`, `amount`, destination, streaming fields, affiliate, and tolerance bps.

The node-returned memo is treated as authoritative and signed without independent reconstruction. This is a reasonable model for a market swap if expiry, destination, assets, amount limits, and inbound state are also verified.

These semantic fields are currently duplicated in the peer payload (`toAmountLimit`, streaming, affiliate/display values), but the signer does not compare them with the actual memo. With a corrupted or maliciously modified payload, the UI may display one limit value while signing another. In the kit, the confirmation model must parse the authoritative memo back and compare it with the quote/intent.

### 9.2 Anti-rekt

If a rapid quote reports `fees.total_bps > 100` (over 1%), the app requests a streaming quote with interval 1 and auto quantity 0, and selects it only if the expected output is better. Failure of the additional streaming quote does not invalidate the original rapid quote.

This is a useful product reference, but the 1% threshold is UX policy, not a protocol constant. In the kit, it should be configurable or remain in the app layer.

### 9.3 Quote ranking

The best net output is selected; a provider within a preference band of approximately 50 bps may win by priority, with THORChain priority 0. Because a THORChain provider is already implemented in Unstoppable Wallet for multichain swaps, the entire `SwapService` does not need to be carried over. For the internal THORChain v2 layer, the important parts are:

- typed quote DTO;
- inbound/router/memo integrity;
- streaming parameters;
- sign-time halt/inbound refresh;
- tracking/refund semantics.

### 9.4 Diagnostic error

In one cross-chain quote path, an unknown transport/decode error becomes `swapAmountTooSmall`. This misleads both the user and telemetry. The kit must preserve the root cause and model protocol quote errors separately.

### 9.5 ERC20 router path

For ERC20, exact approval is performed followed by router `depositWithExpiry`; unlimited approval is not used. This is a strong security/product reference.

`ThorchainRouterDepositBuilder` is also used for LP/SECURE+. In some routes, preliminary setup checks halt/pause, but `synthesizeRouterDeposit` itself may rely on cached inbound data. For every signing entry point, safety validation must be inside the unavoidable finalization stage, rather than depend on which screen called the builder.

There are three more specific fund-safety defects:

1. If the quote contains no inbound/router, the builder may substitute its own source address and still create a signable payload.
2. The sign-time halt check obtains a fresh inbound list, but does not verify that the vault/router in the already-created payload matches the current inbound data.
3. EVM `depositWithExpiry` receives a local `now + 15 min`, even though the quote contains its own expiry. The current official checklist requires expiry at least 60 minutes in the future and a fresh current Asgard vault: [THORChain EVM transaction checklist](https://dev.thorchain.org/concepts/sending-transactions.html).

Absence of a matching inbound must be a typed blocking error, not “not halted.” The official documentation explicitly warns against delaying inbound and requires always checking the latest Asgard address before sending: [THORChain Sending Transactions](https://dev.thorchain.org/concepts/sending-transactions.html).

## 10. Limit swaps

The limit-swap subsystem is one of the highest-quality and most testable parts of the THORChain implementation.

### 10.1 Memo

Format:

```text
=<:ASSET:DESTINATION:LIM/TTL/0:AFFILIATE:BPS
```

Implemented:

- safe LIM calculation;
- scientific compression;
- exact UTF-8 byte limits: 80 bytes for UTXO, 250 for other chains;
- if the memo does not fit, LIM is rounded **up**, but by no more than 50 bps;
- the effective rounded value is returned to the UI for WYSIWYS;
- rounding down is prohibited.

This is the best candidate for extraction into a pure, deterministic module after replacing app-specific types.

### 10.2 Safety gates

The advanced queue is enabled only when Mimir `EnableAdvSwapQueue == 1`. The raw body must be exactly `1`; errors fail the operation closed. The gate is checked both when creating the order and again before signing.

Before signing, inbound data is requested with cache bypass:

- native RUNE → `MsgDeposit`, mandatory global-pause check;
- native external gas asset → send to a fresh Asgard vault with a memo;
- ERC20 → fresh router, exact approval, `depositWithExpiry`.

This is the correct fail-closed reference.

### 10.3 Persistence

`LimitOrder` is stored in SwiftData with pending/filled/expired/cancelled statuses. `LimitOrderStorageService` requires the tx hash before writing and uses hash + vault public key as identity.

However, a local record alone is not reconciliation with the advanced swap queue. The kit needs actual order lookup, payout/refund tracking, and a clear cancel contract; the local enum must not be treated as on-chain truth.

### 10.4 Block-time constant

`THORChainConstants.blockTimeSeconds = 6` is used for expiry/payout UX and is commented as constant since network launch. This is not a safe protocol invariant. TTL in the memo should be expressed in protocol-defined units/blocks; time estimates should be calculated from recently observed blocks and marked as approximate.

## 11. THORName

Implemented:

- name → alias lookup;
- reverse address lookup;
- details;
- TNS-style destination resolution;
- create/edit referral memo.

The edit memo has the form:

```text
~:NAME:CHAIN:ADDRESS:OWNER[:PREFERRED_ASSET]
```

The `THORName`, aliases, and lookup models are compact and useful for reuse after Sendable/fixture review.

Weakness: in one path, an absent name is recognized by HTTP 500 and a substring such as `THORName doesn't exist`. This is brittle server-message parsing; a typed endpoint error or explicit not-found normalization is needed.

## 12. LP

### 12.1 Read side

There are two LP implementations:

- the old `ThorchainService.fetchLPPositions` obtains all pools, sequentially requests the provider position for each pool, adds an artificial delay, and swallows errors;
- `THORChainAPIService+LPs` obtains selected user pools, provider data, and Midgard stats.

The first approach produces N+1 requests, high latency, and silent partial state. Address-indexed discovery or bounded parallelism with an explicit partial-result model would be better for the kit.

### 12.2 Write side

Add/remove liquidity builders and memo value types are implemented:

- add: `+:POOL[:PAIRED_ADDRESS]`;
- remove: `-:POOL:BASIS_POINTS`.

The builders account for native RUNE versus the external/router path, but UI-specific default/dust policy must not enter the kit.

### 12.3 Identified correctness defects

The independent audit found two especially important defects:

1. `THORChainAPIService+LPs.getLPPositions` substitutes deposit values for redeem values;
2. `THORChainLPsInteractor.convert` divides both the RUNE amount and asset amount by the RUNE decimals, ignoring the asset decimals.

Therefore, the derived LP value/APY code is suitable only as a reference and requires new fixtures. DTOs and memo builders are substantially more reliable than the financial calculations.

## 13. Bond/unbond

The read side covers:

- bonded nodes by provider address;
- node details;
- churn history;
- network bond info;
- local reward/APY calculations.

Write memos:

```text
BOND:NODE[:PROVIDER[:OPERATOR_FEE]]
UNBOND:NODE:AMOUNT[:PROVIDER]
```

Memo builders are useful as a reference. APY/reward calculations depend on the current award, churn history, and local time, and must not become canonical kit calculations without protocol-source verification.

## 14. TCY, RUJI, bRUNE, and yield

### 14.1 TCY

Supported:

- native stake memo `tcy+`;
- unstake `tcy-:BPS`;
- staker/distribution/module/all-stakers reads;
- auto-compound through CosmWasm;
- receipt denom `x/staking-tcy`;
- APY/user-share estimates.

There is a hardcoded estimate of payout every 14,400 blocks and 6 seconds per block. This is a UI approximation, not a stable kit constant. The calculations must also guard against division by a zero total stake.

### 14.2 RUJI

RUJI reads go through the Vultisig GraphQL proxy; stake, pending revenue/APR, bond/withdraw/claim execute messages, and merge/unmerge are supported.

This is a Rujira ecosystem integration on top of THORChain, not THORChain L1 core. It should be separated into an optional `ThorChainRujira` module and not included in the minimal sync/signing kit.

### 14.3 bRUNE and yield receipts

Liquid bond/unbond and receipt denoms for bRUNE/ybRUNE/yRUNE/yTCY are supported. Yield prices obtain data from a separate hardcoded third-party endpoint. Contracts and denoms are useful as a snapshot reference, but should come from a versioned configuration/registry.

### 14.4 yVault

Mint/redeem builders use an affiliate CosmWasm proxy and Base64 inner messages. `YVaultConstants` contains a product-specific affiliate address/fee and hardcoded contracts. This must not be carried into the SDK core.

## 15. SECURE+

Implemented:

- list of secured assets;
- mapping/naming;
- mint memo `SECURE+:THOR_ADDRESS`;
- withdraw/router flow;
- static fallback catalog.

The DTOs and memo contract can be carried over after official verification. The static catalog, endpoint hosts, and router state should be runtime data.

## 16. UI and application patterns

### 16.1 Good patterns

- async/await and protocol injection in key networking services;
- `TargetType` isolates method/path/query/headers/status codes;
- separate transaction builders for bond, LP, stake, mint/redeem;
- pure limit math/memo functions;
- the node quote memo is retained as immutable signing input;
- final safety recheck in the limit-swap path;
- exact ERC20 approval;
- deterministic preimage/hash pipeline;
- typed SwiftData models for local product state;
- actor cache in the new API layer.

### 16.2 Problematic patterns

- many global/shared singletons;
- mutable `network` inside a shared service;
- duplicate mainnet/chainnet/stagenet implementations;
- two THORChain API layers;
- app-wide `Coin`, `Chain`, `Vault`, and `KeysignPayload` leak into protocol logic;
- silent `[]`, `0`, and swallowed errors;
- retry without error classification;
- `DispatchGroup.wait()` in signing preparation;
- mixed actor and lock-based caches;
- hardcoded provider/contracts/affiliate policy;
- local history presented as transaction history;
- UI/view models sometimes perform financial/protocol calculations;
- individual `print()` calls violate the project's own logging policy.

### 16.3 Chainnet/stagenet duplication

`ThorchainChainnetService` is in `ThorchainStagenetService.swift`, while `ThorchainStagenetService` is in `ThorchainStagenet2Service.swift`. This is more than a naming smell: both nearly duplicate mainnet flows, so fixes can easily diverge.

The kit should have one implementation and an immutable `ThorChainNetworkConfiguration`:

```text
chainID + addressHRP + lcdURLs + rpcURLs + thornodeURLs
+ midgardURLs + explorer + expected network markers
```

## 17. Tests and verification

### 17.1 What is well covered

The strongest areas are:

- limit math, memo fitting, compression, byte limits, and validation;
- `THORChainAssetSymbol`;
- anti-rekt streaming selection;
- swap destination and halt gates;
- custom token resolver;
- staking receipt parsing and stake interactors;
- secured mint/catalog;
- explorer URL builder;
- custom RPC host routing;
- shared swap payload builders;
- one shared WalletCore preimage fixture passing through `THORChainHelper`.

### 17.2 Significant gaps

Insufficiently covered or not covered:

- actual request/decode paths for balances/account/fee/inbound/quote;
- legacy/modern account schema compatibility;
- chainnet/stagenet service copies;
- broadcast codes 0/19, malformed response, and typed ABCI errors;
- transaction-status provider, especially refund, 429, and 5xx;
- THORName/bond/LP network clients and cache expiry;
- LP deposit/redeem/decimals correctness;
- bond reward/APY calculations;
- TCY/RUJI/bond/unbond/new LP transaction builders;
- decoded golden shapes for MsgSend, MsgDeposit, and Wasm execute;
- concurrent sequence reservation;
- multiple pending transactions and restart recovery;
- endpoint failover, cancellation, and retry classification;
- account-wide history sync;
- live official THORNode/Midgard contract fixtures.

The most dangerous test defect: the repository contains `TestData/thorchainswap.json` with the expected THORChain prehash, but `ChainHelperTests` filters resources by the `ChainHelper` prefix. There are no `ChainHelper*.json` files in the checkout. As a result, the nominal golden signing test executes **zero cases and passes green**. In addition, `ThorAddressValidationTests` only prints results and contains no `XCTAssert`.

Consequently, the presence of fixtures cannot be treated as evidence of signing parity. Before reuse, genuine golden tests are mandatory that assert:

- type URL;
- TxBody/AuthInfo/SignDoc bytes;
- account number and sequence;
- MsgSend/MsgDeposit fields;
- signature wire format;
- TxRaw bytes and uppercase SHA-256 transaction hash;
- broadcast JSON and response codes 0/19.

### 17.3 Local build verification

Direct `xcodebuild` initially did not start because `project.pbxproj` is intentionally not stored in git. After `make generate`, the project was generated correctly. Package resolution for heavyweight Git dependencies did not complete within the allotted window, so no full build/test result was obtained. This does not change the static conclusions or source traces, but runtime assurance is limited: the report does not claim that the pinned checkout currently builds cleanly in the local environment.

## 18. Security and correctness findings

| Priority | Finding | Possible consequence | Kit solution |
|---|---|---|---|
| Critical | Custom endpoint is not checked against the expected chain ID | Signing/sending on the wrong network or through a compromised provider | Strict network identity validation |
| High | No per-address sequence coordinator | Concurrent transactions use one sequence | Actor reservation/serialization |
| High | Sequence growth is treated as confirmation | False positive caused by another transaction | Lookup by exact tx hash |
| High | History is app-originated only | Incomplete wallet state after import/reinstall | Remote indexed sync + reconciliation |
| High | Signing-critical inbound/fee may be cached/fail-soft | Signing against stale vault/router/state | Fresh fail-closed finalization |
| High | LP decimals/redeem bugs | Incorrect position values | Independent fixtures and decimal types |
| High | 429/5xx → transaction failed | False terminal failure | Transport state separate from on-chain status |
| Medium | Legacy `/auth/accounts` schema | Breakage after a node/API update | Versioned modern client |
| Medium | `DispatchGroup.wait()` around async | Deadlock/starvation | Fully async preparation |
| Medium | Unknown quote error → amount too small | False diagnosis | Typed error preservation |
| Medium | Generic retry of all errors | Unnecessary load/delay, repeated business failures | Retry classification + jitter |
| Medium | HTTP financial metadata logging | Privacy leakage | Redaction by default |
| Medium | Hardcoded contracts/providers | Stale or product-coupled behavior | Signed/versioned runtime config |
| Medium | One custom URL for LCD and RPC | Incompatible provider topology | Separate endpoint roles |
| Low | Mainnet/stagenet code duplication | Diverging fixes | One generic client |

## 19. What can be used

### 19.1 Near-direct reuse after license and fixture verification

- simple balance/account/denom metadata DTOs;
- quote, fees, inbound address, and swap error DTOs;
- THORName DTO;
- broadcast/status response DTO;
- bond/node/churn DTO;
- LP provider/pool-stat DTO;
- secured-asset DTO;
- LP add/remove memo value types;
- pure limit math/memo/compression/byte-limit routines.

Even for this group, the recommendation is not to copy app namespaces, but to create immutable `Sendable` value types with explicit base units and custom decoding tests.

### 19.2 Use as a reference and rewrite

- `ThorchainMainnetAPI` as a catalog of contracts;
- `ThorchainService` flows;
- TargetType + injected HTTP client boundary;
- WalletCore preimage/compile pipeline;
- address HRP behavior;
- quote → immutable memo/inbound/router plan;
- anti-rekt streaming strategy;
- exact ERC20 approval + router deposit;
- sign-time halt/Mimir/inbound validation;
- deterministic transaction hash/idempotency;
- THORName, LP, bond, TCY, RUJI, SECURE+ memo/message builders;
- actor-cache idea for presentation data.

### 19.3 Do not carry over

- the entire `ThorchainService` singleton;
- TSS/MPC/mediator layer;
- app types `Coin`, `Vault`, `TokensStore`, `KeysignPayload`, `SwapPayload`;
- duplicate chainnet/stagenet services;
- legacy account endpoint as the only path;
- blocking `ensureTHORChainChainID`;
- sequence-based confirmation;
- local-only history as a sync engine;
- N+1 LP pool scan;
- product affiliate policy;
- hardcoded Rujira/yield contracts as protocol constants;
- fail-soft signing APIs;
- catch-all error remapping;
- 429/5xx as an on-chain failure;
- static 6-second/14,400-block assumptions as protocol truth;
- hardcoded dust `0.02 RUNE` from the UI flow.

## 20. Recommended ThorChainKit architecture

```text
ThorChainKit
├── Domain
│   ├── Network, Address, Asset, Amount
│   ├── AccountState, Balance, Transaction
│   ├── Quote, Inbound, ProtocolState
│   └── Memo / Operation
├── Networking
│   ├── CosmosRESTClient
│   ├── ThorNodeClient
│   ├── TendermintRPCClient
│   ├── MidgardClient
│   └── EndpointPool + Health/Identity checks
├── Sync
│   ├── BalanceSynchronizer
│   ├── HistorySynchronizer
│   ├── TokenMetadataResolver
│   └── Persistent checkpoints/storage adapters
├── Transactions
│   ├── AccountSequenceManager actor
│   ├── MsgSendBuilder
│   ├── MsgDepositBuilder
│   ├── WasmExecuteBuilder
│   ├── FeeEstimator
│   ├── Signer protocol
│   └── Broadcaster
├── Tracking
│   ├── CosmosInclusionTracker
│   ├── ThorChainStatusTracker
│   └── DestinationFinalityTracker
├── ProtocolActions
│   ├── MemoBuilder
│   ├── Market/Streaming/Limit
│   ├── LP
│   ├── Bond
│   └── THORName / SECURE+
└── Optional
    ├── WalletCoreAdapter
    └── Rujira/TCY/Yield modules
```

### 20.1 Network identity

`ThorChainNetwork` should contain the expected chain ID and HRP, while endpoints are separate roles. `EndpointPool` validates chain ID/height and switches providers only within the same network.

### 20.2 Sync engine

The most natural internal analog is TronKit:

- provider abstraction;
- incremental sync state;
- persistence boundary;
- public kit state/event surface;
- reorg/retry/error lifecycle.

However, account number/sequence and Cosmos messages are closer to EvmKit's nonce/builder model.

### 20.3 Transaction pipeline

Separate semantic operations are needed:

- `.send`;
- `.deposit`;
- `.wasmExecute`.

The builder emits an unsigned transaction and digests; the signer abstraction has no knowledge of the network; the compiler assembles the bytes; the broadcaster returns a typed CheckTx result. Sequence reservation belongs to the kit, not the UI.

### 20.4 Swap boundary

Because UW already has a multichain THORChain swap provider, the v1 kit does not need to carry over provider ranking or the entire quote UX. It must provide internal primitives that v2 can use:

- node quote decoding;
- signed immutable swap plan;
- fresh inbound/halt verification;
- native RUNE `MsgDeposit`;
- router path;
- full source/THOR/destination tracking.

### 20.5 Optional DeFi

LP, bond, and THORName can be added after core send/sync. TCY/RUJI/yVault are better delivered as separate modules so hardcoded ecosystem changes do not increase risk to the L1 wallet core.

## 21. Proposed implementation order

1. **Foundation:** network configuration, addresses, asset/amount value types, endpoint identity validation.
2. **Read sync:** balances, metadata, account number/sequence, persistent sync state.
3. **Native send:** MsgSend golden vectors, local signer adapter, typed broadcast.
4. **Tracking/history:** exact tx lookup, Midgard remote history, restart reconciliation.
5. **THOR actions:** MsgDeposit, memo builders, fresh Mimir/inbound/halt state.
6. **Internal swap v2 primitives:** quote, streaming/limit, router and multi-stage tracking.
7. **Optional DeFi:** LP, bond, THORName, SECURE+.
8. **Ecosystem extensions:** TCY/RUJI/yield as separately versioned modules.

Each phase must have golden byte vectors, recorded HTTP fixtures, error fixtures, and at least one integration test against a controlled endpoint/test network.

## 22. Readiness criteria relative to Vultisig

ThorChainKit will be functionally no worse than Vultisig on the core wallet path if it:

- generates the same addresses and validates HRP/chain ID;
- synchronizes all bank balances and metadata;
- restores complete history, not only local sends;
- safely coordinates the account sequence;
- builds byte-identical/officially accepted MsgSend and MsgDeposit;
- signs through UW keys without MPC coupling;
- distinguishes transport, CheckTx, inclusion, THOR action, and destination finality;
- survives restart and provider failure;
- revalidates Mimir/inbound/halt immediately before signing;
- does not log sensitive financial metadata;
- permits mainnet/stagenet/chainnet only through strict immutable configurations.

## 23. License and legal reuse boundary

The repository is licensed under Apache-2.0. Direct reuse of source code is possible subject to the following conditions:

- include the license text;
- preserve applicable copyright/attribution notices;
- explicitly mark modified files;
- do not treat the license as permission to use trademarks.

No separate `NOTICE` was found in the checkout. The licenses for the WalletCore fork, `VultisigCommonData`, and binary TSS frameworks must be checked separately. In practice, it is safer to carry over small pure algorithms/DTOs with provenance and rewrite large app-bound services from the contract.

## 24. Map of key source files

### Core network/signing

- `Blockchain/THORChain/Service/ThorchainService.swift` — primary façade, balances/tokens/quotes/fees/inbound/pools/account/chain ID.
- `Blockchain/THORChain/Service/ThorchainMainnetAPI.swift` — mainnet REST/RPC/Midgard contracts.
- `Blockchain/THORChain/API/THORChainAPIService.swift` — second API façade.
- `Blockchain/THORChain/API/TargetType/*` — THORName/network/bond/LP endpoints.
- `Blockchain/THORChain/Service/ThorchainStagenetAPI.swift` — test-network endpoints.
- `Blockchain/THORChain/Service/ThorchainStagenetService.swift` — chainnet service.
- `Blockchain/THORChain/Service/ThorchainStagenet2Service.swift` — stagenet service.
- `Blockchain/THORChain/Signing/thorchain.swift` — MsgSend/MsgDeposit/Wasm signing.
- `Blockchain/THORChain/Signing/THORChainSwaps.swift` — chain-dispatching swap signing.
- `Blockchain/THORChain/Service/ThorchainBroadcastTransactionService.swift` — broadcast.
- `Blockchain/THORChain/ThorchainRouterDepositBuilder.swift` — router/SECURE+ synthesis.

### Swap/limit

- `Blockchain/Swaps/Common/SwapService.swift` — provider orchestration, quotes, ranking, anti-rekt.
- `Blockchain/Swaps/Common/SwapHaltGate.swift` — halt/inbound gate.
- `Features/Swap/Logic/SwapPayloadBuilder.swift` — THOR payload creation.
- `Features/Keysign/Services/Swap/THORChainSwapPayload.swift` — app payload model.
- `Features/LimitSwap/Logic/LimitMath.swift` — limit calculations.
- `Features/LimitSwap/Logic/LimitSwapMemoBuilder.swift` — memo/compression/byte fitting.
- `Features/LimitSwap/Logic/LimitSwapPayloadAssembler.swift` — sign-time assembly.
- `Features/LimitSwap/Services/ThorchainService+LimitSwapQuote.swift` — Mimir/price quote.
- `Features/LimitSwap/Models/LimitOrder.swift` — SwiftData order.

### Account/history

- `Core/Services/BlockChainService.swift` — account/sequence/fee assembly.
- `Core/Services/PendingTransactionManager.swift` — sequence-based pending check.
- `Core/Services/TransactionStatus/Providers/THORChainTransactionStatusProvider.swift` — Midgard status.
- `Core/Services/TransactionHistoryRecorder.swift` — local recording.
- `Features/TransactionHistory/*` — UI/persistence/history polling.

### DeFi

- `Blockchain/THORChain/API/THORChainAPIService+LPs.swift` — LP reads.
- `Blockchain/THORChain/API/THORChainAPIService+Bonds.swift` — bond reads.
- `Features/Defi/DefiChain/Interactor/LPs/THORChainLPsInteractor.swift` — LP conversion.
- `Features/Defi/DefiChain/Interactor/Bond/THORChainBondInteractor.swift` — bond metrics.
- `Blockchain/THORChain/Service/Staking/THORChainStakingService.swift` — TCY/RUJI read APIs.
- `Blockchain/THORChain/Service/ThorchainService+TCYStake.swift` — stake/receipt operations.
- `Features/FunctionTransaction/TransactionBuilder/*` — LP/bond/stake/mint/redeem builders.

## 25. Final assessment

| Area | Maturity in Vultisig | Value as a reference | Readiness for direct reuse |
|---|---|---|---|
| Address/network model | High | High | Medium |
| Balance/token reads | Medium-high | High | DTO — high, service — low |
| MsgSend/MsgDeposit signing | High for an MPC app | Very high | Low |
| Broadcast | Medium | High | Low-medium |
| Market/streaming swap | High | High | Low for UW; provider already exists |
| Limit swap | High | Very high | Pure logic — high |
| History/sync | Low as wallet sync | High as a negative reference | Low |
| Transaction tracking | Medium | Medium | Low |
| LP/bond | Broad, but with correctness issues | High | Low-medium |
| TCY/RUJI/yield | Broad, product-coupled | Medium-high | Low |
| Tests | Strong pure-feature tests, weak transport/signing edges | High | Not applicable |

Conclusion: Vultisig provides the most complete Swift/iOS reference found for the user-facing THORChain surface, especially for `MsgDeposit`, node-authoritative swap memos, limit swaps, and DeFi. However, the architecture of the future ThorChainKit should be built using Unstoppable Wallet's internal kit patterns, taking verifiable protocol contracts and pure algorithms from Vultisig rather than its app service graph.

## 26. Detailed catalog of THORChain classes/files

Legend: **D** — near-direct reuse after Sendable/fixture/license review; **R** — reference requiring redesign; **X** — do not carry into the kit.

### 26.1 `Blockchain/THORChain/API`

| File/type | Role | Decision |
|---|---|---|
| `Models/Bonds/BondMetrics.swift` | Derived bond/reward metrics | R |
| `Models/Bonds/BondedNodes.swift` | Bond provider/node DTO | D |
| `Models/Bonds/BondedNodesResponse.swift` | API envelope | D |
| `Models/Bonds/ChurnEntry.swift` | Churn history DTO | D |
| `Models/Bonds/NodeDetailsResponse.swift` | Node details DTO | D |
| `Models/LPs/THORChainLPPosition.swift` | App-derived LP position | R |
| `Models/LPs/THORChainLiquidityProviderResponse.swift` | LP provider API DTO | D |
| `Models/LPs/THORChainPoolStats.swift` | Midgard pool stats DTO | D |
| `Models/LastBlockResponse.swift` | Last block DTO | D |
| `Models/THORChainAPIError.swift` | API error envelope | D/R |
| `Models/THORChainHealth.swift` | Midgard health DTO | D |
| `Models/THORChainNetworkInfo.swift` | Network info DTO | D |
| `Models/THORName.swift` | THORName/details/alias values | D |
| `Models/THORNameLookup.swift` | Lookup/reverse DTO | D |
| `NetworkBondInfo.swift` | Derived network bond view | R |
| `THORChainAPICache.swift` | Typed actor TTL cache | R |
| `THORChainAPIService.swift` | Second DeFi/network façade | X as whole |
| `THORChainAPIService+Bonds.swift` | Bond fetch/calculations | R |
| `THORChainAPIService+LPs.swift` | LP fetch/calculations; contains redeem defect | R/X calculations |
| `TargetType/THORChainAPI.swift` | THORName/network/health/constants endpoints | R |
| `TargetType/THORChainBondsAPI.swift` | Bonds/node/churn endpoints | R |
| `TargetType/THORChainLPsAPI.swift` | LP/Pool endpoints | R |

### 26.2 `Blockchain/THORChain/Service`

| File/type | Role | Decision |
|---|---|---|
| `InboundAddress.swift` | Inbound/router/halt/gas/dust DTO | D |
| `MayaChainAPI.swift` | MAYA endpoint definitions | R, outside ThorChain core |
| `MayaChainService.swift` | MAYA service | X for ThorChainKit |
| `NetworkInfo.swift` | Native fee/network response | D |
| `SecuredAssetCatalog.swift` | Secured DTO + static fallback | DTO D, catalog X |
| `Staking/THORChainStakingService.swift` | TCY/RUJI read service | R optional module |
| `Staking/TargetType/THORChainStakingAPI.swift` | Staking/proxy endpoints | R optional module |
| `THORChainNetworkStatus.swift` | RPC status/chain ID DTO | D |
| `THORChainTokenMetadata.swift` | Token metadata value | D |
| `THORChainTokenMetadataFactory.swift` | Curated/product fallback | R |
| `ThorchainBroadcastTransactionService.swift` | Cosmos REST broadcast | R |
| `ThorchainCustomTokenResolver.swift` | Denom normalization → app CoinMeta | R |
| `ThorchainMainnetAPI.swift` | Mainnet endpoint catalog | R |
| `ThorchainService.swift` | Main wallet/swap/network façade | X as whole |
| `ThorchainService+TCYStake.swift` | TCY/RUJI/receipt reads | R optional module |
| `ThorchainService+Yield+Prices.swift` | Third-party yield pricing | X for core |
| `ThorchainServiceFactory.swift` | Shared service switch/fatalError | X |
| `ThorchainStagenetAPI.swift` | Chainnet/stagenet endpoint catalog | R |
| `ThorchainStagenetService.swift` | Chainnet duplicated service | X |
| `ThorchainStagenet2Service.swift` | Stagenet duplicated service | X |
| `ThorchainSwapError.swift` | Quote error DTO | D |
| `ThorchainSwapProvider.swift` | App provider adapter | R |

### 26.3 Signing and constants

| File/type | Role | Decision |
|---|---|---|
| `Signing/thorchain.swift` / `THORChainHelper` | Address validation, MsgSend/MsgDeposit/Wasm, WalletCore compile | R; optional adapter |
| `Signing/THORChainSwaps.swift` | Multichain signing dispatcher | X as whole |
| `THORChainConstants.swift` | Approximate block time/chain constants | R, not protocol truth |
| `ThorchainRouterDepositBuilder.swift` | Router/LP/SECURE+ synthesis | R after fresh preflight redesign |

### 26.4 THORChain function-transaction UI

These 14 files implement seven `Screen + ViewModel` pairs: Add LP, Bond, Mint, Redeem, Remove LP, Unbond, and Withdraw Rewards. They are useful for UX flow and field requirements, but belong to the SwiftUI/application layer and are classified entirely as **X** for the kit. Domain memo/message builders are located separately under `Features/FunctionTransaction/TransactionBuilder` and are classified as **R/D** in the tables above.

### 26.5 Limit-swap subsystem

| File/type | Role | Decision |
|---|---|---|
| `Interactor/LimitSwapInteractor.swift` | App orchestration | R |
| `Logic/LimitMath.swift` | Pure price/LIM math | D |
| `Logic/LimitSwapMemoBuilder.swift` | Memo, compression, byte fitting | D |
| `Logic/LimitSwapPayloadAssembler.swift` | Sign-time routing/preflight | R |
| `Logic/LimitSwapValidation.swift` | Pure validation | D/R |
| `Logic/THORChainAssetSymbol.swift` | Canonical-ish asset rendering | D after trade/synth review |
| `Models/LimitOrder.swift` | SwiftData local order | X for kit model |
| `Models/LimitSwapDraft.swift` | Form/application draft | R |
| `Models/LimitSwapErrors.swift` | Feature error taxonomy | R |
| `Models/LimitSwapInputs.swift` | Typed builder inputs | R |
| `Services/LimitOrderStorageService.swift` | SwiftData persistence | X; keep protocol idea |
| `Services/LimitSwapQuoteServiceProtocol.swift` | Test seam | D/R |
| `Services/ThorchainService+LimitSwapQuote.swift` | Price/Mimir adapter | R |
| `ViewModel/LimitSwapFormViewModel.swift` | SwiftUI state | X |
| `Views/LimitSwapBodyView.swift` | SwiftUI | X |
| `Views/LimitSwapEntryView.swift` | SwiftUI | X |

### 26.6 Critical cross-cutting classes outside the THORChain folder

| Type | Role | Decision |
|---|---|---|
| `BlockChainService` | Account/sequence/fee snapshot for all chains | Snapshot idea R; singleton X |
| `BlockChainSpecific.THORChain` | Prepared signing values | R; replace with a dedicated Thor type |
| `KeysignPayload` | App/TSS transaction intent | X |
| `KeysignMessageFactory` | Hash/preimage orchestration | R |
| `KeysignViewModel` | MPC, retries, broadcast, UI state | X for kit |
| `CosmosSignDataBuilder` | Amino/direct dApp signing | R; requires semantic allowlist |
| `CosmosSerializedParser` | Extract tx bytes/hash | D/R |
| `PendingTransactionManager` | In-memory sequence polling | X |
| `TransactionHistoryRecorder/Storage` | Local outgoing history | X as sync engine |
| `THORChainTransactionStatusProvider` | Midgard action mapping | R after new state machine |
| `ExplorerLinkBuilder` | Runescan URLs | R/D small extraction |
| `SwapService` | Provider fan-out/ranking/anti-rekt | R; host product layer |
| `SwapHaltGate` | Halt/pause interpretation | R; missing inbound must block |
| `SwapPayloadBuilder` | Quote → peer payload | R; remove fallbacks |
| `THORChainSwapPayload` | App/TSS serialized swap | X as public kit type |
| `THORChainLPsInteractor` | LP UI conversion | X calculations until fixed |
| `THORChainBondInteractor` | Bond data aggregation | R |
| `THORChainStakeInteractor` | TCY/RUJI/receipt aggregation | R optional module |
| `TTLCache` | Actor cache/coalescing | R/D after cancellation tests |
| `ThreadSafeDictionary` | Lock/queue cache state | X |
| `HTTPClient` | Generic app transport | R interface; implementation X for wallet privacy |
| `RPCEndpointResolving` | Endpoint injection seam | D/R |
| `PayloadService` | MPC relay upload/download | X; hash verification defect |
| `ProtoSerializer` | LZMA/Base64 peer serialization | X for kit |

This catalog covers every file in the dedicated THORChain directory and the entire dedicated limit/THOR function UI surface; for the 352 cross-referenced files, the report lists the classes that actually affect the protocol, funds, persistence, or integration boundary.
