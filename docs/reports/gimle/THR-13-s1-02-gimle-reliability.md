# Gimle reliability report: THR-13 S1-02 revision 13

- Task: THR-13
- Workflow/phase: `analog_change` / `adversarial_review`
- Trust: **YELLOW**
- Repository/base: `ThorChainKit.Swift@f7da1ce7b0b16c9a44b339d9bdfc5e2c9404dfc9`
- Branch: `docs/THR-13-network-endpoint-policy`
- Runtime: `native-dev@0e9cf57c00ff970f584256126b500166580e7a72`
- Canonical machine state: `audit/runs/THR-13-S1-02/state.json`

This committed report is the redacted repository view. The canonical machine state and generated report retain operator-local checkout anchors and are not committed.

## Summary

- Calls: 12 — 8 success, 4 warning, 0 error, 0 false-success.
- Useful-call rate: 91.7%.
- Gimle-backed claim agreement: 100%; contradictions: 0%.
- Location validity and freshness coverage for Gimle-backed claims: 100%.
- Analog slices/candidates: 2/10.
- Defects/limitations: 4 — target and lifecycle coverage gaps, one fixed caller query, and one historical Serena environment drift.

`YELLOW` is required because Palace has no ThorChainKit or ZcashLightClientKit mapping, and MarketKit has no explicit indexed commit even though its identity and dominant symbol commit match. Current target and lifecycle truth therefore comes from codebase-memory plus exact Git, Serena, and targeted `rg`. Current TronKit and EvmKit mappings agree with their exact checkouts; pinned Vultisig evidence was verified directly. Target Serena now resolves the exact Swift workspace; the earlier cache defect remains historical evidence.

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
| `E-0010` | `palace.health.status` | success | yes | Runtime remains reachable and clean for revision-13 rework. |
| `E-0011` | `palace.memory.list_projects` | warning | yes | ThorChainKit and ZcashLightClientKit are absent; current-tree fallback required. |
| `E-0012` | `palace.memory.get_project_overview` | warning | yes | MarketKit identity/dominant commit match, but explicit indexed commit/freshness are unavailable. |

## Verified analog family

| Slice | Primary | Supporting | Rejected counterexample |
|---|---|---|---|
| Endpoint family contract | Tron `RpcSource` explicit configuration shape | S1-01 endpoint values/tests; Vultisig THOR LCD/RPC routing | Evm broad URL rotation |
| Probe, health, selection, lease lifecycle | Zcash `LatestBlocksDataProviderImpl` actor ownership/reset/DI/test substitution | Vultisig injected probe seam/tests; S1-01 policy bounds; Vultisig THOR role split | Evm recursive retry/mutable request ID; MarketKit wall-clock scheduler/raw error logging |

The accepted evidence preserves actor-owned serialized state, reset, monotonic height update, DI consumers, and test substitution from Zcash. Waiter-aware coalescing, monotonic TTL/health, generation tokens, immutable leases, typed three-request identity/freshness, and origin-only diagnostics remain explicit S1-02 deltas. The design rejects `urls[0]`, treating HTTP 2xx as identity, broad failover, wall-clock TTL, raw error logging, app-global endpoint ownership, and business-read retries inside the pool.

## Load-bearing claims

| Fact | Verdict/basis | Current anchor |
|---|---|---|
| `F-TARGET-S1-01-ENDPOINTS` | `MATCH`, accepted from codebase-memory plus `rg` | `Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift`, `EndpointPolicy.swift`, `EndpointConfiguration.swift`, and `PublicApiTests.swift` at `f7da1ce` |
| `F-TRON-RPC-SOURCE` | `MATCH`, accepted from Gimle + Serena + `rg` | `TronKit.Swift@aa691bcd`, `Sources/TronKit/Models/RpcSource.swift` and its `Kit` consumer |
| `F-VULTISIG-THOR-ROLES` | `MATCH`, accepted from Serena + `rg` | `vultisig-ios@d3123dbe`, `ThorchainMainnetAPI.swift` |
| `F-VULTISIG-PROBE-SEAM` | `MATCH`, accepted from Serena + `rg` | `vultisig-ios@d3123dbe`, `RPCHealthProbe.swift`, tests, and view-model consumer |
| `F-EVM-BROAD-ROTATION` | `MATCH`, accepted as counterevidence from Gimle + Serena + `rg` | `EvmKit.Swift@be028631`, `NodeApiProvider.swift` |
| `F-POOL-ZCASH-LIFECYCLE` | `MATCH`, accepted from exact Git + Serena + `rg` | `ZcashLightClientKit@ff526fa`, committed `LatestBlocksDataProvider.swift`, DI registrations, consumers, and tests |
| `F-POOL-MARKET-SCHEDULER` | `MATCH`, accepted as counterevidence from exact Git + Serena + `rg` | `MarketKit.Swift@95c92c8`, `Scheduler.swift` and composition |

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

- Class/severity/status: `environment_drift` / medium / fixed.
- Historical actual: the target Serena registration retained `languages: []` from the pre-S1-01 checkout until its service reloaded.
- Current status: target Serena resolves the exact Swift workspace in revision-13 rework.
- Fallback used for the affected earlier claims: target codebase-memory + Git/`rg`; analogs were independently verified with Serena and `rg`.

### `GIMLE-THR13-LIFECYCLE-COVERAGE`

- Class/severity/status: `coverage_gap` / medium / workaround.
- Actual: ZcashLightClientKit is absent from Palace; MarketKit identity is valid but explicit indexed commit/freshness are unavailable.
- Impact: Gimle cannot carry the lifecycle-primary or scheduler-counterexample decision.
- Fallback: codebase-memory first, then exact committed-file Git reads, Serena symbols/references, and targeted `rg` at Zcash `ff526fa` and MarketKit `95c92c8`.

## Adversarial decisions and verification

Independent discovery 1/2 returned ten stable High findings. Their latest state entries remain `REVISE` while revision 13 awaits discovery 2/2: `S02-EVID-001`, `S102-SEC-001`, `S102-SEC-002`, `S02-ARCH-001`, `S102-SEC-003`, `VOP-S02-01`, `VOP-S02-02`, `VOP-S02-03`, `VOP-S02-04`, and `VOP-S02-06`.

Pre-approval checks:

- `git diff --check` — pass.
- `swift test` — pass at the revision-12 review head, 18 tests and 0 failures; revision-13 documentation re-verification is recorded at its pushed head.
- Absolute-path/credential scan of the changed design files — pass; no new operator path or secret was added.

No implementation-specific S1-02 test, Maestro, or live probe was run because implementation remains blocked pending independent discovery 2/2 and explicit approval of revision 13.
