# THR-157 — S2-05 Durable Broadcast and Pending Lifecycle

Authoritative spec: `docs/specs/sprint-02-native-send/S2-05-durable-broadcast-pending.md`
at architecture revision 10 (`518835315a65996b9321665213adb0516503df65`).
Slice design artifacts are in `audit/runs/thr-157-20260724-cto/`.

## Goal and acceptance

Persist exact signed bytes/hash and sequence reservation before network I/O;
classify only authoritative Cosmos CheckTx responses; retry exact bytes safely;
publish and recover pending state across cancellation, timeout, observation
failure, and process restart. Acceptance is AC1–AC7 in `s2-05-spec.md` and the
test matrix in `s2-05-test-plan.md`.

## Steps

1. **Plan-first review** — Owner: ThorChainCodeReviewer. Review every step for
   a concrete test, implementation path, and local verification command; reject
   scope outside S2-05. Check: Paperclip `APPROVE` with bounded findings and
   discovery counter `1/2`.
2. **Journal and runtime durability** — Owner: ThorChainSwiftEngineer. Add
   tests first, then the minimum `Send/Storage` migration, journal, reservation
   link, shared writer/runtime recovery, and repair ownership. Check: focused
   journal/restart/repair tests; no endpoint call before durable commit.
3. **Broadcast and retry** — Owner: ThorChainSwiftEngineer. Add strict response
   decoder/classifier, Cosmos lookup client, broadcast coordinator, and exact
   retry tests. Check: full classifier/lookup/retry groups; zero signer/codec
   calls on retry; hash mismatch always unknown.
4. **Pending projection and composition** — Owner: ThorChainSwiftEngineer. Add
   repository/publication barrier, replay/degraded replacement observation, and
   minimum Kit/SendRuntime wiring. Check: pending/replay/public redaction and
   concurrent Kit/restart tests.
5. **Mechanical review** — Owner: ThorChainCodeReviewer. Review exact PR head,
   changed-line scope, local test output, `git diff --check`, and spec/plan
   mapping. Check: Paperclip review with `APPROVE` or targeted findings;
   closure budget max `5/5`.
6. **Adversarial architecture review** — Owner: ThorChainCTO. Recheck only the
   allowlisted critical IDs from discovery 2 and direct changed-line
   regressions. Check: no unresolved critical/high blocker, exact-head evidence.
7. **Independent QA** — Owner: ThorChainQAEngineer. Run the exact PR head
   locally, including restart, cancellation, response loss, hash mismatch,
   retry byte identity, shared writer, and redaction. Check: `QA PASS` citing
   exact head.
8. **Merge gate** — Owner: ThorChainCTO. Confirm CR approval, QA PASS, local
   required checks, no conflict markers, and valid spec/plan references; merge
   only after explicit slice approval and all gates.

## Affected paths

- Approved implementation paths only: `Sources/ThorChainKit/Send/Broadcast/`,
  `Sources/ThorChainKit/Send/Storage/`, directly required `Kit`/composition
  wiring, and `Tests/ThorChainKitTests/Send/Broadcast/`.
- Design/evidence: `audit/runs/thr-157-20260724-cto/`, this plan, and the
  Gimle report under `docs/reports/gimle/`.
- Explicitly untouched: S2-06 Example, S2-07 Unstoppable, UI, host integration,
  explorer/history/finality, and unrelated pre-existing worktree reports.

## Dependencies and handoff

S2-04 merged base is required. S2-06 and S2-07 remain blocked by slice order.
No implementation starts before this design receives explicit user approval.

Discovery `1/2`; closure `0/5` at formalization. The second discovery freezes
the blocker allowlist; later reviews are targeted closure passes only.
