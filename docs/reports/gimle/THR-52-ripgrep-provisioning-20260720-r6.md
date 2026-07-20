# Gimle reliability report — THR-52 S1-02 revision 6

## Scope

This report covers the spec-only correction prompted by closure review 5/5.
The reviewed ThorChainKit worktree is on branch
`feature/THR-32-s1-02-endpoint-policy`, at HEAD
`40e945b65e7f600f7d2a147d0a6932fb8a336acf` before the revision-6 spec edit.
No workflow or verifier implementation was authorized or changed.

The external checkpoint is
`<GIMLE_SKILLS_ROOT>/audit/runs/THR-52-ripgrep-provisioning-20260720-r6/`
(`state.json` and `gimle-report.md`); no repository-local `audit/` content is
part of this deliverable.

## Gimle substrate

- `palace.health.status`: reachable; runtime git SHA
  `0e9cf57c00ff970f584256126b500166580e7a72`; source checkout is the Gimle
  serving repository, not ThorChainKit.
- `palace.memory.health`: reachable; latest ingest completed without errors;
  registered code projects do not include ThorChainKit.
- `palace.memory.list_projects`: returned the registered project inventory;
  `Users-ant013-Data-AI-thorchain` is absent.
- `palace.memory.get_project_overview(slug=Users-ant013-Data-AI-thorchain)`:
  returned `ok=false`, `error=unknown_project` in an otherwise successful MCP
  envelope.

Gimle trust is **RED** for this run because the target project mapping is
unavailable (`G-0001`, confirmed mapping bug). The fallback is safe and
independent: codebase-memory reports the target index `ready`; Serena was
activated for the exact worktree; targeted `rg` and Git reads verified all
load-bearing current-tree anchors; and the official ripgrep release asset was
checked in the prior evidence revision. The Gimle failure remains recorded and
was not treated as evidence of repository absence.

## Closure finding and resolution

Closure review 5/5 identified `B-REV5-001`: the prior spec simultaneously
required the provisioning block to remain byte-for-byte unchanged and required
explicit command-status capture plus an exact first-line version regex. The
current workflow and policy fixture both still used the prefix assertion:

```text
[[ "$("$rg_path" --version)" == "ripgrep 15.2.0"* ]]
```

Revision 6 resolves the contradiction by freezing the pinned URL, digest,
architecture guard, staging, extraction order, PATH ownership, and consumer
position, while explicitly authorizing only the minimal version-assertion
tightening in both existing implementation paths. No new script, installer,
asset, or lifecycle redesign is in scope.

Closure review 5/5 froze this boundary. The repository-local checkpoint was an
operational residue, not product scope: its impact was an invalid repository
delta and an unportable audit location. The state and generated report were
moved to the external checkpoint above; the committed report remains the
deliberate reliability artifact. Follow-up is to initialize future Gimle runs
under the external root and keep hosted/implementation evidence approval-gated.

## Independent current-tree evidence

- `.github/workflows/ci.yml:78-94` contains the existing pinned provisioning
  block and the prefix-only version assertion.
- `Scripts/verify-s1-02-ci-policy.sh:77-207` contains the matching policy
  fixture and existing provisioning/order checks.
- `Scripts/verify-s1-02-ci-policy.sh:332-370` contains the existing mutant
  harness, including wrong URL, digest, ordering, architecture, binary, and
  version mutants.
- The spec now states the reconciled boundary in its goal, affected-path
  table, lifecycle delta, acceptance criteria, and decisions D-002 through
  D-004.

## Verification

Targeted checks for this revision:

```text
git diff --check
rg -n 'byte-for-byte|revision 5|minimal version|command-status|exact first' \
  docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
rg -n 'ripgrep 15\.2\.0|rg_path.*--version|RIPGREP_PROVISION_BLOCK' \
  .github/workflows/ci.yml Scripts/verify-s1-02-ci-policy.sh
git status --short --branch
```

The required hosted run and implementation mutant suite remain intentionally
unrun: this deliverable is spec-only and must receive explicit user approval
before workflow or verifier code changes. Any hosted evidence must be rerun at
the final implementation PR head.

## Residual risk

Gimle cannot independently report target freshness until the repository is
registered. Current-tree fallback evidence is sufficient for this narrow spec
revision, but the Gimle trust state must not be promoted without a valid
project mapping. The macOS architecture assumption remains fail-closed in the
spec and requires a separately approved asset if the runner changes.
