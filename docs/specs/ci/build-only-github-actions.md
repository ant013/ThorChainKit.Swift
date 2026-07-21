# Build-only GitHub Actions policy

**Status:** evidence-complete design revision 2, spec-only. Explicit operator
approval of this revision is required before implementation. GitHub Actions
remains disabled while this specification is reviewed.

## Goal

Reduce hosted macOS usage to one bounded compile check of the final pull-request
head. GitHub Actions proves only that the repository-owned iOS Example and its
local ThorChainKit package compile together on a clean hosted runner. It is not
an acceptance-test environment.

Success means a manually dispatched run performs an exact-head preflight,
checks out that immutable head, invokes one `xcodebuild ... build`, and does
nothing else that exercises product behavior. All tests and acceptance evidence
remain local to the operator MacBook.

## Assumptions

- The operator wants one hosted reproducibility build per final PR head, not a
  second copy of local validation.
- The repository-owned `iOS Example` is the most useful single build target:
  compiling its workspace also compiles the linked ThorChainKit package.
- A generic iOS Simulator destination compiles the app without selecting,
  booting, installing, or downloading a simulator device/runtime.
- Local Reviewer and QA evidence is complete and bound to the same exact head
  before the hosted build is dispatched.
- A ten-minute hard timeout is preferable to an unbounded or retried hosted
  build. A timeout is a failed build and does not authorize an automatic retry.

## Governing policy

This document supersedes earlier slice-specific requirements that use GitHub
Actions for package tests, verifier scripts, mutants, fixture acceptance,
Maestro, simulator-device acceptance, or duplicated local gates. Those gates
continue to exist and run on the MacBook when required by a slice; they are not
run by GitHub Actions.

GitHub Actions remains disabled at repository level until the implementation of
this policy has been reviewed and approved. Re-enabling it is a separate,
explicit operator action after the build-only workflow is present on `main`.

### Hosted workflow

The workflow has these properties:

1. `workflow_dispatch` is its only trigger. There is no `push`, `pull_request`,
   `pull_request_target`, `merge_group`, `schedule`, or reusable automatic
   trigger.
2. It accepts a same-repository PR number, an exact lowercase 40-character head
   SHA, and an explicit confirmation token.
3. A read-only preflight verifies that the PR is open against `main`, the
   dispatched branch is its head branch, and the input, event, workflow, and
   live PR head SHAs are identical.
4. It checks out only that exact SHA with shallow history and without persisted
   credentials.
5. It has one hosted macOS job, one build command, `contents: read`, and
   `timeout-minutes: 10`.
6. A per-PR concurrency group cancels an older accidental in-progress build for
   the same PR.
7. It performs this single product command:

   ```bash
   xcodebuild \
     -workspace 'iOS Example/iOS Example.xcworkspace' \
     -scheme 'iOS Example' \
     -destination 'generic/platform=iOS Simulator' \
     CODE_SIGNING_ALLOWED=NO \
     build
   ```

The workflow must not install tools, select or boot a simulator, run a package
test target, launch the app, upload artifacts, scan outputs, or repeat local
acceptance. It has no Java, Maestro, ripgrep provisioning, `simctl`, test-result
bundle, fixture, verifier, mutant, or `Scripts/run-*` / `Scripts/test-*`
execution.

The generic destination may use the iOS platform support bundled with the
selected Xcode installation, but it must not address a simulator runtime, model,
or UDID and must not call `xcrun simctl`.

### Local acceptance

Before the one hosted build, the Engineer, CodeReviewer, and QA run the slice's
required tests on the MacBook. Their PR evidence records the exact head SHA,
commands, exit statuses, and concise results. This includes, when applicable:

- focused and full package tests;
- warnings-as-errors and platform/public API checks;
- verifier and mutant scripts;
- the Example build and real Maestro flow on the approved local simulator;
- secret, provenance, and diff-hygiene gates.

The hosted build neither replaces missing local evidence nor reruns it. A code
change after local acceptance invalidates that evidence and requires local
revalidation before a new final hosted build.

### Dispatch ownership and budget

- Only the CTO/operator dispatches the build, once, after exact-head local
  Reviewer and QA acceptance and immediately before merge.
- Updating a PR does not run Actions automatically.
- A failed run is diagnosed from its existing log. No automatic retry, matrix,
  parallel job, fallback runner, or duplicate build is allowed.
- A deliberate second manual run requires operator approval and a recorded
  reason.
- The maximum wall-clock duration of one attempt is ten minutes; GitHub may
  apply its current macOS billing multiplier when debiting plan minutes. Normal
  success is expected to finish below the wall-clock cap.

## Scope and affected areas

| Path/area | Intended implementation |
|---|---|
| `.github/workflows/ci.yml` | Replace the current cumulative test/acceptance job with the manual one-job, one-command build policy above. |
| `Scripts/verify-s1-02-ci-policy.sh` | Keep the stable path but replace obsolete S1-02 hosted-acceptance assertions with a fast local static build-only policy check. It is never invoked by Actions. |
| PR/review procedure | Require exact-head MacBook evidence before the sole manual hosted build. |
| Repository Actions setting | Keep disabled during implementation/review; enable only after explicit operator approval and after the build-only workflow reaches `main`. |

Historical slice specs and reports remain immutable evidence of what was
accepted at the time. Where they prescribe hosted tests, this newer governing
policy overrides only the execution location: those checks move to the MacBook,
while their acceptance semantics remain unchanged.

## Verified analog family and delta matrix

The target repository is indexed as codebase-memory project
`Users-ant013-Data-AI-thorchain`, and the load-bearing facts below were checked
independently with Serena and targeted current-tree reads at design base
`11f03094112bd280bf108abd66d5a8fddf495ef7`.

Palace/Gimle has no registered ThorChainKit project. Bounded exact-ref searches
of the current TronKit and EvmKit analog repositories found no `.github`
workflow family to reuse. The design therefore uses the current ThorChainKit
control plane as its coherent primary spine instead of inventing or importing a
foreign CI lifecycle.

### Slice `CI-BUILD-ONLY` — manual exact-head hosted build

| Field | Decision |
|---|---|
| Analog family | Primary: the existing manual exact-head dispatch, live-PR preflight, read-only permission, and pinned checkout in `.github/workflows/ci.yml`. Supporting build shape: the existing Example workspace/scheme/no-signing `xcodebuild ... build` in `Scripts/run-maestro.sh`. Supporting policy seam: the existing local workflow-contract enforcement in `Scripts/verify-s1-02-ci-policy.sh`. Rejected counterexample: the cumulative hosted Java/ripgrep/simulator/test/mutant/Maestro block in the current workflow. |
| Coverage | The primary covers contract, composition, dispatch lifecycle, consumer inputs, error closure, trust boundary, and immutable head binding. The Example build covers implementation, package/app dependency direction, and the local build seam. The policy verifier covers static contract tests and forbidden-state rejection. The rejected cumulative job supplies the explicit counterexample. |
| Invariants to preserve | Manual-only trigger; same-repository open PR against `main`; equality of input, event, workflow, live PR, and checkout head; pinned checkout action; read-only repository permission; repository-owned Example workspace and scheme; `CODE_SIGNING_ALLOWED=NO`; no product source changes. |
| Required differences | Rename the job around build-only responsibility; use confirmation token `FINAL_BUILD_ONLY`; shallow checkout with no persisted credentials; add one per-PR concurrency group and `timeout-minutes: 10`; replace every hosted acceptance/tool/device step with exactly one generic-destination Example build; rewrite the stable policy-verifier path as a local-only build-policy check. |
| Rejected differences | No new workflow, runner, cache, matrix, artifact, dependency, source/test change, automatic trigger, test deletion, local-gate weakening, script rename, simulator selection, package test, Maestro installation, or Actions activation. |
| Failure modes | Wrong/stale SHA or fork PR fails preflight before checkout/build; duplicate dispatch cancels the older same-PR run; dependency resolution/build failure exits the sole job; ten-minute wall-clock timeout fails closed; policy drift is caught locally before dispatch; no automatic retry is permitted. |
| Tests before code | Current-tree observation proves the old workflow contains the forbidden hosted categories at lines 83–190; policy canaries must fail for an automatic trigger, mutable checkout, extra job/build, timeout removal, repository-script call, test action, simulator/device command, tool installation, and artifact upload. |
| Verification | Local policy verifier at exact implementation head; YAML structure validation; exact generic-destination Example build once on the MacBook; diff audit limited to the approved spec, workflow, and stable verifier; repository Actions permission remains disabled and no run is dispatched. |

The Example analog currently uses an exact UDID and continues into install,
launch, and Maestro. Only its workspace, scheme, no-signing, and `build` shape
is inherited. The required hosted delta deliberately changes the destination to
`generic/platform=iOS Simulator` and inherits none of the device lifecycle.

The current policy verifier encodes obsolete S1-02/S1-03 hosted acceptance.
Keeping its path avoids wider caller/document churn, but its contents are
replaced by the approved build-only static contract and it is removed from the
workflow itself.

## Test plan

The policy verifier is tested locally with in-memory temporary workflow text;
those checks do not invoke GitHub Actions, Xcode, a simulator, or product tests.
The baseline approved workflow must pass, while one change per canary must fail:

- automatic event trigger or second job;
- missing timeout/concurrency/read-only permission;
- mutable ref, persisted credentials, or incomplete exact-head preflight;
- second or changed `xcodebuild` command;
- `test`, `-only-testing`, result-bundle, repository-script, verifier, mutant,
  fixture, Maestro, Java/ripgrep/tool installation, `simctl`, UDID/runtime/model,
  scan, artifact, or deployment behavior.

After static policy checks, run exactly one local build command:

```bash
xcodebuild \
  -workspace 'iOS Example/iOS Example.xcworkspace' \
  -scheme 'iOS Example' \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The implementation evidence records command, exit status, implementation head,
and elapsed time. No hosted verification run is part of this test plan.

## Adversarial review resolution

- A plain branch checkout would permit stale or unintended builds, so the
  existing exact-head/live-PR preflight remains the primary spine.
- A package-only build would not prove Example integration; the single Example
  workspace build compiles both the app and linked local package.
- Reusing the current exact-UDID build would retain simulator provisioning; the
  generic destination closes that cost and lifecycle leak.
- Calling the policy verifier from Actions would violate the one-product-command
  boundary; it remains a local Reviewer/QA check only.
- Renaming the historical verifier would create unrelated documentation/caller
  churn; its stable path is retained and its obsolete contents replaced.
- Ten minutes describes the job's wall-clock timeout, not guaranteed billed
  plan minutes; the budget wording now preserves that distinction.
- The smaller alternative of deleting Actions entirely conflicts with the
  operator's explicit requirement to retain one clean hosted build, so the
  one-job/one-build design is the minimum accepted surface.

## Out of scope

- Product source, package API, Example behavior, test, fixture, Maestro, and
  roadmap changes.
- Weakening, deleting, or skipping local slice acceptance.
- Self-hosted runners, runner caches, build matrices, artifact publication,
  deployment, release signing, App Store distribution, or live-network probes.
- Automatic GitHub Actions triggers or automatic retries.
- Re-enabling Actions as part of the spec commit.

## Acceptance criteria

1. The workflow contains exactly one job and is manual-only.
2. The job has `timeout-minutes: 10`, read-only repository permission, exact-head
   preflight, immutable shallow checkout, and per-PR cancellation.
3. There is exactly one product build invocation and it is the generic
   `iOS Example` workspace command specified above.
4. The workflow contains no `test` action/command, `-only-testing`, `.xcresult`,
   mutant, verifier, fixture acceptance, Maestro, Java setup, ripgrep setup,
   `simctl`, simulator UDID/runtime/model, artifact upload, secret scan, or
   invocation of repository scripts.
5. The local policy verifier accepts the approved workflow and rejects each
   forbidden trigger/category through static temporary-input checks; running the
   verifier consumes no GitHub Actions minutes and performs no build or test.
6. Existing slice tests remain locally runnable and are not deleted or weakened.
7. No workflow run is dispatched during implementation or review. Repository
   Actions stays disabled until the operator separately approves activation.

## Verification plan

Implementation verification is local and ordered from cheapest to most direct:

1. Parse the workflow and assert its only trigger, single job, permissions,
   timeout, concurrency, exact-head checkout, and single build command.
2. Statically reject all forbidden hosted command families listed in
   acceptance criterion 4, including split/multiline spellings handled by the
   local policy verifier.
3. Run the rewritten policy verifier locally against the implementation head.
4. Validate YAML syntax locally without executing the workflow.
5. Run the exact generic-destination `xcodebuild ... build` once on the MacBook
   to prove the command before review.
6. CodeReviewer and QA inspect the exact implementation head and confirm that
   only the approved workflow/policy paths changed beyond this spec.
7. Do not dispatch Actions. After merge and separate operator activation, the
   first final product PR may use the single manual hosted build.

## Open questions

None block implementation. The selected default is the `iOS Example` workspace
because it gives one clean compile signal for both app integration and the
package. If ten minutes proves insufficient because a clean runner cannot fetch
pinned dependencies, the workflow fails closed; increasing the cap or adding a
cache requires a separate operator decision rather than an automatic retry.
