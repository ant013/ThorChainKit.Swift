# THR-159 — S2-06 Minimal Send Acceptance Plan

This plan implements revision 8 of
`docs/specs/sprint-02-native-send/S2-06-example-acceptance.md`.

## Goal

Finish S2-06 by proving one complete Example send path and relying on the
existing package tests for retry, unknown, and restart correctness.

## Steps

- [ ] 1. Reduce the acceptance harness
  - Keep only `send-checktx-accepted` as the mandatory S2-06 Maestro flow.
  - Remove the five-flow manifest, OCR, artifact-provenance, and negative
    mutation gates from S2-06.
  - Align the runner with the existing one-slice/one-flow JUnit contract.

- [ ] 2. Minimize fixture composition
  - Preserve only the fixture lifecycle, quote, signer, and accepted-broadcast
    responses needed by the public send path.
  - Keep the focused regression proving exactly one injected POST and
    `.checkTxAccepted`.
  - Remove strict fixture/test machinery that exists only to validate internal
    request order or the deleted UI flows.

- [ ] 3. Verify locally
  - Run the focused composition, retry, and restart package tests.
  - Build Fixture Debug and Live Release on one compatible installed simulator.
  - Run `send-checktx-accepted` once through the supported S2-06 runner.
  - Check secret hygiene and final diff scope.

- [ ] 4. Review and close
  - Push the reduced exact head.
  - CodeReviewer verifies the delta against revision 8.
  - QA reruns only the revision-8 acceptance commands on that exact head.
  - Merge when review and QA pass; no GitHub Actions tests or Maestro.

## Non-goals

No production send refactor, no real mainnet broadcast, no Unstoppable change,
no S2-07 work, and no restoration of the superseded five-flow acceptance gate.
