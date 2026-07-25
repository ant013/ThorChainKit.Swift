# Sprint 2 Roadmap Status Repair

## Goal

Restore agreement between the canonical Sprint 2 roadmap and already merged,
independently closed slices S2-02 through S2-05.

## Assumptions

- `docs/roadmap/sprint-02-native-rune-send.md` is authoritative because it
  explicitly defines each status cell as the canonical repository marker.
- GitHub merge metadata and the completed Paperclip issues are sufficient
  evidence for this documentation-only correction.
- Roadmap dates follow the operator timezone, Asia/Bishkek, as demonstrated by
  the existing S2-01 row.
- This repair changes no product behavior and does not approve or implement
  S2-06.

## Scope

Change only the four status cells in
`docs/roadmap/sprint-02-native-rune-send.md`:

- S2-02: `✅ Implemented — PR #12 — 2026-07-24`
- S2-03: `✅ Implemented — PR #13 — 2026-07-24`
- S2-04: `✅ Implemented — PR #14 — 2026-07-24`
- S2-05: `✅ Implemented — PR #15 — 2026-07-25`

The evidence is:

- PR #12 merged as `754fcc831b3d26e2812630e06b0ffdf05e5c228b`;
- PR #13 merged as `3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`;
- PR #14 merged as `76e3a7195d68140dcd137a3f978ae37f6963b7f5`;
- PR #15 merged as `4c2e82bb17aa48379235a9f01ccdba489bb46e69`;
- Paperclip issues THR-152, THR-154, THR-155, and THR-157 are `done`.

## Out of Scope

- Product source, tests, fixtures, scripts, project files, and CI.
- Re-reviewing or changing the accepted behavior of S2-02 through S2-05.
- Changing S2-01, S2-06, or S2-07.
- Resolving the separate S2-06 Live signer decision.
- Any Unstoppable Wallet change or remote operation.

## Affected Areas

- `docs/roadmap/sprint-02-native-rune-send.md`

No other tracked file may change during implementation of this repair.

## Acceptance Criteria

1. The four rows contain the exact PR numbers and dates listed above.
2. S2-01 remains unchanged and S2-06/S2-07 remain `Pending`.
3. `git diff --name-only <base>...HEAD` reports only the roadmap file for the
   implementation commit; the approved spec commit is the only other change on
   the repair branch.
4. `git diff --check <base>...HEAD` passes.
5. No build, test, mutant, simulator, Maestro, or GitHub Actions run is
   performed because the implementation is a four-cell documentation repair.
6. S2-06 formalization is recreated or rebased from corrected `origin/main`
   before S2-06 implementation begins.

## Verification Plan

- Re-read the exact seven Sprint 2 status rows from the implementation head.
- Compare PR numbers and merge dates with read-only `gh pr list` metadata.
- Confirm the Paperclip source issues remain `done`.
- Run `git diff --check` and inspect the exact changed-file list.
- Confirm no hosted run was dispatched.

## Open Questions

- None. Implementation waits only for explicit approval of this spec.
