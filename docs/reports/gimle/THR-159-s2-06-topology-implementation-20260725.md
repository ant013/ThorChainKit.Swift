# THR-159 S2-06 topology implementation evidence

Date: 2026-07-25
Implementation checkpoint: `a6d2fce74a80cf118c4cab733948dcfbaae95475`
Simulator UDID: `0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`

The report-binding commit necessarily follows this implementation checkpoint;
the report does not self-embed its final commit hash.

## Gimle reliability

Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried before
repository source inspection. Its architecture and ExampleRuntime symbol
results were current-tree compatible for the existing Example boundary.

Palace health was reachable, but the project-overview lookup returned
`unknown_project` for the codebase-memory slug. Gimle therefore has RED trust
for this run; the topology decision used the independently verified current
worktree, targeted `rg`, and Git evidence. Serena MCP tools were not exposed in
this run, so no Serena result is claimed.

## Implementation evidence

- Root `Package.swift` now owns the pinned HdWalletKit revision and the dynamic
  `ThorChainExampleLiveSupport` product backed by `LiveSupport`.
- The Xcode project has one local package root, no direct remote HdWalletKit
  root, no native LiveSupport target, and keeps native FixtureSupport.
- The target-graph audit, S2-06 manifest contract/negative mutations, Swift
  parse checks, shell syntax checks, and `git diff --check` passed.
- The old `96d8962` Fixture Debug and Live Release build logs are
  pre-implementation attempts and are excluded from current-head acceptance.
- The release audit failed closed when the exact Live artifact was unresolved.

## Closure 2 correction verification

- This report uses the implementation checkpoint above for its implementation
  evidence; the final exact PR head is established by Git plus the pushed
  Paperclip handoff/review record, not by a self-embedded value in this file.
- `bash -n` for both Example audit scripts, the target-graph audit, and
  `git diff --check` passed at that head.
- Release-audit probes passed for a clean artifact, fixture-symbol rejection,
  a failing `strings` scanner, and a failing `rg` matcher; each rejection
  exited non-zero.

No hosted workflow was dispatched.
