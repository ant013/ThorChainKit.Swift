# THR-164 — PendingTransactionRepository strict-concurrency correction plan

**Revision:** 4 — discovery 1/2; closure 0/5

## Step 1 — Formalize evidence and design

- Owner: ThorChainCTO
- Files: `docs/specs/sprint-02-native-send/THR-164-pending-transaction-strict-concurrency.md`,
  its delta matrix and test plan, `audit/runs/THR-164-20260727/`.
- Acceptance: exact base SHA, current source/test/composition anchors, one
  coherent analog spine, syntax supporting analog, rejected counterexample,
  scope boundaries, and local verification gates are recorded. No product
  source changes.
- Dependency: none.

## Step 2 — Bounded adversarial discovery review

- Owner: ThorChainCodeReviewer
- Files: Step 1 artifacts and referenced source/test paths.
- Acceptance: architecture/boundaries, security/protocol-safety, and
  verification/operability review; one severity-tagged synthesis; discovery
  remains `1/2`; only current-slice high/critical blockers may block. Recheck
  SEC-01/VOP-01 against the queue-blocked callback test and VOP-02 against the
  revision-4 executable two-run harness: separate per-run checkouts and host
  environments, per-run expected SHA and paths,
  individual four-file pin checks, resolved checkout/graph capture,
  `PIPESTATUS[0]` exit capture under explicit Bash with `pipefail`, positive
  kit compile assertion, and durable evidence manifest.
- Dependency: Step 1 spec commit pushed and handed off.

## Step 3 — Explicit approval and test-first implementation

- Owner: ThorChainSwiftEngineer
- Files: `Sources/ThorChainKit/Send/Storage/PendingTransactionRepository.swift`
  and the smallest focused test change, if Step 2 confirms it is required.
- Acceptance: revision-bound approval exists; the queue-blocked
  weak-deallocation test is added first; focused selectors and the exact local
  compiler/host commands are recorded; positive kit compilation is proven;
  only the two diagnostics are addressed.
- Dependency: Step 2 approval and explicit user/Board approval.

## Step 4 — Exact-head mechanical review and closure

- Owner: ThorChainCodeReviewer
- Acceptance: exact-head scope/diff review, local checks, and CR approval;
  closure budget begins at `1/5`.
- Dependency: Step 3 PR.

## Step 5 — Independent local QA and CTO merge gate

- Owners: ThorChainQAEngineer, then ThorChainCTO.
- Acceptance: QA independently verifies the exact PR head and local host/
  focused evidence; CTO merges only after CR approval and QA pass, then hands
  the merge SHA to THR-160.
- Dependency: Step 4 approval and QA evidence.
