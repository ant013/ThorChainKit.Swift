# S1-02 — Hosted runner ripgrep provisioning

Status: design revision 7, spec-only. Revision 6 is superseded by this
checkpoint and closure-evidence correction; its current-tree boundary remains
unchanged. Explicit user approval is required before workflow or verifier
implementation.

## Goal and assumptions

Close the hosted `rg` failure and bind the S1-02 policy gate to the verified
checkout before `Scripts/verify-s1-02.sh` runs. Preserve exact-head,
workflow-dispatch, build, test, and Maestro gates. The observed failure is run
`29750250371` at exact PR head `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d`:
preflight, builds, and 42 tests passed, then `Scripts/verify-s1-02.sh:208`
failed with `rg: command not found`.

Current-tree boundary: the pinned ripgrep provisioning block already exists at
`.github/workflows/ci.yml:78-94` and its exact-block checks already exist in
`Scripts/verify-s1-02-ci-policy.sh:77-207`. Preserve its pinned URL, digest,
architecture guard, staging, extraction order, PATH ownership, and consumer
position. This revision authorizes only the minimal tightening of the existing
version assertion needed for explicit command-status capture and exact first
line matching; it does not authorize re-adding or otherwise redesigning the
block. The remaining implementation delta is the policy invocation move plus
exact workflow-order, exact-SHA, and no-shadowing guards.

Assumptions: `macos-26` is Apple Silicon, but implementation must assert
`uname -m == arm64` and fail closed otherwise; the official ripgrep 15.2.0
aarch64 Apple archive is approved; `curl`, `tar`, `shasum`, and `GITHUB_PATH`
are available; this task authorizes no implementation changes.

## Scope and affected paths

In scope: move the existing exact-SHA policy command to the first line of the
existing `Verify package and S1-02 contract` step; extend the existing
`Scripts/verify-s1-02-ci-policy.sh` with an exact command-block assertion,
late-order mutants, exact-SHA binding, and protection against later ripgrep
installs or PATH shadowing; and record static/hosted verification. The existing
fixed release URL, archive name, SHA-256, arm64 guard, `$RUNNER_TEMP` staging,
PATH export, and version check are preserved and policy-checked.

Out of scope: changes to `Scripts/verify-s1-02.sh` or its allowlist; Homebrew
or any package manager; new actions, jobs, triggers, permissions, checked-in
binaries, secrets, or x86_64 fallback. A different runner architecture needs a
separate approved asset and design.

| Path | Decision |
|---|---|
| `.github/workflows/ci.yml` | Move the existing exact-SHA policy command to the first line of `Verify package and S1-02 contract`; preserve the existing pinned provisioning behavior and tighten only its version assertion as specified. |
| `Scripts/verify-s1-02-ci-policy.sh` | Extend the existing policy authority with the exact command-block assertion, late-order mutants, exact-SHA binding, and no-shadowing guard. |
| `Scripts/verify-s1-02.sh` | Unchanged consumer; its `swift test list | rg | sort` pipeline remains the acceptance probe. |
| This spec | Normative implementation and verification contract. |

## Pinned artifact and supply-chain rule

Use only this official release asset:

```text
URL: https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-aarch64-apple-darwin.tar.gz
SHA-256: 3750b2e93f37e0c692657da574d7019a101c0084da05a790c83fd335bad973e4
```

The GitHub release API reports this digest. A direct download on 2026-07-20
reproduced it with `shasum -a 256`; the official `.sha256` sidecar matched it.
The archive was shown to contain an arm64 Mach-O `rg` reporting `ripgrep
15.2.0`. Verify the literal digest before `tar` extraction. A changed tag,
changed bytes, failed download, failed digest, unexpected architecture, missing
executable, or unexpected version must stop the job before PATH is updated.
Never resolve the digest at runtime and never use a mutable package-manager
fallback. The policy must reject any second ripgrep download/install, any
ripgrep-specific PATH export outside the pinned block, and any PATH or
`GITHUB_PATH` mutation between the pinned block and the S1-02 consumer that
could shadow its verified directory. Capture the absolute binary's version
output with an explicit fail-closed status check; require its first line to
match exactly `ripgrep 15.2.0 (rev <lowercase-hex>)`, not a prefix such as
`ripgrep 15.2.0-extra`.

The required version check shape is equivalent to:

```text
if ! rg_version_output=$("$rg_path" --version); then exit 1; fi
rg_version_line="${rg_version_output%%$'\n'*}"
[[ "$rg_version_line" =~ ^ripgrep\ 15\.2\.0\ \(rev\ [0-9a-f]+\)$ ]]
```

## Proposed workflow shape

Retain the existing pinned provisioning step immediately before the package/S1-02
contract step; do not add or duplicate it, and apply only the minimal version
assertion tightening specified above. Within that existing
contract step, the exact-SHA policy gate must be the first command, before any
build, test, or product-verifier command:

```text
Scripts/verify-s1-02-ci-policy.sh steady-state --ref "$(git rev-parse HEAD)"
swift build
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test
Scripts/verify-s1-02.sh
```

This ordering is required so a malformed provisioning block is rejected by the
policy authority before the hosted consumer can fail or produce misleading
product-verification evidence. The policy verifier must add one exact
five-command assertion for the `Verify package and S1-02 contract` run body:
the literal policy command with `$(git rev-parse HEAD)`, the two builds,
`swift test`, and `Scripts/verify-s1-02.sh`, each exactly once and in that
order. It must reject a missing, duplicated, or reordered command before
product verification. The four order mutants are made by moving the policy
command after the first build, after the strict-concurrency build, after the
test, or after the consumer; the `--ref HEAD` replacement is a separate
mutant. Each mutant must fail this exact-block assertion before any product
verification command runs.

| Mutant | Required rejection from the exact-block assertion |
|---|---|
| Policy after first `swift build` | The first command is not the exact policy command. |
| Policy after strict-concurrency `swift build` | The first command is not the exact policy command. |
| Policy after `swift test` | The first command is not the exact policy command. |
| Policy after `Scripts/verify-s1-02.sh` | The exact five-command block is absent/reordered. |
| `--ref HEAD` | The first command is not the exact checked-out-SHA expression. |

1. Preserve `set -euo pipefail` and assert `uname -m` is `arm64`.
2. Preserve the exact URL download to `$RUNNER_TEMP` with `curl -fsSL`.
3. Preserve literal SHA-256 verification with `shasum -a 256 -c -`.
4. Extract only after verification into `$RUNNER_TEMP`.
5. Assert the extracted absolute `rg` exists and, with an explicit checked
   command status, reports the exact `15.2.0` version line.
6. Append only the extracted release directory to `$GITHUB_PATH` for later
   steps; no later ripgrep install or shadowing PATH mutation is permitted.

Do not invoke `rg` before PATH update except by its explicit absolute extracted
path. Exact-head preflight, `workflow_sha` equality, checkout equality,
permissions, and triggers remain unchanged.

## Exact checked-out SHA binding

The existing steady-state policy invocation must pass the exact commit checked
out by the preceding verification step:

```text
Scripts/verify-s1-02-ci-policy.sh steady-state --ref "$(git rev-parse HEAD)"
```

The policy verifier must assert that literal command expression, including the
`git rev-parse HEAD` expansion, and must reject `--ref HEAD`. The hosted run
`29750250371` stopped earlier at `Scripts/verify-s1-02.sh:208` with `rg:
command not found`, so it did not expose this latent policy defect. The
steady-state parser already requires a 40-character commit SHA; accepting the
symbolic `HEAD` argument would therefore either fail after the real consumer or
force the verifier to resolve an ambient symbolic ref. Neither behavior binds
the policy result to the exact checkout SHA proved by the workflow. The
verifier must remain fail-closed and SHA-bound.

## Analog delta matrix

| Dimension | Verified invariant | Required delta | Rejected difference/failure |
|---|---|---|---|
| Responsibility | Current tree already provisions a pinned hosted CLI. | Move policy validation before product commands and prove the verified binary cannot be shadowed. | Rewriting the verifier to use `grep` hides the missing dependency. |
| Boundary | Workflow owns host setup; the existing CI-policy verifier owns workflow-policy assertions; product verification remains separate. | Move one existing workflow command and extend the existing policy verifier only. | Re-adding the provisioning block or adding a new script fragments policy ownership. |
| Lifecycle | Existing order is download, checksum, extract, version, PATH. | Preserve the pinned asset, order, and ownership; minimally tighten version status/first-line matching and reject later installs/PATH shadowing. | PATH before verification or a later override could execute wrong bytes. |
| Dependencies/trust | Maestro uses a literal URL and SHA-256 before extraction. | Pin version, URL, and exact digest. | Homebrew or `latest` adds mutable host drift. |
| Failure behavior | Checksum failure stops the shell step. | Download, digest, archive, architecture, and version failures fail closed. | Continuing after checksum failure is unsafe. |
| Consumer/test seam | `Scripts/verify-s1-02.sh:206-210` is the actual consumer and `Scripts/verify-s1-02-ci-policy.sh` is the existing policy authority. | Require the exact block and ordering in the policy verifier, then reach the exact allowlist comparison. | Version-only checking or a second script misses/removes the durable regression guard. |
| Exact-head binding | CI proves `git rev-parse HEAD == EXPECTED_HEAD_SHA` before product commands. | Pass `$(git rev-parse HEAD)` to steady-state policy and assert that exact expression. | Allowing `--ref HEAD` weakens the 40-character SHA contract and can detach policy evidence from the checked-out commit. |

## Tests before implementation

- Reproduce the baseline hosted failure at line 208 with no provisioned `rg`.
- Extend `Scripts/verify-s1-02-ci-policy.sh` (no new script) with an exact
  five-command workflow-block assertion, the four late-order mutants, the
  symbolic-`HEAD` mutant, no-second-install/no-shadowing checks, and assertions
  for the preserved URL, version, archive, digest, arm64 guard,
  verify-before-extract/PATH, `$GITHUB_PATH`, and exact checked-out SHA
  expression.
- Use temporary-copy mutants for missing provisioning, provisioning moved after
  the consumer, the policy invocation moved after the first `swift build`,
  after the strict-concurrency `swift build`, after `swift test`, or after
  `Scripts/verify-s1-02.sh`, wrong URL/version/digest, verification after
  extraction or PATH, mutable package-manager fallback, invalid
  architecture/version assertions, a command-substitution failure, an
  inexact version pattern, and replacing `--ref "$(git rev-parse HEAD)"` with
  `--ref HEAD`. Run the policy check as the first gate against each mutant;
  every mutant must fail there, before product verification is invoked.
- The positive hosted run must reach the existing discovery command and retain
  the prior 42-test result. No allowlist changes are introduced.

## Acceptance criteria

1. The only implementation paths changed are `.github/workflows/ci.yml` and
   `Scripts/verify-s1-02-ci-policy.sh`; no new script is added, the existing
   provisioning block is not re-added, and only its version assertion receives
   the minimal tightening specified above.
2. URL, version, archive name, and digest match the official 15.2.0 asset.
3. Non-arm64, download/checksum/extract, missing-binary, command-substitution,
   and exact-version failures fail closed; PATH is not updated before checksum
   verification; no later ripgrep install or PATH shadowing can replace the
   verified binary before the consumer.
4. The exact-SHA policy gate runs before build, test, and
   `Scripts/verify-s1-02.sh`; policy-first mutants fail when its invocation is
   moved after the first build, strict build, test, or consumer; the symbolic
   `--ref HEAD` mutant fails before product verification; the existing
   allowlist check passes on the hosted runner; and steady-state policy
   receives the exact checked-out SHA expression.
5. Exact-head, checkout, build/test, dispatch, permissions, and Maestro pins
   remain unchanged.
6. No package-manager path, action, trigger, secret, binary, or unrelated file
   change is introduced.
7. Static/mutant checks, including every policy-order, no-shadowing,
   command-status, exact-version, and exact-SHA
   binding mutant, and the exact hosted run are recorded before review. The
   evidence includes the exact two-path implementation diff, full run
   conclusion and logs, successful `rg --version`, workflow/event/PR/checkout/
   run SHA fields, and an explicit equality comparison to the approved head;
   any later push invalidates all hosted evidence and requires a fresh run.

## Verification plan

Spec-only checks completed:

```text
git rev-parse HEAD
git status --short --branch
git show e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d:.github/workflows/ci.yml
rg --hidden -n 'Maestro|shasum -a 256 -c|GITHUB_PATH' .github/workflows/ci.yml
rg -n '\| rg ' Scripts/verify-s1-02.sh
rg -n 'steady-state --ref|git rev-parse HEAD' .github/workflows/ci.yml Scripts/verify-s1-02-ci-policy.sh
curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/tags/15.2.0
shasum -a 256 ripgrep-15.2.0-aarch64-apple-darwin.tar.gz
tar -tzf ripgrep-15.2.0-aarch64-apple-darwin.tar.gz
```

Implementation-phase checks, not authorized or run here:

```text
expected_paths=$(printf '%s\n' .github/workflows/ci.yml Scripts/verify-s1-02-ci-policy.sh | sort)
actual_paths=$(git diff --name-only <implementation-base>...<implementation-head> | sort)
diff -u <(printf '%s\n' "$expected_paths") <(printf '%s\n' "$actual_paths")
git diff --check <implementation-base>...<implementation-head>
Scripts/verify-s1-02-ci-policy.sh steady-state --ref "$(git rev-parse HEAD)"
Scripts/verify-s1-02.sh
gh workflow run CI --ref <same-repository-feature-branch> -f pr_number=<PR> -f expected_head_sha=<exact-head> -f confirmation=FINAL_S1_02_GATE
gh run view <run-id> --log > <full-hosted-log>
gh api repos/<owner>/<repo>/actions/runs/<run-id> \
  --jq '{id,head_sha,head_branch,event,status,conclusion,workflow_id,run_attempt}' > <run-fields-json>
rg -n 'workflow_ref=|workflow_sha=|event_sha=|pr_head_sha=|checkout_sha=|ripgrep 15\.2\.0|PASS verify-s1-02-test-discovery' <full-hosted-log>
jq -e --arg approved '<exact-head>' '.head_sha == $approved and .conclusion == "success"' <run-fields-json>
for field in workflow_sha event_sha pr_head_sha checkout_sha; do
  test "$(rg -c "^${field}=<exact-head>$" <full-hosted-log>)" = 1
  test "$(awk -F= -v key="$field" '$1 == key {print $2; found=1; exit} END {if (!found) exit 1}' <full-hosted-log)" = '<exact-head>'
done
```

The hosted result must cite workflow SHA, event SHA, PR head, checkout SHA, and
run `head_sha`; each recorded SHA must be compared explicitly with the approved
exact head, and the run conclusion must be successful. The full log must show
successful `rg --version` and unchanged S1-02 discovery output. A push after
the run, or any change to the reviewed head, invalidates the run and all local
review/QA attestations; repeat them against the new exact head.

## Adversarial review and open questions

- **D-001 Freshness/identity — ACCEPT.** The incident baseline is exact PR head
  `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d`; the revision-4 baseline head
  before this correction is `ed80ba5f0970d19c4667561662c6fa40b8f1ed42`. The
  revision-5 review head is the exact SHA of the pushed commit carrying this
  spec and is recorded in the CTO handoff; the reviewer must independently
  bind it with `git rev-parse HEAD`. Workflow and verifier anchors remain
  present on the assigned branch, and the historical/current-head distinction
  is explicit without self-referentially embedding a commit hash.
- **D-002 Supply chain — REVISED in revision 6; pending closure.** The official
  digest and verify-before-extract behavior remain fixed. The policy must also
  reject second ripgrep installs, ripgrep-specific PATH exports, PATH mutations
  that can shadow the verified directory before the consumer, command-status
  failures, and inexact version matching. The minimal version assertion
  tightening is explicitly allowed in the existing block and its policy
  fixture.
- **D-003 Minimum scope — REVISED in revision 6; pending closure.** The current
  tree already contains the pinned provisioning block and its basic policy
  checks. The smallest remaining delta is moving the existing policy command
  before product verification, minimally tightening the existing version
  assertion, and adding exact workflow-order, exact-SHA, and no-shadowing
  assertions in the two existing implementation paths.
- **D-004 Verification validity — REVISED in revision 6; pending closure.** The
  policy gate is required before build, test, and the actual failing `rg`
  pipeline. Separate mutants move it after each build, test, and consumer
  command, and replace the exact SHA expression with symbolic `HEAD`; every
  mutant must fail before product verification, so the policy guard cannot be
  bypassed by any late workflow command or ambient ref.
- **D-005 Exact-head binding — ACCEPT.** The steady-state policy command passes
  `$(git rev-parse HEAD)` and the exact-SHA mutant rejects symbolic `--ref HEAD`;
  revision 1 did not cover this masked defect.

Open question: if `macos-26` becomes x86_64, approve a separately pinned asset
or keep this gate unavailable. This spec chooses fail-closed and does not guess.

## Gimle reliability and approval gate

Gimle health was reachable, but `palace.memory.get_project_overview` returned
`unknown_project` for `Users-ant013-Data-AI-thorchain`; codebase-memory indexes
the target under that name, but Gimle does not register it. This is mapping bug
`G-0001` and makes Gimle trust RED. Current-tree conclusions use codebase-memory,
Serena, targeted `rg`, Git, and direct official release verification.

The Gimle checkpoint for this revision is external to the repository at
`<GIMLE_SKILLS_ROOT>/audit/runs/THR-52-ripgrep-provisioning-20260720-r6/`; the
repository-local `audit/` directory is not a deliverable or implementation
path. The deliberate repository report under `docs/reports/gimle/` records the
closure freeze, remaining evidence status, impact, workaround, and follow-up.

The existing `THR-52-ripgrep-provisioning-20260720-r2.md` report is historical
incident evidence anchored to the pre-provisioning baseline; its statement that
provisioning is absent must not be used as a current-tree claim. Current-tree
presence and policy gaps are verified directly at the assigned head and must be
rechecked at the exact pushed review head.

This is the complete spec-only deliverable for THR-52 revision 7. The prior
hosted failure is recorded above, and symbolic `HEAD` is explicitly rejected
as a policy input. Explicit user approval of this revision is required before
workflow or verifier implementation.
