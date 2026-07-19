# THR-13 — S1-02 Network and Endpoint Policy Plan

## Objective and gate

Implement only S1-02 after explicit approval of spec revision 16. The slice adds independently retained three-request family probing, fail-closed identity/freshness selection, cancellation-linearized actor leases, generation-bound health, origin-only diagnostics, deterministic fixture acceptance, an exact-schema and deterministic-winner opt-in mainnet gate, and local-first verification with one workflow-definition-bound final hosted macOS run. Production `Kit.instance` stays inert; S1-04 remains the sole business-read/failover owner.

This plan is tests-before-code and is bound with:

- `docs/specs/sprint-01-foundation/S1-02-network-endpoint-policy.md`;
- `docs/specs/sprint-01-foundation/test-plan.md`;
- `docs/reports/gimle/THR-13-s1-02-gimle-reliability.md`;
- the integrity pins in `docs/specs/sprint-01-foundation/README.md`.

Discovery is exhausted at 2/2. Closure 1/5 closed four frozen IDs and closure 2/5 closed `VOP-S02-04`; only `OP-S02-CI-BOOTSTRAP` remains open. No implementation starts until independent closure review ACCEPTs revision 16's exact workflow-definition binding and mechanical zero-run proof, then a user confirmation names that exact pushed revision.

## 0. Bootstrap manual dispatch on `main` without a hosted run

- Suggested owner: ThorChainSwiftEngineer after revision-16 approval; CodeReviewer reviews, CTO merges.
- Dependencies: exact revision-16 approval; this precedes every product implementation step.
- Basis: GitHub requires `workflow_dispatch` to exist on the default branch, resolves each run from its event SHA/ref, and uses `refs/pull/<number>/merge` for open pull-request events. The cited official workflow/event references are linked from the spec.
- Test first:
  - add bootstrap mode to `Scripts/verify-s1-02-ci-policy.sh` and mutants for every automatic trigger, a third changed path, trigger-unrelated job drift, missing dispatch input, mutable checkout, mismatched head, and duplicate `main` execution;
  - require exact base/head inputs and parse both workflow revisions from Git;
  - after PR creation and every update, retain the current merge-ref SHA and query `event=pull_request&head_sha=<merge-ref-sha>&per_page=1`; after merge query `event=push&head_sha=<merge-commit-sha>&per_page=1`; require HTTP 200 and `total_count == 0` for every tuple and retain the filters, UTC observation time, and bounded responses.
- Implementation:
  - create a branch from then-current `main` changing only `.github/workflows/ci.yml` and `Scripts/verify-s1-02-ci-policy.sh`;
  - replace `pull_request`/`push: main` with the final required `workflow_dispatch` inputs while preserving existing job commands except the dispatch preflight;
  - open and update the CI-policy PR: its merge-ref workflow has no PR trigger, so it allocates no runner;
  - after exact-head CodeReviewer ACCEPT and local CTO verification, merge it: its `main` workflow has no push trigger, so it allocates no runner;
  - record bootstrap PR number, base/head, every observed merge-ref SHA, merge commit, local commands, reviewer evidence, and exact-tuple zero-run API evidence separately; do not update the roadmap Implemented marker.
- Acceptance: `workflow_dispatch` is available on default `main` without consuming hosted minutes, and the later product branch starts from that merge commit.
- Narrow checks: `Scripts/verify-s1-02-ci-policy.sh bootstrap --base-ref <pre-bootstrap-main> --candidate-ref <bootstrap-head>` plus read-only GitHub runs-API queries.

## 1. Lock the typed probe and redaction contracts

- Suggested owner: ThorChainSwiftEngineer after approval.
- Dependencies: completed bootstrap step 0 and product branch from updated `main`.
- Test first:
  - add `LiveNodeProbeTests` for the exact node-info, latest-block, and Comet status requests;
  - add expected node info plus a foreign latest-block header, including a healthy sibling;
  - add foreign node info plus latest-block timeout/invalid, missing/duplicate/extra/request-kind-mismatched outcomes, and strict-concurrency compilation of the complete algebra;
  - add controlled timeout, 429 with/without `Retry-After`, invalid envelope/field, cancellation, and completion permutations;
  - add base-path retention and prohibited-request counts;
  - add hostile path/body/error/chain-ID sentinel tests across diagnostics serialization.
- Implementation:
  - add `RoleProbeFailure: Error`, one indexed typed result for each independent request, and the nonthrowing `NodeProbing` seam that always returns exactly three outcomes;
  - inject a controlled `HTTPTransporting` boundary into `LiveNodeProbe`;
  - decode and retain Cosmos node-info identity, Cosmos block-header identity/height, and Comet status identity/height/catching-up independently, then classify every observed identity before partial failures;
  - append probe paths to configured base paths;
  - expose only `EndpointOrigin`, local expected identity, and fixed diagnostic codes; no provider error stores an actual/raw observed identity.
- Affected paths:
  - `Sources/ThorChainKit/Network/NodeProbing.swift`;
  - `Sources/ThorChainKit/Network/LiveNodeProbe.swift`;
  - `Sources/ThorChainKit/Network/EndpointDiagnostics.swift`;
  - `Sources/ThorChainKit/Network/ProviderError.swift`;
  - `Tests/ThorChainKitTests/LiveNodeProbeTests.swift`;
  - `Tests/ThorChainKitTests/EndpointDiagnosticsTests.swift`.
- Acceptance: no arbitrary `Error`, observed raw identity, URL path, body, or forbidden request escapes the boundary.
- Narrow check: `swift test --filter LiveNodeProbeTests` then `swift test --filter EndpointDiagnosticsTests`.

## 2. Implement actor-owned selection, waiters, health, and immutable leases

- Dependencies: step 1.
- Test first:
  - same identity/healthy heights, mixed/foreign pool lock, catching-up/stale fallback, highest-height/tie/lag selection;
  - healthy sibling plus timeout/429/invalid versus foreign completion permutations;
  - concurrent first lease and TTL revalidation coalescing;
  - pre-cancelled lease, cancellation before/after enrollment, cancellation racing completion through controlled barriers, cancel one of two, cancel all with a cancellation-insensitive probe, and reset during a shared probe;
  - monotonic TTL, cooldown extension/expiry, identity-TTL interaction, stale completion rejection, and `recordFailure` rejection for a pre-reset lease;
  - immutable family/identity/role-height/generation lease assertions.
- Implementation:
  - add `EndpointHealth`, `EndpointLease`, and the `EndpointPool` actor;
  - use one shared `(generation, token)` probe task, actor-owned waiter continuations, and one synchronous `CancellationLatch` per call;
  - share that latch among `onCancel`, actor enrollment, and stable waiter-ID-order commit locking; unknown cancellation messages are no-ops and retain no orphan state;
  - install cache only for a current token/generation with a remaining noncancelled waiter;
  - use injected monotonic time for TTL and `retryNotBefore` eligibility;
  - apply the fixed error precedence and original-index/role/request tie order;
  - retain an observed identity lock until `reset()` and require the originating current-generation lease for health mutation.
- Affected paths:
  - `Sources/ThorChainKit/Network/EndpointHealth.swift`;
  - `Sources/ThorChainKit/Network/EndpointLease.swift`;
  - `Sources/ThorChainKit/Network/EndpointPool.swift`;
  - `Tests/ThorChainKitTests/EndpointPoolTests.swift`.
- Acceptance: cancellation is prompt and race-safe per waiter, stale completions/leases never mutate current state, and no pool method performs a business read, retry, sleep, or backoff calculation.
- Narrow check: `swift test --filter EndpointPoolTests`.

## 3. Add the sole Example-only executable seam

- Dependencies: steps 1–2.
- Test first:
  - syntax gate fails until one `@_spi(Testing) TestingEndpointPolicySession` delegates to the real pool;
  - reject SPI imports outside `ThorChainKitTests` and `iOS Example`;
  - reject duplicated classification/static outcome labels in the Example;
  - verify the inert S1-01 `Kit` snapshot remains unchanged.
- Implementation:
  - add the bounded Testing SPI session/snapshot and enumerated fixture scripts;
  - update `ExampleRuntime` to own the real session beside inert `Kit`;
  - add `EndpointsController`, navigation, and accessibility identifiers;
  - update the Xcode project source list.
- Affected paths:
  - `Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift`;
  - `iOS Example/Sources/Core/ExampleRuntime.swift`;
  - `iOS Example/Sources/Controllers/EndpointsController.swift`;
  - `iOS Example/Sources/AppDelegate.swift`;
  - `iOS Example/iOS Example.xcodeproj/project.pbxproj`;
  - `Tests/ThorChainKitTests/Fixtures/S1-02-spi-syntax.txt`.
- Acceptance: the UI consumes actual S1-02 snapshots and cannot expose internal pool/probe types or perform network/business work.
- Narrow check: the S1-02 SPI/source audit inside `Scripts/verify-s1-02.sh`, then exact-destination Example build.

## 4. Make Maestro execution slice-exact

- Dependencies: step 3.
- Test first:
  - extend runner shims to prove `s1-01` executes only `00-launch-foundation.yaml` and `s1-02` executes only `01-endpoint-policy.yaml`;
  - reject no argument, raw paths, extra arguments, unknown slices, duplicate/multiple flows, output reuse, and cross-slice JUnit/artifacts;
  - preserve every S1-01 provenance, simulator, containment, symlink, JUnit, OCR, and secret canary.
- Implementation:
  - add the S1-02 accessibility flow;
  - make `run-maestro.sh` map one allowlisted slice token to one exact YAML and slice-versioned output root;
  - update `.maestro/config.yaml` and runner tests with separate exact invocations; routine execution remains local and the final hosted job invokes both once.
- Affected paths:
  - `.maestro/config.yaml`;
  - `.maestro/flows/01-endpoint-policy.yaml`;
  - `Scripts/run-maestro.sh`;
  - `Scripts/test-run-maestro.sh`;
  - `.github/workflows/ci.yml`.
- Acceptance: the requested flow is the only flow Maestro receives and fixture artifacts pass the sentinel scanner.
- Narrow check: `Scripts/test-run-maestro.sh`, then `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh s1-02`.

## 5. Add exact deterministic and opt-in live gates

- Dependencies: steps 1–4.
- Test first:
  - exact discovered/non-skipped allowlists for `EndpointPoolTests`, `LiveNodeProbeTests`, and `EndpointDiagnosticsTests`;
  - public symbol subset/exact-current-slice fixtures and production factory inertness;
  - live validator mutants for wrong source/head/path/schema, missing/extra/duplicate keys or families, wrong types/literals/arithmetic/origins, fixture substitution, sentinel leakage, malformed JSON, unavailable provider, selection of the lower-Comet-height family, and selection of the later family on an equal-height tie.
- Implementation:
  - add the S1-02 verifier and fixtures;
  - add `verify-s1-02-live.sh` and `verify-s1-02-live-evidence.swift` with exact schema-v1 keys/types/literals, duplicate/unknown-key rejection, source/path/head binding, arithmetic, configuration-order retention, independent recomputation of the greatest-Comet-height/first-on-tie winner, opt-in environment, and atomic output semantics;
  - keep live output beneath ignored `build/s1-02-live/<head>/` and fixture output beneath `build/s1-02-fixture/`.
- Affected paths:
  - `Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt`;
  - `Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt`;
  - `Scripts/verify-s1-02.sh`;
  - `Scripts/verify-s1-02-live.sh`;
  - `Scripts/verify-s1-02-live-evidence.swift`;
  - `.github/workflows/ci.yml`.
- Acceptance: deterministic gates have no skips; live absence is UNRUN, attempted failure is nonzero, exact source/schema/path validators make fixture/live evidence mechanically non-interchangeable, and lower-height or later-on-tie selections fail validation.
- Check: `Scripts/verify-s1-02.sh`; run the exact live command from the spec separately when approved providers are available.

## 6. Enforce local-first CI and the one-run hosted budget

- Dependencies: steps 1–5.
- Test first:
  - run steady-state policy mutants for `pull_request`, `pull_request_target`, `push`, `schedule`, omitted dispatch inputs, mutable branch checkout, mismatched PR head, a stale bootstrap/default-`main` workflow definition that checks out the right product SHA, and a duplicate `main` job;
  - prove the manual workflow requires `pr_number`, `expected_head_sha`, and confirmation token `FINAL_S1_02_GATE`, is dispatched against the same-repository PR head branch, checks an open PR targeting `main`, and fails closed unless `github.workflow_sha`, `github.sha`, `headRefOid`, and `expected_head_sha` all equal its exact current SHA;
  - prove routine local evidence records the exact head/command/exit status and the hosted job does not invoke the opt-in live probe.
- Implementation:
  - preserve the bootstrap's `workflow_dispatch`-only trigger and extend the product-head workflow definition with S1-02 commands; reject a dispatch whose executing workflow/event SHA is not the exact product head before any product command runs;
  - run package, strict-concurrency, verifier, Example simulator, and both Maestro flows once in the final hosted job;
  - record workflow run ID/URL, PR, dispatched branch/ref, `github.workflow_ref`, `github.workflow_sha`, `github.sha`, checkout SHA, and run `head_sha`; every SHA equals the exact product head. Never trigger on intermediate pushes or the verified merge/push to `main`.
- Affected paths:
  - `.github/workflows/ci.yml`;
  - `Scripts/verify-s1-02-ci-policy.sh`;
  - `Scripts/verify-s1-02.sh`.
- Acceptance: routine verification is local, automatic hosted macOS triggers fail the policy verifier, a stale workflow-definition mutant fails before product verification, and only the CTO/operator can dispatch one final exact-PR-head gate immediately before merge. Self-hosted Mac support is deferred.
- Narrow check: `Scripts/verify-s1-02-ci-policy.sh steady-state --ref HEAD`.

## 7. Open one exact-head implementation PR and run role-separated closure

- Dependencies: steps 1–6.
- Implementation: push the implementation branch, open the PR, and update only the S1-02 roadmap marker with the real PR number/date.
- Affected paths: implementation/test/acceptance paths above, `docs/roadmap/sprint-01-foundation.md`, and this plan’s completion evidence.
- Verification order:
  1. `swift build`;
  2. the three narrow test classes;
  3. `swift test`;
  4. `Scripts/verify-s1-02.sh`;
  5. `Scripts/test-run-maestro.sh`;
  6. exact-destination Example build and `Scripts/run-maestro.sh s1-02`;
  7. opt-in live gate, recorded separately;
  8. exact local CodeReviewer and QA evidence at one `headRefOid`;
  9. one explicit final hosted macOS dispatch for that PR/head;
  10. QA and CodeReviewer append exact-head attestations citing their local outputs plus the hosted run URL/status/SHA, then the CTO checks `git diff --check`, scope/secrets/conflict-marker audits and clean PR merge state.
- Acceptance: CodeReviewer and QA independently cite the same local-command outputs, hosted run, and `headRefOid`; any push invalidates all three. The hosted run URL/status/SHA matches that head, and merge/push to `main` does not repeat it. Closure uses the frozen discovery blocker allowlist and the repository’s five-pass review sequence.

## Handoff sequence

1. CodeReviewer performs closure 3/5 on the exact revision-16 documentation head, limited to `OP-S02-CI-BOOTSTRAP` and direct Critical/High regressions caused by the correction, and either ACCEPTs or returns the stable blocker/requirement gap.
2. CTO presents a confirmation bound to the latest Paperclip plan revision only after independent ACCEPT.
3. After approval, SwiftEngineer opens the two-path CI-policy bootstrap PR; CodeReviewer reviews its exact head, and CTO verifies/records zero PR/push runs before merging it.
4. SwiftEngineer creates the product branch from post-bootstrap `main`, implements tests first, and opens the separate product PR; never merges.
5. CodeReviewer and QA perform local exact-head product closure; neither implements fixes.
6. After the sole hosted exact-product-head run, QA and CodeReviewer append citations binding that run to their unchanged local evidence; the CTO then performs the merge gate. The roadmap marker names only this product PR.

No role may self-review, infer approval, or move business-read ownership from S1-04 into this slice.
