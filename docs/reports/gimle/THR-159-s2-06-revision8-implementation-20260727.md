# THR-159 S2-06 revision 8 implementation evidence

Date: 2026-07-27
Branch: `feature/THR-159-s2-06-send-acceptance`
Approved design head: `a800820bb4aaed7cf6ea264e16f1fe6d059fd152`

## Scope

This implementation applies only the operator-approved revision 8 reduction:
one accepted-CheckTx Maestro flow, the focused injected-transport composition
test, minimum fixture composition, and local Fixture/Live target gates. The
superseded quote-only, unknown, retry, restart, OCR, artifact-provenance, and
manifest-mutation UI harnesses are removed. No library send runtime, public API,
Unstoppable, or S2-07 files were changed.

## Evidence substrate

- Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried first.
  Its current graph returned no symbol for `FixtureScenario`, `FixtureTranscript`,
  or the S2-06 scripts, and only a variable hit for `fixtureTransport`; exact
  current-tree `rg`, Git history, and `swiftc -parse` were therefore the source
  of truth.
- Palace health was reachable, but its registered project list does not include
  `Users-ant013-Data-AI-thorchain`; the project-overview call returned
  `unknown_project`. The Palace runtime also reported a separate Gimle serving
  checkout and a different Git SHA. These are coverage/mapping limitations, not
  implementation evidence.
- The existing current-tree target graph audit passed, proving the Live/Fixture
  ownership boundary remains intact.

## Verification

Passed:

- `bash -n Scripts/run-maestro.sh Scripts/run-maestro-s2-06.sh Scripts/test-run-maestro-s2-06.sh Scripts/audit-example-target-graph.sh Scripts/audit-example-release-binary.sh`
- `Scripts/test-run-maestro-s2-06.sh`
- `Scripts/audit-example-target-graph.sh`
- `swiftc -parse` for every modified Swift source
- committed accepted-send Maestro YAML parse and `git diff --check`

Not completed:

- `xcrun swift test --filter KitCompositionTests/testFixtureSendReachesInjectedTransportOnceAndAcceptsCheckTx`
- Fixture Debug and Live Release xcodebuilds
- simulator install/launch and the single Maestro flow

Both local build attempts reached dependency resolution and stalled cloning the
Swift Protobuf nested `protobuf` submodule before compiling repository sources;
the bounded processes were stopped. No dependency or source workaround was
made. Reviewer and QA must rerun the revision 8 local package/build/simulator
commands on the exact pushed head.

## Trust

Gimle trust is `RED` for this run because the code graph has a coverage gap and
the Palace project mapping is unresolved. The implementation decisions use
independent current-worktree evidence only; no stale or unmapped indexed result
was accepted.
