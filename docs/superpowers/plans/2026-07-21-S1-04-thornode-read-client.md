# S1-04 THORNode Read Client Implementation Plan

**Branch:** `feature/s1-04-thornode-read-client`
**Spec:** `docs/specs/sprint-01-foundation/S1-04-thornode-read-client.md`
**Base:** `4f67b57274b299d320ca8d06dc4b046aa4a43258`
**State:** revision 13 design only after `D-S104-001`; implementation starts
only after exact-revision operator
approval.

## Objective

Deliver one strict account/balances read pinned to a verified S1-02 lease,
with complete-operation failover, a narrow fixture SPI, deterministic SwiftUI
acceptance, and explicit mainnet compatibility evidence. Every product test and
acceptance command runs on the shared MacBook. GitHub Actions is not used for
S1-04 verification.

## Success path

```text
EndpointPool lease
  -> account + all balance pages at lease.cosmosReadHeight
  -> validate both complete results
  -> one AccountReadTransport
  -> fixture projection / later S1-05 consumer
```

A retry throws away the complete failed attempt, records only an allowed
retryable health failure, waits through the injected sleeper, and leases a new
family. Cancellation or a stale generation terminates without another attempt.

## Task 1 — Freeze failing contracts first

Add focused tests and fixtures for:

- base-path-preserving account/balance URLs and exact headers;
- BaseAccount, exact code-5 absence, unknown wrapper, malformed/overflow fields;
- pagination, misleading total, cycles, page limits, duplicate denoms, and
  later-page failure;
- height headers and canonical 256-bit decimal boundaries;
- whole-attempt order, partial discard, retry matrix, backoff, stale lease, and
  cancellation cleanup.

Run only the new test classes first and retain their expected red result before
source implementation.

## Task 2 — Share the existing HTTP seam

- Extract the current `URLSessionTransport` and base-path builder so
  `LiveNodeProbe` and S1-04 use one implementation.
- Preserve the existing `HTTPTransporting` name and behavior.
- Update probe tests to prove no regression in its three S1-02 requests.
- Do not add a parallel transport protocol, endpoint selector, or retry loop.

Run the narrow probe/request tests.

## Task 3 — Implement strict account and balance decoding

- Add internal DTOs and immutable decimal-string transport records.
- Implement exact account success/absence rules.
- Implement complete, height-pinned balance pagination.
- Validate denomination, decimal canonicality, and the 256-bit limit.
- Keep raw bodies/full URLs out of surfaced errors.

Run decoder/request tests, then the direct client test class.

## Task 4 — Implement whole-operation coordination

- Compose the existing pool and live client in `ReadOperationCoordinator`.
- Start account/balances as tagged structured sibling work for one lease.
- On error, cancel and drain the sibling; external cancellation wins, then
  terminal before retryable, then account before balances. Coordinator-induced
  sibling cancellation is ignored.
- After both successes, linearize acceptance through
  `EndpointPool.isCurrent(_:)`; reject a reset ordered before that point.
- Classify only transport and configured retryable statuses as retryable.
- Apply exact Retry-After/fallback delay to both health and sleeper.
- Fail closed when `recordFailure` rejects a stale lease.
- Make `EndpointInstant.advanced` checked/saturating so cooldown never wraps.
- Use a separate wall clock for the completed record.

Run coordinator, cancellation, strict-concurrency, and guarded mutant tests.

## Task 5 — Add the narrow fixture SPI and Example flow

- Add only `TestingHTTPTransport`, `TestingAccountReadProjection`, and
  `TestingAccountReadSession` under `@_spi(Testing)`.
- Derive the session network from `Address.network`; accept no redundant network
  argument.
- Prove normal consumers cannot see it and production `Kit.instance` is
  unchanged/inert.
- Wire one fixture session into `ExampleRuntime`, view model, and SwiftUI view.
- Extend the local guarded runner by exactly one S1-04 fixture flow.
- Add request-count, accessibility, platform, secret, and provenance checks.

Run the generic Example build, runner self-tests, and exact-UDID S1-04 Maestro
flow on the MacBook.

## Task 6 — Add cumulative verifier, mutants, and live target

- Add S1-04 symbol/test/SPI positive baselines and cumulative subset checks.
- Add one-change mutants for every load-bearing boundary in the approved spec.
- Add the separately invoked live XCTest target and fail-closed launcher.
- Bind every deterministic full Xcode test command, including S1-03 and the
  BigInt-floor gate, to `-only-testing:ThorChainKitTests`; only the live launcher
  selects `ThorChainKitLiveTests`.
- Require explicit public provider/address inputs; missing input is nonzero
  `UNRUN`, not success.
- Cancellation before classification records no health; cancellation during
  backoff preserves the already-recorded real failure and starts no new lease.
- Keep all scripts out of `.github/workflows/ci.yml` and run the build-only
  policy verifier locally.

Run the narrow live target after all deterministic gates. Record exact head,
timestamp, sanitized provider family/chain/height, existing/absent address
class, and balance comparison without secrets.

## Task 7 — Exact-head MacBook verification

Use narrow-to-broad order:

1. syntax and fixture schema;
2. new request/decoder tests;
3. new coordinator/cancellation tests;
4. full deterministic `ThorChainKitTests` target;
5. S1-04 verifier and mutants;
6. inherited verifier/mutant/platform/public/secret gates;
7. generic Example build;
8. guarded Maestro self-tests and S1-04 fixture flow;
9. explicit live gate;
10. diff and roadmap-marker audit.

Reviewer and QA independently rerun the required commands against the same PR
head. Any push invalidates their evidence. No Actions dispatch is authorized by
this plan.

## Task 8 — Review, closure, and roadmap marker

- Engineer pushes implementation and opens one PR linked to this plan/spec.
- CodeReviewer performs adversarial exact-head review and never implements.
- QA independently verifies the exact head on the MacBook and never fixes.
- Engineer alone addresses findings, then both roles rerun after every push.
- Only after acceptance and a real PR number/date are known, update the
  canonical S1-04 roadmap row to `✅ Implemented — PR #… — YYYY-MM-DD`.
- CTO merges only a clean, accepted exact head. Actions remains disabled until
  a separate explicit operator activation.

## Diff discipline

Every changed path must trace to a spec acceptance criterion. Preserve all
user-owned changes, avoid dependency/refactor/format churn, commit no generated
test output or local paths, and add no `Co-authored-by:` trailers. Any public
API, route, lifecycle, persistence, wrapper, hosted-test, or Actions activation
expansion returns to design review.
