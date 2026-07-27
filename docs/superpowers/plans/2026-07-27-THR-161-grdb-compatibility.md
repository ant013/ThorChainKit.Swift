# THR-161 — GRDB Compatibility Correction Plan

Base: `origin/main` at `65c8e370db983c6bd500448266a4f8f51561ca5f`
Spec: `docs/specs/sprint-02-native-send/THR-161-grdb-compatibility.md`

## Step 1 — Freeze evidence and approve design

- Owner: ThorChainCTO, then ThorChainCodeReviewer.
- Acceptance: state checkpoint records the current branch/base, revised analog
  family, RED Gimle mapping limitation, delta matrix, and test plan; bounded
  adversarial review accepts the exact revised spec or requests another
  revision.
- Paths: `audit/runs/THR-161-grdb-compatibility-20260727/`, spec, this plan,
  `docs/reports/gimle/`.
- Dependency: none.

## Step 2 — Apply the package and verification correction

- Owner: ThorChainSwiftEngineer.
- Acceptance: `Package.swift` changes only exact GRDB `6.29.1` to `6.29.3`;
  `Package.resolved` refreshes GRDB to revision
  `2cf6c756e1e5ef6901ebae16576a7e4e4b834622`; directly affected verifier
  assertions move to `6.29.3`; a correction-owned test proves host-graph
  resolution and non-GRDB lockfile preservation; no source or unrelated
  verifier changes are present.
- Paths: `Package.swift`, `Package.resolved`,
  `Scripts/test-s1-05-dependency-floor.sh`,
  `Scripts/verify-s1-03.sh`, `Scripts/verify-bigint-floor.sh`,
  `Scripts/test-thr-161-grdb-compatibility.sh`.
- Dependency: Step 1 explicit spec approval.

## Step 3 — Mechanical review

- Owner: ThorChainCodeReviewer.
- Acceptance: exact-head implementation diff is allowlisted; local package
  resolution, isolated approved MarketKit host-graph resolution, lockfile
  comparison, iOS 13 device-floor check, and deterministic tests are green;
  review comment cites exact head.
- Paths: correction branch and local evidence only.
- Dependency: Step 2 pushed correction head.

## Step 4 — Independent QA and merge

- Owners: ThorChainQAEngineer, then ThorChainCTO.
- Acceptance: QA independently verifies exact-head local package and approved
  MarketKit host-graph resolution, iOS 13 floor, resolved pin, lockfile
  preservation, deterministic test output, and the committed Gimle report;
  CTO merges only after all local gates pass.
- Paths: QA evidence, final Gimle report, exact merge head.
- Dependency: Step 3 review approval.

## Step 5 — Return the merge SHA to S2-07

- Owner: ThorChainCTO.
- Acceptance: after merge, CTO performs the required POST comment then PATCH
  handoff with the exact ThorChainKit merge SHA, local evidence, refreshed pin
  instruction, and a read-only GET verification before stopping. The handoff
  cites the exact target-local recipient and follows the atomic protocol.
- Paths: THR-160 issue thread; no Unstoppable source edits in this slice.
- Dependency: Step 4 merged correction.
