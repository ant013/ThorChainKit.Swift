# S1-02 — Hosted runner ripgrep provisioning

Status: design revision 1, spec-only. Explicit user approval is required before
workflow or verifier implementation.

## Goal and assumptions

Provision `rg` on the `macos-26` hosted runner before
`Scripts/verify-s1-02.sh` runs. Preserve exact-head, workflow-dispatch, build,
test, and Maestro gates. The observed failure is run `29750250371` at exact PR
head `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d`: preflight, builds, and 42
tests passed, then `Scripts/verify-s1-02.sh:208` failed with `rg: command not found`.

Assumptions: `macos-26` is Apple Silicon, but implementation must assert
`uname -m == arm64` and fail closed otherwise; the official ripgrep 15.2.0
aarch64 Apple archive is approved; `curl`, `tar`, `shasum`, and `GITHUB_PATH`
are available; this task authorizes no implementation changes.

## Scope and affected paths

In scope: one provisioning step in `.github/workflows/ci.yml` before the step
that invokes `Scripts/verify-s1-02.sh`; a fixed release URL, archive name,
SHA-256, arm64 guard, `$RUNNER_TEMP` staging, PATH export, version check, and
static/hosted verification.

Out of scope: changes to `Scripts/verify-s1-02.sh` or its allowlist; Homebrew
or any package manager; new actions, jobs, triggers, permissions, checked-in
binaries, secrets, or x86_64 fallback. A different runner architecture needs a
separate approved asset and design.

| Path | Decision |
|---|---|
| `.github/workflows/ci.yml` | Add one narrow provisioning step before `Verify package and S1-02 contract`. |
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
fallback.

## Proposed workflow shape

Add the step immediately before the existing package/S1-02 contract step:

1. Run with `set -euo pipefail` and assert `uname -m` is `arm64`.
2. Download the exact URL to `$RUNNER_TEMP` with `curl -fsSL`.
3. Verify the literal SHA-256 with `shasum -a 256 -c -`.
4. Extract only after verification into `$RUNNER_TEMP`.
5. Assert the extracted absolute `rg` exists and reports `15.2.0`.
6. Append the extracted release directory to `$GITHUB_PATH` for later steps.

Do not invoke `rg` before PATH update except by its explicit absolute extracted
path. Exact-head preflight, `workflow_sha` equality, checkout equality,
permissions, and triggers remain unchanged.

## Analog delta matrix

| Dimension | Verified invariant | Required delta | Rejected difference/failure |
|---|---|---|---|
| Responsibility | Current Maestro block provisions a missing hosted CLI. | Provision ripgrep before its real consumer. | Rewriting the verifier to use `grep` hides the missing dependency. |
| Boundary | Workflow owns host setup; scripts own product verification. | Change workflow configuration only. | Setup in the verifier mixes boundaries. |
| Lifecycle | Existing order is download, checksum, extract, PATH. | Preserve order; add architecture/version assertions. | PATH before verification could execute wrong bytes. |
| Dependencies/trust | Maestro uses a literal URL and SHA-256 before extraction. | Pin version, URL, and exact digest. | Homebrew or `latest` adds mutable host drift. |
| Failure behavior | Checksum failure stops the shell step. | Download, digest, archive, architecture, and version failures fail closed. | Continuing after checksum failure is unsafe. |
| Consumer/test seam | `Scripts/verify-s1-02.sh:206-210` is the actual consumer. | Prove ordering and reach the exact allowlist comparison. | Version-only checking misses the hosted failure. |

## Tests before implementation

- Reproduce the baseline hosted failure at line 208 with no provisioned `rg`.
- Add static checks for step order, literal URL/digest, verify-before-extract,
  arm64 guard, `rg --version`, and `$GITHUB_PATH` export.
- Use temporary-copy mutants for wrong digest, wrong architecture, and a step
  moved after the consumer; each must fail before product verification.
- The positive hosted run must reach the existing discovery command and retain
  the prior 42-test result. No allowlist changes are introduced.

## Acceptance criteria

1. Only `.github/workflows/ci.yml` is an implementation file changed.
2. URL, version, archive name, and digest match the official 15.2.0 asset.
3. Non-arm64, download/checksum/extract, missing-binary, and version failures
   fail closed; PATH is not updated before checksum verification.
4. Provisioning precedes `Scripts/verify-s1-02.sh` and its existing allowlist
   check passes on the hosted runner.
5. Exact-head, checkout, build/test, dispatch, permissions, and Maestro pins
   remain unchanged.
6. No package-manager path, action, trigger, secret, binary, or unrelated file
   change is introduced.
7. Static/mutant checks and the exact hosted run are recorded before review;
   any later push invalidates hosted evidence.

## Verification plan

Spec-only checks completed:

```text
git rev-parse HEAD
git status --short --branch
git show e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d:.github/workflows/ci.yml
rg --hidden -n 'Maestro|shasum -a 256 -c|GITHUB_PATH' .github/workflows/ci.yml
rg -n '\| rg ' Scripts/verify-s1-02.sh
curl -fsSL https://api.github.com/repos/BurntSushi/ripgrep/releases/tags/15.2.0
shasum -a 256 ripgrep-15.2.0-aarch64-apple-darwin.tar.gz
tar -tzf ripgrep-15.2.0-aarch64-apple-darwin.tar.gz
```

Implementation-phase checks, not authorized or run here:

```text
git diff --check
Scripts/verify-s1-02-ci-policy.sh steady-state --ref HEAD
Scripts/verify-s1-02.sh
gh workflow run CI --ref <same-repository-feature-branch> -f pr_number=<PR> -f expected_head_sha=<exact-head> -f confirmation=FINAL_S1_02_GATE
gh run view <run-id> --log-failed
```

The hosted result must cite workflow SHA, event SHA, PR head, checkout SHA, run
head SHA, successful `rg --version`, and unchanged S1-02 discovery output.

## Adversarial review and open questions

- **D-001 Freshness/identity — ACCEPT.** Workflow and verifier anchors exist at
  exact head `e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d` on the assigned branch.
- **D-002 Supply chain — ACCEPT.** The official digest is independently
  reproduced; verify-before-extract and no package-manager fallback are fixed.
- **D-003 Minimum scope — ACCEPT.** One workflow step is sufficient; verifier
  and product files remain untouched.
- **D-004 Verification validity — ACCEPT.** The actual failing `rg` pipeline is
  the acceptance probe, with digest, architecture, and ordering mutants.

Open question: if `macos-26` becomes x86_64, approve a separately pinned asset
or keep this gate unavailable. This spec chooses fail-closed and does not guess.

## Gimle reliability and approval gate

Gimle health was reachable, but `palace.memory.get_project_overview` returned
`unknown_project` for `Users-ant013-Data-AI-thorchain`; codebase-memory indexes
the target under that name, but Gimle does not register it. This is mapping bug
`G-0001` and makes Gimle trust RED. Current-tree conclusions use codebase-memory,
Serena, targeted `rg`, Git, and direct official release verification.

This is the complete spec-only deliverable for THR-52. Explicit user approval
of this revision is required before workflow or verifier implementation.
