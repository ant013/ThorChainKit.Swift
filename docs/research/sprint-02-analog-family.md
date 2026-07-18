# Sprint 2 — Verified Analog Family

## Purpose and Method

This report records the analog family used to design native RUNE send. Gimle/Palace supplied semantic candidates; every load-bearing claim was then checked in the pinned current tree with Serena and targeted `rg`/Git inspection. A semantic match is discovery evidence, not authority.

The design intentionally combines three roles:

- Unstoppable, EvmKit, and TronKit define local ownership, naming, composition, lifecycle, and public API style;
- THORNode and Cosmos SDK define wire and consensus semantics;
- Vultisig supplies THOR-specific end-to-end examples and independent vectors, while its MPC/TSS architecture is rejected.

## Pinned Trees

| Source | Revision | Role |
|---|---|---|
| Unstoppable Wallet iOS | `8a63bfda028dd8543115b26dd777235a53304311` | host handler, adapter, wrapper, and factory conventions |
| TronKit.Swift | `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` | Example composition, pending state, tests, counterexamples |
| EvmKit.Swift | `be0286317c202084784c5a695928cdc985c4ff7b` | local transaction construction and send facade |
| BitcoinCore.Swift | `5b49f424f495904cf06519b1a7b861ef37b45b50` | persist/publish-before-send and stored-pending retry lifecycle |
| HsCryptoKit.Swift | `7c11ad0e690cbb178a70f3b9d1116d0a37a51a41` | compact normalized secp256k1 signing |
| Vultisig iOS | `d3123dbe6ef1103937c272a8b1cd81f613af0acc` | THOR signing/broadcast reference and vector |
| THORNode | `a759cb4f99b1a13d5d94ace1dddcaf25c165641f` | authoritative MsgSend, halt, module fee, TxConfig, and native-send CLI semantics |
| THORNode current module-policy tags | `v3.19.0@5f2141c3`, `v3.19.1@59a3e925`, `v3.19.2@c6fa8caa`, `v3.19.3@52e66ad9` | exact source-identical `IsModuleAccAddress`/module-name manifest for live version gating |

## Selection Matrix

| Slice | Primary analog | Supporting evidence | Rejected counterexample | Adopted delta |
|---|---|---|---|---|
| S2-01 | current UW `EvmSendHandler`/`TronSendHandler` review→send split | `SendData`, `SendHandlerFactory` | EvmKit public seed/private-key signer | quote moves into the standalone kit, remains opaque, and stores only checked-Sendable snapshots |
| S2-02 | Vultisig THOR preflight spine | THORNode `handler_send.go`/keeper Mimir semantics, Vultisig fixture | EvmKit maximum nonce across providers | one endpoint family with coherent monotonic H0/H1/H2 snapshots; every provider operation has an owned deadline/token race |
| S2-03 | Vultisig `THORChainHelper` signing spine | THORNode proto/TxConfig/official CLI, independent fixture | Vultisig `20_000_000` default gas | local Swift protobuf encoding with pinned official `3_000_000` gas provenance and complete deterministic signed vector |
| S2-04 | UW host owns signing capability | HsCryptoKit compact signing, THOR vector | concrete EvmKit signer owning a private key | ephemeral async signer; kit verifies key/address/signature; actor serialization and non-cooperative-operation liveness |
| S2-05 | BitcoinCore created/pending/send retry lifecycle | EvmKit local bytes/hash, Tron pending manager/tests, Vultisig CheckTx envelope, Cosmos SDK BroadcastTx/GetTx schemas, GRDB observation contract | remote build, post-success-only pending, unscoped code 19, permissive duplicate-key JSON, independent writers, and reread-without-resubscribe recovery | physical database identity/one writer; atomic active-generation journal plus every-generation publication barrier; observation replacement; strict bounded broadcast/lookup envelopes; hash-first sdk-codespace classification; version-tokened repair and exact retry |
| S2-06 | TronKit iOS Example structure | `SendController`, adapter/project/workspace | plaintext mnemonic/UserDefaults and empty Testables | fixture-first runtime, stable accessibility IDs, guarded Maestro only in Example |
| S2-07 | current UW `TronSendHandler`/factory/wrapper | AccountManager authorization, ISendHandler/RegularSendView/SlideButton/PreSendView seams | Vultisig ownership, Tron rounding/optional signer, all-account lookup, and Void-success `sent` banner | canonical Sendable review snapshots; per-client live-handle owner; ephemeral active-account signer; full changed-surface `Debug-Dev` concurrency gate; outcome-gated CheckTx UX |

## Exact Current-Tree Anchors

### Unstoppable Wallet

- `packages/WalletCore/Sources/WalletCore/Core/Protocols.swift` — adapter protocol boundary.
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/TronSendHandler.swift` — current pre-send/review/send lifecycle analog.
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendHandlerFactory.swift` — ordered handler registration.
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendData.swift` — review-data enum contract.
- `packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift` — wrapper lifetime and dependency ownership.

The older root-level `Unstoppable/Core/...` paths are stale for send implementation and must not be used.

### Kits

- `BitcoinCore.Swift/Sources/BitcoinCore/Classes/Transactions/TransactionCreator.swift`, `PendingTransactionProcessor.swift`, and `Classes/Network/TransactionSender.swift` — the transaction is processed/stored and pending listeners are notified before send; the sender later reloads stored pending transactions. This is the S2-05 lifecycle primary, while its UTXO/P2P semantics are not copied.
- `EvmKit.Swift/Sources/EvmKit/Core/TransactionBuilder.swift` — transaction bytes/hash are local values before RPC.
- `EvmKit.Swift/Sources/EvmKit/Core/Signer/Signer.swift` — useful private-key ownership counterexample.
- `TronKit.Swift/Sources/TronKit/Core/TransactionManager.swift` and `Tests/TronKitTests/TransactionManagerPendingTests.swift` — pending lifecycle/tests.
- `TronKit.Swift/iOS Example/Sources/Core/Manager.swift` and `Controllers/SendController.swift` — runnable Example shape.

### THOR-specific sources

- `thornode/proto/thorchain/v1/types/msg_send.proto` — exact `/types.MsgSend` fields.
- `thornode/x/thorchain/handler_send.go` — native-send validation and module-address behavior.
- `thornode/docs/cli/multisig.md:27-56` — official native RUNE example with denom `rune`, empty fee coins, and gas `3_000_000`; blob `537cac65592828fb0f10dbf2d75edf51eaa4be67`, file SHA-256 `27e39d943dee5744df87d87ef29828c8b34f51ae8bb4a7504fe4c98716d2649c`.
- Cosmos SDK `v0.53.0` `proto/cosmos/tx/v1beta1/service.proto` and `x/auth/tx/service.go` — exact `BroadcastTx` POST, `GetTx` GET, `BroadcastTxResponse.tx_response`, and NotFound source semantics; Foundation's permissive duplicate-key behavior is an explicit client-parser counterexample.
- `vultisig-ios/.../Blockchain/THORChain/Signing/thorchain.swift` — pre-sign and signed transaction flow.
- `vultisig-ios/.../ThorchainBroadcastTransactionService.swift` — Cosmos broadcast response handling.
- `vultisig-ios/.../VultisigAppTests/TestData/thorchain.json` — independent native RUNE vector.

## Material Deltas

### Kept from Unstoppable style

- handler/factory registration and review-data separation;
- wrapper/adapter ownership outside the kit;
- host-specific private-key derivation/signing stays in WalletCore;
- errors cross the adapter boundary as typed values with host-owned localization.

### Kept from kit style

- a small public `Kit` facade;
- local construction before transport;
- storage-backed pending state and publishers;
- runnable package-owned iOS Example.

### Added because no analog is sufficient

- height-coherent native fee/halt/recipient-policy preflight with per-route REST-header, Comet-ABCI, or authoritative-body proof; the broken bulk ModuleAccounts route is replaced by exact-height recipient Account classification plus a versioned THORNode source-derived forbidden-module set; query-only REST is rejected;
- explicit Max intent resolved from spendable RUNE and current fee;
- opaque one-use quote with sign-time revalidation;
- external asynchronous signer and in-kit signature verification;
- durable pre-broadcast signed-byte journal, following BitcoinCore's persist/publish-before-send lifecycle but retaining exact Cosmos bytes/generations;
- process-wide runtime keyed by physical database identity with one shared GRDB writer across namespace children, one file-migration owner, child-owned namespace recovery, per-Kit lifecycle generation, lifecycle-first operation admission, atomic initial active generation, client/operation/repair activity holds, live inactive-work repair, durable sequence reservation, monotonic CAS transitions, and generation-scoped observation replacement;
- publication acknowledgement for every exact initial/retry pending generation before endpoint I/O;
- replaceable repair-intent token so an older reentrant pass cannot clear newer failed work;
- cancellation/deadline races around every signer, H0/H1/H2, retry and broadcast operation, with a token check before any subsequent endpoint call;
- codespace-aware CheckTx classification; only matching `sdk/19` is duplicate acceptance;
- exact bounded Cosmos REST broadcast request/response manifest through one duplicate-key-rejecting UTF-8 JSON decoder; every status/media/schema/type/bounds deviation remains unknown and cannot release a reservation;
- one family-pinned Cosmos REST retry lookup with bounded matching-hash positive and exact gRPC-code-5 not-found envelopes; inconsistent identity remains unknown and blocks rebroadcast;
- current-active-account/duress authorization at sign time and a dedicated CheckTx-not-confirmed host outcome;
- host-owned internal live/fake quote-handle send-client seam and executable complete strict-concurrency diagnostics without public quote construction;
- private per-client live-handle identity and one drag/accessibility completion router which permits generic success only for `.sent`;
- explicit ambiguous outcome and idempotent exact-byte retry;
- fixture Maestro coverage for response loss and restart.

### Explicitly rejected

- accepting a mnemonic/private key in ThorChainKit;
- choosing the maximum account sequence across providers;
- caching the native transaction fee for minutes;
- trusting remote sign bytes or a remote transaction builder;
- using Vultisig's 20M gas default for native MsgSend;
- importing Vultisig KeysignPayload, TSS responses, WalletCore compiler, or global services;
- copying TronKit Example secret persistence or treating an empty test suite as success.
- copying Tron's Decimal rounding or optional watch-mode signer into the mnemonic-only THOR send path.
- treating a successful full reread as observation recovery after GRDB has completed the failed subscription.

## Evidence Quality

Fresh Palace reads reported all three indexed architecture trees current. Trust remains **YELLOW** because source ranges are absent from semantic responses, bounded result counts are sometimes unreliable, generated-source filtering is imperfect, and several precise intents underfill. These defects did not determine the design: every selected path and protocol constant was independently verified in the pinned tree. See [`../reports/gimle/sprint-02-gimle-reliability.md`](../reports/gimle/sprint-02-gimle-reliability.md).
