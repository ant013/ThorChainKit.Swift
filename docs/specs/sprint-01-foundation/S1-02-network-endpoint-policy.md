# S1-02 — Network and Endpoint Policy

**Status:** synchronized to S1-01 revision 7 after adversarial REVISE; implementation blocked pending approval.
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
5. Any configured foreign/mixed identity is a terminal configuration failure; it is not silently skipped.
6. Select the healthy family with the highest height; exclude families below `bestHeight - maximumHeightLag`.
7. Coalesce concurrent initial/revalidation probes.
8. Identity TTL expiration triggers revalidation before the next lease.

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
| catching up/excessive inter-family or cross-role lag | select another verified family | stale | stale after exhaustion |

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

## Analog Delta

| Source | Use | Reject |
|---|---|---|
| Tron network/source | explicit configuration | `urls[0]`, ungrouped endpoints |
| Evm provider seam | narrow transport | rotation on any error, mutable nonisolated ID |
| Vultisig | Cosmos/RPC separation, HRP fixtures | one URL override, 2xx-only health, infinite chain-ID cache |
| Official docs | Cosmos REST + CometBFT roles, 429/503 backoff | unstable stagenet defaults |

## Tests Before Implementation

`EndpointPoolTests`:

- same identity/healthy height → lease;
- a single-family configuration with public default policy is valid and produces `effectiveMaximumAttempts == 1`;
- multi-family default uses each family at most once; explicit attempts > family count is rejected;
- Cosmos/Comet mismatch within a family → terminal;
- fresh Comet + stale Cosmos REST is rejected; distinct hosts are permitted only with independent per-role freshness agreement;
- any foreign configured family → terminal, with no silent skip;
- selection of the highest healthy family and lag/catching-up exclusion;
- concurrent lease calls share one probe;
- reset during probing blocks stale health installation;
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

## Slice-versioned contract gates

S1-02 adds `Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt` and `Scripts/verify-s1-02.sh`; the S1-02 CI job compares the generated public graph exactly with that current-slice baseline and also requires every canonical declaration in `S1-01-public-symbols.txt` to remain an unchanged subset. New S1-02 declarations appear only in the S1-02 exact baseline; removal or signature mutation of an S1-01 declaration fails. The S1-02 script repeats S1-01's exact production factory capability audit because this slice does not compose probing or networking into `Kit.instance`.

## Acceptance Criteria

- The S1-01 public configuration surface is consumed unchanged and compile-tested with the pool.
- HRP/chain ID are atomic.
- A family binds Cosmos+Comet attempts; roles are not mixed.
- Role-specific probes prove the identity + freshness of each role; the published account height is never borrowed from another host.
- Foreign/mixed identity fails closed.
- Failover has exactly one owner in S1-04.
- Cancellation is not retried and does not become a sync error.
- The deterministic matrix and controlled mainnet probe pass.
