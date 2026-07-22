# THR-104 S1-06 Gimle reliability report

**Run:** `THR-104-s1-06-20260722`

**Base:** `origin/main` / `0f572e455be07df798a233eff31bbc27bb0940c5`

**Workflow phase:** design revision 5; discovery 2/2, closure 0/5; exact-head
review is required before approval

**Trust:** RED for Gimle; current-tree fallback is usable.

**Revision 5 artifact hashes:** spec
`c5b7fc0fca855a2d77479c12c0966cff8634d22566797c47a207361743235c54`; plan
`75e97e671cba99f6b719acadbe2f1057a841cecc5def384f0e409b71ef7892a0`.
**Reviewed ThorChainKit design head:** `45ca84599df07501d20f701cb2fcde466c4bca87`
(spec-only branch; implementation remains prohibited).

## Identity

The exact ThorChainKit design branch is based on the clean base above. Current
UW evidence uses the adjacent clean clone labeled
`unstoppable-wallet-ios-THR-104`, branch
`feature/THR-104-thorchain-lifecycle`, at
`db86b99e9a12d758729a41c83a514b709df0a525`, fetched from the official origin.
MarketKit evidence uses the adjacent clean clone labeled
`MarketKit.Swift-THR-104`, branch
`feature/THR-104-thorchain-metadata`, at clean base
`95c92c876c3f40c28816e8e9891d6ffaf6eb0828`. The unrelated dirty Unstoppable
checkout was not edited or read for source evidence.

Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried first and
reported `status=ready`; its index-status response did not provide an indexed
commit, so none is invented here.

## Gimle calls and defect

Six bounded read-only calls succeeded: runtime health, UW project overview,
three graph searches, and one semantic search. The UW project overview reports
the mounted root
and commit `8a63bfda028dd8543115b26dd777235a53304311`, while the required clean
evidence checkout is a different root at commit `db86b99e9a12d758729a41c83a514b709df0a525`.
It also reports `stale=false/current_local_tree` for that other mount.

This is recorded as `GIMLE-001` (`mapping_bug`, high, confirmed, workaround,
forces RED). Gimle results were used only to discover candidate vocabulary and
paths. All load-bearing claims were independently verified with Serena,
targeted `rg`, and Git reads in the exact detached worktree. No contradicted
Gimle result influenced the design.

## Verified analog decision

The composition spine is the current `TronKitManager` vertical. The positive
lifecycle spine is `MoneroAdapter`; `AdapterManager`, `AdapterFactory`,
`TronAdapter`, `AccountAddress`, the current protocol surface, and
`Unstoppable/Tests/AppTests.swift` are supporting evidence. The rejected
counterexample is the current manager-owned `tronKit.start()` plus empty
`TronAdapter.start/stop/refresh` lifecycle. The design keeps manager
construction/cache ownership, moves lifecycle forwarding to the new adapter,
and uses the generic adapter-manager path.

The exact-head review also corrected the draft's nonexistent
`AccountAddressProvider.swift`/`IAccountAddressProvider` assumption. The plan
uses the existing direct `AccountAddress.swift` boundary and keeps the manager
local in `Core`, held by `AdapterFactory`, matching the current construction
shape.

## Dependency delivery decision

ThorChainKit is public at
`https://github.com/ant013/ThorChainKit.Swift.git`, with package/product name
`ThorChainKit` and iOS 13 support. The reviewed `0f572e455be07df798a233eff31bbc27bb0940c5`
manifest is not consumable by remote WalletCore while production target-level
unsafe flags remain. S1-06 requires a separately reviewed ThorChainKit commit
that removes those flags and keeps warnings-as-errors in the owned build
invocation; the exact resulting SHA is pinned in the final host resolver.
MarketKit's exact resulting metadata SHA is likewise pinned in the final host
resolver. The adjacent MarketKit path is a local-only development override.

## Adversarial review

The bounded architecture, security/protocol-safety, and verification/operability
checklist was completed against the exact worktree. Discovery is frozen at 2/2;
closure remains 0/5. Stable decisions `D-001` through `D-012` remain `ACCEPT`.
The security and verification reviews required revisions for derivation-boundary
use, mnemonic retention, endpoint provenance, checked balance conversion,
idempotent cancellation, sanitized diagnostics, runtime-generated test material,
direct AppTests product dependency, exact local execution, lifecycle sentinels,
exhaustive state mapping, and refresh/concurrency negatives.

The current host pin is MarketKit.Swift `3.6.12` at
`95c92c876c3f40c28816e8e9891d6ffaf6eb0828`; it does not define THOR chain
metadata. The revised design moves only `BlockchainType.thorChain`, native
RUNE metadata/query, and focused tests into S1-06. Discovery/UI/import/relaunch/
explorer remain S1-07. Stable reviewer findings `D-VER-001` through
`D-VER-006`, `D-SEC-001` through `D-SEC-003`, and `D-DELIVERY-001` are explicitly
resolved in the current revision; the exact hashes, clean clone heads, changed-
file allowlist, complete physical-device selectors, and decision outcomes are
bound in the authoritative external Gimle state for run
`THR-104-s1-06-20260722`.

No implementation, host-repository modification, GitHub Actions test, mutant,
simulator, Maestro run, or acceptance run was performed in this design phase.
