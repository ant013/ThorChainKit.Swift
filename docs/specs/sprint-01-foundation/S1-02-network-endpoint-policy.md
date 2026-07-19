# S1-02 — Network and Endpoint Policy

**Status:** revision 15 resolves the remaining closure-1 winner-validation blocker and makes the accepted local-first CI transition executable without a bootstrap runner allocation; implementation remains blocked pending independent closure review and explicit revision-bound approval.
**Risk:** high/security boundary.
**Observable outcome:** the kit accepts only provider families consistent with `Network`; wrong-chain, stale, mixed-family, retryable, terminal, and cancelled operations have deterministic, distinct outcomes.

## Goal

Consume S1-01's cohesive network and endpoint-family values to prevent the Vultisig-class error `{mainnet HRP + foreign chain ID + foreign node}`. Add probing, health, selection, and leasing on which S1-04 implements a single explicit owner of read failover.

## Scope

In scope:

- mainnet/stagenet/chainnet identity;
- grouped Cosmos REST + CometBFT provider families;
- actor-owned validation/health pool;
- role-specific identity/freshness probes;
- immutable family lease;
- typed probe/error/cancellation policy and monotonic health eligibility;
- in-memory health.

Out of scope:

- `/thorchain/*`, Midgard, and gRPC; the `thorNode` role is added in Sprint 2;
- custom-node UI and persisted health;
- write/broadcast failover;
- API-payload quorum;
- automatic stagenet chain-ID discovery.

## Assumptions and Open Questions

- S1-01 revision 11 at `f7da1ce` is the immutable public-value baseline for this slice.
- Callers explicitly group one Cosmos REST URL and one CometBFT URL into a family; matching hosts are not required, but both roles must independently prove identity and freshness.
- Provider presets and opt-in live credentials are deployment inputs, not part of the S1-02 policy contract.
- There are no open design questions for revision 15. Any material change to identity precedence, waiter ownership, diagnostic redaction, stale-family fallback, CI execution ownership, live-winner validation, or failover ownership requires a new spec revision and approval.

## Files

```text
Sources/ThorChainKit/Network/EndpointHealth.swift
Sources/ThorChainKit/Network/EndpointLease.swift
Sources/ThorChainKit/Network/EndpointPool.swift
Sources/ThorChainKit/Network/ProviderError.swift
Sources/ThorChainKit/Network/NodeProbing.swift
Sources/ThorChainKit/Network/LiveNodeProbe.swift
Sources/ThorChainKit/Network/EndpointDiagnostics.swift
Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift
Tests/ThorChainKitTests/EndpointPoolTests.swift
Tests/ThorChainKitTests/LiveNodeProbeTests.swift
Tests/ThorChainKitTests/EndpointDiagnosticsTests.swift
Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt
iOS Example/Sources/Controllers/EndpointsController.swift
iOS Example/Sources/Core/ExampleRuntime.swift
iOS Example/Sources/AppDelegate.swift
iOS Example/iOS Example.xcodeproj/project.pbxproj
.maestro/flows/01-endpoint-policy.yaml
.maestro/config.yaml
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
Scripts/verify-s1-02.sh
Scripts/verify-s1-02-ci-policy.sh
Scripts/verify-s1-02-live.sh
Scripts/verify-s1-02-live-evidence.swift
.github/workflows/ci.yml
```

## Inherited Public Configuration Surface

S1-01 owns the exact public declarations and construction validation for `Network.Environment`, `Network`, `EndpointFamilyDescriptor`, `EndpointPolicy`, `EndpointConfiguration`, and `EndpointConfigurationError`. S1-02 consumes them without redeclaration or semantic change. `Network` still contains no URLs, and mainnet convenience endpoints remain a separate versioned preset.

## Internal Contracts

```swift
enum EndpointRole: String, Sendable {
    case cosmosRest
    case cometBft
}

struct EndpointOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int?
}

enum ProbeRequestKind: Int, CaseIterable, Sendable {
    case cosmosNodeInfo
    case cosmosLatestBlock
    case cometStatus
}

struct ProbeRequestIndex: Equatable, Sendable {
    let familyIndex: Int
    let familyId: String
    let role: EndpointRole
    let request: ProbeRequestKind
}

struct CosmosNodeInfoObservation: Equatable, Sendable {
    let chainId: String
}

struct CosmosLatestBlockObservation: Equatable, Sendable {
    let chainId: String
    let latestHeight: Int64
}

struct CometObservation: Equatable, Sendable {
    let chainId: String
    let latestHeight: Int64
    let catchingUp: Bool
}

enum TransportFailureKind: Equatable, Sendable {
    case dns
    case connection
    case timeout
    case tls
    case offline
    case other
}

enum ProbeField: Equatable, Sendable {
    case httpEnvelope
    case nodeInfoNetwork
    case blockHeaderChainId
    case blockHeaderHeight
    case cometNetwork
    case cometHeight
    case cometCatchingUp
}

enum RoleProbeFailure: Error, Equatable, Sendable {
    case cancelled
    case transport(kind: TransportFailureKind)
    case httpStatus(code: Int, retryAfterSeconds: Int?)
    case invalidResponse(field: ProbeField)
}

enum ProbeRequestResult: Equatable, Sendable {
    case cosmosNodeInfo(Result<CosmosNodeInfoObservation, RoleProbeFailure>)
    case cosmosLatestBlock(Result<CosmosLatestBlockObservation, RoleProbeFailure>)
    case cometStatus(Result<CometObservation, RoleProbeFailure>)
}

struct IndexedProbeOutcome: Equatable, Sendable {
    let index: ProbeRequestIndex
    let cosmosOrigin: EndpointOrigin
    let cometOrigin: EndpointOrigin
    let result: ProbeRequestResult
}

protocol NodeProbing: Sendable {
    func probe(index: Int, family: EndpointFamilyDescriptor) async -> [IndexedProbeOutcome]
}

struct EndpointLease: Sendable {
    let family: EndpointFamilyDescriptor
    let verifiedChainId: String
    let cosmosReadHeight: Int64
    let cometReferenceHeight: Int64
    let poolGeneration: UInt64
}

enum EndpointFailure: Equatable, Sendable {
    case transport(retryNotBefore: ContinuousClock.Instant)
    case retryableStatus(code: Int, retryNotBefore: ContinuousClock.Instant)
}

enum IdentityFailureCode: Equatable, Sendable {
    case foreign
    case mixed
}

enum ProviderError: Error, Equatable, Sendable {
    case noEligibleFamily
    case identityFailure(
        expected: String,
        familyId: String,
        role: EndpointRole,
        request: ProbeRequestKind,
        code: IdentityFailureCode
    )
    case catchingUp
    case staleEndpoint(height: Int64, bestKnown: Int64)
    case invalidResponse(familyId: String, role: EndpointRole, field: ProbeField)
    case temporarilyUnavailable
}

actor EndpointPool {
    init(
        network: Network,
        configuration: EndpointConfiguration,
        probe: NodeProbing,
        clock: any EndpointClock
    )
    func lease(excludingFamilyIds: Set<String>) async throws -> EndpointLease
    @discardableResult
    func recordFailure(for lease: EndpointLease, failure: EndpointFailure) async -> Bool
    func reset() async
}
```

`LiveNodeProbe` launches all three requests independently and returns exactly three outcomes, one for every `ProbeRequestKind`, even when another request fails. It never collapses Cosmos node info and latest block into one `Result`, so an observed foreign identity survives a sibling timeout or decoding failure. Each result's enum case must equal its `ProbeRequestIndex.request`; a duplicate, missing, extra, or mismatched index is `.invalidResponse(.httpEnvelope)` after all successfully observed identities have first been classified. `LiveNodeProbe` catches every transport/HTTP/decoding failure and never forwards an arbitrary `Error`; `.cancelled` is the only probe cancellation code. Family index, family ID, role, request kind, status code, and fixed `ProbeField`/`TransportFailureKind` codes are the complete diagnostic algebra. Raw bodies and `localizedDescription` are never stored.

## Acceptance Criteria

- S1-01's public `Network`, endpoint-family, policy, configuration, and error declarations are consumed unchanged and compile-tested with the pool.
- A family is lease-eligible only when Cosmos node info, the Cosmos latest-block header, and Comet status all return the exact expected chain ID, both heights are positive, Comet reports `catching_up == false`, and cross-role skew is at most `maximumHeightLag`.
- A mixed Cosmos/Comet identity or any consistently foreign configured family is a terminal configuration error for the pool. It is never silently skipped in favor of another family. The aggregator classifies every successfully observed identity before considering missing/invalid/retryable outcomes, so a foreign node-info result plus a latest-block timeout still locks the pool despite a healthy sibling.
- A correctly identified but catching-up, nonpositive-height, cross-role-skewed, or best-height-lagging family is stale, not foreign. It may be excluded in favor of another already verified family; if no eligible family remains, the pool returns a distinct `catchingUp` or `staleEndpoint` result.
- Concurrent completion order cannot change the outcome. Precedence is `mixedFamilyIdentity`, `wrongNetwork`, `invalidResponse`, `catchingUp`, `staleEndpoint`, `temporarilyUnavailable`, then `noEligibleFamily`; ties use original family order and then role/request order (`cosmosNodeInfo`, `cosmosLatestBlock`, `cometStatus`). Observed mixed/foreign identity locks the pool until `reset()`; invalid, stale, and retryable outcomes never lock it.
- Selection uses the greatest verified Comet height, filters families below `bestHeight - maximumHeightLag`, and breaks equal-height ties by original family order.
- `EndpointLease` is immutable and contains one complete family, the verified identity, both role heights, and the pool generation. A lease never borrows a height or role from another family.
- Initial and TTL revalidation probes are coalesced by one actor-owned shared task plus an explicit per-waiter registry. After `identityRevalidationInterval`, no cached lease is returned until revalidation succeeds.
- Waiter enrollment and cancellation have one linearized handshake. A per-call lock-protected `CancellationLatch` is synchronously marked by `onCancel`; actor enrollment checks that same latch, and completion acquires live waiter latches in stable waiter-ID order and holds them through its synchronous cache commit. Whichever latch mark or commit lock acquisition linearizes first determines cancellation versus delivery. Cancelling one waiter resumes that waiter promptly with `CancellationError` and leaves the shared task alive for remaining waiters. Cancelling the last waiter cancels the shared task and installs no cache, including when cancellation races registration or completion.
- `reset()` cancels the active probe, resumes all waiters with cancellation, increments generation, clears cache/health/identity lock, and prevents an old generation from installing results.
- TTL, cooldown, and rate-limit eligibility use an injected monotonic clock. `recordFailure(for:failure:)` accepts an immutable lease, verifies its family and `poolGeneration` against current actor state, and returns `false` without mutation for a stale/foreign lease. For a current lease it accepts only retryable transport/status failures with an explicit monotonic `retryNotBefore`; it extends but never shortens existing unavailability and returns `true`. Before expiry the family is excluded. At expiry it becomes eligible from an unexpired identity cache, or participates in one coalesced revalidation if the identity TTL also expired. Cancellation, identity, stale, and invalid-response outcomes create no timed health state.
- `EndpointPool` never performs or retries a business read. S1-04's `ReadOperationCoordinator` is the only owner of whole-operation attempts, backoff, family exclusion, exhaustion, and cancellation propagation.
- Diagnostics and Example output contain family IDs, role/request labels, local expected identity, identity classification (`expected`, `foreign`, or `mixed`), heights, status codes, fixed reason codes, and `EndpointOrigin` only. They never contain an observed raw chain ID, userinfo, path, query, fragment, full URL, response body, `localizedDescription`, or arbitrary server/error text.

The probe always uses both URLs from one family and obtains freshness separately for each role:

- Cosmos REST: `/cosmos/base/tendermint/v1beta1/node_info` supplies `network`; `/cosmos/base/tendermint/v1beta1/blocks/latest` supplies both `block.header.chain_id` and its own REST height. All three role identities must equal one another and `Network.expectedChainId`.
- CometBFT: `/status` proves the same identity and supplies its own height/`catching_up`.
- Probe paths are appended to, rather than resolved from, a configured base path. Leading/trailing slash and percent-encoded path tests prove that a proxy prefix is retained. Diagnostics still project only scheme, lowercase host, and explicit port.
- `abs(cosmosLatestHeight - cometLatestHeight) <= maximumHeightLag`; a fresh Comet endpoint cannot legitimize stale Cosmos REST.
- The lease pinning height equals `cosmosLatestHeight`, not Comet height. S1-04 sends `x-cosmos-block-height` with account/balance requests and requires the exact response-header height on every page.

`EndpointLease` is internal, immutable, and contains one complete family, verified identity, reference height, and pool generation. Account, balances, and status for one attempt never mix families.

## Construction Validation Ownership

S1-01 validates families, IDs, URL safety, client ID, timeouts, lag, retryable codes, attempts, and page-count bounds before S1-02 receives a configuration. S1-02 adds no alternate initializer and never silently clamps or repairs invalid input. Distinct hosts remain valid only as one explicitly caller-grouped family; S1-02 independently proves identity and freshness for both roles before leasing it.

## Probe and Selection

1. Probe families concurrently with a bounded task group and retain exactly three independent request outcomes under each original family/role/request index.
2. Classify all successfully observed chain IDs before transport/HTTP/invalid failures. Each family must return identical Cosmos node-info, Cosmos block-header, and Comet chain IDs; one observed foreign value is never erased by a failed sibling request.
3. All three must equal `Network.expectedChainId`.
4. Both heights must be positive, `catching_up == false`, and cross-role skew must not exceed `maximumHeightLag`.
5. Reject a missing, duplicate, extra, or request-kind-mismatched outcome as invalid after preserving any identity lock implied by the valid observed outcomes. Aggregate all completed probes in original configuration order; do not let task completion order select an error or family.
6. Any observed foreign/mixed identity, including expected node info plus a foreign Cosmos block header, locks the pool even when a sibling is healthy.
7. Invalid and retryable failures reject only that family for the current probe set. A verified sibling may still lease; if none remains, fixed precedence distinguishes invalid response from temporary unavailability.
8. Exclude correctly identified catching-up, nonpositive-height, cross-role-skewed, and best-height-lagging families. If another verified family remains, continue with it; otherwise apply the fixed precedence above.
9. Select the remaining family with the highest Comet height, breaking ties by original order.
10. Coalesce concurrent initial/revalidation probes under the waiter/token rules in Lifecycle.
11. Identity TTL expiration triggers revalidation before the next lease.

### Typed outcome permutations

The controlled tests permute task completion for a healthy family alongside timeout, HTTP 429 with/without `Retry-After`, invalid JSON/field, and foreign identity. A healthy sibling wins over timeout/429/invalid. Foreign or mixed identity always locks the pool regardless of completion order. If no family is healthy, the fixed precedence above selects one sanitized error; no arbitrary thrown error participates in precedence.

## Single Failover Owner

`EndpointPool` only validates, selects, and records health. It does not perform the business read. The S1-04 `ReadOperationCoordinator` is the sole owner of attempts/backoff and repeats the **entire** account read operation on the next family.

```text
ReadOperationCoordinator
  → pool.lease(excluding attempted families)
  → status + account + complete balances on same family
  → classify failure
  → recordFailure(for: lease, failure:)
  → optional injected backoff
  → retry whole operation, at most configuration.effectiveMaximumAttempts
```

Neither `LiveThorNodeClient`, the decoder, nor `AccountSyncer` performs its own failover.

## Failover Matrix

| Event | Whole-operation retry | Health effect | Internal result |
|---|---|---|---|
| `CancellationError` or task-cancelled `URLError.cancelled` | no | none | cancellation |
| DNS/connectivity/timeout | S1-04 only | `retryNotBefore` supplied by S1-04 | typed transport |
| HTTP 408/429/502/503/504 | S1-04 only | monotonic `retryNotBefore`; later values extend eligibility | typed retryable status |
| HTTP 400/401/403/404 | no | client/config | terminal HTTP |
| malformed JSON/invalid field | no | no timed health state | typed invalid field/request kind |
| wrong/mixed chain ID | no | pool locked | wrong/inconsistent network |
| catching up/nonpositive height/excessive inter-family or cross-role lag | S1-04 may request another already verified family | stale | distinct stale result when none remains |

Each family is used at most once per logical read. Broadcast receives a separate policy in Sprint 2.

## Internal Versus Public Errors

`ProviderError`, `RoleProbeFailure`, and `EndpointFailure` are internal and preserve only enumerated diagnostic detail (`familyId`, role, request kind, HTTP status, fixed field/transport code, identity classification, and the local expected identity). `ProviderError` has no `actual`, observed-ID, Cosmos-ID, or Comet-ID associated value. They never appear directly in public `SyncState`. S1-05 maps them to the stable, sanitized `SyncError`.

`EndpointOrigin` is constructed from `scheme`, lowercase `host`, and explicit `port` only. Sensitive URL credentials/query are prohibited during construction, but arbitrary safe base paths remain valid configuration and are therefore treated as secret-bearing. Diagnostics, UI, logs, xUnit, Maestro, live JSON, and committed artifacts contain neither path/query/fragment/userinfo nor raw bodies, raw observed chain IDs, arbitrary `Error` text, or `localizedDescription`.

## Lifecycle

- The pool is initially unvalidated and owns all mutable cache, waiter, identity-lock, and timed-health state inside one actor.
- The first lease creates a shared probe token `(generation, UUID)` and one waiter continuation. Later leases join that token rather than awaiting the task directly. Every call creates a unique waiter ID and lock-protected `CancellationLatch` before entering `withTaskCancellationHandler`.
- `onCancel` synchronously marks the latch, then sends the waiter ID back to the actor. Enrollment reads the latch under the same lock and rejects a marked call; if enrollment wins, the later actor cancellation removes and resumes that waiter. A cancellation message for an unknown waiter is a no-op because the marked latch remains the authoritative pre-enrollment fact; the actor retains no orphan IDs.
- When the last waiter cancels, the actor cancels and removes the shared task. Even a cancellation-insensitive probe cannot install cache because no current waiter/token remains.
- A shared completion atomically checks generation/token, acquires waiter latches in stable ID order, filters marked waiters, and holds the remaining locks through the non-suspending cache commit before resuming continuations. A latch marked before lock acquisition loses to cancellation; a commit that acquired the latch first may deliver the lease. No actor state mutation or continuation resume occurs while acquiring another latch, preventing lock-order inversion.
- `reset()` cancels/removes the shared task, resumes all waiters with cancellation, increments generation, clears cache/timed health/identity lock, and invalidates every old token.
- `recordFailure(for:failure:)` checks the lease generation and configured family inside the same actor. A lease created before `reset()` can never reinstall health into the new generation.
- TTL and retry eligibility use the injected monotonic `EndpointClock`; wall-clock `Date` does not decide cache or cooldown validity.
- The S1-05 lifecycle owner cancels the active `ReadOperationCoordinator`; the pool remains reusable after restart.

## Evidence Revision

- Target: `ThorChainKit.Swift@f7da1ce` on `docs/THR-13-network-endpoint-policy`.
- Primary configuration analog: `TronKit.Swift@aa691bcd`, `RpcSource` plus its `Kit` consumer.
- Primary pool lifecycle analog: `ZcashLightClientKit@ff526fa`, committed `LatestBlocksDataProviderImpl` actor ownership/reset/monotonic update plus DI consumers/test doubles. Coalescing, TTL, generation tokens, waiter cancellation, health selection, and leases are explicit S1-02 deltas, not inherited claims.
- Supporting probe seam and THOR-specific evidence: pinned `vultisig-ios@d3123dbe`, `RPCHealthProbe`, its tests/consumer, and `ThorchainMainnetAPI` role routing.
- Rejected counterexamples: `EvmKit.Swift@be028631`, `NodeApiProvider` broad recursive rotation/mutable request ID; `MarketKit.Swift@95c92c8`, `Scheduler` wall-clock expiry, queue/task split ownership, and raw error logging.
- Gimle trust is `YELLOW`: ThorChainKit and ZcashLightClientKit are absent from Palace, and MarketKit lacks an explicit indexed commit even though its identity and dominant symbol commit match. Target and lifecycle decisions use codebase-memory plus exact Git/Serena/`rg`; Tron/Evm mappings remain current.

## Analog Delta Matrix

### Endpoint family contract

| Field | Revision-15 decision |
|---|---|
| Analog family | Primary: Tron `RpcSource`. Supporting: the inherited S1-01 endpoint values and Vultisig LCD/RPC role routing. Rejected: Evm `NodeApiProvider` URL rotation. |
| Coverage | Contract/composition/consumer from Tron; runtime-safe value and error contract plus tests from S1-01; THOR role boundary from Vultisig. No role waiver. |
| Invariants to preserve | Explicit caller configuration, immutable value flow, separate network identity, narrow dependency direction, and construction-time URL safety. |
| Required differences | Replace an untyped URL array with one typed Cosmos+Comet family; independently verify both roles; bind the complete family to one lease. |
| Rejected differences | `urls[0]`, arbitrary endpoint rotation, app-global endpoint inventory, `/thorchain/*`, Midgard, gRPC, persisted health, and automatic stagenet discovery. |
| Failure modes | Mixed roles, consistently foreign identity, unsafe URL disclosure, role height borrowed from another host, and nondeterministic family ordering. |
| Tests before code | S1-01 surface preservation, same/foreign/mixed identity, distinct-host role agreement, deterministic family order, and sanitized diagnostics. |
| Verification | `swift test --filter EndpointPoolTests`; `Scripts/verify-s1-02.sh`; fixture Maestro flow; opt-in two-role mainnet probe. |

### Probe, health, selection, and lease lifecycle

| Field | Revision-15 decision |
|---|---|
| Analog family | Primary lifecycle spine: Zcash `LatestBlocksDataProviderImpl`. Supporting: Vultisig `RPCHealthProbe` injection/fixtures, S1-01 policy bounds, and Vultisig THOR LCD/RPC split. Rejected: Evm broad recursive failover and MarketKit wall-clock/untyped scheduler. |
| Coverage | Actor ownership/reset/composition/consumers/test substitution from Zcash; probe contract/error fixture shape from Vultisig; policy/trust bounds from S1-01; THOR role split from Vultisig. Evm and MarketKit challenge retry, task, clock, and redaction behavior. No role waiver. |
| Invariants to preserve | One serialized owner, async collaborator boundary, explicit reset, monotonic height update, protocol DI/test doubles, injected transport, deterministic fixtures, explicit role paths, and bounded policy. |
| Required differences | Cancellation-latch enrollment handshake plus shared token, cancel-one/cancel-all/reset rules, monotonic TTL/eligibility, three independently retained typed request outcomes, Cosmos block-header identity binding, fixed precedence/pool lock, catching-up/skew/lag filtering, generation-bound health mutation, immutable leases, and origin-only diagnostics. |
| Rejected differences | Claiming Vultisig as lifecycle ownership, treating 2xx `node_info` as verified identity, liveness-only health, mutable nonisolated request IDs, wall-clock TTL, raw error logging, retrying every error, and business-read retries inside the pool. |
| Failure modes | Cancelled waiter hangs, last-waiter completion installs cache, reset races old generation, completion-order nondeterminism, foreign Cosmos block under expected node info, stale Cosmos legitimized by fresh Comet, cooldown applied to terminal errors, secret-bearing path/body/chain ID disclosure, and stale lease reuse after TTL. |
| Tests before code | Cancel one of two, cancel all, reset during shared probe, TTL/cooldown clock, typed permutation precedence, Cosmos block identity, selection/tie/lag, fresh-Comet+stale-Cosmos, origin redaction, exact probe requests, and retryable-only health effects. |
| Verification | Controlled `LiveNodeProbeTests`, `EndpointPoolTests`, redaction tests, full package/strict-concurrency/symbol gates, exact-flow Maestro fixture, and mechanically distinct opt-in live evidence. |

## Tests Before Implementation

`EndpointPoolTests`:

- same identity/healthy height → lease;
- a single-family configuration with public default policy is valid and produces `effectiveMaximumAttempts == 1`;
- explicit attempts greater than family count remain rejected by the inherited S1-01 tests; attempt order/exhaustion remains in S1-04;
- expected Cosmos node info plus a foreign Cosmos block header → terminal pool lock even when another family is healthy;
- foreign node info plus a timed-out/invalid latest-block request still preserves the foreign fact and locks the pool; missing, duplicate, extra, and request-kind-mismatched outcomes remain invalid without masking an observed foreign fact;
- any Cosmos node-info/block-header/Comet mismatch within a family → terminal pool lock even when another family is healthy;
- a consistently foreign configured family → terminal pool lock even when another family is healthy;
- fresh Comet + stale Cosmos REST is rejected; distinct hosts are permitted only with independent per-role freshness agreement;
- catching-up or stale correctly identified family is excluded in favor of another verified family, with a distinct stale error when none remains;
- selection of the highest healthy family, configured-order tie break, and lag exclusion;
- permuted concurrent probe completion preserves the same family/error and fixed terminal precedence;
- `RoleProbeFailure: Error` and the complete three-result algebra compile under strict concurrency, with family/role/request index retained by every path;
- concurrent lease calls share one probe; a pre-cancelled call, cancellation before/after enrollment, and cancellation racing completion use the cancellation-latch linearization rule; cancelling one of two waiters is prompt and the remaining waiter receives the shared result;
- cancelling all waiters cancels the shared task and installs no result, including with a cancellation-insensitive probe double;
- TTL expiry blocks lease reuse until one coalesced revalidation completes;
- reset during probing cancels all waiters, advances generation, and blocks stale completion; `recordFailure` using a pre-reset lease returns `false` and cannot install health;
- monotonic cooldown/rate-limit expiry, extension, identity-TTL interaction, and active-family best-height selection are deterministic;
- healthy plus timeout/429/invalid/foreign permutations prove sibling fallback, foreign pool lock, fixed precedence, and completion-order independence;
- URL order does not change kit persistence identity.

`LiveNodeProbeTests` use a controlled `HTTPTransporting` double and compile the production probe. They assert exactly one request to each of the three role paths, configured base-path preservation, status/`Retry-After` classification, decoder field classification, cancellation mapping, request timeout/client-ID forwarding, and zero `/thorchain`, Midgard, gRPC, business-read, write, broadcast, or retry requests. Exact non-skipped discovery is part of `Scripts/verify-s1-02.sh`.

`EndpointDiagnosticsTests` inject sentinel secrets independently into URL path, response body, arbitrary transport error text, and foreign chain ID. They inspect typed diagnostics, textual descriptions, captured logs, xUnit, Example rendering input, Maestro fixture artifacts, and live-evidence serialization; every sentinel must be absent while family ID, role/request kind, origin, fixed reason, and height remain observable.

`ReadOperationCoordinatorTests` live in S1-04 and prove retry ownership/attempt order.

### Example/Maestro Acceptance

Production `Kit.instance` remains inert. The package adds one `@_spi(Testing) public TestingEndpointPolicySession` in `Core/TestingEndpointPolicySession.swift`, available only to `ThorChainKitTests` and `iOS Example`. It accepts an S1-01 `Network`/`EndpointConfiguration` plus an enumerated fixture script, constructs the real `EndpointPool`, and returns only sanitized `TestingEndpointPolicySnapshot` values. It cannot expose `EndpointPool`, accept arbitrary closures/raw bodies, perform business reads, mutate `Kit`, or be imported by Unstoppable. A syntax fixture pins this sole SPI root and its call into the real pool.

`ExampleRuntime` imports `@_spi(Testing) ThorChainKit`, owns that session beside the unchanged inert `Kit`, and injects the selected fixture scenario into `EndpointsController`. The controller renders actual pool snapshots—never duplicated classification or static labels—and displays selected family, origin-only Cosmos/Comet projections, local expected identity, identity classification, both role heights, cross-role skew, catching-up, and fixed rejection reason. In fixture mode, flow `01-endpoint-policy.yaml`:

- selects a family with matching identity;
- rejects mixed Cosmos/Comet identity;
- rejects a catching-up/stale family;
- rejects fresh Comet + stale Cosmos REST even when the chain ID matches;
- verifies that terminal wrong-network is not masked by an automatic transition to another family;
- uses accessibility IDs rather than localized display text.

`Scripts/run-maestro.sh` takes exactly one allowlisted slice argument: `s1-01` or `s1-02`. It maps that token internally to exactly one YAML path, passes that exact path to `maestro test`, writes slice-versioned output roots, and rejects raw paths, extra arguments, unknown slices, multi-flow manifests, and output reuse. `Scripts/test-run-maestro.sh` proves both exact argv paths and all existing S1-01 provenance/artifact canaries. Local operator verification runs both exact slice invocations; the one manual final hosted gate repeats them once at the exact PR head. Neither invocation can execute the other flow.

## Live Verification

1. Probe exactly two approved mainnet families supplied through operator environment variables; no credentials or URLs are accepted on the command line.
2. Assert exact `thorchain-1` from Cosmos node info, Cosmos block header, and Comet status.
3. Assert both heights are positive, cross-role skew is bounded, and Comet is not catching up.
4. With two providers, compute the deterministic winner from the recorded eligible families: greatest Comet height, then the first configuration-order entry on an equal-height tie.
5. Record the exact implementation head and one sanitized record per family: family ID, role origins, local expected identity, identity classification, heights, skew, catching-up, outcome code, and timestamp. Never record observed raw identity or arbitrary text.

The exact opt-in command is:

```bash
THORCHAIN_S1_02_LIVE=1 \
THORCHAIN_S1_02_FAMILY_A_ID=<id> \
THORCHAIN_S1_02_FAMILY_A_COSMOS_URL=<url> \
THORCHAIN_S1_02_FAMILY_A_COMET_URL=<url> \
THORCHAIN_S1_02_FAMILY_B_ID=<id> \
THORCHAIN_S1_02_FAMILY_B_COSMOS_URL=<url> \
THORCHAIN_S1_02_FAMILY_B_COMET_URL=<url> \
Scripts/verify-s1-02-live.sh
```

The script refuses to run without the opt-in value, validates a clean implementation HEAD, writes atomically to `build/s1-02-live/<head>/evidence.json`, and exits nonzero for missing inputs, network/identity/freshness failures, schema mismatch, secret sentinel detection, dirty/mismatched head, or unavailable providers. The hosted gate never invokes it and never reports an absent live run as skipped or green.

### Live evidence schema v1

The UTF-8 JSON document has exactly these keys; unknown or missing keys fail validation. Integers are JSON integers, not strings or floating-point values. Array order is configuration order.

```json
{
  "schemaVersion": 1,
  "source": "thorchainkit-s1-02-live",
  "implementationHead": "0123456789abcdef0123456789abcdef01234567",
  "generatedAt": "2026-07-19T00:00:00Z",
  "expectedChainId": "thorchain-1",
  "families": [
    {
      "familyId": "provider-a",
      "cosmosOrigin": { "scheme": "https", "host": "example.invalid", "port": null },
      "cometOrigin": { "scheme": "https", "host": "rpc.example.invalid", "port": 443 },
      "identityClassification": "expected",
      "cosmosHeight": 1,
      "cometHeight": 1,
      "heightSkew": 0,
      "catchingUp": false,
      "outcome": "eligible"
    },
    {
      "familyId": "provider-b",
      "cosmosOrigin": { "scheme": "https", "host": "second.invalid", "port": null },
      "cometOrigin": { "scheme": "https", "host": "rpc.second.invalid", "port": null },
      "identityClassification": "expected",
      "cosmosHeight": 1,
      "cometHeight": 1,
      "heightSkew": 0,
      "catchingUp": false,
      "outcome": "eligible"
    }
  ],
  "selection": { "familyId": "provider-a", "poolGeneration": 0 }
}
```

`schemaVersion` must be integer `1`; `source` must equal `thorchainkit-s1-02-live`; `implementationHead` must be the clean current 40-character lowercase Git SHA and the output directory name; `generatedAt` must be canonical UTC RFC 3339 with whole seconds; `expectedChainId` must equal the selected local `Network.expectedChainId`; `families` must contain exactly the two supplied IDs once each in configuration order; `identityClassification` and `outcome` must be the exact literals `expected` and `eligible`; heights must be positive signed 64-bit integers; `heightSkew` must be the nonnegative absolute difference and within policy; and `catchingUp` must be `false`. The validator must independently recompute the deterministic winner from the recorded array—greatest `cometHeight`, then lowest array index on a tie—and require `selection.familyId` to equal that family ID. `selection.poolGeneration` must be a nonnegative unsigned 64-bit integer.

Each origin has exactly `scheme`, `host`, and `port`; scheme must be `https`, host must be lowercase and nonempty, and port is `null` or an integer in `1...65535`. The validator recursively rejects keys or string values that can encode `url`, `userinfo`, `path`, `query`, `fragment`, response/body/error text, or actual/observed/raw chain IDs. It also rejects duplicate JSON keys. `verify-s1-02-live-evidence.swift` validates the exact shape, source discriminator, head/directory binding, arithmetic, family set/order, deterministic winner, and redaction before atomic rename. Its mandatory mutants include selecting the lower-Comet-height family and selecting the later array entry on an equal-height tie; both must fail. Fixture evidence uses source `thorchainkit-s1-02-fixture`, a different schema, and `build/s1-02-fixture/`; either source/path supplied to the other validator fails.

## Local-first CI budget policy

- Routine `swift build`, narrow/full tests, Swift 5 strict-concurrency warnings-as-errors, verifier/mutant scripts, exact-destination Example simulator builds, and both Maestro flows run on the operator MacBook. The Engineer, CodeReviewer, and QA cite exact local commands, exit status, head SHA, and retained redacted output in their role-separated evidence.
- GitHub requires a `workflow_dispatch` workflow to exist on the default branch before it can receive dispatches, while each run uses the workflow version at its event SHA/ref. A `pull_request` event uses `refs/pull/<number>/merge` and its merge commit. These rules require a separate zero-run bootstrap before the product PR; they are documented in GitHub's [workflow model](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows), [workflow-dispatch event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch), and [pull-request event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request).
- After revision-bound approval, ThorChainSwiftEngineer first opens a minimal CI-policy bootstrap PR from the then-current `main`. Its only permitted paths are `.github/workflows/ci.yml` and `Scripts/verify-s1-02-ci-policy.sh`; it contains no S1-02 product source, tests, Example, Maestro, roadmap, or slice-document edits. The candidate workflow replaces `pull_request` plus `push: main` with `workflow_dispatch` only and requires `pr_number`, exact 40-character `expected_head_sha`, and confirmation token `FINAL_S1_02_GATE`.
- The bootstrap PR's merge ref therefore contains no `pull_request` trigger, so opening or updating it starts no hosted job. Its merged `main` commit contains no `push` trigger, so merging it starts no hosted job. CodeReviewer reviews the exact bootstrap head and the CTO runs the policy verifier locally, confirms through the GitHub runs API that neither event created a run, records bootstrap PR/base/head/merge commit separately, and only then starts the product implementation branch from updated `main`.
- `Scripts/verify-s1-02-ci-policy.sh bootstrap --base-ref <pre-bootstrap-main> --candidate-ref <bootstrap-head>` requires the base workflow to lack `workflow_dispatch`, permits exactly the two bootstrap paths, proves the candidate has no `pull_request`, `pull_request_target`, `push`, `schedule`, or other automatic trigger, and asserts the required dispatch inputs. `steady-state --ref <implementation-head>` repeats the trigger/input/preflight checks and rejects any automatic macOS or duplicate `main` job. Mutants cover each forbidden trigger, an extra bootstrap path, changed job commands beyond the trigger/preflight transition, omitted input, mutable checkout, mismatched PR head, and duplicate merge-time suite.
- The dispatch preflight reads the open PR from GitHub, requires base `main`, requires its current `headRefOid` to equal `expected_head_sha`, checks out that immutable SHA, and records PR number, workflow run ID/URL, and SHA. The CTO/operator dispatches it once, immediately before merge, only after local Reviewer and QA evidence is exact-head green.
- Intermediate PR pushes start no hosted macOS work. A failed final run requires a changed/fixed PR head and a new exact-head review before another dispatch; a successful run for a SHA is not rerun. Pushing or merging that already-verified SHA to `main` starts no duplicate full suite.
- The one final hosted run executes the same deterministic package, strict-concurrency, verifier, Example simulator, and Maestro suite; the opt-in mainnet live probe remains local and separate. Reviewer/QA/CTO closure evidence cites both local output and, when dispatched, the single hosted run URL/status/SHA.
- Self-hosted Mac support may be added in a separate approved slice and is not required by S1-02.

## Verification Commands

Run in order after approval and implementation:

```bash
swift build
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --filter LiveNodeProbeTests
swift test --filter EndpointPoolTests
swift test --filter EndpointDiagnosticsTests
swift test
Scripts/verify-s1-02.sh
Scripts/verify-s1-02-ci-policy.sh steady-state --ref HEAD
Scripts/test-run-maestro.sh
THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh s1-02
```

The live command above runs separately after deterministic gates. Its absence is `UNRUN`, never pass/skip; an attempted unavailable or invalid run is failure evidence.

The bootstrap command runs earlier, on the standalone CI-policy PR, with its exact base and head refs. The bootstrap PR is recorded separately and never populates the roadmap's S1-02 Implemented marker; that marker names only the later product implementation PR.

## Slice-versioned contract gates

S1-02 adds `Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt` and `Scripts/verify-s1-02.sh`; the S1-02 CI job compares the generated public graph exactly with that current-slice baseline and also requires every canonical declaration in `S1-01-public-symbols.txt` to remain an unchanged subset. New S1-02 declarations appear only in the S1-02 exact baseline; removal or signature mutation of an S1-01 declaration fails. The S1-02 script repeats S1-01's exact production factory capability audit because this slice does not compose probing or networking into `Kit.instance`. A separate SPI syntax fixture permits only `TestingEndpointPolicySession`/`TestingEndpointPolicySnapshot`, proves `ExampleRuntime` reaches the real pool through that root, and rejects SPI import anywhere outside tests and `iOS Example`.

## Frozen closure matrix after closure 1/5

Discovery is exhausted at 2/2. Closure 1/5 closed `S102-SEC-001`, `S102-SEC-002`, `S02-ARCH-001`, and `S102-SEC-003`; the five closed-at-discovery IDs also remain closed. Closure 2/5 may evaluate only `VOP-S02-04`, the frozen operator CI-bootstrap acceptance requirement, and a direct Critical/High regression caused by revision 15.

| Stable blocker | Revision-15 resolution | Required closure evidence |
|---|---|---|
| `VOP-S02-04` | Live schema v1 now binds `selection.familyId` to a validator-recomputed winner: greatest recorded Comet height, then first configuration-order entry on a tie. | Existing schema mutants plus explicit lower-height selection and later-equal-height-tie selection mutants both fail. |

The operator's local-first CI budget is an additional frozen acceptance requirement. Closure must also verify that the plan includes the manual exact-head workflow contract and that the future CI-policy verifier rejects automatic hosted macOS triggers or a repeated `main` gate.
