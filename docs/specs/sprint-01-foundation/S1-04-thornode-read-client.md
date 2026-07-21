# S1-04 — THORNode read client, coordinated failover, and freshness

**Status:** evidence-complete design revision 13 after `D-S104-001` review;
implementation requires
adversarial acceptance and explicit revision-bound operator approval.
**Design base:** `4f67b57274b299d320ca8d06dc4b046aa4a43258` on
`feature/s1-04-thornode-read-client`.
**Risk:** high — network, freshness, cancellation, and account-integrity
boundary.

## Goal and observable outcome

Add one strict, read-only THORNode account pipeline on top of the S1-02
`EndpointPool`. A complete attempt leases one already-verified endpoint family,
reads the account and every balance page at the lease's Cosmos height, and
publishes one immutable transport record. A retry discards the entire failed
attempt and starts again with another family.

Done means deterministic fixtures and an explicit mainnet run on the shared
MacBook return typed chain metadata, account existence/number/sequence, all
balances, accepted height, and provider family. Malformed, partial,
wrong-height, unsupported-account, cancelled, and stale-generation outcomes
never become zero balances or partial success.

## Assumptions and governing decisions

- S1-02 already owns status/node-info probing, identity, role freshness,
  selection, leasing, and health. S1-04 consumes `EndpointLease`; it does not
  duplicate those requests in a second client.
- `HTTPTransporting`, `URLSessionTransport`, and the current
  `LiveNodeProbe` transport/error shape are extended, not replaced by a parallel
  `HttpTransport` family.
- All S1-04 tests, verifier/mutant scripts, strict builds, deterministic
  Maestro, and live-network gates run on the shared MacBook and are bound to the
  exact PR head.
- GitHub Actions supplies no S1-04 acceptance evidence. The governing
  build-only policy permits only one separately activated manual generic
  Example build; repository Actions stays disabled until a separate operator
  instruction enables it.
- The current modern Cosmos account response for a derived user address is
  `/cosmos.auth.v1beta1.BaseAccount`. Module, vesting, nested, or unknown
  wrappers are rejected in this slice.
- The live provider URLs and public test addresses are runtime inputs. They are
  never committed as credentials, and no mnemonic, seed, or private key enters
  the repository or evidence.

## Scope

### In scope

- base-path-preserving request construction;
- `/cosmos/auth/v1beta1/accounts/{address}`;
- complete `/cosmos/bank/v1beta1/balances/{address}` pagination;
- exact `x-cosmos-block-height` request/response pinning;
- strict typed envelopes, decimal parsing, absence recognition, and error
  classification;
- whole-operation family failover, bounded backoff, stale-lease rejection, and
  cancellation cleanup;
- a narrow `@_spi(Testing)` fixture session used only by tests and the SwiftUI
  Example;
- deterministic fixture UI acceptance and an explicit mainnet test target;
- cumulative public/platform/secret/diff contract gates.

### Out of scope

- fee, send, sign, broadcast, transaction history, `/thorchain/network`,
  Midgard, gRPC, persistence, polling, public snapshot publication, or host
  integration;
- legacy `/auth/accounts` fallback;
- automatic provider discovery or a production endpoint preset;
- live Maestro, hosted tests, hosted mutants, hosted simulator selection, or
  GitHub Actions activation;
- public read APIs beyond the narrow unstable testing SPI.

## Existing contracts preserved

- `EndpointPool.lease(excludingFamilyIds:)` is the only family-selection entry.
- `EndpointPool.recordFailure(for:failure:) -> Bool` accepts only a current
  generation lease and retryable transport/status health.
- S1-04 adds one read-only `EndpointPool.isCurrent(_:)` check and uses it as
  the success linearization point; `recordFailure` reuses the same predicate.
- `EndpointLease.family`, `verifiedChainId`, `cosmosReadHeight`,
  `cometReferenceHeight`, and `poolGeneration` remain the source of verified
  identity and freshness.
- `EndpointClock` remains monotonic and is used only for health/backoff.
- `AccountState` still requires account number and sequence exactly when
  `exists == true`, and an absent account still requires empty balances.
- `Denom` remains exact ASCII
  `[A-Za-z][A-Za-z0-9/:._-]{2,127}`; native RUNE is exact lowercase `rune`.
- `Kit.instance` remains inert. S1-04 adds no lifecycle, request, storage, or
  task capability to production construction.
- `Sources/ThorChainKit` imports neither UIKit nor SwiftUI; the Example remains
  SwiftUI/Combine with no UIKit.

## Internal design

### Shared HTTP and request construction

Move the existing private `URLSessionTransport` into the internal shared HTTP
seam and keep the already-existing `HTTPTransporting` spelling:

```swift
protocol HTTPTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransporting { /* current behavior */ }
```

`RequestBuilder` extracts the current `LiveNodeProbe.appending(path:to:)`
behavior. Both probe and account clients use it. It:

- retains the base URL's percent-encoded prefix;
- appends route components without replacing the provider prefix;
- encodes the validated address as one path component;
- constructs pagination with `URLComponents.queryItems`;
- sets `Accept: application/json`, configured timeout, and optional non-empty
  `X-Client-ID`;
- sets `x-cosmos-block-height` only for account and balance requests.

No code constructs request URLs by interpolating an unvalidated absolute URL.

### Read client and transport records

```swift
protocol ThorNodeReading: Sendable {
    func account(address: Address, using lease: EndpointLease) async throws
        -> AccountTransport?
    func balances(address: Address, using lease: EndpointLease) async throws
        -> [BalanceTransport]
}

protocol AccountReading: Sendable {
    func read(address: Address) async throws -> AccountReadTransport
}

struct AccountTransport: Equatable, Sendable {
    let accountNumber: UInt64
    let sequence: UInt64
}

struct BalanceTransport: Equatable, Sendable {
    let denom: Denom
    let amountDecimal: String
}

struct AccountReadTransport: Equatable, Sendable {
    let acceptedHeight: Int64
    let account: AccountTransport?
    let balances: [BalanceTransport]
    let familyId: String
    let observedAt: Date
}
```

`AccountReadTransport` validates the inherited absence invariant again:
`account == nil` requires an empty balance list. It also rejects duplicate
denominations and nonpositive heights. Records crossing async boundaries hold
only genuinely `Sendable` values. They do not contain `BigUInt`,
`AccountState`, or `@unchecked Sendable` declarations.

`BalanceTransport.amountDecimal` is canonical unsigned decimal: exactly `0` or
a nonzero digit followed by digits. A local `BigUInt` validation accepts values
through `2^256 - 1` and rejects `2^256`, signs, leading zeroes, whitespace,
empty values, and malformed digits. The transport stores the canonical string,
not `BigUInt`.

### Account response contract

A successful account response must:

1. have HTTP 2xx;
2. echo the requested height in `Grpc-Metadata-X-Cosmos-Block-Height`
   (case-insensitive HTTP lookup);
3. decode `account.@type` exactly as
   `/cosmos.auth.v1beta1.BaseAccount`;
4. contain canonical, non-overflowing `UInt64` decimal strings for
   `account_number` and `sequence`.

Only this exact absence response maps to `nil`:

- HTTP 404;
- JSON `code == 5`;
- `details` is an empty array;
- `message` exactly equals
  `rpc error: code = NotFound desc = account <requested-address> not found: key not found`.

That observed gateway response may omit the height header. Absence is accepted
for the complete operation only when the sibling balances request succeeds at
the pinned height and returns no balances. Any other 404, changed message,
nonempty details, malformed body, or unsupported account type is terminal.

### Balance response contract

Every page must be HTTP 2xx, echo the requested Cosmos height, and decode every
coin strictly. Pagination starts without a key, uses a fixed limit of `100`,
then forwards the exact nonempty `pagination.next_key` value. The `total` field
is ignored because providers may return `"0"` while a next key exists.

The client rejects:

- a missing or mismatched height on any page;
- a repeated nonempty next key;
- more than `EndpointPolicy.maximumBalancePageCount` pages;
- a duplicate denomination across or within pages;
- an invalid `Denom` or amount;
- a malformed/unknown envelope or a later-page failure.

The final list is sorted by exact `Denom.rawValue`. No partial page result
escapes.

### Whole-operation failover

`ReadOperationCoordinator` is the sole business-read retry owner. It is an
immutable `Sendable` coordinator; mutable family health remains in the
`EndpointPool` actor.

```text
excluded = empty set
for attempt in 1...configuration.effectiveMaximumAttempts
  check cancellation
  lease = await pool.lease(excludingFamilyIds: excluded)
  excluded += lease.family.id
  start tagged account and balances child tasks for this lease
  collect tagged outcomes; after first failure cancel and drain the sibling
  parent cancellation -> throw CancellationError
  if both valid, require await pool.isCurrent(lease)
  current success -> construct one AccountReadTransport and return
  stale success -> throw staleLease
  deterministically select and normalize one real child error
  cancellation -> throw immediately
  terminal response/decode/identity/stale-lease -> throw immediately
  retryable transport/status -> calculate bounded delay
  accepted = await pool.recordFailure(for: lease, failure: typed failure)
  accepted == false -> throw staleLease; do not sleep or retry
  attempts exhausted -> throw attemptsExhausted; do not sleep
  await injected sleeper for the same delay
throw attemptsExhausted
```

A family is used at most once per `read`. Account data from one family is never
combined with balances from another. If one sibling fails, the coordinator
tags the observed outcome, cancels the sibling, awaits its termination, and
only then classifies the attempt. Child work cannot escape the read call.

Error precedence is independent of child completion order:

1. external parent cancellation wins over every child result;
2. induced sibling cancellation after coordinator `cancelAll()` is ignored;
3. a real terminal error outranks a real retryable error;
4. within the same class, account outranks balances.

Tests use barriers to make both real failures observable in both completion
orders and prove the same selected error. If cancellation prevents the sibling
from producing a real error, only the first real error remains.

After two successful children drain, `EndpointPool.isCurrent(_:)` checks the
lease generation and configured family inside the pool actor. That actor call
is the success linearization point: a reset ordered before it rejects the
result; a reset ordered after it is later lifecycle work and S1-05 owns any
publication-generation guard. S1-04 itself publishes no public snapshot.

### Error, retry, backoff, and cancellation policy

Retryable outcomes are only:

- transport errors after cancellation normalization; and
- HTTP status codes already present in
  `EndpointPolicy.retryableStatusCodes` (`408`, `429`, `502`, `503`, `504` by
  default).

All decoding, unsupported type, invalid field, arbitrary 404, height mismatch,
pagination, duplicate-denom, wrong-role/identity, and stale-generation errors
are terminal and do not mutate endpoint health.

`Retry-After` accepts only an exact nonnegative integer delta in `0...60`
seconds. HTTP-date, signed, fractional, whitespace-polluted, overflow, or values
above 60 are ignored. The deterministic fallback delay by failed attempt is
`1, 2, 4, 8` seconds, capped at 8. A valid `Retry-After` takes precedence.

The chosen delay is used twice and must be identical: first as
`endpointClock.now.advanced(seconds:)` in the `EndpointFailure`, then as the
argument to the injected sleeper. `EndpointClock` never supplies `Date`.
`AccountReadWallClock.now` is a separate injected wall clock used only for
`observedAt` after a complete success.

S1-04 corrects the inherited `EndpointInstant.advanced(seconds:)` wraparound.
It rejects negative/nonfinite input fail-closed and uses checked nanosecond
conversion plus `addingReportingOverflow`; an unrepresentable delta or sum
saturates at `UInt64.max`. Zero and representable values retain their exact
current result. A cooldown can never wrap into the past.

`CancellationError`, or `URLError.cancelled` while `Task.isCancelled`, exits
immediately. Cancellation detected before failure classification records no
health and starts no new lease. If a real retryable failure was already
classified and recorded, cancellation thrown by the injected sleeper preserves
that truthful cooldown, exits immediately, and starts no new lease. An
unsolicited `.cancelled` while the task is not cancelled remains a retryable
transport error.

## Narrow testing SPI and Example

S1-04 follows `TestingEndpointPolicySession` with a separate, narrow fixture
owner instead of widening `Kit`:

```swift
@_spi(Testing)
public protocol TestingHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

@_spi(Testing)
public struct TestingAccountReadProjection: Equatable, Sendable {
    public let accountExists: Bool
    public let accountNumber: UInt64?
    public let sequence: UInt64?
    public let runeAmountDecimal: String
    public let acceptedHeight: Int64
    public let providerFamilyId: String
}

@_spi(Testing)
public struct TestingAccountReadSession: Sendable {
    public init(
        address: Address,
        configuration: EndpointConfiguration,
        transport: any TestingHTTPTransport
    )
    public func read() async throws -> TestingAccountReadProjection
}
```

The session adapts the injected transport into the real `LiveNodeProbe`,
`EndpointPool`, `LiveThorNodeClient`, and `ReadOperationCoordinator`. It does
not accept a second network value: endpoint identity is derived only from
`address.network`. It does not own `Kit`, snapshots, lifecycle, storage,
timers, or polling. A normal
`import ThorChainKit` cannot reference these SPI symbols.

The SwiftUI Example adds `AccountReadViewModel` and `AccountReadView`. Fixture
mode uses one scripted multi-page read, displays `FIXTURE`, existence, RUNE
amount, height, and family, and exposes stable accessibility identifiers.
`03-account-read-fixture.yaml` selects those identifiers. The guarded local
runner gains exactly the `s1-04` fixture flow; prior flows remain unchanged.

## Affected areas

Expected implementation paths are limited to:

```text
Package.swift
Sources/ThorChainKit/Network/NodeProbing.swift
Sources/ThorChainKit/Network/LiveNodeProbe.swift
Sources/ThorChainKit/Network/EndpointPool.swift
Sources/ThorChainKit/Network/EndpointHealth.swift
Sources/ThorChainKit/Network/HTTPTransporting.swift
Sources/ThorChainKit/Network/RequestBuilder.swift
Sources/ThorChainKit/Network/ThorNodeReading.swift
Sources/ThorChainKit/Network/LiveThorNodeClient.swift
Sources/ThorChainKit/Network/ReadOperationCoordinator.swift
Sources/ThorChainKit/Network/AccountReadTransport.swift
Sources/ThorChainKit/Network/ThorNodeReadError.swift
Sources/ThorChainKit/Core/TestingAccountReadSession.swift
Tests/ThorChainKitTests/*S1_04*.swift
Tests/ThorChainKitTests/EndpointPoolTests.swift
Tests/ThorChainKitTests/EndpointInstantTests.swift
Tests/ThorChainKitTests/Fixtures/S1-04-*.{json,txt}
Tests/ThorChainKitLiveTests/MainnetReadTests.swift
iOS Example/iOS Example.xcodeproj/project.pbxproj
iOS Example/Sources/Core/ExampleRuntime.swift
iOS Example/Sources/Presentation/AccountReadViewModel.swift
iOS Example/Sources/Views/AccountReadView.swift
.maestro/config.yaml
.maestro/flows/03-account-read-fixture.yaml
Scripts/verify-s1-04.sh
Scripts/test-s1-04-mutants.sh
Scripts/verify-s1-04-live.sh
Scripts/verify-s1-03.sh
Scripts/verify-bigint-floor.sh
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
docs/roadmap/sprint-01-foundation.md
```

If implementation needs a path outside this list for build membership,
slice-versioned baselines, or a proven compile dependency, the PR explains the
exact acceptance criterion. Any behavioral expansion returns to design review.

## Verified component analog family and delta matrices

The target repository was queried first through codebase-memory project
`Users-ant013-Data-AI-thorchain`, then checked in the exact active Serena
project and with targeted current-tree reads at the design base. Palace has no
registered ThorChainKit project (`GIM-S104-001`), so it was used only for
bounded current TronKit/EvmKit analog discovery; target facts came from the
current worktree.

### `S104-READ` — strict typed read pipeline

| Field | Decision |
|---|---|
| Primary | Current `LiveNodeProbe`: injected `HTTPTransporting`, typed decode, status classification, timeout/client ID, and base-path-preserving URL construction. |
| Supporting | `EndpointPool` composition; existing `AccountState`/`Denom` contracts; current probe/pool tests. |
| Counterexample | Current EvmKit `EtherscanTransactionProvider`: untyped dictionaries, message-text outcome handling, and recursive retry. |
| Preserve | Existing HTTP seam, URLComponents behavior, strict typed failure, immutable values, inherited account/denom invariants. |
| Change | Extract the shared builder/URLSession transport; add only account and paginated balance DTOs; exact BaseAccount and exact code-5 absence; strict height and 256-bit decimal proof. |
| Reject | Parallel `HttpTransport`, string URL concatenation, vague wrapper allowlist, zero coercion, total-based pagination, raw body/public URL errors. |
| Tests | Exact URLs/headers/base path; success/absence/unsupported/malformed account; pagination/cycle/duplicate/height; decimal boundaries; public/SPI surface. |

### `S104-FAILOVER` — coordinated complete attempts

| Field | Decision |
|---|---|
| Primary | Current `EndpointPool` lease, exclusion, generation, health, and `recordFailure` contracts. |
| Supporting | Current `LiveNodeProbe` classification, lease models/tests, Testing SPI composition, and EvmKit's exact-operation cancellation handler. |
| Counterexample | Current TronKit `Syncer`: saves height before all account/token work, changes provider mid-operation, and permits partial `try?` results. |
| Preserve | Actor-owned health, monotonic clock, configuration attempt/page limits, family generation, cancellation as no-health-effect. |
| Change | One coordinator owns tagged account+balances child tasks, deterministic error precedence, sibling drain, success-generation linearization, family-at-most-once, bounded retry delay, saturating monotonic advancement, and a separate wall clock. |
| Reject | Per-request rotation, mixed-family assembly, partial publication, nested retry, fixed sleeps, stale-lease retry, Comet height as account height. |
| Tests | Exact call/family order; partial discard; both-error completion permutations; retryable versus terminal matrix; Retry-After/fallback; stale generation before success linearization; monotonic overflow; cancellation at every phase; no escaped task. |

### `S104-LOCAL-ACCEPTANCE` — inert fixture and MacBook gates

| Field | Decision |
|---|---|
| Primary | Current `TestingEndpointPolicySession` narrow SPI pattern. |
| Supporting | `ExampleRuntime`, `AccountState`, real pool, current tests, guarded local Maestro runner. |
| Preserve | Production `Kit.instance` inertness, SPI-only fixture capability, SwiftUI/no-UIKit Example, provenance/secret checks. |
| Change | Add a separate `TestingAccountReadSession`, deterministic S1-04 view/flow, explicit live XCTest target, and slice verifier/mutants. |
| Reject | Public mutable provider, fixture transport in production, static UI labels, live secrets, live Maestro, and hosted acceptance. |
| Tests | SPI visibility/composition; one executable read; request count; Example build; deterministic Maestro; live target on exact PR head; zero Actions test runs. |

## Tests before implementation

### Deterministic client tests

- exact base-prefix/address/query/header construction and no URL replacement;
- BaseAccount success, exact not-found, changed not-found, unknown/nested type,
  malformed/overflow fields;
- zero and `2^256 - 1` accepted; `2^256`, leading zero, signed, whitespace,
  empty, and malformed amounts rejected;
- one/many/empty pages, null/empty/real next keys, misleading total, cycle,
  page limit, duplicate denom, later-page failure;
- required exact height on success and every balance page; absent account plus
  nonempty balances rejected;
- strict concurrency over actual records/protocol witnesses with no
  `@unchecked Sendable`.

### Deterministic coordinator tests

- transport and each configured retryable status repeat the complete operation
  on the next family in exact order;
- terminal statuses/decode/identity/height errors make no health change and do
  not retry;
- integer Retry-After boundaries and every rejected spelling/value;
- fallback delay sequence/cap and identical health/sleeper delay;
- maximum attempts, one family at most once, and stale `recordFailure == false`;
- reset after child completion but before success linearization rejects the
  result; reset ordered after the linearization does not retroactively fail it;
- account success plus balance failure never publishes/merges;
- both real child failures select the same documented error under every
  completion permutation, and induced sibling cancellation never replaces it;
- cancellation before lease, during each sibling, pagination, classification,
  and sleep starts no later request and leaves no child; cancellation before
  classification records no failure, while cancellation during sleep preserves
  the already-recorded real retryable failure;
- `EndpointInstant.advanced` exact, invalid, near-maximum, conversion-overflow,
  and addition-overflow cases never wrap into the past;
- mock call counts prove the coordinator is the only business retry owner.

### Contract, Example, and mutant gates

- cumulative public-symbol and exact test-discovery baselines;
- every deterministic full Xcode test command selects only
  `ThorChainKitTests`; only the live launcher selects `ThorChainKitLiveTests`;
- a normal public-only consumer cannot see the testing SPI;
- positive source/callee partitions prove production inertness and the one
  testing-session composition/read path;
- platform scan, package iOS 13 floor, Example iOS 14+ SwiftUI lifecycle, and
  generic Example build;
- guarded canaries reject parallel transport, string URL construction,
  account-wrapper widening, missing height proof, partial merge, nested retry,
  cancellation retry, stale-lease retry, Kit publication, second read, static
  UI result, and Actions test/runner invocation;
- `Scripts/test-run-maestro.sh`, then exact-UDID
  `Scripts/run-maestro.sh s1-04` on the MacBook.

### Explicit live gate on the MacBook

After deterministic gates, `Scripts/verify-s1-04-live.sh` invokes only the
`ThorChainKitLiveTests` target against the exact implementation head. It
requires opt-in, public provider role URLs, one known public existing address,
and the deterministic valid absent address. Missing inputs produce `UNRUN` and
nonzero; they never become a pass. Before merge, this slice requires a real
pass unless the operator explicitly waives it in the exact-head review record.
The target contains no `XCTSkip`; missing inputs fail the launcher before
Xcode. `verify-s1-03.sh`, `verify-bigint-floor.sh`, and the new S1-04
deterministic command use `-only-testing:ThorChainKitTests`, so the live target
cannot enter default/cumulative results. A source canary enforces this split.

The live assertions are:

1. exact `thorchain-1`, positive Cosmos/Comet heights, bounded configured skew,
   and not catching up through the real S1-02 lease;
2. existing BaseAccount plus every balance at one echoed Cosmos height;
3. direct captured raw RUNE amount equals the implementation result;
4. deterministic absent address produces the exact account-not-found envelope,
   empty height-pinned balances, and `exists == false`;
5. no write, sign, broadcast, mnemonic, private key, or user-funded account.

Two-family failover is deterministic fixture evidence; a second public provider
is live evidence only when the operator supplies it and is not required for a
single-provider protocol compatibility pass.

## Verification order

All commands below run locally on the shared MacBook:

1. shell/Swift syntax and fixture-schema checks;
2. narrow new decoder/request tests;
3. narrow coordinator/cancellation tests;
4. full deterministic `ThorChainKitTests` target with zero failure/error/skip;
5. `Scripts/verify-s1-04.sh` with warnings as errors;
6. `Scripts/test-s1-04-mutants.sh` and existing cumulative verifier/mutant gates;
7. generic Example build;
8. guarded Maestro runner self-tests and `run-maestro.sh s1-04` on the exact
   local simulator UDID;
9. explicit `verify-s1-04-live.sh` pass;
10. platform/public/secret/provenance/diff hygiene and roadmap-marker audit;
11. independent Reviewer and QA rerun against the same exact PR head.

No GitHub Actions run is part of S1-04 verification. If Actions is later
enabled by a separate operator instruction, its one generic Example build is a
clean-host compile signal only.

## Acceptance criteria

1. The S1-02 lease is the sole identity/freshness input; no duplicate status or
   node-info client is introduced.
2. Account and every balance page stay in one family and one exact Cosmos
   height per attempt.
3. Only exact BaseAccount and exact code-5 absence are accepted; absence plus
   nonempty balances is impossible.
4. Pagination is complete, cycle/page/duplicate protected, and independent of
   `pagination.total`.
5. Amounts are canonical unsigned decimal and at most 256 bits.
6. Whole-operation retry is bounded, family-at-most-once, cancellation-clean,
   generation-safe at an actor-linearized success check, and owned only by
   `ReadOperationCoordinator`.
7. Only transport and configured retryable statuses mutate health/retry; all
   other failures are terminal.
8. Async records are genuinely `Sendable`; no BigUInt-backed transport or
   `@unchecked Sendable` crosses the reader boundary.
9. Production `Kit` remains inert and normal consumers cannot see or inject the
   testing transport.
10. Deterministic unit/contract/mutant/Example/Maestro gates and the explicit
    mainnet gate pass locally on the MacBook at the exact reviewed head.
11. GitHub Actions performs no S1-04 tests, mutants, simulator work, Maestro,
    live probes, or verifier scripts and remains disabled absent separate
    activation.
12. The canonical roadmap row is changed from `Pending` only after the exact PR
    head is accepted and the real PR number/date are known.

## Open questions

None block implementation. A provider outage is recorded as a failed or unrun
live gate, never reclassified as fixture success. Any request to accept a live
waiver, broaden account wrapper support, add legacy routes, or enable Actions is
a separate explicit operator decision.
