# Gimle reliability report — THR-52 hosted acceptance recovery revision 9

## Scope and identity

This report covers a read-only, spec-only correction to the hosted simulator
selector. The reviewed worktree is
`feature/THR-32-s1-02-endpoint-policy` at the unchanged implementation head
`64575a9aea42201b31f3549ba517f1e02017199d`. No hosted rerun, merge,
implementation edit, or fresh CR/QA review was performed.

The revision-9 spec is
`docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md`.
It preserves revision 7's ripgrep and exact-head evidence and revision 8's
Maestro driver diagnosis. Spec SHA-256:
`ffca0888eb0c46b999bd4f508d3c58caaf81b570e161c16fe9d31700f735de84`.

## Gimle trust

Gimle trust remains **RED**. The target project mapping is unavailable and the
Gimle/Palace lookup for `Users-ant013-Data-AI-thorchain` remains an
`unknown_project` mapping failure. Independent fallback evidence was used:
codebase-memory reports the target index `ready`, Serena was activated for the
exact worktree, and targeted `rg`/Git reads verified the selector and Maestro
lifecycle.

## New selector evidence

The current workflow at `.github/workflows/ci.yml:117-118` flattens all
available runtime buckets and selects the first shutdown iPhone. The operator
reported that this selected iOS 26.4.1 even though `DEVELOPER_DIR` is Xcode
26.3. Official runner-image documentation confirms Xcode 26.3 uses the iOS
26.2 SDK and the image includes both iOS 26.2 and iOS 26.4.1 simulator
runtimes:

https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md

The selector mismatch is a concrete, narrow recovery candidate. It does not
prove that runtime selection caused the Maestro loopback-driver failure.

## Recovery design and gate

Revision 9 proposes only an explicit iOS 26.2 runtime/device selector tied to
the Xcode 26.3 contract, with fail-closed absence handling. Before approval of
implementation, the operator must perform local A/B evidence with the exact
Maestro 2.6.1 and Temurin 17.0.19+10 pair:

- A: current all-runtimes first-shutdown-iPhone selection;
- B: explicit iOS 26.2 selection.

Both legs must capture tuple identity, runtime/device identifiers, install and
launch, driver readiness and loopback port behavior, and the first flow result.
No hosted run at unchanged head `64575a9` is authorized. A new hosted run
requires approved selector implementation, fresh CR/QA at a new exact head,
and local proof.

## Verification

Completed:

```text
codebase-memory index_status(project=Users-ant013-Data-AI-thorchain)
codebase-memory search_graph/search_code for simulator selector and Maestro lifecycle
Serena activate_project(<repo-root>)
git status --short --branch
git log -2 --format='%H %s'
targeted rg and Git reads of .github/workflows/ci.yml and Scripts/run-maestro.sh
official actions/runner-images macos-26 image documentation review
```

Not run by design: local A/B exact-toolchain reproduction, hosted CI, merge,
implementation tests, and workflow/verifier edits. The operator owns the
local A/B evidence prerequisite.

## Residual risk

The runtime selector is a demonstrated workflow defect but only a hypothesis
for the Maestro driver failure. If explicit iOS 26.2 does not restore driver
readiness, a separate Maestro/XCUITest compatibility design is required.
Gimle remains RED until target project mapping is repaired.
