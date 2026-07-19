# Sprint 1 — adversarial architecture review

## Conclusion

**Current S1-02 decision: REVISE pending discovery 2/2.** The earlier Sprint-wide rounds remain historical evidence, but independent S1-02 discovery 1/2 returned the frozen High-severity allowlist below. Revision 13 is prepared for a second independent exact-head review; it may not be presented for approval or implementation until that review ACCEPTs.

The review was performed against the current versions of the seven slice specs and the consolidated test plan. The ThorChainKit, Unstoppable Wallet, and reference-kit source code was not changed.

## Round 1 — REVISE

The first round found the following load-bearing issues:

| Area | Finding | Resolution |
|---|---|---|
| S1-05 lifecycle | the generation check did not establish FIFO and compare-and-set before publication | introduced `LifecycleCommandBridge`, persistent generation, and generation CAS immediately before atomic save/publication |
| S1-04 failover | retry ownership could split between the HTTP client and endpoint pool | `ReadOperationCoordinator` became the sole owner of the entire complete read operation; a partial operation does not move between families |
| S1-06 adapter | the contracts were described approximately | recorded the exact current `IAdapter`, `IBalanceAdapter`, and `IDepositAdapter` properties and the existing `AdapterManager` lifecycle |
| S1-07 parser | an unnecessary parser protocol had been invented | uses the existing `IAddressParserItem` with `handle`/`isValid`; `AddressParserChain` does not change |
| S1-01/S1-04 API | public and internal testing surfaces were mixed | production API separated from `@_spi(Testing)` transport injection |
| S1-02 probes | Cosmos REST and CometBFT lacked independent role checks | introduced role-specific identity/freshness probes and an immutable family lease |
| S1-03 crypto | checking key length did not establish a valid secp256k1 point; the HdWallet contract was inaccurate | added `secp256k1_ec_pubkey_parse`; recorded the exact `coinType`, `xPrivKey`, `purpose`, `curve`, and compressed-public-key pipeline |
| S1-07 MarketKit | the metadata change had no dedicated test target | added `Package.swift`, a MarketKit test target, and metadata/UID tests to scope |
| S1-07 restore | sequential saves could incorrectly be read as an atomic transaction | recorded that current restore consists of three sequential, non-atomic `Void` saves; no network work is added to this path |

## Round 2 — REVISE

Three high-severity findings remained after the first revision:

1. **Cosmos REST freshness was not established independently of CometBFT.** S1-02 now obtains `cosmosLatestHeight` through Cosmos REST and `cometLatestHeight` through `/status`, checks bounded skew, and creates a lease with separate heights. S1-04 requires exact `x-cosmos-block-height == lease.cosmosReadHeight` for the auth account and every bank page.
2. **`maximumAttempts = 2` broke a valid single-family configuration.** The public default was changed to `nil`, meaning exactly one pass over all configured families; effective attempts for one family is `1`, and a value greater than the number of families is rejected.
3. **Offline UI acceptance was not reproducible.** The second revision proposed a DEBUG-only injected transport and a scenario on a disposable simulator. After the user's Maestro constraint, that solution was deemed obsolete and removed completely from Unstoppable; the current replacement was verified in round 4.

## Round 3 — ACCEPT

The repeat review verified the corrected high-risk boundaries:

- independent Cosmos/Comet heights, bounded skew, and a Cosmos-pinned lease;
- exact height header on the account and all pagination pages;
- correct single-family semantics;
- a single owner for whole-operation failover;
- cancellation, lifecycle generation CAS, and stop barrier;
- exact Unstoppable adapter/parser/restore contracts;
- the then-current DEBUG-only acceptance harness, process termination, cleanup, recovery, and artifact-secret policy.

Result for that revision: **ACCEPT**. The subsequent change to the Maestro scope materially changed the design and required a new review.

## Maestro-boundary revision and round 4 — ACCEPT

The user established a new strict boundary: Maestro applies only to the `iOS Example` in the standalone `ThorChainKit` repository; Maestro does not apply to Unstoppable.

The host `.maestro` flows, runner, acceptance fixtures, DEBUG transport/factory, and launch-argument hooks were removed from the design package. Automated verification of Unstoppable remains in the existing `AppTests`, while the observable product path goes through a concrete manual `Development` checklist.

The first pass of the revision review returned four high-severity findings; all were corrected before reevaluation:

1. The Testing SPI is limited to the `ThorChainKit/iOS Example` fixture target; Unstoppable does not import it.
2. A regular internal production abstraction, `IThorChainKit`, was introduced in WalletCore. Production `ThorChainKit.Kit` and the `AppTests` spy implement the same contract without SPI/DEBUG.
3. The manual checklist explicitly verifies offline relaunch, recovery, remove-wallet/cancellation, and reinstall without cache.
4. The integrity manifest is recalculated after the final design edits.

An independent repeat review verified the current files and returned **ACCEPT** with no critical/high findings. In particular, it confirmed:

- absence of Maestro/acceptance-only runtime in Unstoppable;
- ability to verify exact `start/stop/refresh` and the absence of orphan publication through a normal `IThorChainKit` spy in `AppTests`;
- separation of Example Maestro evidence and manual host evidence;
- complete manual sequence offline → recovery → remove → reinstall.

## S1-02 revision 12 — preparatory CTO self-review, superseded

This slice review is bound to `ThorChainKit.Swift@f7da1ce`, spec revision 12, and the consolidated test-plan revision on branch `docs/THR-13-network-endpoint-policy`. Five stable challenges were closed:

| Decision | Challenge | Resolution |
|---|---|---|
| `D-S02-01` | Are the analog identity and freshness claims current enough for a high-risk boundary? | Tron and Evm Gimle mappings match the exact local heads and were independently verified with Serena/`rg`; pinned Vultisig was verified directly. ThorChainKit Palace coverage and target Serena caching remain explicit YELLOW limitations, so target truth comes from codebase-memory plus Git/`rg`. |
| `D-S02-02` | Is there one coherent family rather than an incompatible collage? | Tron remains the configuration spine; Vultisig supplies only the injected probe seam and THOR LCD/RPC role evidence; S1-01 supplies the inherited local contract. Every conflict is stated in the delta matrix, and Evm broad rotation remains rejected. |
| `D-S02-03` | Do foreign identity and stale health have deterministic, noncontradictory outcomes? | Revision 12 removes the prior contradiction: mixed/foreign identity locks the pool, while a correctly identified stale/catching-up family may be excluded for another verified family. Fixed error precedence and configured-order tie breaking remove task-completion nondeterminism. |
| `D-S02-04` | Can cancellation, old probe completion, or split failover ownership install invalid state or duplicate retries? | Coalesced actor probes, TTL blocking, generation invalidation, and cancellation-with-no-health-effect are required tests. `EndpointPool` performs no business read; S1-04 alone owns whole-operation attempts and exhaustion. |
| `D-S02-05` | Is the change and test surface the smallest sufficient delta? | Scope stays within the six network files, one test file, Example controller/flow, and slice verification assets. `/thorchain/*`, Midgard, gRPC, persisted health, custom-node UI, broadcast, and host-app integration remain excluded. |

Result at the time: preparatory **ACCEPT** by the CTO workflow. The board later clarified that this self-check did not satisfy role-separated discovery and could not be presented for approval. Independent discovery 1/2 supersedes it.

## S1-02 independent discovery 1/2 — REVISE

The CodeReviewer reproduced all four artifact digests at exact pushed head `224141f24a7348ddab5d217e98477457f784cd08`, verified a clean four-document delta, passed `git diff --check` and all 18 package tests, and returned no Critical finding. The following ten High IDs are the frozen candidate allowlist for discovery 2/2:

| Stable ID | Finding | Revision-13 response awaiting independent verification |
|---|---|---|
| `S02-EVID-001` | Vultisig’s stateless probe was incorrectly assigned lifecycle ownership. | Zcash `LatestBlocksDataProviderImpl@ff526fa` is now the actor ownership/reset/DI/test spine; Vultisig is supporting probe seam only; MarketKit/Evm are rejected counterexamples. |
| `S102-SEC-001` | Cosmos latest-block identity was not bound to node info/lease height. | `block.header.chain_id == node_info.network == comet.network == expectedChainId` is mandatory; a foreign block header locks the pool despite a healthy sibling. |
| `S102-SEC-002` | Throwing probe/failure algebra, precedence, diagnostics, and cooldown semantics were incomplete. | Indexed typed per-role/request outcomes, fixed complete precedence, identity-lock rules, and monotonic explicit `retryNotBefore` semantics are specified with permutations. |
| `S02-ARCH-001` | Shared-probe cancellation ownership was undefined. | An actor-owned waiter registry plus `(generation, token)` shared task defines cancel-one, cancel-all, reset, and cache installation atomically. |
| `S102-SEC-003` | Diagnostics could expose secret-bearing URL paths and arbitrary text. | Origin-only diagnostics forbid path/query/fragment/userinfo, body, raw foreign identity, arbitrary error text, and `localizedDescription`; sentinel tests cover every artifact/UI/log surface. |
| `VOP-S02-01` | Maestro runner ignored the requested flow. | One `s1-01|s1-02` token maps to one exact YAML/output root; runner tests and CI execute both paths independently. |
| `VOP-S02-02` | The separate Example could not execute internal policy. | One bounded Example/test-only Testing SPI session calls the real pool while production `Kit` remains inert; syntax/import/static-logic gates pin the seam. |
| `VOP-S02-03` | `LiveNodeProbe` lacked controlled product-level contract tests. | Dedicated controlled-transport tests pin exact requests, decoders, statuses, cancellation, base paths, and zero prohibited requests/retries. |
| `VOP-S02-04` | Mainnet verification was prose-only. | Exact environment command, two-family contract, output path/schema/head binding, validator, redaction, and nonzero failure/UNRUN semantics are defined separately from fixture evidence. |
| `VOP-S02-06` | The bundle lacked a revision-bound implementation plan and current manifest pins. | A tests-before-code affected-file plan is added and spec/test-plan/plan digests are refreshed in the integrity manifest before the second review. |

The non-blocking monotonic clock, base-path, cooldown/best-height, and S1-04 `attemptsExhausted` notes are also incorporated: monotonic time and path appending are explicit, cooldown selection is specified, and S1-02 no longer declares `attemptsExhausted`.

Result: **REVISE remains active** until CodeReviewer discovery 2/2 verifies the exact pushed revision-13 head and returns ACCEPT or frozen blocker IDs.

Revision-13 pre-handoff verification:

- `git diff --check` and docs-only scope audit — pass;
- integrity manifest reproduces the exact spec, test-plan, and implementation-plan digests — pass;
- added-line operator-path/credential scan — pass;
- `swift test` — 18 tests, 0 failures;
- `Scripts/verify-s1-01.sh` — pass, including topology, imports, symbols, exact discovery/xUnit/execution, skip/factory/value/mutant gates, strict build, public consumer, Example workspace, CI provenance, and redacted Gimle report.

## Decision constraints

- Gimle trust remains `RED`; all load-bearing conclusions were reverified in the exact current trees through Serena and targeted `rg`.
- Maestro CLI is not installed on the current machine, so the Example YAML and runner currently exist only as an asserted design contract and apply exclusively to the future `ThorChainKit/iOS Example`.
- The user's term `Meteora` was interpreted as Maestro. If it refers to another internal tool, the UI layer must be rebound to its actual contract before implementation.
- Implementation remains blocked pending independent S1-02 discovery 2/2 ACCEPT and explicit revision-bound user approval.
- For S1-02 revision 13 specifically, Gimle trust is `YELLOW`, not the earlier Sprint-wide `RED`: current Tron/Evm mappings agree with exact checkouts; ThorChainKit and Zcash lifecycle evidence lack Palace mappings, and MarketKit has no explicit indexed commit. Codebase-memory plus exact Git/Serena/`rg` provides the recorded fallback basis.
