# THR-161 — ThorChainKit GRDB 6.29.3 Compatibility Correction

Status: revised draft for bounded adversarial review
Base: `origin/main` at `65c8e370db983c6bd500448266a4f8f51561ca5f`
Parent: THR-160 S2-07 Unstoppable Native RUNE Send Integration

## Goal

Make the approved S2-07 dependency graph satisfiable with the smallest
ThorChainKit-only package correction: change ThorChainKit's exact GRDB
dependency from `6.29.1` to `6.29.3`, refresh the tracked resolved state, and
prove the package still retains its iOS 13 product floor and existing behavior.

Observable success is a clean local package and isolated host-graph resolution
plus deterministic verification on the correction head. The implementation
delta is limited to the two package-state files and directly affected
dependency-verification tests; the final documentation branch additionally
contains this spec, plan, state, and Gimle report.

## Assumptions and decisions required

- The operator approved the correction direction, not this unwritten design.
- The approved S2-07 MarketKit revision remains
  `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` and is not changed.
- GRDB upstream tag `v6.29.3` resolves to
  `2cf6c756e1e5ef6901ebae16576a7e4e4b834622` and declares iOS 11, so the
  ThorChainKit iOS 13 floor does not move upward.
- The exact correction SHA is unknown until implementation and merge; S2-07
  must not update its pin before that SHA exists.
- Existing repository gates that assert GRDB 6.29.1 are acceptance contracts,
  not unrelated cleanup; their assertions must move with this prerequisite.
- The exact MarketKit repository URL is supplied as a verification input by the
  approved S2-07 host graph; the host fixture uses only the approved revision
  2c327452237cfbbdc4d87bcd5dd417d1da46a61e and never edits that checkout.
- Gimle has no registered project for `Users-ant013-Data-AI-thorchain` in the
  deployed runtime. Gimle trust is RED; current Git/rg and local package
  verification are the authoritative fallback.

Open decision: approve or revise this final design after adversarial review.

## Scope

In scope:

- `Package.swift`: exact GRDB `6.29.3` pin.
- `Package.resolved`: GRDB `6.29.3` and its exact upstream revision,
  preserving all other pins.
- A bounded correction report/spec/plan and local verification evidence.
- Existing ThorChainKit package resolution and deterministic tests required to
  prove the dependency correction.
- Directly affected dependency-verification tests:
  Scripts/test-s1-05-dependency-floor.sh, Scripts/verify-s1-03.sh,
  Scripts/verify-bigint-floor.sh, and one correction-owned test for lockfile
  preservation and the isolated host graph.

Out of scope:

- ThorChainKit protocol, source, public API, or runtime behavior changes.
- Any Unstoppable Wallet file, package pin, branch, PR, or remote change.
- MarketKit revision changes.
- Local package overrides, GRDB forks, or relaxed version ranges.
- Hosted Actions, hosted tests, mutants, simulator work, Maestro, or live
  network acceptance.
- Any change to source behavior, Unstoppable, MarketKit, or unrelated verifier
  assertions.

## Acceptance criteria

1. `Package.swift` pins `https://github.com/groue/GRDB.swift.git` exact
   `6.29.3`; no unrelated manifest or source changes exist.
2. `Package.resolved` records GRDB version `6.29.3` at revision
   `2cf6c756e1e5ef6901ebae16576a7e4e4b834622`, with every other approved pin
   preserved.
3. The package resolves locally at the exact correction head; an isolated
   temporary consumer fixture resolves ThorChainKit plus the approved MarketKit
   revision without changing either repository; and the required existing
   deterministic tests pass.
4. A structural comparison proves that only GRDB state and generated
   originHash changed from the frozen base; temporary-copy resolution does
   not rewrite the committed lockfile.
5. The existing iOS 13 device-floor verifier passes at the correction head; no
   target floor is raised by the correction.
6. The final Gimle report under `docs/reports/gimle/` records the RED Gimle
   project-mapping limitation, the fallback evidence, exact commands, and any
   unrun checks.
7. The merge SHA is handed to THR-160. Only after that handoff may S2-07
   update its ThorChainKit revision and resume.

## Evidence and analog family

Primary spine: historical commit `da502c439f530de5f45588bd2fb0c8d5b9fd9799`
changed only `Package.swift`, replacing exact GRDB `6.29.1` with `6.29.3`.

Supporting evidence: historical commit
`3f492c8c7f334d69ce0cacb14157ba9846f59c69` changed only `Package.resolved` to
the GRDB `6.29.3` revision and corresponding origin hash. These are sequential
halves of one unmerged correction, not independent test evidence; the old
verifier assertions are explicitly corrected in this slice.

Current-tree contract: base `Package.swift` declares iOS 13 and exact GRDB
`6.29.1`; base `Package.resolved` records revision
`dd6b98ce04eda39aa22f066cd421c24d7236ea8a` and version `6.29.1`.

Rejected counterexample: retaining exact `6.29.1` reproduces the Xcode
resolver conflict with the approved MarketKit lower bound `6.29.3`. A local
override or fork would hide the conflict and violate reproducibility.

## Delta matrix

| Area | Preserve | Required delta | Rejected delta | Failure mode | Test / verification |
|---|---|---|---|---|---|
| Dependency declaration | Exact package identity and product `GRDB` | Exact version `6.29.3` | Range, override, fork, or MarketKit change | Host graph remains unsatisfiable or becomes non-reproducible | Manifest assertion and resolver command |
| Resolved state | All non-GRDB pins and package graph | GRDB revision/version and generated origin hash | Hand-editing unrelated pins | Manifest and lockfile disagree | Canonical base/head JSON comparison excluding only GRDB state and `originHash`; temporary-copy resolution |
| Deployment floor | ThorChainKit iOS 13 | None | Raising target floor | S2-07 consumer compatibility regresses | `Package.swift` platform check; upstream GRDB tag manifest check |
| Runtime/source | All existing kit source and public API | None | Protocol or implementation edits | Scope expansion and untested behavior change | `git diff --name-only` allowlist; existing deterministic tests |
| Verification boundary | Local MacBook evidence | Exact-head local resolution/tests and Gimle report | Hosted Actions, simulator, Maestro, live network | False acceptance evidence or unauthorized external run | Recorded command output and exact-head review |

## Test-first plan

Before implementation, define the failing observation as an isolated temporary
host fixture pinned to the approved MarketKit revision: ThorChainKit exact
`6.29.1` cannot satisfy MarketKit's `6.29.3..<7.0.0` requirement. The fixture
must fail before the correction and resolve after it. The correction tests are
package-level rather than new source tests:

1. Assert the manifest has exactly GRDB `6.29.3` and retains iOS 13.
2. Assert the resolved file has GRDB version `6.29.3`, the expected revision,
   and no unrelated pin drift using a structural comparison against immutable
   base `65c8e370db983c6bd500448266a4f8f51561ca5f`.
3. Resolve the package locally and resolve the isolated temporary consumer
   against the exact approved MarketKit revision, failing closed if the URL
   input or host graph cannot be resolved.
4. Run the existing deterministic selector contract and the existing iOS 13
   device-floor verifier; do not run the live test target.
5. Confirm temporary-copy resolution leaves the tracked lockfile unchanged and
   the final implementation diff contains no source or unrelated verifier
   changes.

If local package resolution cannot run because of an external substrate issue,
record the exact command, error, and strongest safe substitute; do not claim
the acceptance criterion passed.

## Verification commands

From the correction worktree on the exact correction head `<correction-head>`;
the immutable comparison base is `65c8e370db983c6bd500448266a4f8f51561ca5f`:

```text
test "$(git rev-parse HEAD)" = "<correction-head>"
test -z "$(git status --porcelain)"
git diff --name-only 65c8e370db983c6bd500448266a4f8f51561ca5f...HEAD
git diff --check 65c8e370db983c6bd500448266a4f8f51561ca5f...HEAD
rg -n 'GRDB|6\.29\.3|platforms' Package.swift Package.resolved Scripts
xcodebuild -scheme ThorChainKit -resolvePackageDependencies
Scripts/test-thr-161-grdb-compatibility.sh --marketkit-url "$MARKETKIT_URL" --marketkit-revision "2c327452237cfbbdc4d87bcd5dd417d1da46a61e"
xcrun swift test --filter ThorChainKitTests
Scripts/verify-s2-01-deployment-floor.sh
```

The implementation allowlist is `Package.swift`, `Package.resolved`,
`Scripts/test-s1-05-dependency-floor.sh`, `Scripts/verify-s1-03.sh`,
`Scripts/verify-bigint-floor.sh`, and
`Scripts/test-thr-161-grdb-compatibility.sh`. The correction-owned test must
use temporary copies and must not modify either repository. Do not dispatch
GitHub Actions or add Maestro/live checks to this prerequisite; the existing
local iOS 13 device-floor verifier is the narrowly required compile check.

## Review and handoff gates

- Discovery and design evidence: this spec, plan, state checkpoint, and Gimle
  report are complete before implementation.
- Adversarial review: bounded architecture/boundary, dependency/safety, and
  verification/operability challenges must be ACCEPT or resolved in a new
  spec revision.
- Explicit approval: the operator must approve this exact spec revision before
  `Package.swift` or `Package.resolved` is edited.
- Implementation: ThorChainSwiftEngineer edits only the approved package and
  directly affected verifier files, pushes the correction branch, and hands
  the exact PR/head to review. A push invalidates prior review/QA evidence.
- QA: independent local exact-head package verification.
- Merge: ThorChainCTO merges only after reviewer and QA evidence, then hands
  the resulting merge SHA to THR-160.
