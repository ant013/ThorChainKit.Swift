# S1-02 — Hosted runner ripgrep provisioning

Status: design revision 12, spec-only. Revision 7 remains the frozen
ripgrep-provisioning design and exact-head CR/QA baseline; revisions 8 and 9's
Maestro diagnosis and selector evidence are preserved. This revision replaces
revision 9's impossible local iOS 26.2 prerequisite with deterministic
verifier/mutant proof and one post-implementation hosted acceptance gate.
It incorporates the closure-4/5 correction for hosted-log normalization plus the
closure-3/5 review corrections for hosted version evidence,
post-provisioning shadowing, and committed-path hygiene. Explicit user approval
is required before any recovery implementation.

## Revision 12 review correction

Closure 4/5 identified that `gh run view --log` prefixes payload lines with job,
step, timestamp, and ANSI/source text, so the prior column-zero assertions could
not parse the artifact they required. This revision changes only the
implementation-phase evidence extraction: obtain the selected job's raw log,
strip ANSI escapes, extract only the declared evidence fields into a normalized
payload, and assert the normalized payload. The implementation boundary and
approval gate are unchanged.

## Revision 11 review correction

The latest closure review identified three high blockers in the prior revision:
the validated `rg --version` line was not required to be emitted to hosted
logs; the policy contract did not reject a later `$GITHUB_ENV` PATH mutation or
replacement of the extracted binary; and committed spec/report text contained
operator-local absolute paths. This revision adds those requirements and
sanitizes the committed paths. It remains spec-only: no workflow, verifier,
hosted-run, merge, or approval action is authorized here. The exact-head
Reviewer/QA/hosted merge gate remains open.

### Normative closure of review findings 1–2

Finding 1 is closed in the design by requiring the already validated first
`rg --version` line to be emitted as `rg_version_line=...` after the fail-closed
assertion, and by requiring a mutant that removes that log emission to fail the
policy gate. A source-text match is not hosted execution evidence.

Finding 2 is closed in the design by requiring the policy verifier to treat the
complete interval between the pinned provisioning block and the S1-02 consumer
as an exact allowed contract: only the approved simulator-selection block may
remain, with no `$GITHUB_ENV` PATH mutation and no write, removal, or replacement
of the extracted binary or its exported directory. Mutants for `$GITHUB_ENV`
PATH shadowing and extracted-binary replacement must fail before product
verification. These are implementation requirements for the already approved
workflow/verifier paths, not authorization to edit them in this spec phase.

Finding 3 is handled only by the four-path documentation sanitation in this
revision; it does not expand the implementation boundary.

## Goal and assumptions

Close the hosted `rg` failure and bind the S1-02 policy gate to the verified
checkout before `Scripts/verify-s1-02.sh` runs. Preserve exact-head,
workflow-dispatch, build, test, and Maestro gates. The observed failure is run
`29750250371` at exact PR head `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d`:
preflight, builds, and 42 tests passed, then `Scripts/verify-s1-02.sh:208`
failed with `rg: command not found`.

Current-tree boundary: the pinned ripgrep provisioning block already exists in
the workflow step named `Provision pinned ripgrep`, with exact-block checks
owned by `verify_ripgrep_provisioning()` and `RIPGREP_PROVISION_BLOCK` in
`Scripts/verify-s1-02-ci-policy.sh`. Preserve its pinned URL, digest,
architecture guard, staging, extraction order, PATH ownership, and consumer
position. This revision authorizes only the minimal tightening of the existing
version assertion needed for explicit command-status capture and exact first
line matching; it does not authorize re-adding or otherwise redesigning the
block. The existing exact policy ordering and simulator selector/identity work
completed at implementation head `3ec8044` are preserved and are not part of
the recovery implementation delta. The remaining post-approval work is only
the F1 version emission/removal mutant and the F2 exact-allowed-interval,
`$GITHUB_ENV` PATH-shadowing, and extracted-binary replacement checks in these
same two implementation paths.

Assumptions: `macos-26` is Apple Silicon, but implementation must assert
`uname -m == arm64` and fail closed otherwise; the official ripgrep 15.2.0
aarch64 Apple archive is approved; `curl`, `tar`, `shasum`, and `GITHUB_PATH`
are available; this task authorizes no implementation changes.

## Scope and affected paths

In scope: move the existing exact-SHA policy command to the first line of the
existing `Verify package and S1-02 contract` step; extend the existing
`Scripts/verify-s1-02-ci-policy.sh` with an exact command-block assertion,
late-order mutants, exact-SHA binding, and protection against later ripgrep
installs or PATH/binary shadowing; require the validated version line to be
emitted in hosted logs; and record static/hosted verification. The existing
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

After the exact version assertion succeeds, emit the validated line to the
hosted log with a stable field such as
`printf 'rg_version_line=%s\n' "$rg_version_line"`. The log line is evidence
of the checked absolute binary, not a replacement for the fail-closed check.

The required version check shape is equivalent to:

```text
if ! rg_version_output=$("$rg_path" --version); then exit 1; fi
rg_version_line="${rg_version_output%%$'\n'*}"
[[ "$rg_version_line" =~ ^ripgrep\ 15\.2\.0\ \(rev\ [0-9a-f]+\)$ ]]
printf 'rg_version_line=%s\n' "$rg_version_line"
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
   steps; no later ripgrep install, `$GITHUB_PATH`/`$GITHUB_ENV` PATH mutation,
   or replacement of the extracted `$rg_path` is permitted.

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

## Post-provisioning shadowing contract

Between the pinned provisioning block and the S1-02 consumer, the policy must
reject both of these workflow mutations:

- any `$GITHUB_ENV` assignment that changes `PATH` (the existing simulator
  identity export remains allowed because it does not alter `PATH`);
- any `cp`, `mv`, `install`, redirection, or equivalent write that can replace
  `$RUNNER_TEMP/ripgrep-15.2.0-aarch64-apple-darwin/rg` or the directory later
  appended to `$GITHUB_PATH`.

The mutant suite must add one temporary-copy mutant for each class and run the
policy gate before product verification. A later download/install mutant and
the existing direct/`$GITHUB_PATH` PATH mutants remain required. The positive
workflow must therefore have one verified binary identity, one logged version
line, and no mutable route to change the executable consumed by
`Scripts/verify-s1-02.sh`.

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
  verify-before-extract/PATH, `$GITHUB_PATH`, exact checked-out SHA expression,
  and required `rg_version_line` output. Add a mutant that removes the version
  log emission; it must fail the policy gate before product verification.
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
7. Before approval review, the spec-review evidence is recorded: current-tree
   anchors, the exact two-path implementation boundary, the pinned artifact
   evidence, the runtime-selector contract, and the static/mutant verification
   plan. No hosted run is required or authorized for this spec-only review.
8. After approval and implementation, fresh exact-head CodeReviewer and QA
   evidence must precede exactly one hosted acceptance run, and that run must
   complete before merge. Its evidence includes the full run conclusion and
   logs, successful `rg --version`, workflow/event/PR/checkout/run SHA fields,
   selected runtime/device identity, and explicit equality with the approved
   implementation head; any later push invalidates all hosted evidence and
   requires fresh review, QA, and hosted acceptance.

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
gh api repos/<owner>/<repo>/actions/runs/<run-id> \
  --jq '{id,head_sha,head_branch,event,status,conclusion,workflow_id,run_attempt}' > <run-fields-json>
gh run view <run-id> --log > <full-hosted-log>
set -euo pipefail
python3 - "<full-hosted-log>" > "<normalized-hosted-log>" <<'PY'
import re
import sys

ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
timestamp = re.compile(
    r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z)(?:[ \t]+(.*))?$"
)

with open(sys.argv[1], encoding="utf-8", newline="") as source:
    for line_number, raw_line in enumerate(source, 1):
        line = ansi.sub("", raw_line.rstrip("\r\n"))
        fields = line.split("\t", 2)
        if len(fields) != 3:
            raise SystemExit(f"malformed hosted log at line {line_number}: expected 3 tab fields")
        job, step, remainder = fields
        remainder = remainder.removeprefix("\ufeff")
        match = timestamp.match(remainder)
        if not job or not step or not match:
            raise SystemExit(f"malformed hosted log at line {line_number}: invalid prefix or timestamp")
        print(match.group(2) or "")
PY
rg -n 'workflow_ref=|workflow_sha=|event_sha=|pr_head_sha=|checkout_sha=|PASS verify-s1-02-test-discovery' <normalized-hosted-log>
test "$(rg -c '^rg_version_line=ripgrep 15\.2\.0 \(rev [0-9a-f]+\)$' <normalized-hosted-log>)" = 1
jq -e --arg approved '<exact-head>' '.head_sha == $approved and .conclusion == "success"' <run-fields-json>
for field in workflow_sha event_sha pr_head_sha checkout_sha; do
  test "$(rg -c "^${field}=[0-9a-f]{40}$" <normalized-hosted-log>)" = 1
  test "$(rg -c "^${field}=<exact-head>$" <normalized-hosted-log>)" = 1
  test "$(awk -F= -v key="$field" '$1 == key {print $2; found=1; exit} END {if (!found) exit 1}' <normalized-hosted-log)" = '<exact-head>'
done
printf '%s\t%s\t\357\273\277%s %s\t%s\n' s1-02 'Set up job' \
  2026-07-20T17:36:01.3714820Z workflow_sha=<exact-head> checkout_sha=<exact-head> > <prefix-fixture>
printf '%s\t%s\n' 'workflow_sha=<exact-head>' 'checkout_sha=<exact-head>' > <fixture-expected>
python3 - "<prefix-fixture>" > <fixture-normalized> <<'PY'
import re
import sys

ansi = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
timestamp = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z(?:[ \t]+(.*))?$")
with open(sys.argv[1], encoding="utf-8", newline="") as source:
    for raw_line in source:
        fields = ansi.sub("", raw_line.rstrip("\r\n")).split("\t", 2)
        if len(fields) != 3:
            raise SystemExit(1)
        match = timestamp.match(fields[2].removeprefix("\ufeff"))
        if not match:
            raise SystemExit(1)
        print(match.group(1) or "")
PY
diff -u <fixture-expected> <fixture-normalized>
printf '%s\t%s\t%s\n' s1-02 'Set up job' 'not-a-timestamp payload' > <malformed-timestamp-fixture>
if python3 - "<malformed-timestamp-fixture>" <<'PY'
import sys
import re

timestamp = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z(?:[ \t]+.*)?$")
for line in open(sys.argv[1], encoding="utf-8"):
    fields = line.rstrip("\r\n").split("\t", 2)
    if len(fields) != 3 or not timestamp.match(fields[2].removeprefix("\ufeff")):
        raise SystemExit(1)
PY
then
  printf 'malformed timestamp fixture unexpectedly passed\n' >&2; exit 1
fi
```

The hosted result must cite workflow SHA, event SHA, PR head, checkout SHA, and
run `head_sha`; each recorded SHA must be compared explicitly with the approved
exact head, and the run conclusion must be successful. The full `gh run
view --log` artifact is the source. ANSI removal followed by strict removal of
exactly three tab-delimited fields—job, step, and UTC timestamp—is the
deterministic normalization step. A timestamped blank payload is valid and
emits an empty normalized line; only missing job/step/timestamp or wrong tab
structure fails visibly. Fields are never silently invented. The normalized payload must
contain exactly one validated `rg_version_line` and exactly one exact 40-hex
value for each SHA key, with each value matching the approved head. The
normalized log must also show unchanged S1-02 discovery output. A replay fixture
with the demonstrated `s1-02<TAB>Verify package and S1-02
contract<TAB><UTC timestamp+payload>` shape must pass, while a
malformed-timestamp fixture must fail before assertions. A push
after the run, or any change to the reviewed head, invalidates the run and all
local review/QA attestations; repeat them against the new exact head.

## Adversarial review and open questions

- **D-001 Freshness/identity — ACCEPT.** The incident baseline is exact PR head
  `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d`; the revision-4 baseline head
  before this correction is `ed80ba5f0970d19c4667561662c6fa40b8f1ed42`. The
  revision-5 review head is the exact SHA of the pushed commit carrying this
  spec and is recorded in the CTO handoff; the reviewer must independently
  bind it with `git rev-parse HEAD`. Workflow and verifier anchors remain
  present on the assigned branch, and the historical/current-head distinction
  is explicit without self-referentially embedding a commit hash.
- **D-002 Supply chain — CLOSED in revision 10.** Current-tree anchors are the
  workflow step `Provision pinned ripgrep`, the policy constant
  `RIPGREP_PROVISION_BLOCK`, and `verify_ripgrep_provisioning()` plus its
  `RIPGREP_DOWNLOAD_RE`, `RIPGREP_PATH_RE`, and `PATH_MUTATION_RE` checks. The outcome
  is a fixed URL/digest, verify-before-extract, architecture/version checks,
  and rejection of second downloads or PATH shadowing. Residual backlog is
  limited to a separately approved asset decision if the runner architecture
  changes; it does not block this slice.
- **D-003 Minimum scope — CLOSED in revision 10.** Current-tree anchors are the
  workflow steps `Select exact iOS 26.2 simulator` and `Verify package and S1-02
  contract`, plus `verify_simulator_selection()` and the simulator mutant
  entrypoint. The selector/identity work is completed at implementation head
  `3ec8044`; only F1 version emission/removal-mutant work and F2 exact-interval,
  PATH-shadowing, and extracted-binary replacement checks remain after approval.
  No new script, package path, trigger, secret, binary, or unrelated file is
  authorized.
- **D-004 Verification validity — CLOSED in revision 10.** Current-tree anchors
  are the five-command body of `Verify package and S1-02 contract` and the
  policy/mutant entrypoints `run_contract_mutants()`,
  `run_ripgrep_mutants()`, and `run_simulator_mutants()`. The outcome separates
  spec-review proof from the post-implementation gate: static and mutant
  checks must reject late policy execution and symbolic `HEAD` before product
  verification, while fresh exact-head CR/QA and one hosted run are required
  before merge. Residual backlog is only the separately approved Maestro
  design if the exact iOS 26.2 hosted flow still fails.
- **D-005 Exact-head binding — ACCEPT.** The steady-state policy command passes
  `$(git rev-parse HEAD)` and the exact-SHA mutant rejects symbolic `--ref HEAD`;
  revision 1 did not cover this masked defect.

Open question: if `macos-26` becomes x86_64, approve a separately pinned asset
or keep this gate unavailable. This spec chooses fail-closed and does not guess.

## Revision 8 — hosted acceptance recovery design

This addendum supersedes only the hosted-acceptance recovery portion of the
prior design. It does not revise the pinned ripgrep asset, the two-file
implementation boundary, PR head `64575a9aea42201b31f3549ba517f1e02017199d`,
or the existing CodeReviewer/QA attestations. No hosted rerun, merge, or
implementation change is authorized by this revision.

### Observed failure and current-tree boundary

Hosted run `29764294250` used the approved PR head and passed exact-head
preflight, checkout, pinned ripgrep provisioning, the S1-02 policy/product
contract, Swift builds/tests, the guarded Maestro runner, and pinned Maestro
CLI installation. Xcode 26.3 built the Example against the iPhoneSimulator
26.2 SDK; `simctl install` and `simctl launch` succeeded with
`org.horizontalsystems.thorchainkit.example: 7990`. The first S1-01 flow then
failed before assertions while Maestro 2.6.1 attempted to set app permissions:

```text
Unable to set permissions for app org.horizontalsystems.thorchainkit.example:
Failed to connect to /127.0.0.1:50637
```

The current lifecycle is verified in `Scripts/run-maestro.sh:27-31` (Maestro
2.6.1 and Temurin 17.0.19+10), `:107-135` (boot, build, install, launch, then
`maestro test`), and `.github/workflows/ci.yml:106-120` (pinned CLI download
followed by the two slice flows). The failure is therefore downstream of the
ripgrep remediation and after successful app launch; it is not evidence that
the ripgrep policy or S1-02 product contract regressed.

### Local evidence and evidence limits

The operator supplied an exact-pair reproduction in progress using the pinned
Maestro/Temurin pair. An independent read-only check of this checkout's local
shell found Xcode 26.3 (`17C529`) and iOS 26.3/18.6 runtimes, but no `maestro`
binary and Java 21.0.1 rather than Temurin 17.0.19+10. The local shell cannot
therefore claim to reproduce the exact hosted pair. That mismatch is recorded
as an evidence limit, not silently treated as a successful reproduction.

### Primary upstream evidence

The failure shape is consistent with, but not proven identical to, two primary
Maestro issue records:

- [Maestro #3327](https://github.com/mobile-dev-inc/Maestro/issues/3327)
  records XCUITest-driver connection failures on Maestro 2.6.0 + Xcode 26.4,
  including repeated loopback `ConnectException` failures after driver
  installation.
- [Maestro #3137](https://github.com/mobile-dev-inc/Maestro/issues/3137)
  records the driver app installing and launching on Apple Silicon/iOS 26.x
  while opening no HTTP port; its environment includes Java 17 and iOS 26.x
  simulators.

Neither record proves that Maestro 2.6.1 + Xcode 26.3 is incompatible, and no
alternate version or runner is approved by this spec. A version change,
runtime change, or acceptance bypass would require a new evidence-backed
design and approval.

### Recovery design

1. Preserve the exact ripgrep implementation, policy gate, PR head, and
   existing CR/QA attestations. Do not rerun hosted CI or merge as part of
   this revision.
2. Complete the operator's read-only exact-pair reproduction and capture the
   tuple (`maestro --version`, Java identity, `xcodebuild -version`, simulator
   runtime/device), successful install/launch, driver installation state, and
   the loopback-driver readiness/port failure. Capture Maestro debug output
   and simulator/XCTest logs without modifying the application or skipping
   permission setup.
3. If the exact pair reproduces the same driver-not-listening behavior, treat
   it as an external Maestro/XCUITest compatibility blocker. Select a future
   slice only after primary evidence identifies either a known-good pinned
   Maestro/runtime tuple or a compatible hosted runner. Do not guess a
   downgrade/upgrade from issue titles alone.
4. If the exact pair does not reproduce the failure, preserve the hosted log
   as an environment-specific failure and require a separately approved
   runner-diagnostics slice before changing the workflow.
5. In both cases, fail closed: a build, install, and launch success is not a
   Maestro acceptance pass, and no recovery may remove the permission step,
   bypass the first flow, or convert a driver connection failure into a
   warning.

### Recovery acceptance criteria

The next recovery slice may proceed only when its approved design provides:

1. An exact local or hosted compatibility tuple and a reproducible driver
   readiness observation, with the current Maestro/Temurin pins explicitly
   preserved or replaced by a separately approved, digest-pinned tuple.
2. A bounded failure path that retains the full diagnostic evidence for driver
   installation, loopback readiness, and the first failing flow.
3. Unchanged ripgrep policy behavior and unchanged exact-head/CR/QA evidence
   until a new pushed head is independently reviewed and verified.
4. No acceptance bypass, mutable download, unpinned runtime, or speculative
   version change.

### Spec-only verification and open decision

Verified for this revision: codebase-memory index status is `ready`; Serena is
activated for `<repo-root>`; targeted `rg` and Git reads
confirm the current Maestro lifecycle; local runtime/toolchain observations
are recorded above; and the two primary upstream issue records were checked.
Gimle trust remains RED because the target project mapping is unavailable.

Not run by design: hosted CI, merge, implementation tests, or any workflow or
verifier edit. Board must choose whether to accept the current-slice hosted
ripgrep evidence and defer the downstream Maestro issue to a new slice, or
authorize a separate runner/fixture recovery slice after the exact-pair
diagnosis.

## Revision 9 — simulator runtime selector correction

**Superseded by revision 10.** The runtime hypothesis and official image
evidence remain historical context, but revision 9's requirement for a local
iOS 26.2 A/B leg is no longer normative.

The operator cancelled the redundant unchanged-head retry. Official
`macos-26-arm64` image evidence shows that Xcode 26.3 uses the iOS 26.2 SDK
while the image also provides iOS 26.2 and iOS 26.4.1 simulator runtimes:
[actions/runner-images macos-26-arm64 image documentation](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md),
image version `20260715.0248.1`.
The current workflow selector at `.github/workflows/ci.yml:117-118` searches
all runtime buckets and chooses the first shutdown iPhone. That selection
chose iOS 26.4.1 on the failed run, even though the workflow pins Xcode 26.3.

### Narrow recovery delta

The only proposed recovery implementation delta is to make simulator choice
explicit and fail closed:

1. Derive the simulator runtime from the pinned Xcode/SDK contract, selecting
   the exact iOS 26.2 runtime supported by Xcode 26.3 rather than flattening
   every runtime bucket.
2. Select a deterministic iPhone device within that runtime and assert that
   the selected device's runtime identifier is exactly the requested runtime.
3. Fail before build/install/launch if the required runtime or deterministic
   device is unavailable; never silently fall back to iOS 26.4.1 or another
   runtime.
4. Keep the existing Maestro 2.6.1 and Temurin 17.0.19+10 pins unchanged for
   the A/B test. Do not change ripgrep provisioning, permission setup, flow
   order, or acceptance semantics in this narrow correction.

This is a design, not authorization to edit `.github/workflows/ci.yml`.

### Required local A/B evidence before implementation approval

The operator must run the exact pinned Maestro/Temurin pair locally against:

- A: the current all-runtimes, first-shutdown-iPhone selector, recording the
  selected runtime and the loopback driver result; and
- B: the proposed explicit iOS 26.2 selector, with the same app, flow, Xcode,
  Maestro, Java, and device family, recording the same driver readiness data.

Each leg must record `maestro --version`, Java identity,
`xcodebuild -version`, simulator runtime/device identifiers, install/launch
success, driver installation/readiness, loopback port behavior, and the first
flow result. A/B evidence that does not distinguish the runtime is
insufficient. If B is not available locally, the recovery remains blocked and
the design must not guess a different runtime, Maestro version, or runner.

### Revision 9 acceptance boundary

1. No hosted run is authorized at unchanged head `64575a9`; the cancelled
   retry adds no evidence and must not be repeated.
2. Implementation may begin only after explicit approval of this revision and
   local A/B evidence shows that the selector correction is a meaningful,
   fail-closed diagnostic delta.
3. The implementation head must receive fresh CodeReviewer and QA evidence;
   revision 7's attestations remain historical evidence for `64575a9` and are
   not silently transferred to a new head.
4. The new hosted run must bind the exact new head, selected runtime, Xcode
   version, and simulator device in its logs before any Maestro flow result is
   accepted.
5. If the explicit iOS 26.2 A/B leg still fails with the same driver error,
   stop and create a separately approved Maestro/XCUITest compatibility
   recovery design. Do not bypass permissions or downgrade/upgrade pins by
   inference.

### Revision 9 evidence status

Codebase-memory remains `ready`; Serena and targeted `rg`/Git independently
verified the selector and lifecycle anchors. Official runner-image evidence
was checked directly. Gimle trust remains RED because the target project
mapping is unavailable. No hosted run, merge, implementation edit, or fresh
CR/QA review was performed for this revision.

## Revision 10 — evidence correction and deterministic selector proof

Revision 9 is not approvable as written: the operator's exact local toolchain
has iOS 26.3 and 18.6 runtimes, not iOS 26.2. The exact local evidence is
nevertheless meaningful and complete for the current hypothesis:

| Tuple | Evidence |
|---|---|
| Local | Maestro 2.6.1 release SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`; Temurin JRE SHA-256 `cef790b404cf168fd1a8a7abc5054fbb442c7d4bfe390cceccfe3f64b9b776a9`; Java `Temurin-17.0.19+10`; Xcode 26.3 build `17C529`; iPhoneSimulator SDK 26.2; local iPhone 17 Pro on iOS 26.3, UDID `9F8C536F-C2BF-44A0-B315-85E7405D5F76`; S1-01 and S1-02 flows passed and OCR scans passed. |
| Hosted | Xcode 26.3 with iOS 26.4.1 selected by the first-shutdown-iPhone selector; install/launch passed, then Maestro failed at `127.0.0.1:50637` before assertions. |

This contrast supports a runtime-compatibility hypothesis but does not prove
that iOS 26.2 will pass. The old revision-9 local iOS 26.2 A/B prerequisite
is removed; no pending revision-8 or revision-9 approval is accepted.

### Narrow implementation delta after approval

The next implementation slice remains limited to the existing two paths:

1. `.github/workflows/ci.yml` must select only
   `com.apple.CoreSimulator.SimRuntime.iOS-26-2`, select exactly one
   deterministic available shutdown iPhone from that bucket, and log the
   Xcode version, requested runtime, selected runtime identifier, device name,
   and UDID before build/install/launch.
2. `Scripts/verify-s1-02-ci-policy.sh` must add positive contract checks and
   temporary-copy mutants proving that the workflow rejects: flattened
   all-runtime selection, a missing runtime filter, nondeterministic device
   selection, missing identity logging, and silent fallback to a newer or
   different runtime.
3. The workflow must fail closed before build/install/launch when the exact
   runtime is absent or when zero or multiple eligible devices violate the
   deterministic selection contract.

The Maestro 2.6.1, Temurin 17.0.19+10, ripgrep, permission, flow-order, and
acceptance semantics remain unchanged. No alternative version, runner, or
runtime is guessed. No implementation edit is authorized by this revision.

### Verification and hosted gate

The local exact-toolchain evidence above is the required pre-implementation
proof for spec review; it is not a hosted acceptance prerequisite for approval
of this spec-only revision. After explicit approval and implementation, the
implementation must receive fresh adversarial CodeReviewer review and
independent QA at a new exact head. Exactly one hosted run is then authorized
against that new head, before merge, and must prove in its logs:

- the exact checked-out SHA and workflow/event/PR SHA equality;
- Xcode 26.3 identity and the requested iOS 26.2 runtime identifier;
- one deterministic iPhone device from that runtime, including name and UDID;
- successful ripgrep policy/product gates, builds, install, launch, and both
  Maestro flows.

If the explicit iOS 26.2 hosted flow still fails with the same driver error,
stop and require a separately approved Maestro/XCUITest compatibility design.
Do not dispatch another run at unchanged head `64575a9`, merge, or bypass the
permission/flow acceptance.

### Revision 10 evidence status and identity

The spec-only head for this revision is recorded in the pushed handoff and
report; the implementation base remains `64575a9aea42201b31f3549ba517f1e02017199d`.
Codebase-memory is `ready`; Serena and targeted `rg`/Git verified the selector
and lifecycle anchors; official runner-image evidence was checked directly;
Gimle trust remains RED. No hosted rerun, merge, implementation edit, or fresh
CR/QA review was performed for this revision.

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

This is the complete spec-only deliverable for THR-52 revision 12. The prior
hosted ripgrep failure, local-pass/hosted-failure contrast, deterministic
runtime-selector proof, one-run hosted gate, and recovery boundary are recorded
above. Symbolic `HEAD` remains explicitly rejected as a policy input. Explicit
user approval of revision 12 is required before any recovery implementation.
