# THR-161 — GRDB Compatibility Correction Plan

Base: `origin/main` at `65c8e370db983c6bd500448266a4f8f51561ca5f`  
Spec: `docs/specs/sprint-02-native-send/THR-161-grdb-compatibility.md`

## Step 1 — Freeze evidence and approve design

- Owner: ThorChainCTO, then ThorChainCodeReviewer.
- Acceptance: state checkpoint records the current branch/base, analog family,
  RED Gimle mapping limitation, delta matrix, and test plan; adversarial review
  accepts the exact spec revision or requests a revision.
- Paths: `audit/runs/THR-161-grdb-compatibility-20260727/`, spec, this plan,
  `docs/reports/gimle/`.
- Dependency: none.

## Step 2 — Apply the package-only correction

- Owner: ThorChainSwiftEngineer.
- Acceptance: `Package.swift` changes only exact GRDB `6.29.1` to `6.29.3`;
  `Package.resolved` refreshes GRDB to revision
  `2cf6c756e1e5ef6901ebae16576a7e4e4b834622`; no source or unrelated pin
  changes are present.
- Paths: `Package.swift`, `Package.resolved`.
- Dependency: Step 1 explicit spec approval.

## Step 3 — Mechanical review

- Owner: ThorChainCodeReviewer.
- Acceptance: exact-head diff is allowlisted; local package resolution and
  required deterministic tests are green; review comment cites exact head.
- Paths: correction branch and local evidence only.
- Dependency: Step 2 pushed correction head.

## Step 4 — Independent QA and merge

- Owners: ThorChainQAEngineer, then ThorChainCTO.
- Acceptance: QA independently verifies exact-head local package resolution,
  iOS 13 floor, resolved pin, and test output; CTO merges only after all local
  gates pass.
- Paths: QA evidence, final Gimle report, exact merge head.
- Dependency: Step 3 review approval.

## Step 5 — Return the merge SHA to S2-07

- Owner: ThorChainCTO.
- Acceptance: atomic comment and assignee/status handoff to THR-160 cite the
  exact ThorChainKit merge SHA, local evidence, and refreshed pin instruction.
- Paths: THR-160 issue thread; no Unstoppable source edits in this slice.
- Dependency: Step 4 merged correction.

