# THR-13 — S1-02 Network and Endpoint Policy Plan

## Objective and gate

Implement only S1-02 after explicit approval of spec revision 13. The slice adds typed three-request family probing, fail-closed identity/freshness selection, actor-owned waiter-aware leases, origin-only diagnostics, deterministic fixture acceptance, and a mechanically separate opt-in mainnet gate. Production `Kit.instance` stays inert; S1-04 remains the sole business-read/failover owner.

This plan is tests-before-code and is bound with:

- `docs/specs/sprint-01-foundation/S1-02-network-endpoint-policy.md`;
- `docs/specs/sprint-01-foundation/test-plan.md`;
- `docs/reports/gimle/THR-13-s1-02-gimle-reliability.md`;
- the integrity pins in `docs/specs/sprint-01-foundation/README.md`.

No implementation starts until discovery 2/2 independently ACCEPTs the frozen discovery-1 blocker allowlist and a user confirmation names the resulting exact revision.

## 1. Lock the typed probe and redaction contracts

- Suggested owner: ThorChainSwiftEngineer after approval.
- Dependencies: approved revision-13 gate.
- Test first:
  - add `LiveNodeProbeTests` for the exact node-info, latest-block, and Comet status requests;
  - add expected node info plus a foreign latest-block header, including a healthy sibling;
  - add controlled timeout, 429 with/without `Retry-After`, invalid envelope/field, cancellation, and completion permutations;
  - add base-path retention and prohibited-request counts;
  - add hostile path/body/error/chain-ID sentinel tests across diagnostics serialization.
- Implementation:
  - add indexed typed observations/failures and the nonthrowing `NodeProbing` seam;
  - inject a controlled `HTTPTransporting` boundary into `LiveNodeProbe`;
  - decode and cross-bind Cosmos node-info identity, Cosmos block-header identity/height, and Comet status identity/height/catching-up;
  - append probe paths to configured base paths;
  - expose only `EndpointOrigin` and fixed diagnostic codes.
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
  - cancel one of two, cancel all with a cancellation-insensitive probe, and reset during a shared probe;
  - monotonic TTL, cooldown extension/expiry, identity-TTL interaction, and old-generation rejection;
  - immutable family/identity/role-height/generation lease assertions.
- Implementation:
  - add `EndpointHealth`, `EndpointLease`, and the `EndpointPool` actor;
  - use one shared `(generation, token)` probe task and an actor-owned waiter continuation registry;
  - install cache only for a current token/generation with a remaining waiter;
  - use injected monotonic time for TTL and `retryNotBefore` eligibility;
  - apply the fixed error precedence and original-index/role/request tie order;
  - retain an observed identity lock until `reset()`.
- Affected paths:
  - `Sources/ThorChainKit/Network/EndpointHealth.swift`;
  - `Sources/ThorChainKit/Network/EndpointLease.swift`;
  - `Sources/ThorChainKit/Network/EndpointPool.swift`;
  - `Tests/ThorChainKitTests/EndpointPoolTests.swift`.
- Acceptance: cancellation is prompt per waiter, stale completions never install, and no pool method performs a business read, retry, sleep, or backoff calculation.
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
  - update `.maestro/config.yaml`, runner tests, and CI with separate exact invocations.
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
  - live validator mutants for wrong head/schema, missing family, fixture substitution, sentinel leakage, malformed JSON, and unavailable provider.
- Implementation:
  - add the S1-02 verifier and fixtures;
  - add `verify-s1-02-live.sh` and `verify-s1-02-live-evidence.swift` with exact opt-in environment/schema/output semantics;
  - keep live output beneath ignored `build/s1-02-live/<head>/` and fixture output beneath `build/s1-02-fixture/`.
- Affected paths:
  - `Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt`;
  - `Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt`;
  - `Scripts/verify-s1-02.sh`;
  - `Scripts/verify-s1-02-live.sh`;
  - `Scripts/verify-s1-02-live-evidence.swift`;
  - `.github/workflows/ci.yml`.
- Acceptance: deterministic gates have no skips; live absence is UNRUN, attempted failure is nonzero, and fixture/live evidence are mechanically non-interchangeable.
- Check: `Scripts/verify-s1-02.sh`; run the exact live command from the spec separately when approved providers are available.

## 6. Open one exact-head implementation PR and run role-separated closure

- Dependencies: steps 1–5.
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
  8. `git diff --check`, scope/secrets/conflict-marker audits, required CI, and clean PR merge state.
- Acceptance: CodeReviewer and QA independently cite the same `headRefOid`; any push invalidates their evidence. Closure uses the frozen discovery blocker allowlist and the repository’s five-pass review sequence.

## Handoff sequence

1. CodeReviewer performs discovery 2/2 on the exact revision-13 documentation head and either ACCEPTs or returns only frozen blocker IDs.
2. CTO presents a confirmation bound to the latest Paperclip plan revision only after independent ACCEPT.
3. SwiftEngineer implements tests first and opens the PR; never merges.
4. CodeReviewer and QA perform exact-head closure; neither implements fixes.
5. CTO verifies all role-separated evidence and performs the merge gate.

No role may self-review, infer approval, or move business-read ownership from S1-04 into this slice.
