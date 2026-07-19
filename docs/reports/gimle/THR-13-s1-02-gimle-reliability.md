# Gimle reliability report: THR-13 S1-02 revision 12

- Task: THR-13
- Workflow/phase: `analog_change` / `awaiting_approval`
- Trust: **YELLOW**
- Repository/base: `ThorChainKit.Swift@f7da1ce7b0b16c9a44b339d9bdfc5e2c9404dfc9`
- Branch: `docs/THR-13-network-endpoint-policy`
- Runtime: `native-dev@0e9cf57c00ff970f584256126b500166580e7a72`
- Canonical machine state: `audit/runs/THR-13-S1-02/state.json`

This committed report is the redacted repository view. The canonical machine state and generated report retain operator-local checkout anchors and are not committed.

## Summary

- Calls: 9 — 7 success, 2 warning, 0 error, 0 false-success.
- Useful-call rate: 88.9%.
- Gimle-backed claim agreement: 100%; contradictions: 0%.
- Location validity and freshness coverage for Gimle-backed claims: 100%.
- Analog slices/candidates: 2/8.
- Defects/limitations: 3 — one target coverage gap, one fixed caller query, one Serena environment drift.

`YELLOW` is required because Palace has no ThorChainKit target mapping and the target Serena registration cached the earlier documentation-only checkout. Current target truth therefore comes from the healthy codebase-memory project plus Git and targeted `rg`. Current TronKit and EvmKit mappings agree with their exact checkouts and were independently verified with Serena and `rg`; pinned Vultisig evidence was verified directly.

## Evidence calls

| Event | Tool | Outcome | Used | Decision-relevant result |
|---|---|---|:---:|---|
| `E-0001` | `palace.health.status` | success | yes | Runtime reachable and clean. |
| `E-0002` | `palace.memory.health` | success | yes | Graph and latest ingest healthy. |
| `E-0003` | `palace.memory.list_projects` | warning | yes | ThorChainKit absent; initial list-level freshness/identity fields unresolved. |
| `E-0004` | `palace.code.list_passthrough_projects` | success | yes | Relevant code calls use native routing. |
| `E-0005` | `palace.memory.get_project_overview` | success | yes | `tron-kit` maps to current `aa691bcd`. |
| `E-0006` | `palace.memory.get_project_overview` | success | yes | `evm-kit` maps to current `be028631`. |
| `E-0007` | `palace.code.search_graph` | warning | no | Combined name query truncated before `RpcSource`; superseded by a split query. |
| `E-0008` | `palace.code.search_graph` | success | yes | Located Evm `NodeApiProvider` and `RpcSource`. |
| `E-0009` | `palace.code.search_graph` | success | yes | Located exact Tron `RpcSource`. |

## Verified analog family

| Slice | Primary | Supporting | Rejected counterexample |
|---|---|---|---|
| Endpoint family contract | Tron `RpcSource` explicit configuration shape | S1-01 endpoint values/tests; Vultisig THOR LCD/RPC routing | Evm broad URL rotation |
| Probe, health, selection, lease lifecycle | Vultisig injected async `RPCHealthProbe` seam/tests | S1-01 policy bounds; Vultisig THOR role split | Evm recursive retry and mutable request ID |

The accepted deltas are actor-owned coalescing, decoded two-role identity/freshness, fixed error precedence, deterministic selection, TTL revalidation, generation invalidation, immutable leases, and retryable-only health effects. The design explicitly rejects `urls[0]`, treating HTTP 2xx as network identity, broad failover, app-global endpoint ownership, and business-read retries inside the pool.

## Load-bearing claims

| Fact | Verdict/basis | Current anchor |
|---|---|---|
| `F-TARGET-S1-01-ENDPOINTS` | `MATCH`, accepted from codebase-memory plus `rg` | `Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift`, `EndpointPolicy.swift`, `EndpointConfiguration.swift`, and `PublicApiTests.swift` at `f7da1ce` |
| `F-TRON-RPC-SOURCE` | `MATCH`, accepted from Gimle + Serena + `rg` | `TronKit.Swift@aa691bcd`, `Sources/TronKit/Models/RpcSource.swift` and its `Kit` consumer |
| `F-VULTISIG-THOR-ROLES` | `MATCH`, accepted from Serena + `rg` | `vultisig-ios@d3123dbe`, `ThorchainMainnetAPI.swift` |
| `F-VULTISIG-PROBE-SEAM` | `MATCH`, accepted from Serena + `rg` | `vultisig-ios@d3123dbe`, `RPCHealthProbe.swift`, tests, and view-model consumer |
| `F-EVM-BROAD-ROTATION` | `MATCH`, accepted as counterevidence from Gimle + Serena + `rg` | `EvmKit.Swift@be028631`, `NodeApiProvider.swift` |

## Defects and fallbacks

### `GIMLE-THR13-TARGET-COVERAGE`

- Class/severity/status: `coverage_gap` / medium / workaround.
- Actual: ThorChainKit is absent from Palace; list-level analog freshness initially remained unknown.
- Impact: Gimle cannot establish target truth.
- Fallback: use codebase-memory project `Users-ant013-Data-AI-thorchain`, exact Git reads, and targeted `rg`; use Gimle only for bounded analog discovery.

### `GIMLE-THR13-COMBINED-NAME-QUERY`

- Class/severity/status: `caller_error` / low / fixed.
- Actual: the combined `Network|RpcSource` query returned 17 Network-heavy nodes and truncated at 10.
- Resolution: split the idempotent read to exact `RpcSource`, which returned one current result.

### `SERENA-THR13-LANGUAGE-CACHE`

- Class/severity/status: `environment_drift` / medium / workaround.
- Actual: the target Serena registration retained `languages: []` from the pre-S1-01 checkout. Ignored workspace metadata was corrected, but the running service did not reload it.
- Impact: target symbol navigation was unavailable in this run.
- Fallback: target codebase-memory + Git/`rg`; all external analogs were still independently verified with Serena and `rg`.

## Adversarial decisions and verification

Five stable revision-12 decisions are `ACCEPT`: freshness/identity, family coherence, deterministic identity-versus-staleness semantics, cancellation/generation/failover ownership, and minimum surface/test coverage.

Pre-approval checks:

- `git diff --check` — pass.
- `swift test` — pass, 18 tests and 0 failures.
- Absolute-path/credential scan of the changed design files — pass; no new operator path or secret was added.

No implementation-specific S1-02 test, Maestro, or live probe was run because implementation remains blocked pending explicit approval of revision 12.
