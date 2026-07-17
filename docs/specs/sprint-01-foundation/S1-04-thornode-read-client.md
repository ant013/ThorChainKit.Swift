# S1-04 — THORChain read client, coordinated failover, and freshness

**Status:** revised after adversarial review; implementation blocked pending approval.
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
Sources/ThorChainKit/Network/AccountReadResult.swift
Sources/ThorChainKit/Network/HttpTransport.swift
Sources/ThorChainKit/Network/URLSessionHttpTransport.swift
Sources/ThorChainKit/Network/CancellationClassifier.swift
Sources/ThorChainKit/Network/RequestBuilder.swift
Sources/ThorChainKit/Network/ApiError.swift
Sources/ThorChainKit/Network/DTO/StatusResponse.swift
Sources/ThorChainKit/Network/DTO/NodeInfoResponse.swift
Sources/ThorChainKit/Network/DTO/AccountResponse.swift
Sources/ThorChainKit/Network/DTO/BankBalancesResponse.swift
Sources/ThorChainKit/Models/NodeStatus.swift
Sources/ThorChainKit/Models/Account.swift
Sources/ThorChainKit/Models/CoinBalance.swift
Tests/ThorChainKitTests/LiveThorNodeClientTests.swift
Tests/ThorChainKitTests/ReadOperationCoordinatorTests.swift
Tests/ThorChainKitTests/FixtureDecodingTests.swift
Tests/ThorChainKitTests/Fixtures/*.json
Tests/ThorChainKitLiveTests/MainnetReadTests.swift
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
    func balances(address: Address, using lease: EndpointLease) async throws -> [CoinBalance]
}

protocol AccountReading: Sendable {
    func read(address: Address) async throws -> AccountReadResult
}

actor ReadOperationCoordinator: AccountReading {
    func read(address: Address) async throws -> AccountReadResult
}

protocol HttpTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```

All contracts are internal; the public consumer sees `Kit`, config, snapshots, and the sanitized `SyncError`.

### Example-only acceptance SPI

For a reproducible `ThorChainKit/iOS Example` UI harness, S1-04 provides a narrow unstable SPI that is absent from the normal consumer surface:

```swift
@_spi(Testing)
public protocol TestingHttpTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

@_spi(Testing)
public extension Kit {
    static func testingInstance(
        address: Address,
        network: Network,
        walletId: String,
        endpoints: EndpointConfiguration,
        transport: any TestingHttpTransport
    ) throws -> Kit
}
```

Production `Kit.instance` does not accept a transport and never activates fixtures. Only the Example fixture target imports `@_spi(Testing) ThorChainKit`; Unstoppable does not import this SPI in either production or tests. A separate public API compile check proves that a normal `import ThorChainKit` cannot see `TestingHttpTransport/testingInstance`.

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
    return AccountReadResult(status, account, balances, familyId)
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
public struct CoinBalance: Equatable {
    public let denom: Denom
    public let amount: BigUInt
    public init(denom: Denom, amount: BigUInt)
}

struct Account: Equatable, Sendable {
    let accountNumber: UInt64
    let sequence: UInt64
}

struct AccountReadResult: Equatable {
    let status: NodeStatus
    let acceptedHeight: Int64
    let account: Account?
    let balances: [CoinBalance]
    let familyId: String
    let observedAt: Date
}
```

S1-01 owns `Denom`; S1-04 consumes it without redeclaration. `CoinBalance` becomes public because the read layer exposes typed balances internally to the kit snapshot; low-level account/status remain internal.

`Denom`: non-empty, no whitespace/control; opaque/case-sensitive; `/` allowed; native only exact `rune`.

`CoinBalance` and `AccountReadResult` are intentionally not `Sendable` under the minimum BigInt `v5.0.0`, whose `BigUInt` has no such conformance. S1-04 must pass the strict-concurrency build without `@unchecked Sendable`; changing the dependency or isolation design requires separate review.

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
- `AccountReadResult.acceptedHeight = lease.cosmosReadHeight`; Comet height remains diagnostic and is never persisted as account observation height.
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
- zero/max BigUInt, invalid amount never zero;
- full pagination, cycle, max pages, duplicate denom, later-page failure;
- account/all pages exact pinned height; missing/mismatched `x-cosmos-block-height` rejects whole attempt;
- strict-concurrency compile checks for immutable DTOs, with no BigUInt-containing `Sendable` or `@unchecked Sendable` claim.

### Coordinator

- transport/429/503 retries entire operation on next family in exact order;
- first-family partial success never merges with second;
- maximum attempts and one-use-per-family enforced;
- 400/401/decode/wrong identity terminal;
- cancellation at probe/status/account/page/backoff starts no further request and records no health failure;
- coordinator is only retry owner: mock client call count proves no hidden nested retry.

Clock/sleeper/transport/pool/client are injected; fixed sleeps forbidden.

### Example/Maestro acceptance

The fixture flow launches the Example app with canned multi-page bank responses and verifies the complete raw `rune` balance, account existence, accepted height, and endpoint family. The live flow uses only a public address passed through the environment, explicitly displays a `LIVE` badge, and verifies chain ID/height/balance without sending transactions. A missing opt-in variable means an explicit skip at the launcher-script level, not a silently green flow.

## Live gate

1. Validate approved mainnet family/families.
2. Exact `thorchain-1`, positive Cosmos/Comet heights, bounded skew, not catching up.
3. Read known public address; compare raw `rune` with direct captured response.
4. Empty/new address distinguishes absence from error.
5. Controlled proxy/provider failure proves whole-operation retry when two families are configured.

Current research environment DNS failure is recorded as unrun, not success.

## Acceptance criteria

- Four operations only; no Sprint 2 THORNode fee surface.
- Complete pagination and strict string integers.
- Account absence distinct from errors.
- `ReadOperationCoordinator` is sole failover owner.
- Every attempt uses one verified family end-to-end.
- Published `acceptedHeight` is proven by Cosmos REST pinned response headers, never borrowed from Comet.
- Cancellation normalized and never retried.
- Client owns neither lifecycle nor persistence.
- Deterministic suite and controlled live read/failover pass.
