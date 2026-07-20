# Gimle reliability report — THR-52 hosted ripgrep closure revision 11

## Scope and identity

This is the narrow revision-11 report-only identity record for the
specification at
`docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md`.
The exact pushed spec-content head is
`270d15882162a47b41054fc5e234f07d68c74522`; the spec SHA-256 is
`e453b5111de2f82274ceb37c989e34e63a7a4f3a59c2b1427f9390f0d1ff969b`.
This report is spec-only: no workflow, verifier, hosted-run, approval, merge,
or implementation action was performed.

## Gimle trust and fallback

Gimle trust remains **RED**. The target project mapping is unavailable
(`G-0001`, confirmed mapping bug): the registered Gimle project inventory does
not contain `Users-ant013-Data-AI-thorchain`, and project-overview lookup for
that slug returned `ok=false` with `error=unknown_project`.

The safe independent fallback is current-tree evidence: codebase-memory reports
the target index `ready`; Serena was activated for the assigned workspace;
targeted `rg` and Git reads verified the load-bearing workflow, policy, report,
and specification paths; and the official ripgrep release asset evidence is
retained from the prior revision. Gimle's mapping failure was not treated as
evidence that the repository or its symbols are absent.

## Revision-11 closure dispositions

### F1 — exact hosted version evidence: corrected

Both normative shell examples use one shell `\n` escape in
`printf 'rg_version_line=%s\n' "$rg_version_line"`. The hosted verification
plan requires exactly one anchored field matching
`rg_version_line=ripgrep 15.2.0 (rev [0-9a-f]+)`, and retains the mutant that
removes the field and must fail before product verification. A generic source
or log match is not sufficient execution evidence.

### F2 — post-provisioning shadowing: accepted

The specification requires the interval between the pinned provisioning block
and the S1-02 consumer to be an exact allowed contract. It rejects
`GITHUB_ENV` PATH mutation, `GITHUB_PATH` mutation, and writes, removal, or
replacement of the extracted ripgrep binary or exported directory. Temporary
copy mutants for PATH shadowing and binary replacement must fail before product
verification.

### F3 — committed path hygiene: accepted

The four authorized documentation paths contain repository-relative or
`<repo-root>` references instead of operator-local absolute paths. No unrelated
historical content was rewritten.

## Future implementation boundary

After explicit revision-bound user approval, implementation is limited to these
two existing paths:

- `.github/workflows/ci.yml`
- `Scripts/verify-s1-02-ci-policy.sh`

The approved future delta preserves the pinned ripgrep URL, archive, digest,
architecture guard, verify-before-extract order, PATH ownership, exact checked
out SHA binding, and S1-02 consumer. It adds the corrected version-log field,
fail-closed post-provisioning interval/shadowing checks, and the corresponding
policy mutants. No new script, package-manager fallback, action, trigger,
secret, binary, or unrelated file is authorized.

## Verification and remaining gate

Completed for this report-only correction:

```text
git rev-parse HEAD
shasum -a 256 docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
sed -n '112,130l' docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
git diff --check
git status --short --branch
```

The worktree is clean at the exact pushed head, and no implementation or
hosted verification was run or authorized. Fresh targeted CodeReviewer closure
4/5 is the next gate. Explicit user approval of the revision-11 spec is still
required before any workflow or verifier implementation; fresh exact-head QA
and one hosted acceptance run remain post-implementation requirements.

## Residual risk

Gimle cannot independently report target freshness until the project mapping is
repaired. Current-tree fallback evidence is sufficient for this narrow identity
record, but Gimle trust must remain RED and must not be promoted from fallback
evidence alone.
