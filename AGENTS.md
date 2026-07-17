# ThorChainKit Engineering Contract

## Repository boundary

This private repository is the product authority for `ThorChainKit.Swift`.
The integration branch is `main`. Work on exactly one approved roadmap slice
at a time. The initial repository seed is documentation-only: do not add
`Package.swift`, `Sources/`, `Tests/`, `iOS Example/`, or `.maestro/` outside
the approved S1-01 workflow.

## Evidence before repository changes

1. Load `analog-driven-change` and its required `gimle-evidence` companion.
   Never substitute the legacy `analog-driven-development` workflow.
2. Query codebase-memory project `Users-ant013-Data-AI-thorchain` first.
3. Activate the exact assigned workspace with Serena and independently verify
   every load-bearing analog with targeted `rg` and Git reads.
4. Use current Horizontal Systems kits and Unstoppable Wallet only as verified
   architecture analogs. Load `uw-ios-analog-profile` only for an exact
   Unstoppable checkout and an Unstoppable integration slice.
5. Treat Vultisig iOS as THOR-specific supporting evidence, not as the primary
   lifecycle or ownership spine unless an approved design explicitly says so.
6. Persist the Gimle reliability report under `docs/reports/gimle/`, complete
   adversarial review, push the final spec and plan, and wait for explicit user
   approval before implementation.

## Development workflow

- `ThorChainCEO` owns only the dormant outer roadmap walker.
- `ThorChainCTO` owns architecture, planning, approval blocking, and the merge
  gate for one child slice.
- `ThorChainCodeReviewer` owns adversarial spec review and exact-PR-head code
  review; it never implements or merges.
- `ThorChainSwiftEngineer` owns test-first implementation and the pull request;
  it never merges.
- `ThorChainQAEngineer` independently verifies the exact PR head and never
  implements fixes or merges.

Every handoff is atomic: push evidence, POST the issue comment and require a
2xx response, PATCH assignee/status, perform one read-only verification, then
STOP. A mention alone is not a handoff. Never bypass an execution-lock conflict
with direct database writes.

## Product and acceptance boundaries

- Preserve Horizontal Systems kit conventions where current-tree evidence
  supports them; do not copy demo-only lifecycle or secret-storage shortcuts.
- Native THORChain support belongs in this kit. The existing multichain swap
  provider is not reimplemented in the initial slices.
- Maestro acceptance belongs only in the ThorChainKit `iOS Example`.
  Unstoppable Wallet uses adapter tests, AppTests, and manual acceptance; never
  apply this repository's Maestro suite to the wallet application.
- Never commit secrets, mnemonic phrases, provider credentials, host-local
  bindings, or absolute operator paths.
- Never add `Co-authored-by:` trailers.

The autonomous roadmap walker remains off until an explicit operator
instruction activates it after live team acceptance.
