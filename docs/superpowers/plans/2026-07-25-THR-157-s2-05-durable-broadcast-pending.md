# THR-157 — S2-05 Durable Broadcast and Pending Lifecycle

Authoritative current-main base: `76e3a7195d68140dcd137a3f978ae37f6963b7f5`.
Authoritative slice spec: `docs/specs/sprint-02-native-send/S2-05-durable-broadcast-pending.md`.
Formalization artifacts: `audit/runs/thr-157-reformalize-20260725/`.

## Goal and acceptance

Persist exact signed bytes/hash and the S2-04 reservation link before network I/O; classify only authoritative Cosmos CheckTx responses; retry exact bytes safely; publish/recover pending state across cancellation, timeout, observation failure, and restart. Done means AC1–AC7 in the current S2-05 spec pass with local MacBook evidence and no out-of-slice integration.

## Steps

1. **Plan-first review** — Owner: ThorChainCodeReviewer. Review this exact-main plan and the re-formalized artifacts; check every step has concrete tests, implementation paths, and local verification. Counter: discovery 2/2; frozen IDs `ARCH-157-01/02`, `SEC-157-01/02/03`, `VOP-157-01..05`. Gate: Paperclip APPROVE or bounded findings.
2. **Journal/runtime durability** — Owner: ThorChainSwiftEngineer. Tests first; add only the S2-05 migration, journal, immutable bytes/hash, reservation link, shared-writer recovery, and repair ownership in `Sources/ThorChainKit/Send/Storage` plus the two-level ownership changes in `Sources/ThorChainKit/Send/Internal/SendRuntime.swift`. Gate: journal/order/restart/repair tests, zero endpoint call before durable commit.
3. **Broadcast/retry and capability gate** — Owner: ThorChainSwiftEngineer. Tests first; add strict REST envelope/classifier, lookup client, broadcast coordinator, exact-byte retry and fee/sequence policy in `Sources/ThorChainKit/Send/Broadcast`; update only the current endpoint capability gate in `Sources/ThorChainKit/Network/EndpointLease+Send.swift` and matching manifest tests. No current family is production-enabled until approved positive/absent-hash probes exist. Gate: full classifier/lookup/retry groups, no signer/codec calls on retry, mismatch always unknown, and production-unavailable test.
4. **Pending/composition/restart** — Owner: ThorChainSwiftEngineer. Tests first; add the minimum pending repository/publication barrier, direct `Kit`/`SendRuntime` wiring, deterministic observation seam, and `Scripts/test-s2-05-restart.sh` two-process harness required by S2-05. Gate: named AC1–AC7 tests, true restart, pending replay/order/degraded/restart/concurrent-runtime tests, and no history/UI/host files.
5. **Mechanical review** — Owner: ThorChainCodeReviewer. Review exact PR head, changed-line scope, local outputs, `git diff --check`, and spec/plan mapping. Gate: APPROVE; closure budget max 5/5.
6. **Adversarial closure** — Owner: ThorChainCTO. Recheck only the frozen blocker IDs from discovery 2 and changed-line regressions; no new broad discovery. Gate: no unresolved critical/high blocker; record closure counter.
7. **Independent QA** — Owner: ThorChainQAEngineer. Run exact PR head locally, including restart, cancellation, response loss, hash mismatch, retry byte identity, shared writer, and redaction. Gate: QA PASS citing exact head.
8. **Merge gate** — Owner: ThorChainCTO. Require CR approval, QA PASS, local required checks, no conflict markers, and valid current spec/plan paths. Merge only after explicit slice approval.

## Affected paths

- `Sources/ThorChainKit/Send/Broadcast/`
- `Sources/ThorChainKit/Send/Storage/`
- `Sources/ThorChainKit/Send/Internal/SendRuntime.swift`
- narrowly gated `Sources/ThorChainKit/Network/EndpointLease+Send.swift` and `Tests/ThorChainKitTests/Send/Preflight/EndpointManifestTests.swift`
- directly required `Sources/ThorChainKit/Core/Kit+Send.swift`, `Sources/ThorChainKit/Core/Kit.swift`, or `Sources/ThorChainKit/Core/KitFactory.swift`
- matching `Tests/ThorChainKitTests/Send/Broadcast/`, storage, composition, pending, and runtime-ownership tests
- `Scripts/test-s2-05-restart.sh` and `Scripts/test-s2-05-family-compatibility.sh`

Untouched: S2-06 Example, S2-07 Unstoppable, UI/host integration, inclusion/history/finality, replacement/resigning, explorer logic, and unrelated pre-existing reports.

Discovery **2/2**; closure **0/5** at this revised formalization. Frozen allowlist: `ARCH-157-01`, `ARCH-157-02`, `SEC-157-01`, `SEC-157-02`, `SEC-157-03`, `VOP-157-01`, `VOP-157-02`, `VOP-157-03`, `VOP-157-04`, `VOP-157-05`. Later review is targeted closure only. Implementation remains prohibited until this exact revision receives explicit user confirmation, including the fail-closed current-family retry gate.
