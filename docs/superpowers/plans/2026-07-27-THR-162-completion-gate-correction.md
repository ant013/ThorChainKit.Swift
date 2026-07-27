# THR-162 — CompletionGate correction plan

**Revision:** 2 — discovery 1/2; closure 0/5

## Step 1 — Formalize and preserve evidence

- Owner: ThorChainCTO
- Files: `docs/specs/sprint-02-native-send/THR-162-completion-gate-correction.md`,
  `THR-162-completion-gate-delta-matrix.md`,
  `THR-162-completion-gate-test-plan.md`,
  `docs/reports/gimle/`, `audit/runs/THR-162-20260727-1125/`
- Acceptance: current-tree analogs include the THR-152 historical precedent,
  codebase-memory limitations, exact base SHA, strict-build blockers, scope
  boundaries, and conditional candidate delta. No product source changes.
- Dependency: none.

## Step 2 — Discovery and adversarial review

- Owner: ThorChainCodeReviewer
- Files: the Step 1 spec/plan and referenced source/test paths.
- Acceptance: bounded architecture, security/protocol-safety, and
  verification/operability review; one severity-tagged synthesis; discovery
  counter remains `1/2`; allowlisted blockers THR162-REV-001 through
  THR162-REV-003 are resolved in this revision without reopening discovery.
- Dependency: Step 1 pushed and explicitly handed off.

## Step 3 — Test-first implementation after explicit approval

- Owner: ThorChainSwiftEngineer
- Files: `Sources/ThorChainKit/Network/EndpointOperationRunner.swift` and a
  focused test/probe file only if Step 2 and approval require it.
- Acceptance: capture an exact A/B compiler proof or the specified reduced
  canary before editing; implement only the compiler-proven minimal
  transfer-boundary correction and pass focused package tests. If no proof is
  available, do not edit source.
- Dependency: reviewer approval and explicit user/Board approval.

## Step 4 — Mechanical review and closure

- Owner: ThorChainCodeReviewer
- Acceptance: exact-head diff/scope review, local checks, and CR approval;
  closure budget begins at `1/5`.
- Dependency: Step 3 PR.

## Step 5 — Independent QA and CTO merge gate

- Owners: ThorChainQAEngineer, then ThorChainCTO
- Acceptance: QA independently verifies the exact PR head and required local
  package regressions; simulator/Maestro remain out of scope. CTO merges only
  with CR + QA evidence and hands the exact merge SHA to THR-160.
- Dependency: Step 4 approval and QA pass.
