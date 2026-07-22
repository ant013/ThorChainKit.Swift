# THR-104 S1-06 Gimle reliability report

**Run:** `THR-104-s1-06-20260722`

**Base:** `origin/main` / `0f572e455be07df798a233eff31bbc27bb0940c5`

**Workflow phase:** awaiting approval

**Trust:** RED for Gimle; current-tree fallback is usable.

## Identity

The exact ThorChainKit design branch is clean at the base above. The exact UW
phase-1 evidence checkout is a detached clean worktree at
`db86b99e9a12d758729a41c83a514b709df0a525`, fetched from the official
`https://github.com/horizontalsystems/unstoppable-wallet-ios.git` origin.
The unrelated checkout at `/Users/ant013/Ios/HorizontalSystems/unstoppable-wallet-ios`
was not edited, switched, cleaned, stashed, or read for source evidence.

Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried first and
reported `status=ready`; its index-status response did not provide an indexed
commit, so none is invented here.

## Gimle calls and defect

Six bounded read-only calls succeeded: runtime health, UW project overview,
three graph searches, and one semantic search. The UW project overview reports
the mounted path `/Users/Shared/Ios/Gimle-Repos/HorizontalSystems/unstoppable-wallet-ios`
and commit `8a63bfda028dd8543115b26dd777235a53304311`, while the required clean
evidence checkout is a different root at commit `db86b99e9a12d758729a41c83a514b709df0a525`.
It also reports `stale=false/current_local_tree` for that other mount.

This is recorded as `GIMLE-001` (`mapping_bug`, high, confirmed, workaround,
forces RED). Gimle results were used only to discover candidate vocabulary and
paths. All load-bearing claims were independently verified with Serena,
targeted `rg`, and Git reads in the exact detached worktree. No contradicted
Gimle result influenced the design.

## Verified analog decision

The primary spine is the current `TronKitManager` vertical. Supporting roles
are `AdapterManager`, `AdapterFactory`, `TronAdapter`, `AccountAddress`, the
current protocol surface, and `Unstoppable/Tests/AppTests.swift`. The rejected
counterexample is the current manager-owned `tronKit.start()` plus empty
`TronAdapter.start/stop/refresh` lifecycle. The design keeps manager
construction/cache ownership, moves lifecycle forwarding to the new adapter,
and uses the generic adapter-manager path.

The exact-head review also corrected the draft's nonexistent
`AccountAddressProvider.swift`/`IAccountAddressProvider` assumption. The plan
uses the existing direct `AccountAddress.swift` boundary and keeps the manager
local in `Core`, held by `AdapterFactory`, matching the current construction
shape.

## Adversarial review

The bounded architecture, security/protocol-safety, and verification/operability
checklist was completed against the exact worktree. Stable decisions `D-001`
through `D-012` are all `ACCEPT`: freshness/identity, family completeness,
primary coherence, counterexample disposition, failure behavior, test validity,
scope, and the smaller alternative are resolved in the spec revision and plan.

No implementation, host-repository modification, GitHub Actions test, mutant,
simulator, Maestro run, or acceptance run was performed in phase 1.
