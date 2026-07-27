# THR-162 — CompletionGate correction plan

## Step 1 — Formalize and preserve evidence

- Owner: ThorChainCTO
- Files: `docs/specs/sprint-02-native-send/THR-162-completion-gate-correction.md`,
  `THR-162-completion-gate-delta-matrix.md`,
  `THR-162-completion-gate-test-plan.md`,
  `docs/reports/gimle/`, `audit/runs/THR-162-20260727-1125/`
- Acceptance: current-tree analogs, codebase-memory limitations, exact base
  SHA, strict-build blockers, scope boundaries, and candidate delta are
  recorded. No product source changes.
- Dependency: none.

## Step 2 — Discovery and adversarial review

- Owner: ThorChainCodeReviewer
- Files: the Step 1 spec/plan and referenced source/test paths.
- Acceptance: bounded architecture, security/protocol-safety, and
  verification/operability review; one severity-tagged synthesis; discovery
  counter recorded as `1/2` and stable blocker IDs used for subsequent closure.
- Dependency: Step 1 pushed and explicitly handed off.

## Step 3 — Test-first implementation after explicit approval

- Owner: ThorChainSwiftEngineer
- Files: `Sources/ThorChainKit/Network/EndpointOperationRunner.swift` and a
  focused test/probe file only if Step 2 and approval require it.
- Acceptance: capture the pre-change diagnostic, implement only the
  compiler-proven minimal transfer-boundary correction, and pass focused tests.
- Dependency: reviewer approval and explicit user/Board approval.

## Step 4 — Mechanical review and closure

- Owner: ThorChainCodeReviewer
- Acceptance: exact-head diff/scope review, local checks, and CR approval;
  closure budget begins at `1/5`.
- Dependency: Step 3 PR.

## Step 5 — Independent QA and CTO merge gate

- Owners: ThorChainQAEngineer, then ThorChainCTO
- Acceptance: QA independently verifies the exact PR head and required local
  S2-06 gates; CTO merges only with CR + QA evidence and hands the exact merge
  SHA to THR-160.
- Dependency: Step 4 approval and QA pass.

