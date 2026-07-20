# Gimle reliability report — THR-52 hosted ripgrep closure revision 12

## Scope and identity

This is the narrow revision-12 report for the specification at
`docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md`.
The exact pushed spec-content head is
`555329369cea86dd303a854b81363d1f26489009`; the spec SHA-256 is
`d85c6035bf08dabfbc03e2a71c21b56007106e91d30df475352e347bc6971f9b`.
This report is spec-only: no workflow, verifier, hosted-run, approval, merge,
or implementation action was performed.

## Gimle trust and fallback

Gimle trust remains **RED**. The target project mapping is unavailable
(`G-0001`, confirmed mapping bug): the registered Gimle project inventory does
not contain `Users-ant013-Data-AI-thorchain`, and project-overview lookup for
that slug returned `ok=false` with `error=unknown_project`.

The safe independent fallback is current-tree evidence: codebase-memory reports
the target index `ready`; Serena was activated for the assigned workspace;
targeted `rg` and Git reads verified the workflow step/job anchors, the
three-field fractional-timestamp hosted-log normalization contract,
specification, and report paths; and the official ripgrep release asset
evidence is retained from the prior revision. Gimle's mapping failure was not
treated as evidence that the repository or its symbols are absent.

## Revision-12 closure disposition

### F1 — hosted-log artifact parsing: corrected

The prior plan parsed `gh run view --log` as column-zero payload, but the
demonstrated artifact has three tab fields: job, step, and a BOM-prefixed
timestamp-plus-payload remainder. The revision-12 plan now strips ANSI
escapes, splits each line on tabs with `maxsplit=2`, removes an optional BOM,
parses a fractional-or-whole-second UTC timestamp, and emits only the payload
while preserving payload tabs. Timestamped blank payloads are valid and emit
empty normalized lines; malformed or under-columned lines fail visibly. It
then requires exactly one validated `rg_version_line` and exactly one exact
40-hex field matching the approved head for each of `workflow_sha`,
`event_sha`, `pr_head_sha`, and `checkout_sha`. The replay fixture covers the
verified `s1-02` / `Set up job` shape; the version-log-removal mutant remains
required to fail before product verification.

### F2 — post-provisioning shadowing: accepted

The specification still requires the interval between the pinned provisioning
block and the S1-02 consumer to be an exact allowed contract. It rejects
`GITHUB_ENV` PATH mutation, `GITHUB_PATH` mutation, and writes, removal, or
replacement of the extracted ripgrep binary or exported directory. Temporary
copy mutants for PATH shadowing and binary replacement must fail before product
verification.

### F3 — committed path hygiene: accepted

The authorized documentation paths contain repository-relative or
`<repo-root>` references instead of operator-local absolute paths. No unrelated
historical content was rewritten.

## Future implementation boundary

After explicit revision-bound user approval, implementation remains limited to
these two existing paths:

- `.github/workflows/ci.yml`
- `Scripts/verify-s1-02-ci-policy.sh`

The approved future delta preserves the pinned ripgrep URL, archive, digest,
architecture guard, verify-before-extract order, PATH ownership, exact checked
out SHA binding, completed simulator selector/identity work at `3ec8044`, and
the S1-02 consumer. It adds only the corrected version-log field/removal mutant
and the F2 exact-allowed-interval, PATH-shadowing, and extracted-binary
replacement checks. No new script, package-manager fallback, action, trigger,
secret, binary, or unrelated file is authorized.

## Verification and remaining gate

Completed for this report-only correction:

```text
git rev-parse HEAD
git diff --check
git status --short --branch
shasum -a 256 docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
rg -n 'gh run view|split\("\\t", 2\)|malformed hosted log|prefix-fixture' docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
rg -n 'jobs:|s1-02|Verify package and S1-02 contract' .github/workflows/ci.yml
git show --stat --oneline 555329369cea86dd303a854b81363d1f26489009
gh run view 29764294250 --log > <historical-full-hosted-log>
python3 <normalizer-script> <historical-full-hosted-log> > <historical-normalized-log>
test "$(wc -l < <historical-normalized-log)" = 1592
test "$(rg -c '^$' <historical-normalized-log)" = 351
```

The spec-content commit is pushed on the assigned feature branch, the worktree
is clean after the report commit, and no implementation or hosted verification
was run or authorized. Explicit user approval of the revision-12 spec is still
required before any workflow or verifier implementation; fresh exact-head QA
and one hosted acceptance run remain post-implementation requirements.

## Residual risk

Gimle cannot independently report target freshness until the project mapping is
repaired. Current-tree fallback evidence is sufficient for this narrow identity
record, but Gimle trust must remain RED and must not be promoted from fallback
evidence alone.
