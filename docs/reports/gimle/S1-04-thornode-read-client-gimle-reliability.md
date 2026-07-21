# S1-04 THORNode Read Client — Gimle Reliability Report

**Run:** `thorchain-s1-04-read-client-20260721`
**Workflow:** `analog_change`
**Design base:** `4f67b57274b299d320ca8d06dc4b046aa4a43258`
**Current design:** revision 13 after `D-S104-001`
**Trust:** GREEN for the recorded design evidence.

This repository-safe report is the durable summary of the canonical Gimle run.
The machine-authoritative `state.json` and fully rendered report remain in the
external audit run directory; they are intentionally not committed because
they contain operator-local checkout paths.

## Context and tool reliability

- codebase-memory project `Users-ant013-Data-AI-thorchain` was ready and used
  first for target architecture/search.
- Serena activated the exact ThorChainKit worktree and verified load-bearing
  symbols and current callers.
- Targeted `rg` and Git reads independently verified all accepted current-tree
  target claims.
- Palace runtime `0e9cf57c00ff970f584256126b500166580e7a72`
  does not register ThorChainKit. Defect `GIM-S104-001` records that medium
  coverage gap. The safe workaround was to use codebase-memory + Serena + `rg`
  for the target and Palace only for bounded registered analog discovery.
- Current supporting analog commits were TronKit
  `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` and EvmKit
  `be0286317c202084784c5a695928cdc985c4ff7b`; local Git reads matched those
  indexed commits.
- Eight Palace calls completed successfully; four influenced design. There
  were no warning, error, false-success, contradicted, or unverifiable accepted
  results.

## Selected component families

| Slice | Primary current-tree spine | Supporting evidence | Rejected counterexample |
|---|---|---|---|
| `S104-READ` | `LiveNodeProbe` + existing `HTTPTransporting` | `EndpointPool`, `AccountState`, `Denom`, current probe/pool tests | EvmKit untyped dictionary/message retry provider |
| `S104-FAILOVER` | `EndpointPool` lease/generation/health contracts | `LiveNodeProbe` classification, exact-operation cancellation, current tests | TronKit partial height/account/token sync and per-request fallback |
| `S104-LOCAL-ACCEPTANCE` | `TestingEndpointPolicySession` narrow SPI pattern | `ExampleRuntime`, real pool, guarded local Maestro runner/self-tests | public mutable provider and obsolete hosted product-test policy |

The selected design preserves one coherent owner per responsibility:

- S1-02 continues to own status/node-info identity probing and leases.
- S1-04 adds only strict account and paginated balances requests.
- `ReadOperationCoordinator` alone owns complete-operation retry.
- `EndpointPool` alone owns family health and generation.
- the testing SPI remains separate from inert production `Kit.instance`.

## Accepted current-tree claims

- `Sources/ThorChainKit/Network/LiveNodeProbe.swift` supplies typed decoding,
  HTTP classification, cancellation normalization, and base-prefix URL behavior.
- `Sources/ThorChainKit/Network/EndpointPool.swift` supplies family exclusion,
  cooldown, generation invalidation, and stale-failure rejection.
- `Sources/ThorChainKit/Models/AccountState.swift` and `Denom.swift` supply the
  absence and strict denomination invariants.
- `Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift`,
  `iOS Example/Sources/Core/ExampleRuntime.swift`, and the guarded local runner
  supply the inert fixture/Example acceptance pattern.
- `Sources/ThorChainKit/Network/EndpointHealth.swift` currently uses wrapping
  monotonic addition; revision 13 explicitly corrects it to checked/saturating
  arithmetic with boundary tests.
- Current S1-03 and BigInt-floor full scheme commands would discover a new live
  test target; revision 13 explicitly binds deterministic runs to
  `ThorChainKitTests` and the live launcher alone to `ThorChainKitLiveTests`.

## Protocol observation

A read-only mainnet observation on 2026-07-21 confirmed the design fixtures:

- a modern existing account returned a typed
  `/cosmos.auth.v1beta1.BaseAccount` response;
- successful balance responses carried the pinned Cosmos height;
- a deterministic valid absent address returned HTTP 404 with code `5`, the
  address-specific not-found message, and empty details;
- absent balances returned a successful empty height-pinned page;
- `pagination.total` cannot be trusted to decide whether a next page exists.

The observation influenced the strict fail-closed contract but is not a
substitute for the exact-head live implementation gate.

## Adversarial review

`D-S104-001` returned REVISE on design revision 12. Revision 13 closes its
findings in the spec and test plan:

1. actor-linearized current-lease validation before successful return;
2. tagged sibling outcomes with fixed cancellation/error precedence;
3. truthful health semantics when cancellation occurs during backoff;
4. checked/saturating `EndpointInstant` advancement;
5. deterministic/live test-target isolation;
6. network identity derived only from `Address.network`;
7. refreshed evidence anchors, plan, report, and integrity hashes.

The required independent repeat review is bound to the revision-13 spec hash.
Implementation remains blocked until that review accepts and the operator gives
explicit revision-bound approval.

## Verification location and Actions boundary

All S1-04 unit, controlled-async, strict-concurrency, verifier, mutant,
simulator, Maestro, Example, and live-network evidence runs on the shared
MacBook at one exact PR head. GitHub Actions remains disabled and contributes no
S1-04 acceptance evidence. Its separately governed future role is one manually
dispatched generic Example build only.

## Residual limitations

- ThorChainKit remains absent from Palace; target evidence therefore depends on
  the independently verified codebase-memory/Serena/`rg` workaround.
- Provider compatibility is not claimed by design fixtures. The explicit
  exact-head mainnet gate must pass or receive a separately recorded operator
  waiver.
- GREEN describes evidence reliability, not implementation completion.
