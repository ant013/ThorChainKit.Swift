# S1-02 SwiftUI Integration Recovery

**Status:** approved revision 2; implementation steps 1–5 complete; exact-head local verification and independent review pending.
**Risk:** high because this recovery changes the Example lifecycle immediately before the final S1-02 gate.
**Bindings:** `main` `28c2852cbcf194971b755cc52c911ebd94890b3f`; PR #3 reviewed head `422043e893f01237b4eca89b26676b356d31ab5c`; S1-02 endpoint-policy spec SHA-256 `66da80580e202a5789d6b8026fed694c77030aaacccfe525e25a6f499ab7f486`; accepted recovery interactions `808336db-a3d9-42bf-8694-14cf04e969ae` and `69c96738-82b3-4098-a550-d460c7fe4750`.

## Goal

Make PR #3 mergeable without weakening either authority that now applies:

1. preserve the reviewed S1-02 endpoint-policy behavior and local-first CI gates; and
2. satisfy current `main`'s SwiftUI + Combine boundary before adding the endpoint screen.

Success is an exact product head whose repository-owned Example uses a SwiftUI `App`, SwiftUI views, and Combine-backed presentation only; whose endpoint behavior is unchanged from accepted revision 16; and whose local Reviewer, QA, sole hosted run, and merge evidence all cite that same head.

## Assumptions and Rulings

- The discovery and closure counters remain frozen at **2/2** and **5/5**. This recovery permits only the integration delta below and direct regressions caused by it.
- `docs/specs/platform/swiftui-combine-ui-boundary.md` is the lifecycle and presentation spine.
- Accepted S1-02 revision 16 remains the endpoint-policy spine. Identity precedence, selection, waiters, health, leases, diagnostics, live evidence, and CI execution ownership do not change.
- The already approved S1-01 migration prerequisite is executed inside this recovery before the S1-02 endpoint view is added. Historical S1-01 completion evidence remains historical and is not rewritten.
- TronKit supplies only the `.xcodeproj`/shared-scheme/workspace/root-package topology. Its UIKit lifecycle, controller ownership, demo secrets, and demo lifecycle shortcuts remain rejected.
- There are no open design choices. Material changes require a new revision and approval.

## Scope

### In scope

- merge current `main` into `feature/THR-32-s1-02-endpoint-policy` without force-push;
- resolve the three documentation conflicts by retaining current `main`'s platform boundary and accepted S1-02 endpoint semantics;
- replace `AppDelegate`, `UIWindow`, `MainController`, `DiagnosticsController`, and `EndpointsController`;
- add a SwiftUI `App`, diagnostics and endpoint views, and thin Combine-backed presentation models;
- raise only the Example deployment target to iOS 14 or later;
- preserve workspace/package topology, bundle identity, fixture behavior, accessibility identifiers, exact-UDID runner, and both Maestro flows;
- add a fail-closed platform verifier and mutation coverage;
- refresh exact-head review, QA, PR-body evidence, the single hosted run, and merge evidence.

### Out of scope

- any endpoint-policy semantic change;
- UIKit or SwiftUI in `Sources/ThorChainKit`;
- changing the library iOS 13 floor;
- production activation of `Kit.instance` or exposure of Testing SPI outside tests/Example;
- `/thorchain/*`, Midgard, gRPC, business reads, send/swap/sync lifecycle, persistence, custom-node UI, or Unstoppable integration;
- rewriting historical S1-01 evidence or adding new Example functionality.

## Required Product Shape

```text
iOS Example/Sources/
  ThorChainExampleApp.swift
  Configuration.swift
  Core/ExampleRuntime.swift
  Presentation/DiagnosticsViewModel.swift
  Presentation/EndpointsViewModel.swift
  Views/DiagnosticsView.swift
  Views/EndpointsView.swift
```

- `ThorChainExampleApp` creates the Example-owned runtime and the diagnostics presentation model once through SwiftUI lifecycle ownership.
- `DiagnosticsViewModel` subscribes to the real `lastBlockHeightPublisher`, `syncStatePublisher`, and `accountStatePublisher`, retains their cancellation tokens for its lifetime, and publishes UI state on `MainActor`; it does not own kit state.
- `ExampleRuntime` is the sole Testing SPI importer and session owner. `EndpointsViewModel` requests sanitized snapshots through `ExampleRuntime.endpointSnapshot` and supplies them to `EndpointsView`; it does not import the SPI or reimplement classification, selection, retries, or endpoint ownership.
- `DiagnosticsView` owns navigation/presentation to `EndpointsView`. Stable accessibility identifiers and fixture labels remain unchanged.
- `EndpointsViewModel` owns at most one snapshot operation. A new request and model teardown cancel the prior operation, and a model-owned generation guard rejects late completion from any cancelled or superseded request, so view recomputation cannot create duplicate sessions or stale publication.
- No repository-owned Swift file imports UIKit. No library Swift file imports SwiftUI.

## Affected Areas

Product changes are limited to:

- the seven Example source paths above;
- removal of the four legacy lifecycle/controller paths;
- `iOS Example/iOS Example.xcodeproj/project.pbxproj`;
- the existing S1-01/S1-02 verifier, mutant, and SPI syntax fixtures needed to enforce the boundary;
- the three conflicted S1-02 documentation files, this recovery spec, its plan, integrity hashes, Gimle report, and exact roadmap marker;
- PR #3 body/evidence after the new product head is frozen.

The endpoint pool/probe/health/lease/diagnostic implementation and its existing unit tests may change only for a directly demonstrated integration regression. No such change is currently authorized.

## Acceptance Criteria

1. PR #3 is based on current `main`, has `mergeStateStatus=CLEAN`, and contains no conflict markers.
2. `Sources/ThorChainKit` imports neither UIKit nor SwiftUI; `iOS Example/Sources` contains no UIKit import, lifecycle/view-controller type, or UIKit representable wrapper.
3. The library floor remains iOS 13 and the Example target is iOS 14 or later.
4. The Example has a SwiftUI `App` entry point and SwiftUI views; its diagnostics model retains subscriptions to all three real kit publishers and publishes their values on `MainActor` without becoming a second state owner.
5. Existing S1-01 fixture output, accessibility identifiers, workspace/root-package linkage, exact-UDID runner, and Maestro flow remain green.
6. The S1-02 view renders real sanitized Testing SPI snapshots requested through the sole SPI-owning `ExampleRuntime`; one model-owned operation is cancelled on supersession and teardown, and late results cannot publish. The accepted endpoint acceptance matrix remains unchanged, with no duplicated classification or static outcomes.
7. Existing endpoint tests and every revision-16 verifier/mutant remain green; no endpoint-policy source changes occur unless a direct integration regression is first reproduced.
8. Documentation retains accepted endpoint semantics, incorporates the current platform boundary, updates integrity hashes, and does not claim the source migration shipped before the implementation head exists.
9. Reviewer and QA independently accept the same immutable head. Any push invalidates both attestations.
10. The sole hosted workflow is dispatched only after those local attestations and proves workflow/event/PR/input/checkout/run SHA equality at that same head.

## Tests Before Product Code

The named `Scripts/verify-s1-01.sh --platform-only` mode is added before migration and must fail against the legacy Example. It runs the shared platform boundary, Example observation, and their mutant gates without invoking S1-01's exact source/test/public-symbol closure. Temporary-copy mutants must prove failure for:

- UIKit import in library or Example;
- `UIApplicationDelegate`, `UIWindow`, `UIViewController`, or UIKit representable use;
- SwiftUI import in the library;
- missing SwiftUI `App` entry point;
- Example deployment target below iOS 14;
- library deployment target above or below the approved iOS 13 floor;
- controller-era paths reintroduced into the Xcode project;
- a diagnostics model disconnected from any of the three real kit publishers or replaced by scalar launch snapshots;
- a missing retained Combine cancellation token or missing main-actor UI publication hop;
- a second Testing SPI importer/session owner, a static endpoint view, or a second endpoint-classification owner;
- endpoint operation overlap without cancellation, teardown without cancellation, or late publication after supersession; removing either the cancellation path or generation guard must make the focused S1-02 contract/mutant fail.

After the migration, `Scripts/verify-s1-01.sh --platform-only` must pass. The full no-argument S1-01 verifier remains the historical S1-01 exact-closure gate and is not run against the expanded S1-02 source tree. `Scripts/verify-s1-02.sh` remains the sole exact current-tree source/test/public-symbol closure authority and invokes or duplicates no competing platform scanner.

After implementation, run in this order:

```bash
Scripts/verify-s1-01.sh --platform-only
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --filter LiveNodeProbeTests
swift test --filter EndpointPoolTests
swift test --filter EndpointDiagnosticsTests
swift test
Scripts/verify-s1-02.sh
Scripts/verify-s1-02-ci-policy.sh steady-state --ref <exact-head>
Scripts/test-run-maestro.sh
THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh s1-01
THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh s1-02
```

The opt-in two-provider live gate remains separate. Missing credentials remain `UNRUN`, never pass or skip.

## Analog Delta Matrix

| Field | Decision |
|---|---|
| Analog family | Primary: current-main SwiftUI + Combine boundary. Supporting: accepted S1-02 revision 16, current platform migration/test gate, and TronKit topology. Rejected: TronKit and PR #3 UIKit lifecycle/controller implementations. |
| Coverage | Contract, implementation, composition, consumer, lifecycle/error, tests, trust boundary, and counterexamples are covered by exact Git, Serena, and targeted `rg`; Gimle supplies only verified external-project identity/freshness. |
| Invariants to preserve | Endpoint policy and redaction; actor ownership; inert production Kit; one bounded Testing SPI; workspace/root-package linkage; fixture/accessibility behavior; iOS 13 library floor; manual-only CI. |
| Required differences | SwiftUI `App`; SwiftUI views; thin Combine-backed presentation models; no UIKit; Example iOS 14+; fail-closed platform gate; refreshed exact-head evidence. |
| Rejected differences | Endpoint refactor, duplicate state/classification, new retries or network calls, new public API, UIKit wrappers, SwiftUI in the library, Unstoppable work, or hosted runs before the head is frozen. |
| Failure modes | Duplicate runtime/session, stale task publication, static fixture output, UIKit leakage, accidental library-floor bump, path/hash drift, stale review/QA, or dispatch against a non-mergeable head. |
| Tests before code | Named S1-01 platform-only verifier plus temporary-copy observation mutants; focused S1-02 SPI-ownership/cancellation/stale-result contract mutants; then migration, Example build, both Maestro flows, and S1-02 exact-tree closure. |
| Verification | Narrow-to-broad commands above; diff audit against this matrix; exact GitHub/Paperclip head checks; one hosted run only after local acceptance. |

## Evidence Reliability

Gimle trust is **YELLOW**. Palace has no ThorChainKit project mapping and semantic search did not surface the known TronKit Example symbols. The decision basis is exact target/analog Git, exact-worktree Serena, and targeted `rg`; Gimle results do not decide the design.

## Approval Gate

This document and the companion plan must pass independent adversarial review, be pushed as a documentation-only revision, and receive explicit revision-bound approval before any product branch change.
