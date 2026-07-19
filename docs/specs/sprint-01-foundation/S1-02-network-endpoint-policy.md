# S1-02 — Network and Endpoint Policy

**Status:** revision 12 adversarial review accepted; implementation blocked pending explicit revision-bound approval.
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
- bounded attempts/backoff/error/cancellation policy;
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
- There are no open design questions for revision 12. Any material change to identity precedence, stale-family fallback, or failover ownership requires a new spec revision and approval.

## Files

```text
Sources/ThorChainKit/Network/EndpointHealth.swift
Sources/ThorChainKit/Network/EndpointLease.swift
Sources/ThorChainKit/Network/EndpointPool.swift
Sources/ThorChainKit/Network/ProviderError.swift
Sources/ThorChainKit/Network/NodeProbing.swift
Sources/ThorChainKit/Network/LiveNodeProbe.swift
Tests/ThorChainKitTests/EndpointPoolTests.swift
iOS Example/Sources/Controllers/EndpointsController.swift
.maestro/flows/01-endpoint-policy.yaml
```

## Inherited Public Configuration Surface

S1-01 owns the exact public declarations and construction validation for `Network.Environment`, `Network`, `EndpointFamilyDescriptor`, `EndpointPolicy`, `EndpointConfiguration`, and `EndpointConfigurationError`. S1-02 consumes them without redeclaration or semantic change. `Network` still contains no URLs, and mainnet convenience endpoints remain a separate versioned preset.

## Internal Contracts

```swift
enum EndpointRole: Sendable {
    case cosmosRest
    case cometBft
}

protocol NodeProbing: Sendable {
    func probe(family: EndpointFamilyDescriptor) async throws -> FamilyProbe
}

struct FamilyProbe: Sendable {
    let familyId: String
    let cosmosChainId: String
    let cometChainId: String
    let cosmosLatestHeight: Int64
    let cometLatestHeight: Int64
    let catchingUp: Bool
    let observedAt: Date
}

struct EndpointLease: Sendable {
    let family: EndpointFamilyDescriptor
    let verifiedChainId: String
    let cosmosReadHeight: Int64
    let cometReferenceHeight: Int64
    let poolGeneration: UInt64
}

enum EndpointFailure: Equatable, Sendable {
    case transport
    case rateLimited(retryAfterSeconds: Int?)
    case unavailable(statusCode: Int)
    case stale(height: Int64)
    case invalidResponse
}

enum ProviderError: Error, Equatable, Sendable {
    case noEligibleFamily
    case wrongNetwork(expected: String, actual: String)
    case mixedFamilyIdentity(cosmos: String, comet: String)
    case catchingUp
    case staleEndpoint(height: Int64, bestKnown: Int64)
    case attemptsExhausted
    case invalidResponse
}

actor EndpointPool {
    init(network: Network, configuration: EndpointConfiguration, probe: NodeProbing)
    func lease(excludingFamilyIds: Set<String>) async throws -> EndpointLease
    func recordFailure(familyId: String, failure: EndpointFailure) async
    func reset() async
}
```

## Acceptance Criteria

- S1-01's public `Network`, endpoint-family, policy, configuration, and error declarations are consumed unchanged and compile-tested with the pool.
- A family is lease-eligible only when Cosmos and Comet return the exact expected chain ID, both heights are positive, Comet reports `catching_up == false`, and cross-role skew is at most `maximumHeightLag`.
- A mixed Cosmos/Comet identity or any consistently foreign configured family is a terminal configuration error for the pool. It is never silently skipped in favor of another family.
- A correctly identified but catching-up, nonpositive-height, cross-role-skewed, or best-height-lagging family is stale, not foreign. It may be excluded in favor of another already verified family; if no eligible family remains, the pool returns a distinct `catchingUp` or `staleEndpoint` result.
- Concurrent completion order cannot change the outcome. Terminal precedence is `mixedFamilyIdentity`, `wrongNetwork`, `catchingUp`, `staleEndpoint`, then `noEligibleFamily`; ties use original family order.
- Selection uses the greatest verified Comet height, filters families below `bestHeight - maximumHeightLag`, and breaks equal-height ties by original family order.
- `EndpointLease` is immutable and contains one complete family, the verified identity, both role heights, and the pool generation. A lease never borrows a height or role from another family.
- Initial and TTL revalidation probes are coalesced. After `identityRevalidationInterval`, no cached lease is returned until revalidation succeeds.
- `reset()` cancels the active probe, increments generation, clears health, and prevents an old generation from installing results.
- `recordFailure` applies cooldown/rate-limit state only to retryable transport/status failures. Cancellation records nothing; terminal configuration and invalid-response failures are not converted into retryable health state.
- `EndpointPool` never performs or retries a business read. S1-04's `ReadOperationCoordinator` is the only owner of whole-operation attempts, backoff, family exclusion, exhaustion, and cancellation propagation.
- Diagnostics and Example output contain family IDs, role labels, chain IDs, heights, and sanitized reasons only; they never contain credentials, full query-bearing URLs, or response bodies.

The probe always uses both URLs from one family and obtains freshness separately for each role:

- Cosmos REST: `/cosmos/base/tendermint/v1beta1/node_info` proves `network` identity, while `/cosmos/base/tendermint/v1beta1/blocks/latest` provides its own REST height.
- CometBFT: `/status` proves the same identity and supplies its own height/`catching_up`.
- `abs(cosmosLatestHeight - cometLatestHeight) <= maximumHeightLag`; a fresh Comet endpoint cannot legitimize stale Cosmos REST.
- The lease pinning height equals `cosmosLatestHeight`, not Comet height. S1-04 sends `x-cosmos-block-height` with account/balance requests and requires the exact response-header height on every page.

`EndpointLease` is internal, immutable, and contains one complete family, verified identity, reference height, and pool generation. Account, balances, and status for one attempt never mix families.

## Construction Validation Ownership

S1-01 validates families, IDs, URL safety, client ID, timeouts, lag, retryable codes, attempts, and page-count bounds before S1-02 receives a configuration. S1-02 adds no alternate initializer and never silently clamps or repairs invalid input. Distinct hosts remain valid only as one explicitly caller-grouped family; S1-02 independently proves identity and freshness for both roles before leasing it.

## Probe and Selection

1. Probe families concurrently with a bounded task group.
2. Each family must return identical Cosmos/Comet chain IDs.
3. Both must equal `Network.expectedChainId`.
4. Both heights must be positive, `catching_up == false`, and cross-role skew must not exceed `maximumHeightLag`.
5. Aggregate all completed probes in original configuration order; do not let task completion order select an error or family.
6. Any configured foreign/mixed identity is a terminal configuration failure; it is not silently skipped.
7. Exclude correctly identified catching-up, nonpositive-height, cross-role-skewed, and best-height-lagging families. If another verified family remains, continue with it; otherwise apply the fixed terminal precedence above.
8. Select the remaining family with the highest Comet height, breaking ties by original order.
9. Coalesce concurrent initial/revalidation probes.
10. Identity TTL expiration triggers revalidation before the next lease.

## Single Failover Owner

`EndpointPool` only validates, selects, and records health. It does not perform the business read. The S1-04 `ReadOperationCoordinator` is the sole owner of attempts/backoff and repeats the **entire** account read operation on the next family.

```text
ReadOperationCoordinator
  → pool.lease(excluding attempted families)
  → status + account + complete balances on same family
  → classify failure
  → recordFailure
  → optional injected backoff
  → retry whole operation, at most configuration.effectiveMaximumAttempts
```

Neither `LiveThorNodeClient`, the decoder, nor `AccountSyncer` performs its own failover.

## Failover Matrix

| Event | Whole-operation retry | Health effect | Internal result |
|---|---|---|---|
| `CancellationError` or task-cancelled `URLError.cancelled` | no | none | cancellation |
| DNS/connectivity/timeout | yes | cooldown | transport after exhaustion |
| HTTP 408/429/502/503/504 | yes, bounded | cooldown/rate-limit | typed after exhaustion |
| HTTP 400/401/403/404 | no | client/config | terminal HTTP |
| malformed JSON/invalid field | no | quarantine | invalid response |
| wrong/mixed chain ID | no | pool locked | wrong/inconsistent network |
| catching up/nonpositive height/excessive inter-family or cross-role lag | S1-04 may request another already verified family | stale | distinct stale result when none remains |

Each family is used at most once per logical read. Broadcast receives a separate policy in Sprint 2.

## Internal Versus Public Errors

`ProviderError` and `EndpointFailure` are internal and preserve diagnostic detail (`familyId`, HTTP status, invalid field). They never appear directly in public `SyncState`. S1-05 maps them to the stable, sanitized `SyncError`.

Sensitive URL credentials/query are prohibited during construction; diagnostics contain neither the full URL nor the raw body.

## Lifecycle

- The pool is initially unvalidated.
- The first lease coalesces one probe task.
- `reset()` cancels the probe, increments the pool generation, and clears health.
- An old probe generation cannot install health.
- The S1-05 lifecycle owner cancels the active `ReadOperationCoordinator`; the pool remains reusable after restart.

## Evidence Revision

- Target: `ThorChainKit.Swift@f7da1ce` on `docs/THR-13-network-endpoint-policy`.
- Primary configuration analog: `TronKit.Swift@aa691bcd`, `RpcSource` plus its `Kit` consumer.
- Primary probe seam and THOR-specific support: pinned `vultisig-ios@d3123dbe`, `RPCHealthProbe`, its tests/consumer, and `ThorchainMainnetAPI` role routing.
- Rejected counterexample: `EvmKit.Swift@be028631`, `NodeApiProvider` broad recursive rotation and mutable request ID.
- Gimle trust is `YELLOW`: Tron/Evm mappings are current, but ThorChainKit is absent from Palace and target Serena symbol navigation remained cached as documentation-only. The target decision basis is codebase-memory plus exact Git/`rg`; analogs were independently verified with Serena and `rg`.

## Analog Delta Matrix

### Endpoint family contract

| Field | Revision-12 decision |
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

| Field | Revision-12 decision |
|---|---|
| Analog family | Primary: Vultisig `RPCHealthProbe` injected async seam and tests. Supporting: S1-01 policy bounds and Vultisig THOR LCD/RPC split. Rejected: Evm broad recursive failover. |
| Coverage | Probe contract/implementation/error/test seam from Vultisig; policy/trust bounds from S1-01; composition/consumer from the Vultisig view model; lifecycle counterexample from Evm. No role waiver. |
| Invariants to preserve | Injected transport, typed results, deterministic fixtures, explicit role paths, bounded policy, and caller-owned composition. |
| Required differences | Actor-owned coalescing, fixed error precedence, decoded chain IDs and heights for both roles, catching-up/skew/lag filtering, TTL revalidation, generation invalidation, and immutable leases. |
| Rejected differences | Treating 2xx `node_info` as verified identity, liveness-only health, mutable nonisolated request IDs, retrying every error, and business-read retries inside the pool. |
| Failure modes | Cancellation installing health, old-generation completion, completion-order nondeterminism, stale Cosmos legitimized by fresh Comet, cooldown applied to terminal errors, and stale lease reuse after TTL. |
| Tests before code | Coalescing, cancellation, generation reset, TTL clock, precedence under permuted completion, selection/tie/lag, fresh-Comet+stale-Cosmos, and retryable-only health effects. |
| Verification | Narrow controlled async tests first, then full package tests, strict concurrency and symbol gates, Maestro fixture flow, and opt-in live probe. |

## Tests Before Implementation

`EndpointPoolTests`:

- same identity/healthy height → lease;
- a single-family configuration with public default policy is valid and produces `effectiveMaximumAttempts == 1`;
- explicit attempts greater than family count remain rejected by the inherited S1-01 tests; attempt order/exhaustion remains in S1-04;
- Cosmos/Comet mismatch within a family → terminal pool lock even when another family is healthy;
- a consistently foreign configured family → terminal pool lock even when another family is healthy;
- fresh Comet + stale Cosmos REST is rejected; distinct hosts are permitted only with independent per-role freshness agreement;
- catching-up or stale correctly identified family is excluded in favor of another verified family, with a distinct stale error when none remains;
- selection of the highest healthy family, configured-order tie break, and lag exclusion;
- permuted concurrent probe completion preserves the same family/error and fixed terminal precedence;
- concurrent lease calls share one probe;
- cancellation records no health effect and cannot install a probe result;
- TTL expiry blocks lease reuse until one coalesced revalidation completes;
- reset during probing blocks stale health installation;
- `recordFailure` applies cooldown/rate-limit only to retryable failures and never turns invalid response or configuration errors into retryable state;
- URL order does not change kit persistence identity.

`ReadOperationCoordinatorTests` live in S1-04 and prove retry ownership/attempt order.

### Example/Maestro Acceptance

`EndpointsController` displays the selected family, Cosmos/Comet URLs without credentials, expected/actual chain ID, both role heights, cross-role skew, catching-up, and rejection reason. In fixture mode, flow `01-endpoint-policy.yaml`:

- selects a family with matching identity;
- rejects mixed Cosmos/Comet identity;
- rejects a catching-up/stale family;
- rejects fresh Comet + stale Cosmos REST even when the chain ID matches;
- verifies that terminal wrong-network is not masked by an automatic transition to another family;
- uses accessibility IDs rather than localized display text.

## Live Verification

1. Probe at least one approved mainnet family.
2. Assert exact `thorchain-1` from both Cosmos and Comet.
3. Assert both heights are positive, cross-role skew is bounded, and Comet is not catching up.
4. With two providers, compare lag and select the expected family.
5. Record family IDs/heights only, without credentials.

## Verification Commands

Run in order after approval and implementation:

```bash
swift build
swift test --filter EndpointPoolTests
swift test
Scripts/verify-s1-02.sh
THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh .maestro/flows/01-endpoint-policy.yaml
```

The live probe remains opt-in and must record the exact implementation head, timestamp, family IDs, chain IDs, both heights, skew, catching-up state, and skipped/unavailable reasons without recording provider credentials or full URLs.

## Slice-versioned contract gates

S1-02 adds `Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt` and `Scripts/verify-s1-02.sh`; the S1-02 CI job compares the generated public graph exactly with that current-slice baseline and also requires every canonical declaration in `S1-01-public-symbols.txt` to remain an unchanged subset. New S1-02 declarations appear only in the S1-02 exact baseline; removal or signature mutation of an S1-01 declaration fails. The S1-02 script repeats S1-01's exact production factory capability audit because this slice does not compose probing or networking into `Kit.instance`.
