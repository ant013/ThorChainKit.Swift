# Build-only GitHub Actions policy

**Status:** proposed, spec-only. Explicit operator approval is required before
implementation. GitHub Actions remains disabled while this specification is
reviewed.

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
- The maximum hosted cost of one attempt is ten macOS minutes; normal success is
  expected to finish below that cap.

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
2. Statistically reject all forbidden hosted command families listed in
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
