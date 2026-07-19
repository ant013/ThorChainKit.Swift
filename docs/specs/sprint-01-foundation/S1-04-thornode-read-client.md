# S1-04 — THORChain read client, coordinated failover, and freshness

**Status:** synchronized to S1-01 revision 11 after revision-10 adversarial REVISE; implementation blocked pending fresh review and approval.
**Risk:** high/network and data-integrity boundary.
**Observable outcome:** fixtures and a controlled mainnet test return one complete typed account read; retry repeats the entire operation on another verified family, while malformed/partial/wrong-network/cancelled results do not become zeros or partial successes.

## Goal

Implement a narrow Cosmos REST/CometBFT client and a single owner of read-operation attempts. The client builds/decodes one request; the coordinator obtains a family lease, performs a complete account read, and repeats the entire operation according to the error classification.

## Endpoint surfaces Sprint 1

| Operation | Role | Path | Result |
|---|---|---|---|
| status | CometBFT | `/status` | chain ID, height, time, catching-up |
| node info | Cosmos REST | `/cosmos/base/tendermint/v1beta1/node_info` | network/application identity |
| account | Cosmos REST | `/cosmos/auth/v1beta1/accounts/{address}` | account number, sequence, exists |
| balances | Cosmos REST | `/cosmos/bank/v1beta1/balances/{address}` | complete paginated denoms |

The `/thorchain/network` endpoint and `thorNode` role are removed from Sprint 1: they are needed for fee/send in Sprint 2. Legacy `/auth/accounts` is not implemented; if the approved mainnet families do not support the modern route, the spec returns for review; silent fallback is prohibited.

## Files

```text
Package.swift
Sources/ThorChainKit/Network/ThorNodeClient.swift
Sources/ThorChainKit/Network/LiveThorNodeClient.swift
Sources/ThorChainKit/Network/ReadOperationCoordinator.swift
Sources/ThorChainKit/Network/AccountReading.swift
Sources/ThorChainKit/Network/AccountReadTransport.swift
Sources/ThorChainKit/Network/BalanceTransport.swift
Sources/ThorChainKit/Network/HttpTransport.swift
Sources/ThorChainKit/Network/URLSessionHttpTransport.swift
Sources/ThorChainKit/Network/TestingHttpTransportAdapter.swift
Sources/ThorChainKit/Network/CancellationClassifier.swift
Sources/ThorChainKit/Network/RequestBuilder.swift
Sources/ThorChainKit/Network/ApiError.swift
Sources/ThorChainKit/Network/DTO/StatusResponse.swift
Sources/ThorChainKit/Network/DTO/NodeInfoResponse.swift
Sources/ThorChainKit/Network/DTO/AccountResponse.swift
Sources/ThorChainKit/Network/DTO/BankBalancesResponse.swift
Sources/ThorChainKit/Models/NodeStatus.swift
Sources/ThorChainKit/Models/Account.swift
Sources/ThorChainKit/Core/TestingKitFactory.swift
Tests/ThorChainKitTests/LiveThorNodeClientTests.swift
Tests/ThorChainKitTests/ReadOperationCoordinatorTests.swift
Tests/ThorChainKitTests/FixtureDecodingTests.swift
Tests/ThorChainKitTests/Fixtures/*.json
Tests/ThorChainKitTests/Fixtures/S1-04-public-symbols.txt
Tests/ThorChainKitTests/Fixtures/S1-04-spi-factory-syntax.txt
Tests/ThorChainKitTests/Fixtures/S1-04-spi-read-syntax.txt
Tests/ThorChainKitLiveTests/MainnetReadTests.swift
Scripts/verify-s1-04.sh
iOS Example/Sources/Controllers/AccountReadController.swift
.maestro/flows/03-account-read-fixture.yaml
.maestro/flows-live/03-account-read-mainnet.yaml
```

S1-04 adds a separate `.testTarget(name: "ThorChainKitLiveTests", dependencies: ["ThorChainKit"])`. Each live test first checks `THORCHAIN_LIVE_TESTS == "1"`; the absence of opt-in skips this target specifically through `XCTSkip` with a reason and does not affect the deterministic `ThorChainKitTests`.

## Internal contracts

```swift
protocol ThorNodeClient: Sendable {
    func status(using lease: EndpointLease) async throws -> NodeStatus
    func nodeInfo(using lease: EndpointLease) async throws -> NodeInfo
    func account(address: Address, using lease: EndpointLease) async throws -> Account?
    func balances(address: Address, using lease: EndpointLease) async throws -> [BalanceTransport]
}

protocol AccountReading: Sendable {
    func read(address: Address) async throws -> AccountReadTransport
}

actor ReadOperationCoordinator: AccountReading {
    func read(address: Address) async throws -> AccountReadTransport
}

protocol HttpTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

All contracts are internal; the public consumer sees `Kit`, config, snapshots, and the sanitized `SyncError`.

Every value returned from an async `ThorNodeClient` or `AccountReading` requirement—`NodeStatus`, `NodeInfo`, `Account`, `BalanceTransport`, and `AccountReadTransport`—is an immutable `Sendable` value whose stored fields are themselves `Sendable`. Only the balance/public-snapshot conversion needs BigInt, and that conversion follows the decimal-record boundary below.

### Example-only acceptance SPI

For a reproducible `ThorChainKit/iOS Example` UI harness, S1-04 provides a narrow unstable SPI that is absent from the normal consumer surface:

```swift
@_spi(Testing)
public protocol TestingHttpTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

@_spi(Testing)
public struct TestingAccountReadProjection: Equatable, Sendable {
    public let accountExists: Bool
    public let runeAmountDecimal: String
    public let acceptedHeight: Int64
    public let providerFamilyId: String
}

@_spi(Testing)
@MainActor
public final class TestingKitInstance {
    public let kit: Kit
    public func readAccount() async throws -> TestingAccountReadProjection
}

@_spi(Testing)
public extension Kit {
    @MainActor
    static func testingInstance(
        address: Address,
        walletId: String,
        endpoints: EndpointConfiguration,
        transport: any TestingHttpTransport
    ) throws -> TestingKitInstance
}
```

Production `Kit.instance` does not accept a transport and never activates fixtures. Only the Example fixture target imports `@_spi(Testing) ThorChainKit`; Unstoppable does not import this SPI in either production or tests. A separate public API compile check proves that a normal `import ThorChainKit` cannot see `TestingHttpTransport`, `TestingAccountReadProjection`, `TestingKitInstance`, or `testingInstance`.

`Sources/ThorChainKit/Core/TestingKitFactory.swift` is the sole SPI root and owns all four SPI declarations plus `Kit.testingInstance`. Construction derives the sole network from `address.network`; there is no redundant network argument. Its executed composition closure is limited to the initializer bodies of `TestingHttpTransportAdapter`, `EndpointPool`, `RequestBuilder`, `LiveThorNodeClient`, `ReadOperationCoordinator`, `KitDependencies`, `Kit`, and `TestingKitInstance`, plus the already-pinned `Network.persistenceKey` getter. The `S1-04-spi-factory-syntax.txt` partition contains exactly that root and those initializer/getter bodies; it excludes request execution, retry, storage, lifecycle-start, and every production `Kit.instance` body. A helper, wrapper, initializer, import, identifier/member reference, or call outside this list fails the SPI construction audit. The production partition independently reruns the unchanged S1-01 inert `Kit.instance` baseline.

`TestingKitInstance` retains the exact constructed internal `AccountReading` and validated `Address` only for the Example fixture handle. `readAccount()` performs one explicit `reader.read(address:)`, rejects a nil account with nonempty balances, selects exact `Denom.rune` or canonical `"0"` when absent, and returns only `TestingAccountReadProjection`. It never calls a Kit snapshot setter, subject `send`, lifecycle method, storage API, or another request owner; the enclosed public `kit` therefore remains at the S1-01 nil/idle/zero/no-account snapshot. `S1-04-spi-read-syntax.txt` positively pins the declarations and exact call/member shapes of `TestingKitInstance.readAccount` and the projection initializer. Temporary-copy canaries that return `AccountState`, add a second `AccountReading.read`, call any Kit lifecycle/publication path, or route through an out-of-closure helper must fail this independent SPI read gate.

## Sole failover algorithm

```text
attemptedFamilyIds = ∅
for attempt in 1...configuration.effectiveMaximumAttempts
  check cancellation
  lease = pool.lease(excluding: attemptedFamilyIds)
  attemptedFamilyIds += lease.familyId
  do
    status = client.status(lease)
    nodeInfo = client.nodeInfo(lease)
    validate both identities against lease
    pin Cosmos reads to lease.cosmosReadHeight
    async let account = client.account(address, lease)
    async let balances = client.balances(address, lease)
    await both completely
    return AccountReadTransport(
      acceptedHeight: lease.cosmosReadHeight,
      account: account,
      balances: balances,
      familyId: lease.familyId,
      observedAt: clock.now
    )
  catch
    normalized = CancellationClassifier.normalize(error)
    if cancellation → throw immediately
    classification = classify(normalized)
    pool.recordFailure(familyId, classification)
    if terminal or attempts exhausted → throw
    await injectedBackoff.sleep(attempt, classification)
throw exhausted
```

A retry creates a new lease and retrieves status/account/all balance pages again. An account from family A is never combined with balances from family B. `AccountSyncer` S1-05 calls the coordinator once and contains no retry loop.

## Domain models

```swift
struct Account: Equatable, Sendable {
    let accountNumber: UInt64
    let sequence: UInt64
}

struct BalanceTransport: Equatable, Sendable {
    let denom: Denom
    let amountDecimal: String
}

struct AccountReadTransport: Equatable, Sendable {
    let acceptedHeight: Int64
    let account: Account?
    let balances: [BalanceTransport]
    let familyId: String
    let observedAt: Date
}
```

S1-01 owns `Denom`; S1-04 consumes it without redeclaration. `CoinBalance` is not introduced: there is no approved public consumer beyond `AccountState.balances`. Low-level account/status and both transport records remain internal.

`Denom`: non-empty, no whitespace/control; opaque/case-sensitive; `/` allowed; native only exact `rune`.

`BalanceTransport.amountDecimal` is a canonical unsigned decimal string (`"0"` or a nonzero digit followed by digits). `LiveThorNodeClient` validates it by constructing a local `BigUInt`, requiring that value's decimal description equals the input, and requiring `value.bitWidth <= 256`, matching `cosmossdk.io/math v1.5.3`'s `MaxBitLen = 256`. Exact `2^256 - 1` is accepted and `2^256` is rejected as `.invalidField`; no unbounded or “max BigUInt” criterion is valid. The client never stores `BigUInt` in either transport. The genuinely `Sendable` transport crosses the actor boundary; S1-05 reconstructs the public BigUInt-backed snapshot only on the S1-01 facade dispatcher. S1-04 must pass the strict-concurrency build without `@unchecked Sendable`.

## Request construction

- role URL only from immutable lease;
- validated address inserted as one encoded path component;
- pagination uses `pagination.limit` and exact `pagination.key`;
- optional non-empty `x-client-id`;
- the account request and every balances page send `x-cosmos-block-height: lease.cosmosReadHeight`;
- the response must return a parseable `x-cosmos-block-height` exactly equal to the requested height; a missing/mismatched value discards the entire attempt;
- `Accept: application/json`, configured timeout;
- URLComponents/path APIs, no injectable string concatenation.

Height pinning follows the documented Cosmos REST `x-cosmos-block-height` contract: [Interacting with a Node](https://docs.cosmos.network/sdk/latest/node/interact-node). Compatibility with the exact THORChain providers is confirmed by the live gate before a family is accepted into the production preset.

## Complete balance pagination

```text
key = nil; seenKeys = ∅; balances = [:]
repeat
  check cancellation
  require response x-cosmos-block-height == lease.cosmosReadHeight
  decode every item strictly
  reject any duplicate denom
  if next_key empty → return deterministic denom order
  reject repeated next_key
  enforce policy.maximumBalancePageCount
  key = next_key
```

Second/later-page failure discards the whole attempt. Coordinator may repeat whole operation on another family only for retryable classification.

## Account decoding

- explicit contract-approved not-found → nil;
- BaseAccount and allowlisted wrappers with `base_account` → account;
- unknown `@type` → `.unsupportedAccountType`;
- invalid/missing/overflow decimal string → `.invalidField`;
- arbitrary 404 is not automatically account absence; fixture pins accepted error code/body.

## Internal errors

```swift
enum ApiError: Error, Equatable {
    case invalidURL
    case http(statusCode: Int, bodyCode: Int?, message: String?)
    case emptyBody
    case malformedJSON
    case invalidField(path: String, value: String?)
    case unsupportedAccountType(String)
    case duplicateDenom(Denom)
    case paginationCycle
    case paginationLimitExceeded(Int)
    case missingBlockHeightHeader
    case unexpectedBlockHeight(expected: Int64, actual: Int64)
    case roleMismatch(expected: EndpointRole)
}
```

Internal transport/provider errors retain family diagnostics. S1-05 maps to public `SyncError`; raw response bodies and full URLs are not exposed.

## Cancellation normalization

`URLSession.data(for:)` can throw `CancellationError` or `URLError(.cancelled)`. `CancellationClassifier` maps to `CancellationError` when:

- error is `CancellationError`; or
- `Task.isCancelled` and underlying URL error code is `.cancelled`.

Unsolicited `.cancelled` while task is not cancelled remains a transport failure with bounded policy. Pagination checks cancellation between pages. Cancellation never records endpoint failure, sleeps or starts another attempt.

## Freshness semantics

- Family probe S1-02 decides lease freshness.
- Coordinator revalidates Comet status/Cosmos node-info identities on attempt.
- Account and every balance page are queried at one explicit Cosmos height and must echo that exact response height.
- `AccountReadTransport.acceptedHeight = lease.cosmosReadHeight`; Comet height remains diagnostic and is never persisted as account observation height.
- REST response without exact height evidence fails closed; no invented height and no publication using another host's height.

## Analog delta

| Source | Adopted | Corrected |
|---|---|---|
| Tron providers | narrow async contracts | no broad fallback/`try?` |
| Evm provider seam | transport injection | no client-owned rotation |
| Vultisig | concrete paths/envelopes/denom escaping | pagination, numeric validation, immutable Sendable DTOs |
| S1-02 family policy | identity/health selection | coordinator explicitly owns whole-operation retry |

## Fixtures

- `status-mainnet.json`, `node-info-mainnet.json`;
- `account-base.json`, `account-not-found.json`, `account-wrapped-base.json`;
- `balances-page-1.json`, `balances-page-2.json`, `balances-empty.json`;
- malformed/missing/overflow/HTTP error variants.

Each fixture records source class, capture date, chain ID/height and redaction note.

## Tests before implementation

### Client/decoding

- exact role URLs, headers, address/denom/page encoding;
- valid/wrong/malformed status/node info;
- BaseAccount/wrapper/not-found/unknown type;
- zero and `2^256 - 1` accepted; `2^256`, noncanonical, signed, and malformed amounts rejected rather than coerced to zero;
- full pagination, cycle, max pages, duplicate denom, later-page failure;
- account/all pages exact pinned height; missing/mismatched `x-cosmos-block-height` rejects whole attempt;
- strict-concurrency compile checks over the actual `BalanceTransport`, `AccountReadTransport`, `AccountReading`, and actor witness, with no BigUInt-containing transport or `@unchecked Sendable` claim.

### Coordinator

- transport/429/503 retries entire operation on next family in exact order;
- first-family partial success never merges with second;
- maximum attempts and one-use-per-family enforced;
- 400/401/decode/wrong identity terminal;
- cancellation at probe/status/account/page/backoff starts no further request and records no health failure;
- coordinator is only retry owner: mock client call count proves no hidden nested retry.

Clock/sleeper/transport/pool/client are injected; fixed sleeps forbidden.

### Example/Maestro acceptance

The fixture flow launches the Example app, obtains `TestingKitInstance`, explicitly awaits exactly one `readAccount()`, and displays its projection without mutating `kit` snapshots. Canned multi-page bank responses must therefore produce the complete raw `rune` balance, account existence, accepted height, and endpoint family while the enclosed `kit` remains nil/idle/zero/no-account. A request-count assertion proves the UI used the executable SPI read path rather than static labels. The live flow uses only a public address passed through the environment, explicitly displays a `LIVE` badge, and verifies chain ID/height/balance without sending transactions. A missing opt-in variable means an explicit skip at the launcher-script level, not a silently green flow.

## Live gate

1. Validate approved mainnet family/families.
2. Exact `thorchain-1`, positive Cosmos/Comet heights, bounded skew, not catching up.
3. Read known public address; compare raw `rune` with direct captured response.
4. Empty/new address distinguishes absence from error.
5. Controlled proxy/provider failure proves whole-operation retry when two families are configured.

Current research environment DNS failure is recorded as unrun, not success.

## Slice-versioned contract gates

S1-04 adds `Tests/ThorChainKitTests/Fixtures/S1-04-public-symbols.txt`, `Tests/ThorChainKitTests/Fixtures/S1-04-spi-factory-syntax.txt`, `Tests/ThorChainKitTests/Fixtures/S1-04-spi-read-syntax.txt`, and `Scripts/verify-s1-04.sh`; its CI job compares the generated public graph exactly with the S1-04 baseline and requires every canonical declaration in S1-01…S1-03 to remain an unchanged subset. The exact public baseline adds only the declared SPI surface and does not contain `CoinBalance`. Prior removal or signature mutation fails. The script owns three independent positive normalized syntax/callee paths: production `Kit.instance` must still match the exact S1-01 inert baseline, including its transitive `Network.persistenceKey` getter and dispatcher-context key operations; the SPI construction partition starts only at `Core/TestingKitFactory.swift` and includes exactly the transitive initializer/getter bodies enumerated above; and the SPI read partition pins the one `readAccount` → `AccountReading.read` → projection path without Kit publication. A missing or extra declaration/import/identifier/member/call shape fails its owning path; production imports or reachability to the SPI, and SPI capabilities beyond the enumerated transport fixture/projection, fail named temporary-copy canaries. No blacklist-only audit substitutes for a positive baseline.

## Acceptance criteria

- Four operations only; no Sprint 2 THORNode fee surface.
- Complete pagination and strict string integers.
- Account absence distinct from errors.
- `ReadOperationCoordinator` is sole failover owner.
- Every attempt uses one verified family end-to-end.
- Published `acceptedHeight` is proven by Cosmos REST pinned response headers, never borrowed from Comet.
- Cancellation normalized and never retried.
- Client owns neither lifecycle nor persistence.
- Only internal `Sendable` decimal-string transport records cross the reader actor boundary; `CoinBalance` is absent from the public surface and the actual-source strict-concurrency gate passes without `@unchecked Sendable`.
- Decimal amounts are canonical unsigned values bounded to 256 bits; exact `2^256 - 1` passes and `2^256` fails.
- The Example has one executable SPI read-to-projection path; it displays one real fixture projection while the enclosed Kit remains immutable at its S1-01 snapshot, and the independent positive SPI read audit rejects publication or extra-read capability.
- Deterministic suite and controlled live read/failover pass.
