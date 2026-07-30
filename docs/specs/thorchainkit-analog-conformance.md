# ThorChainKit — поклассовая спецификация архитектурного соответствия аналогам

**Статус:** active — реализация Sprint 3 transaction/history разрешена  
**Базовый Kit для оценки:** `ThorChainKit.Swift@ad9c748cc7d2952fba9ed4a64c13c07f8cb15bd5`  
**Текущий host-потребитель:** `unstoppable-wallet-ios@c0bb5a16d848be7cd6d57ad0f5587df339d168a4`, ветка `feature/THR-160-s2-07-unstoppable`  
**Исторические аналоги:** `TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5`, `EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b`, `unstoppable-wallet-ios@44d6df8db07bd7165481e02fc61cae72ad64743a`

## 1. Решение и границы

Цель — не переписать ThorChainKit как TRON/EVM-kit. Цель — сделать его
распознаваемым Horizontal Systems kit: маленький публичный `Kit` facade,
узкие provider/seam protocols, composition внутри package, storage-backed
state, стандартная вертикаль Unstoppable `manager → wrapper → adapter →
SendNew`, и названия, совпадающие с ролью объекта.

THORChain/Cosmos факты остаются первичными для протокола. Поэтому следующие
решения являются намеренными дельтами, а не расхождениями, которые надо
«исправлять» копированием:

- actor-изолированный identity-pinned `EndpointPool` вместо EvmKit
  `NodeApiProvider` с ротацией на почти любую ошибку;
- внешний `Signer` capability вместо EvmKit signer, владеющего private key;
- immutable `SendQuote`, direct-sign protobuf и height-coherent preflight;
- durable exact-byte journal и sequence reservation, а не TRON-specific
  transaction records;
- UIKit-free SwiftUI Example при UIKit-oriented исторических Example apps.

### Жёсткое правило TronKit-first

Для Sprint 3 `TronKit.Swift` является **исходным default-кодом**, а не только
аналогом роли. Новый THOR transaction/history class сначала переносит из
соответствующего TronKit class его ответственность, API-форму, ownership,
storage shape, publisher и control flow. Нельзя заменять этот каркас новым
THOR-specific design только потому, что он кажется удобнее.

Новая логика допускается лишь в самом узком месте, где literal перенос
невозможен из-за подтверждённого Cosmos/THOR требования: cursor/wire format,
height/endpoint proof, protobuf decoding, hash/status semantics или
reconciliation с существующим sequence journal. Такая дельта обязана быть
локальной, названа по THOR-причине и не может менять остальной Tron-shaped
контур. Generated protobuf, fixture-only transports и test-only adapters не
являются архитектурными аналогами.

## 2. Фактический baseline

Локальная ветка Unstoppable фиксирует `ThorChainKit.Swift` в `ad9c748…` в
`packages/WalletCore/Package.swift`, workspace `Package.resolved` и
`Unstoppable.xcodeproj`. Поэтому все оценки Kit ниже относятся именно к
этому commit, а не к `main` или к другой локальной ветке. `ad9c748…` не
является предком текущего `origin/main`; считать возможности main уже
доступными приложению запрещено.

### Уровень соответствия сейчас

| Область | Оценка | Вывод |
|---|---|---|
| Public Kit facade, адрес, сеть, read/sync | соответствует роли kit | Сохранить форму и развивать через facade, не через app services. |
| Provider boundary и identity | сильнее аналогов по safety | Сохранить THOR-дельту; не переносить EVM failover буквально. |
| Local signing, send, pending | соответствует принципам local construction и storage-first | Сохранить разделение runtime/coordinator/journal; улучшать API вокруг него, а не ослаблять инварианты. |
| История и статусы | отсутствует | Следующий Kit-модуль должен получить TRON-shaped `TransactionManager`/`TransactionSyncer` вертикаль. |
| Native THOR actions, assets, swap | отсутствуют | Добавлять отдельными capability-модулями после history. |
| Current Unstoppable lifecycle/signer boundary | не соответствует утверждённым THOR границам | Исправить до расширения host-функций. |

## 3. Обязательные правила для всех будущих классов

1. Сначала выбрать **component family**: public facade, state/sync,
   provider, protocol codec, transaction lifecycle, storage, или
   Unstoppable consumer. Новый класс без семьи и проверенного аналога не
   добавляется.
2. Имена несут роль: `Manager` владеет cached composition, `Syncer` владеет
   периодическим чтением, `Provider`/`Client` выполняет узкий transport,
   `Coordinator` сериализует один рискованный workflow, `Repository`/`Journal`
   владеет durability, `Factory` только собирает зависимости.
3. `Kit` — единственный публичный orchestration facade. Public API не
   экспортирует GRDB, HTTP transport, generated protobuf, private key, seed,
   task/generation token или mutable quote authority.
4. Каждая операция с внешним состоянием получает typed error/result и
   детерминированные tests. `try?`, silent zero/default и global singleton не
   являются допустимой адаптацией из старых kit'ов.
5. Новая host-функция проходит только через стандартные WalletCore seams;
   протокольная логика не переносится в `SendNew`, `AdapterFactory` или view
   model.

## 4. Поклассовая матрица — public facade, models, crypto

| ThorChainKit type(s) | Роль и подтверждённый аналог | Статус | Требование к дальнейшей работе |
|---|---|---|---|
| `Kit` | Главный facade; `TronKit.Kit` — основной аналог, `EvmKit.Kit` — supporting | keep | Оставить `start/stop/refresh`, state/publishers и `quote/send/retry` как единственные public orchestration entry points. Новые возможности добавлять capability methods или отдельные value types, не публиковать managers. |
| `KitDependencies`, `KitLifecycle`, `LifecycleCommandBridge`, `NoOpLifecycle`, `KitFactory` | Внутренняя composition factory; `TronKit.Kit.instance(...)` | align | Сохранить hidden dependency graph. Любой новый service получает protocol seam и test fixture через factory; runtime dependency не должен проникать в public initializer. |
| `AccountState`, `SyncState`, `SyncError`, `StateSnapshot`, `StatePublishing` | Published account state; `TronKit` `SyncState` + `AccountInfoManager`, `EvmKit` account-state update | align | Держать snapshot atomic и публичные типы value-like. При history не перегружать `AccountState`: добавить отдельный transaction state/publisher. |
| `Address`, `AddressCodec`, `AddressError`, `Bech32Codec`, `BitConversion` | Network-bound account identity; `TronKit.Address`/`EvmKit.Address` — только форма public value | keep THOR delta | Не переименовывать в общий AddressManager. Проверка HRP, checksum и 20-byte payload остаётся внутри Kit. |
| `Network`, `Denom`, `EndpointConfiguration`, `EndpointFamilyDescriptor`, `EndpointPolicy` | Chain selection/configuration; `TronKit.Network`/`RpcSource`, EVM RPC-source shape | align with safer delta | Public config остаётся immutable. Добавлять network only с identity, HRP, coin type и explicit endpoint role; нельзя возвращаться к mutable current RPC id. |
| `DerivationPath`, `AccountAddressFactory`, `CosmosAccountAddressDeriver`, `AccountAddressHasher`, `Secp256k1PublicKeyValidator` | Address derivation seam; HdWalletKit/HsCryptoKit use, not ownership analog | keep THOR delta | Поддерживать только public-key input. Никакой seed/private-key API в Kit. Watch-only появится отдельной host/account спецификацией. |

## 5. Поклассовая матрица — read/sync/state/storage

| ThorChainKit type(s) | Аналог и роль | Статус | Требование |
|---|---|---|---|
| `AccountSyncer`, `AccountSyncing`, `SyncGeneration`, `SyncSchedule`, `SyncClock`, `LifecycleGate` | `TronKit.Syncer` — primary lifecycle spine | keep, safer than TRON | Название `AccountSyncer` корректно: синхронизируется account snapshot, а не chain history. Сохранить actor/generation/cancellation. Не копировать TRON unowned `Task` behavior. |
| `AccountStateManager` | `TronKit.AccountInfoManager` | align | Оставить как единственного owner cached read state. Если вводится history, не превращать его в общий god-manager — создать `TransactionManager`. |
| `AccountStateStorage`, `GrdbAccountStateStorage`, `StorageKey`, `StorageRecord`, `StoredBalance`, `ThorChainMigrations` | `TronKit` account/record storage | align | Сохранить storage behind protocol. Миграции версионировать отдельно от send journal migrations; raw RUNE остаётся integer. |
| `AccountReading`, `ReadOperationCoordinator`, `AccountReadTransport`, `AccountTransport`, `BalanceTransport`, `AccountReadWallClock` | EVM concurrent account read is supporting evidence; THOR pinned-height requirement is primary | keep THOR delta | Один coordinator должен продолжать собирать complete snapshot only from one validated family/height. Новые balances/denoms не должны делать independent app reads. |
| `LiveThorNodeClient`, `ThorNodeReading`, `ThorNodeReadError`, `CosmosQueryCodec`, `RequestBuilder` | `TronKit.INodeApiProvider` narrow request boundary | align | Оставить узкий typed client, separate DTO/decoder. Любая новая THOR query добавляется здесь или в dedicated capability client, не в `Kit`/adapter. |

## 6. Поклассовая матрица — provider и endpoint family

| ThorChainKit type(s) | Аналог/контрпример | Статус | Требование |
|---|---|---|---|
| `EndpointPool`, `EndpointLease`, `EndpointHealth`, `EndpointInstant`, `EndpointFailure` | EvmKit `NodeApiProvider` — контрпример broad rotation; Tron `RpcSource` — only config shape | keep THOR delta | `EndpointPool` остаётся actor owner identity validation, cache and failure accounting. Не переименовывать в `NodeApiProvider`, пока он не станет простым transport; это другой уровень ответственности. |
| `NodeProbing`, `LiveNodeProbe`, `ProbeRequestKind`, `ProbeRequestIndex`, `EndpointOrigin`, identity/role observations | Нет полного kit-аналога; THOR identity facts required | keep | Probe остаётся отдельным narrow protocol. Новые roles добавлять через capability manifest и fixture probe, не через URL string switches in consumer. |
| `EndpointOperationRunner`, clocks, `CompletionGate`, cancellation/orphan helpers | Counterexample to unowned TRON/EVM async operations | keep | Сохранить dedicated bounded operation owner. Любой новый network operation должен проходить через same deadline/cancellation contract. |
| `HTTPTransporting`, `URLSessionTransport`, redirect delegate | transport seam; EVM/Tron networking only supporting | align | Не раскрывать HTTP abstraction public. Redirect/media/schema policy тестируется у client/decoder boundary. |
| `EndpointDiagnostics`, `ProviderError`, `NativeRuneEndpointRegistry`, send route/manifest/height proof types | No literal analog; THOR safety policy | keep | Эти types остаются internal policy vocabulary. При provider reliability sprint добавить public diagnostic projection only if host действительно его потребляет. |

## 7. Поклассовая матрица — protocol and signing

| ThorChainKit type(s) | Аналог/контрпример | Статус | Требование |
|---|---|---|---|
| `DirectSignCodec`, `SignPayload`, `SignedTransaction` | `EvmKit.TransactionBuilder` local bytes/hash; THORNode protobuf is authority | align with protocol delta | Keep local construction before transport. New Cosmos messages receive a dedicated codec/message factory and official vectors; remote sign bytes are forbidden. |
| `SigningRequestFactory`, `SigningRequest`, `Signer`, `SignerVerifier`, `CompactSignature` | EvmKit `Signer` is counterexample because it owns private key | keep THOR delta | Preserve external capability: host may sign a digest, Kit verifies address/key/low-S. Do not add `privateKey`, mnemonic, or synchronous signing convenience API. |
| `SendCoordinator`, `SendAttemptHandoff`, `AccountGate`, `OperationHold`, signer race helpers | Transaction-sending coordinator; TRON/EVM send surface is supporting only | keep | One actor serializes per-account quote consumption/sign/broadcast admission. Future THOR action coordinators may reuse common primitives but must not collapse send-specific policy into a generic unsafe coordinator. |
| Generated Cosmos/THOR protobuf | Protocol artifact, not application architecture | keep generated | Generated files are never hand-refactored and never listed as app-facing analog work. Changes come from source proto + regeneration + vector test. |

## 8. Поклассовая матрица — send domain, preflight, broadcast and persistence

| ThorChainKit type(s) | Аналог и роль | Статус | Требование |
|---|---|---|---|
| `SendAmount`, `SendQuote`, quote authority internals, `SendSubmission`, `TransactionID`, `SendError` graph | Unstoppable `EvmSendHandler`/`TronSendHandler` review→send split | align with THOR delta | Keep immutable opaque one-use quote. Host receives checked display snapshots, not constructible quote or `BigUInt` authority. |
| `SendPreflightCoordinator`, `SendPreflightProviding`, `ThorNodeSendPreflightProvider`, `SendSnapshot`, `SendPolicy`, halt/module/recipient types | Vultisig/THORNode protocol evidence; EVM nonce reads are supporting only | keep | Keep one family/height policy. Any `MsgDeposit` preflight shares generic height/lease primitives but has a separate action policy; never reuse `MsgSend` assumptions. |
| `ThorNodeSendClient`, `TransactionBroadcaster`, `CosmosTransactionBroadcaster`, `CosmosTransactionLookupClient`, `BroadcastClassifier`, strict JSON decoder | EVM local encode then RPC; TRON sender only high-level lifecycle analog | keep, stronger | Preserve bounded exact envelope and hash equality. Adding history must reuse hash identity but not classify CheckTx as inclusion. |
| `QuoteStore`, `SendRuntime`, `SendRuntimeRegistry`, shared state/admission helpers | `TronKit.TransactionManager` is lifecycle analogy, not implementation template | keep | Keep runtime private. Document its ownership and expose only facade operations. Do not rename it `TransactionManager` while it owns quote admission, not historical transactions. |
| `SendJournal`, `PendingTransactionRepository`, `PendingPublicationBarrier`, `SequenceReservationStore`, `DatabaseRuntime`, `DatabaseLocation` | BitcoinCore storage-first pending; Tron pending projection | keep | Keep journal/repository/reservation split. New history storage must read/reconcile journal through a separate `TransactionManager`; it must not become a second writer. |
| `PendingTransaction`, `PendingTransactionsStatus`, retry result/policy types | `TronKit.TransactionManager.pendingTransaction()` | partial | Current pending state is only local send lifecycle. Sprint 3 must add normalized confirmed transaction model, pagination, reconciliation, and explorer status without changing pending hash truth. |

## 9. Unstoppable поклассовая матрица

Эти классы находятся в host repository. Они не переносят protocol logic, но
определяют, насколько Kit выглядит как остальные Horizontal Systems kits.

| Current host type | TRON/EVM/Unstoppable analog | Факт сейчас | Обязательное решение |
|---|---|---|---|
| `ThorChainKitManager` | `TronKitManager` composition/cache owner | Correct family/name, но `makeWrapper` derives signer and invokes `kit.start()` | Remove lifecycle start/stop ownership from manager. It may cache/rebuild wrapper by account+endpoint identity only. |
| `ThorChainKitWrapper` | `TronKitWrapper` | Correct wrapper shape, but stores `Signer` | Wrapper must become secret-free. Quote/send bridge accepts ephemeral signer only at final send boundary or owns a private live-handle client as specified by S2-07. |
| `ThorChainSigner` | Host signing bridge; EvmKit signer is rejected ownership pattern | Current manager derives and retains private key material in signer | Construct asynchronously at send time from currently authorized active account; expose only immutable public key and signing capability; no seed/key/account-type stored in wrapper/manager. |
| `ThorChainAdapter` | `TronAdapter` + generic `IAdapter` | State/balance translation is in correct layer; `start()` is empty | Adapter alone owns Kit `start/stop/refresh`, matching the documented ThorChain lifecycle rule. Manager must not start it. |
| `ThorChainEndpointManager` | Wallet endpoint manager family | Correct host ownership of persisted endpoint selection | Keep host persistence/allowlist here. It creates `EndpointConfiguration`; identity/probe/failover remains in Kit `EndpointPool`. |
| `ThorChainPreSendHandler` | `TronPreSendHandler` | Correct SendNew entry family | Keep only exact amount/address/memo conversion. It must not duplicate fee/halt/module policy or round fractional RUNE. |
| `ThorChainSendHandler`, `ThorChainSendData`, `ThorChainSendHelper` | `TronSendHandler`, `EvmSendHandler`, `SendData` | Correct class family, but current `send` maps unknown to generic error and lacks outcome-aware host presentation | Adopt S2-07 outcome seam: opaque live quote handle, absolute expiry, explicit `checkTxAccepted`/`unknown` local-hash views, no generic success banner. |
| `ThorChainAddressParserItem`, `AccountAddress`, `AccountAddressProvider` | TRON parser/address factory vertical | Correct consumer location | Preserve Kit-owned validation and host-owned mnemonic/public-key acquisition. No duplicate Bech32 codec in WalletCore. |
| `AdapterFactory`, `AdapterManager`, `Core` registrations | Existing chain routing convention | Correct destination for registration | Keep additions minimal and ordered with sibling chains. No Thor-only lifecycle special case. |

## 10. Required future class families by roadmap milestone

### Sprint 3 — history and inclusion status

Add a new, explicit transaction vertical; do not extend `SendRuntime` until it
also pretends to be a history engine.

| Proposed family | Primary naming/role analog | Required contract |
|---|---|---|
| `TransactionManager` | `TronKit.TransactionManager` | Own normalized historical transaction cache/projection and publish ordered transactions. It never signs or reserves sequences. |
| `TransactionSyncer` | `TronKit.TransactionSyncer` | Own pagination/cursor/schedule and trigger manager updates; lifecycle binds to Kit start/stop. |
| `TransactionRepository` | Existing `PendingTransactionRepository` shape | Single persisted source for normalized history; journal pending records are reconciled into it, not copied into an independent writer. |
| `ThorNodeTransactionClient` | `LiveThorNodeClient` narrow provider style | Typed Cosmos tx-search/GetTx transport with pagination, strict decode and family lease. |
| `TransactionStatusResolver` | TRON decoration/transaction status responsibility | Projects pending/checkTx/unknown/confirmed/failed/reorg-safe state without claiming inclusion from broadcast. |
| Host `ThorChainTransactionAdapter`/history consumer | Existing WalletCore transaction adapter contract | Added only after the Kit model is stable; it consumes Kit publisher, never queries Cosmos directly. |

### Sprint 4 — native actions

Introduce action-specific value/codec/preflight families: `DepositRequest`,
`DepositQuote`, `MsgDepositCodec`, `DepositPreflightCoordinator`,
`DepositCoordinator`. These reuse lease, signer verification, journal and
broadcast primitives, but not `MsgSend` amount/module/halt rules. Do not use a
generic stringly-typed `ActionManager`.

### Sprint 5 — THOR assets

Introduce `DenomMetadataRepository`, `DenomMetadataSyncer` and a typed
`AssetDescriptor`/policy value. `AccountState` may expose selected native
balances, but metadata/pagination belongs to the new repository. No EVM
`TokenManager` copy without slash-denom/synth/trade-asset policy.

### Sprint 6 — provider reliability

Extend `EndpointPool` and `EndpointHealth`; do not create a parallel app-side
failover manager. Add only narrowly named policies such as
`EndpointBackoffPolicy`, `EndpointRateLimitPolicy`, and telemetry projections
after their privacy contract is approved.

### Sprint 7 — native swap v2

Create a separate swap capability with `SwapQuote`, `SwapPreflightCoordinator`,
`SwapMemoBuilder`, `SwapCoordinator` and status reconciliation. It consumes
the generic signing/broadcast primitives but does not replace the existing
multichain provider without a separate migration decision.

## 11. Mandatory implementation order

1. Correct the current Unstoppable lifecycle and signer ownership boundary.
2. Close S1-06/S1-07 and S2-07 acceptance using the exact pinned Kit revision;
   publish/bump a new revision only after host acceptance.
3. Add Sprint 3 history as the `TransactionManager` family above.
4. Add native actions, assets, provider reliability, then swap in roadmap
   order. Each slice receives its own analog selection, delta matrix and test
   plan; this document is a map, not blanket implementation approval.

## 12. Acceptance criteria for a future implementation PR

- No public source in `Sources/ThorChainKit` imports UIKit or SwiftUI; Example
  remains SwiftUI + Combine only.
- `Kit` remains the sole public orchestration facade and contains no seed or
  private key API.
- Every new named architectural class has a documented component family,
  pinned analog/current-tree anchor, rationale for any THOR delta, and
  deterministic tests.
- Manager/wrapper/adapter lifecycle ownership and signer lifetime are covered
  by WalletCore AppTests: manager does not start Kit, adapter starts/stops it,
  and a signer is created only after final send admission.
- New history/action/asset clients use `EndpointLease`/typed transport rather
  than separate app HTTP calls or EVM-style blind URL rotation.
- Pending → included reconciliation preserves the local transaction hash and
  never upgrades CheckTx acceptance to confirmed without historical evidence.
- The exact integration revision is built and tested in Unstoppable; the
  current local branch does not rely on a sibling path dependency.

## 13. Verification plan

1. Re-run public API fixture tests and source-boundary scans in ThorChainKit.
2. Run deterministic Kit tests for each changed component family, with
   cancellation/timeout/restart cases for lifecycle and provider changes.
3. Run narrow WalletCore tests for manager/wrapper/adapter/handler ownership,
   exact RUNE conversion, quote expiry, signer authorization, and dedicated
   CheckTx/unknown UI outcomes.
4. Build the repository-owned Example and run its fixture Maestro flows only
   there. Build and manually test Unstoppable separately; no Maestro assets or
   secrets enter the app repository.
5. Validate a controlled real-network scenario appropriate to the milestone
   and record endpoint family, height/transaction hash and outcome without
   secrets.

## 14. Open questions requiring a separate decision

1. Should the first public history API expose raw normalized transactions, or
   only a host-neutral projection plus a separate explorer URL builder?
2. Is the local Unstoppable `feature/THR-160-s2-07-unstoppable` branch the
   intended parent for the lifecycle/signer correction, or should it be split
   into a fresh host review branch after the Kit revision is released?
3. Which non-`rune` THOR denoms are product-supported in Sprint 5, and where
   is the metadata authority released?
4. What user-visible retry/reconciliation surface should Sprint 3 add for a
   durable `.unknown` submission?
