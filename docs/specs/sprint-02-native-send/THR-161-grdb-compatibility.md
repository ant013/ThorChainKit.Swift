# THR-161 — ThorChainKit GRDB 6.29.3 Compatibility Correction

Status: draft for bounded adversarial review  
Base: `origin/main` at `65c8e370db983c6bd500448266a4f8f51561ca5f`  
Parent: THR-160 S2-07 Unstoppable Native RUNE Send Integration

## Goal

Make the approved S2-07 dependency graph satisfiable with the smallest
ThorChainKit-only package correction: change ThorChainKit's exact GRDB
dependency from `6.29.1` to `6.29.3`, refresh the tracked resolved state, and
prove the package still retains its iOS 13 product floor and existing behavior.

Observable success is a clean local package resolution and test run on the
correction head, with exactly the two package-state files changed relative to
the frozen base unless the package manager requires a directly related test
evidence artifact.

## Assumptions and decisions required

- The operator approved the correction direction, not this unwritten design.
- The approved S2-07 MarketKit revision remains
  `2c327452237cfbbdc4d87bcd5dd417d1da46a61e` and is not changed.
- GRDB upstream tag `v6.29.3` resolves to
  `2cf6c756e1e5ef6901ebae16576a7e4e4b834622` and declares iOS 11, so the
  ThorChainKit iOS 13 floor does not move upward.
- The exact correction SHA is unknown until implementation and merge; S2-07
  must not update its pin before that SHA exists.
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

Out of scope:

- ThorChainKit protocol, source, public API, or runtime behavior changes.
- Any Unstoppable Wallet file, package pin, branch, PR, or remote change.
- MarketKit revision changes.
- Local package overrides, GRDB forks, or relaxed version ranges.
- Hosted Actions, hosted tests, mutants, simulator work, Maestro, or live
  network acceptance.

## Acceptance criteria

1. `Package.swift` pins `https://github.com/groue/GRDB.swift.git` exact
   `6.29.3`; no unrelated manifest or source changes exist.
2. `Package.resolved` records GRDB version `6.29.3` at revision
   `2cf6c756e1e5ef6901ebae16576a7e4e4b834622`, with every other approved pin
   preserved.
3. The package resolves locally at the exact correction head and the required
   existing ThorChainKit deterministic tests pass.
4. The ThorChainKit package remains iOS 13-compatible; no target floor is
   raised by the correction.
5. The final Gimle report under `docs/reports/gimle/` records the RED Gimle
   project-mapping limitation, the fallback evidence, exact commands, and any
   unrun checks.
6. The merge SHA is handed to THR-160. Only after that handoff may S2-07
   update its ThorChainKit revision and resume.

## Evidence and analog family

Primary spine: historical commit `da502c439f530de5f45588bd2fb0c8d5b9fd9799`
changed only `Package.swift`, replacing exact GRDB `6.29.1` with `6.29.3`.

Supporting evidence: historical commit
`3f492c8c7f334d69ce0cacb14157ba9846f59c69` changed only `Package.resolved` to
the GRDB `6.29.3` revision and corresponding origin hash.

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
| Resolved state | All non-GRDB pins and package graph | GRDB revision/version and generated origin hash | Hand-editing unrelated pins | Manifest and lockfile disagree | `Package.resolved` structural diff and package resolution |
| Deployment floor | ThorChainKit iOS 13 | None | Raising target floor | S2-07 consumer compatibility regresses | `Package.swift` platform check; upstream GRDB tag manifest check |
| Runtime/source | All existing kit source and public API | None | Protocol or implementation edits | Scope expansion and untested behavior change | `git diff --name-only` allowlist; existing deterministic tests |
| Verification boundary | Local MacBook evidence | Exact-head local resolution/tests and Gimle report | Hosted Actions, simulator, Maestro, live network | False acceptance evidence or unauthorized external run | Recorded command output and exact-head review |

## Test-first plan

Before implementation, define the failing observation as the approved host
resolver rejection: ThorChainKit exact `6.29.1` cannot satisfy MarketKit's
`6.29.3..<7.0.0` requirement. The correction tests are package-level rather
than new source tests:

1. Assert the manifest has exactly GRDB `6.29.3` and retains iOS 13.
2. Assert the resolved file has GRDB version `6.29.3`, the expected revision,
   and no unrelated pin drift.
3. Resolve the package locally from the correction worktree.
4. Run the existing deterministic ThorChainKit test target required by the
   local package verification policy.
5. Confirm the final diff contains no source or unrelated package changes.

If local package resolution cannot run because of an external substrate issue,
record the exact command, error, and strongest safe substitute; do not claim
the acceptance criterion passed.

## Verification commands

From the correction worktree on the exact head:

```text
git diff --name-only origin/main...HEAD
rg -n 'GRDB|6\.29\.3|platforms' Package.swift Package.resolved
git diff --check origin/main...HEAD
xcodebuild -scheme ThorChainKit -resolvePackageDependencies
xcodebuild test -scheme ThorChainKit -destination '<local iOS destination>'
```

Use the repository's existing narrow verification script when it covers the
same package target. Do not dispatch GitHub Actions or add simulator/Maestro/
live checks to this prerequisite.

## Review and handoff gates

- Discovery and design evidence: this spec, plan, state checkpoint, and Gimle
  report are complete before implementation.
- Adversarial review: bounded architecture/boundary, dependency/safety, and
  verification/operability challenges must be ACCEPT or resolved in a new
  spec revision.
- Explicit approval: the operator must approve this exact spec revision before
  `Package.swift` or `Package.resolved` is edited.
- Implementation: ThorChainSwiftEngineer edits only the approved package
  files, pushes the correction branch, and hands the exact PR/head to review.
- QA: independent local exact-head package verification.
- Merge: ThorChainCTO merges only after reviewer and QA evidence, then hands
  the resulting merge SHA to THR-160.

