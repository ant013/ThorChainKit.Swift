# THR-87 S1-05 Gimle reliability and adversarial review

## Review binding

- Repository: `ThorChainKit.Swift`
- Reviewed design head: `0694dbc399c1087349e0dd2cd137d699b8e829b3`
- Base: `d35770a0430eee921fa1fe91b2f8812a8c0535ff`
- Spec: `docs/specs/sprint-01-foundation/S1-05-rune-account-sync.md`
- Plan: `docs/superpowers/plans/2026-07-21-THR-87-s1-05-rune-account-sync.md`
- Review phase: discovery 2/2 frozen, closure 0/5

## Gimle trust

**RED for Gimle/Palace; current-tree fallback is authoritative.**

Codebase-memory contains the ThorChainKit project and was queried before source
inspection. Its graph returned current S1-01/S1-04 symbols and tests, then
Serena plus targeted `rg`/Git reads verified the relied-on local anchors.
Palace was reachable, but its registered code projects do not include
ThorChainKit; its kit analog mappings have unknown freshness and cannot bind
this review to the target head. No Gimle result was accepted as load-bearing
evidence. The Palace runtime reported `neo4j=reachable`, but its source
checkout and SHA identify the Palace service rather than this repository.

## Authoritative Gimle recheck — revision 3

The recheck was performed against the pushed design head above on
2026-07-21. Palace health reported `neo4j=reachable`, runtime
`native-dev@0e9cf57c00ff970f584256126b500166580e7a72`, clean service state, and
no project-integrity warnings. The registered project inventory contained 18
projects but no ThorChainKit namespace. A direct lookup of
`Users-ant013-Data-AI-thorchain` returned `unknown_project`; the bounded audit
call rejected the same value as an invalid Gimle slug. These results are
recorded in the reworked checkpoint as events `E-0008` through `E-0012` and
bug revision `GIM-THR87-TARGET-MAPPING@3`.

This is a confirmed Gimle mapping/coverage gap, not target-tree evidence.
Current-tree codebase-memory, Serena, and targeted `rg`/Git reads remain the
authoritative fallback. Gimle trust therefore remains RED, and no Gimle-only
claim is accepted as load-bearing.

## Stable discovery findings

| ID | Severity | Finding | Required correction |
|---|---|---|---|
| `S105-ARCH-001` | high | Generation is called the sole `AccountSyncer` owner, while the facade/bridge and storage control transaction also advance or gate it (`spec:74,113,164`). | Define one authoritative generation/token owner and the exact handoff/CAS ordering; distinguish runtime mirror state from durable authority. |
| `S105-ARCH-002` | high | GRDB is required, but neither the spec file list nor plan Step 2 includes `Package.swift`/`Package.resolved` or a dependency-resolution/iOS-13 compatibility gate (`S1-01:171,612`; plan:62-74). | Add manifest/lockfile ownership and an exact GRDB resolution and iOS-13 verification step. |
| `S105-ARCH-003` | high | The design requires one atomic account/balance/height snapshot, but the publication contract names `AccountStateManager` and does not explicitly bind `acceptedHeight` to the existing `Kit.lastBlockHeight` getter/publisher (`spec:225-229`; `Sources/ThorChainKit/Core/Kit.swift:12,32,52-58`). | Specify the single snapshot update for account, balance, and height and add an exact getter/publisher ordering test. |
| `S105-SEC-001` | high | `load` returns a composite record, but only save is explicitly transactional; a torn account/balance read is not ruled out (`spec:95-104,194-219`; tests:266-279). | Require a consistent GRDB read transaction and test concurrent load/write interleavings for old-or-new completeness. |
| `S105-SEC-002` | high | `advanceGeneration` throws across a nonthrowing public stop path, with no SQLite-failure behavior (`spec:95-104`; `Sources/ThorChainKit/Core/Kit.swift:80-86`). | Specify fail-closed durable-generation failure semantics and prove stop cannot return while an old CAS/publication remains admissible. |
| `S105-ARCH-004` | high | The synchronous facade holds its serial dispatcher while invoking collaborators; the required actor drain/publication barrier can deadlock if completion needs that dispatcher (`Sources/ThorChainKit/Core/Kit.swift:109-145`; `spec:78,115,225-228`). | Define a nonblocking bridge handshake and an in-flight publication/stop barrier test that cannot self-wait. |
| `S105-ARCH-005` | high | Invalid fresh decimal data can be saved before the gate performs canonical/256-bit validation (`spec:129-137` versus `spec:107-111`). | Make `StorageRecord` construction or `saveIfCurrent` validate before persistence; test malformed fresh input leaves no invalid row. |
| `S105-VOP-001` | high | Example acceptance requires pending/cancel/offline/relaunch/recovery, but current Example composition has no specified Kit-connected fixture transport/storage/clock seam (`spec:291-299`; plan:97-112; `iOS Example/Sources/Core/ExampleRuntime.swift:47-51,76-88`). | Specify the fixture seam and prove the flow exercises Kit lifecycle/state rather than a bypassing read session. |
| `S105-VOP-002` | high | Isolation mutants lack exact files/transforms, baseline compiler command, and diagnostic assertions (`spec:281`; plan:114-128). | Pin two unique source transforms, strict-concurrency command, baseline pass, mutant fail, and diagnostic checks. |
| `S105-VOP-003` | high | The invariant subprocess harness has no source/command/marker/stderr/timeout/baseline protocol (`spec:76,148,156,163,246`; plan:118-128). | Specify and test all three isolated commands and exact failure evidence. |
| `S105-VOP-004` | high | Exact test discovery and invocation are labels, not executable selectors or artifact/head bindings (`spec:50-53,310`; plan:47-56,136-140). | Add exact test allowlists, selectors, xcresult checks, simulator inputs, and base/head bindings. |
| `S105-VOP-005` | high | Persistence/relaunch/live recovery is required but has no concrete S1-05 live verifier, fixture, environment, schema, or output contract (`spec:301-306,320`; plan:136-144). | Add a bounded live evidence command/schema and explicit unrun/fail-closed behavior. |
| `S105-VOP-006` | high | No test proves a storage save error maps to `.notSynced(.storageUnavailable, cached:)` without publishing `.synced` (`spec:219-221`; tests:253-279). | Add the synchronizer/facade boundary test. |

The spec header also says “synchronized to S1-01 revision 11”, while the
canonical S1-01 document at this head is revision 12. This is a direct binding
inconsistency that must be corrected before approval; it is included in the
Paperclip review handoff as `S105-ARCH-006`.

## Closure status after discovery 2/2

Discovery is frozen at 2/2. The first six high findings and the revision-2
review IDs are resolved in the current spec/plan. Revision 3 explicitly closes
`S105-ARCH-007` by binding the internal barrier-returning `KitLifecycle`,
post-dispatcher `Kit.submit` wait, and no-token `cancelStop()` path to
`Core/KitDependencies.swift`, `Core/Kit.swift`, and a combined successful-stop/
control-failure contract test. It closes `S105-ARCH-008` by defining
`LifecycleGate.publishFailureIfCurrent(SyncFailure)` with generation, address,
chain-ID, cached-state, and publisher-ordering checks. No product code changed.

## Historical non-blocking backlog from discovery 1

- `S105-ARCH-007` medium: clarify that Tron partial-save/partial-publication
  behavior is rejected analog evidence, not inherited lifecycle behavior.
- `S105-ARCH-008` medium: reconcile the 60-second interval with the stated
  50,000-request/day rationale.
- `S105-VOP-007` medium: name duplicate-snapshot suppression and
  height/`fetchedAt` policy tests.
- `S105-VOP-008` medium: assert exact `60 → 120 → 240 → 300` backoff/cap and
  one complete coordinator read per refresh.
- `S105-SEC-003` medium: define validation for persisted height, timestamp,
  provider ID, and account-existence relationships.

## Decision

**FRESH ADVERSARIAL ACCEPT REQUIRED.** The revised design is pushed and the
Gimle state/report has been reworked and rehashed. Implementation remains
blocked until `ThorChainCodeReviewer` posts a fresh adversarial ACCEPT for
head `0694dbc` and the user then approves the exact resulting plan revision.
