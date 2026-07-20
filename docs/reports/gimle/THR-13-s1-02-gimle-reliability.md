# Gimle reliability report: THR-13 S1-02 revision 16

- Task: THR-13
- Workflow/phase: `analog_change` / `design` rework after closure 2/5
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

`YELLOW` is required because Palace has no ThorChainKit or ZcashLightClientKit mapping, and MarketKit has no explicit indexed commit even though its identity and dominant symbol commit match. Current target and lifecycle truth therefore comes from codebase-memory plus exact Git, Serena, and targeted `rg`. Current TronKit and EvmKit mappings agree with their exact checkouts; pinned Vultisig evidence was verified directly. Target Serena resolves the exact Swift workspace. Revision 16 changes no analog selection: it narrowly binds the final CI workflow definition and zero-run API proof to exact revisions.

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

Independent discovery 2/2 at exact head `0f26a98b715e011e2272ca0e4cd58e5984b1d557` exhausted discovery with no Critical finding. Five IDs are closed: `S02-EVID-001`, `VOP-S02-01`, `VOP-S02-02`, `VOP-S02-03`, and `VOP-S02-06`. Five High IDs remain frozen for closure: `S102-SEC-001`, `S102-SEC-002`, `S02-ARCH-001`, `S102-SEC-003`, and `VOP-S02-04`.

Revision 14 responded without changing the verified analog family:

- three independently indexed request outcomes preserve observed foreign identity across partial Cosmos failures;
- the failure algebra compiles, every result retains family/role/request, and stale-generation leases cannot mutate health;
- synchronous cancellation latches shared by `onCancel`, enrollment, and stable-order commit locking define race-safe linearization without retained unknown IDs;
- typed provider errors have no raw observed-identity associated values;
- live evidence has an exact schema-v1/source/path/head contract with mechanical fixture rejection;
- routine verification is local-first and GitHub-hosted macOS is one explicit final exact-PR-head gate with no PR/push/`main` trigger.

Independent closure 1/5 at exact head `4dd51c36eda2495a5cfb84ec6fd382be131ff187` closed `S102-SEC-001`, `S102-SEC-002`, `S02-ARCH-001`, and `S102-SEC-003`. It retained only `VOP-S02-04`: the schema accepted any eligible selected family instead of requiring the deterministic greatest-Comet-height/first-on-tie winner. Revision 15 requires validator recomputation and adds lower-height and later-equal-height-tie mutants.

The operator's CI transition clarification adds no analog claim. Current GitHub documentation establishes that `workflow_dispatch` must exist on the default branch, workflow runs use the version at the event SHA/ref, and open pull-request events use a merge ref. Revision 15 therefore specifies a separately recorded two-path CI-policy bootstrap whose candidate merge ref has no PR trigger and whose merged commit has no push trigger, verified locally and through read-only zero-run evidence before the product branch is created.

Independent closure 2/5 at exact head `af6b16bd9f9883eb2644dfd0c4ceb5bf8fcc021a` closed `VOP-S02-04` and retained `OP-S02-CI-BOOTSTRAP`. A legal default-`main` dispatch could execute the older bootstrap workflow while checking out the exact product SHA, so checkout/head binding alone did not prove that S1-02 commands ran. Revision 16 requires the same-repository product branch as dispatch ref, exact equality among workflow-definition SHA, event SHA, PR head, expected head, checkout, and run head, plus a stale-default-workflow mutant. It also binds each bootstrap no-run query to the exact event and merge-ref/merge-commit SHA with a bounded HTTP-200 response and `total_count == 0`.

Pre-approval checks:

- `git diff --check` — pass.
- `swift test` — pass at the revision-14 review head, 18 tests and 0 failures; revision-16 documentation re-verification is recorded at its pushed head.
- Absolute-path/credential scan of the changed design files — pass; no new operator path or secret was added.

No implementation-specific S1-02 test, Maestro, hosted workflow, or live probe was run because implementation remains blocked pending independent closure review and explicit approval of revision 16.
