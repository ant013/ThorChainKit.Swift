# THR-32 S1-02 SwiftUI Integration Recovery Plan

**Goal:** reconcile PR #3 with current `main` while preserving accepted endpoint-policy revision 16 and completing the already-approved UIKit-to-SwiftUI Example prerequisite.

**Design authority:** `docs/specs/sprint-01-foundation/S1-02-swiftui-integration-recovery.md`.

**Frozen review budget:** discovery **2/2**; closure **5/5**. Review after implementation is limited to the approved integration delta and direct regressions introduced by it.

## 1. Integrate current main and resolve documentation authority

- Owner: ThorChainSwiftEngineer.
- Dependencies: explicit approval of this plan/spec.
- Test first: capture `origin/main`, PR head, merge base, conflict paths, and prove the workflow has no automatic hosted trigger.
- Implementation: merge current `main` into `feature/THR-32-s1-02-endpoint-policy` without force-push. Resolve the three conflicts by retaining the current platform boundary and the accepted revision-16 endpoint behavior. Update status/hashes only after the complete product tree exists.
- Affected paths: the three conflicted S1-02 documents plus integrity manifest/roadmap fields directly required by the merge.
- Acceptance: the merge has no unresolved marker, no endpoint-policy semantic drift, and no hosted run.
- Check: `git diff --check`; conflict-marker scan; `Scripts/verify-s1-02-ci-policy.sh steady-state --ref HEAD` after the workflow definition is present.
- Commit: `merge: integrate SwiftUI boundary into S1-02`.

## 2. Add the fail-closed platform gate before migration

- Owner: ThorChainSwiftEngineer.
- Dependencies: step 1.
- Test first: temporary-copy mutants for UIKit import/types/representables, core SwiftUI, missing SwiftUI `App`, wrong library/Example floors, controller paths retained in the Xcode project, a diagnostics model disconnected from any real kit publisher, scalar launch snapshots, missing retained cancellation tokens, and missing main-actor UI publication; each must fail.
- Implementation: add one named `Scripts/verify-s1-01.sh --platform-only` mode to the existing S1-01 verifier/mutant surface so S1-02 inherits one platform authority without running S1-01's exact source/test/public-symbol closure. Do not create a second competing scanner.
- Affected paths: `Scripts/verify-s1-01.sh`, its existing platform/observation mutant fixture surface, and only directly required fixtures.
- Acceptance: the positive gate fails on the pre-migration tree and every mutant fails for the intended reason.
- Check: `Scripts/verify-s1-01.sh --platform-only` fails for the intended UIKit reason before migration and passes with every platform/observation mutant rejected after step 3.
- Commit: `test: enforce SwiftUI Example boundary`.

## 3. Migrate the S1-01 Example shell

- Owner: ThorChainSwiftEngineer.
- Dependencies: step 2 red gate.
- Test first: exact project/source scan, Example deployment-target assertion, retained subscriptions to `lastBlockHeightPublisher`, `syncStatePublisher`, and `accountStatePublisher`, MainActor UI publication, exact-destination build, and existing S1-01 Maestro flow.
- Implementation: replace `AppDelegate`, `MainController`, and `DiagnosticsController` with `ThorChainExampleApp`, `DiagnosticsViewModel`, and `DiagnosticsView`; keep `ExampleRuntime`, configuration, bundle identity, workspace/root-package linkage, fixture values, and accessibility identifiers.
- Affected paths: the legacy and replacement Example files plus `iOS Example/iOS Example.xcodeproj/project.pbxproj`.
- Acceptance: SwiftUI owns lifecycle; one Combine-backed diagnostics model retains the three real kit subscriptions and publishes on `MainActor`; no UIKit remains; library floor is iOS 13; Example floor is iOS 14+; S1-01 Maestro remains 1/1.
- Check: `Scripts/verify-s1-01.sh --platform-only`; exact-destination Example build; `Scripts/run-maestro.sh s1-01`.
- Commit: `refactor: migrate Example shell to SwiftUI`.

## 4. Attach the S1-02 endpoint surface to SwiftUI

- Owner: ThorChainSwiftEngineer.
- Dependencies: step 3 green.
- Test first: update the existing SPI/source fixture and mutant gate to require `EndpointsViewModel`/`EndpointsView`, make `ExampleRuntime` the sole Testing SPI importer/session owner, reject controller/static/duplicate-classification paths, and prove one model-owned operation cancels on supersession and teardown and rejects late completion. Mutants removing cancellation or the generation guard must fail.
- Implementation: replace `EndpointsController` with a thin `EndpointsViewModel` and `EndpointsView`; route from `DiagnosticsView`; have the model request sanitized snapshots through `ExampleRuntime.endpointSnapshot`; keep `ExampleRuntime` as the sole Testing SPI importer/session owner; retain at most one model-owned operation with cancellation and a stale-result generation guard.
- Affected paths: `Presentation/EndpointsViewModel.swift`, `Views/EndpointsView.swift`, `Views/DiagnosticsView.swift`, `ExampleRuntime.swift`, Xcode project, and the existing S1-02 SPI syntax fixture/verifier.
- Acceptance: sanitized real snapshots render with unchanged accessibility IDs; superseded, torn-down, or late operations cannot publish; no endpoint policy, retry, business read, raw identity, second SPI owner, or second state owner is added.
- Check: focused Testing SPI/source ownership and operation-lifetime contract/mutants, `Scripts/verify-s1-02.sh`, exact Example build, and `Scripts/run-maestro.sh s1-02`.
- Commit: `feat: present endpoint policy in SwiftUI`.

## 5. Reconcile documentation and exact hashes

- Owner: ThorChainSwiftEngineer.
- Dependencies: steps 3-4 final product shape.
- Test first: compute the spec/plan/test-plan hashes and compare all normative UI statements and file paths.
- Implementation: update the S1-02 spec to the approved recovery revision, merge the current platform clauses into the consolidated test plan/README, update the plan completion evidence, preserve historical S1-01 evidence, and retain the real PR #3 roadmap marker.
- Affected paths: only the approved recovery/spec/plan/test-plan/README/roadmap/Gimle documents.
- Acceptance: no contradictory controller/UIKit guidance remains in normative current-slice documents; all manifest hashes match exact bytes.
- Check: targeted normative `rg`, hash checks, `git diff --check`, secret/absolute-path/co-author scans.
- Commit: `docs: bind S1-02 to SwiftUI recovery`.

## 6. Freeze and verify one product head

- Owner: ThorChainSwiftEngineer.
- Dependencies: steps 1-5.
- Test first: narrow platform and S1-02 checks.
- Implementation: run the complete ordered local gate from the recovery spec, record exact command/exit/artifact/head evidence, push once, and update the PR body. The live provider gate is `UNRUN` when credentials are absent.
- Acceptance: package/strict/full tests, the S1-01 platform-only gate, the S1-02 exact-tree verifier, policy mutants, Example build, runner tests, S1-01 Maestro, and S1-02 Maestro are green at one immutable head; worktree is clean; no hosted run occurred.
- Check: exact commands in the recovery spec plus remote `headRefOid` equality.
- Commit: no evidence-only product commit unless plan/hash/roadmap bytes require it.

## 7. Exact-head review, QA, hosted gate, and merge

- Owners: ThorChainCodeReviewer → ThorChainQAEngineer → ThorChainCTO.
- Dependencies: step 6 frozen head.
- Reviewer: targeted integration-delta pass only; discovery 2/2 and closure 5/5 remain frozen.
- QA: independent fresh-worktree rerun of the S1-01 platform-only gate, package, strict, S1-02 verifier/policy, Example, both Maestro flows, artifacts, and explicit live-gate status.
- CTO: dispatch the sole manual hosted workflow only after unchanged Reviewer/QA acceptance; require workflow/event/PR/input/checkout/run SHA equality; then require `CLEAN`, empty conflict scan, valid plan reference, and exact-head attestations.
- Acceptance: one green hosted run and squash merge using `--match-head-commit`; merge evidence records the reviewed head, Reviewer/QA comments, required check conclusions, and merge commit.
- Commit: GitHub squash merge only; no direct push to `main`.

## Implementation evidence through step 5

- Step 1: `b7cf08b4120613ce12c5f7817a8c7f0be3ac90a0` merged current `main`, resolved only the three approved documentation conflicts, and passed the manual-only workflow policy with all ten mutants rejected.
- Step 2: `96e12ee0cba482c97f56385fd36a30dca787f6e1` added the red-first `--platform-only` gate; the legacy tree failed specifically on UIKit before migration.
- Step 3: `f684a9358c5fbdd7385ff8a3a09841b0212909ba` replaced the UIKit lifecycle/controllers with the SwiftUI app, diagnostics model, and diagnostics view. The platform gate and all fifteen platform/observation mutants pass.
- Step 4: `61cb3df8bbaa46364655985da55a0f75b2af7559` added the thin endpoint model/view and sole-SPI `ExampleRuntime` projection. The exact-tree verifier and all five SPI/operation-lifetime mutants pass.
- Step 5: current documentation preserves the historical S1-01 evidence and the roadmap's real PR #3 marker. Exact-head simulator, Maestro, live-gate status, push, and PR evidence remain owned by step 6.
