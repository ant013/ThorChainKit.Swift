# S2-06 — iOS Example Send Acceptance

**Revision:** 8 — minimal acceptance
**Risk:** high
**Depends on:** S2-01 through S2-05
**Produces:** a locally runnable Example proving one complete native RUNE send path

Revision 8 supersedes the previous five-flow/OCR/mutation acceptance design.
The earlier revisions remain available in Git history. They are not acceptance
requirements for S2-06.

## Goal

Prove through the package-owned iOS Example that the public ThorChainKit API can:

1. start the fixture runtime;
2. quote a native RUNE send;
3. sign through the injected signer;
4. submit through the injected transport;
5. publish `CheckTx accepted — not confirmed`.

Retry, unknown-result, duplicate-broadcast protection, and restart recovery
remain required product behavior. They are verified at the package layer where
those state transitions are owned; they are not repeated as mandatory Maestro
flows.

## Assumptions

- S2-01 through S2-05 are merged and their focused package tests remain green.
- Exact head `230fe8f48d8693bc94c5117b3817c3877a6cd55d` already passed the focused
  fixture composition test, local Fixture build/install/launch, and the
  standalone `send-checktx-accepted` flow.
- A compatible locally installed Xcode, iOS Simulator runtime, iPhone simulator,
  Java, and Maestro may be used. S2-06 does not pin an obsolete Xcode/runtime
  pair when the current installed pair can build and run the Example.
- GitHub Actions is not an acceptance environment. All tests, builds, simulator
  work, and Maestro execution are local on the MacBook.

## Scope

### In scope

- Keep the existing SwiftUI Fixture and Live Example targets.
- Keep the fixture-only signer and injected HTTP transport required to exercise
  the public send facade without real network I/O or private material.
- Keep the minimum fixture responses needed for lifecycle, quote, signing, and
  one accepted broadcast.
- Keep one mandatory Maestro flow:
  `.maestro/sprint-02/send-checktx-accepted.yaml`.
- Keep one focused composition regression proving exactly one injected
  broadcast POST returns `checkTxAccepted`.
- Reuse existing S2-05 package tests for retry, unknown, timeout, restart,
  sequence advancement, publication failure, and late-result protection.
- Keep a local Live Release compile gate. It proves target composition only; it
  does not authorize or execute a real send.
- Preserve the no-secret and fixture/live target-separation boundaries.

### Out of scope

- Four additional mandatory Maestro flows for quote-only, unknown, retry, and
  restart.
- OCR of screenshots, OCR canary self-tests, full accessibility-tree secret
  scanning, or synthetic secret mutations.
- Manifest/YAML/source mutation suites whose purpose is testing the test runner.
- Exact five-case JUnit cardinality or an action/assertion matrix manifest.
- Exact Xcode, simulator runtime, UDID model, Java patch, or host fingerprint
  pinning beyond using one available compatible local simulator consistently
  for a run.
- Revalidating every internal request, query-key order, response envelope, or
  transport branch through UI automation.
- Repeating S2-03 through S2-05 codec, signer, retry, journal, or concurrency
  contracts in the Example acceptance layer.
- Any Unstoppable Wallet change, remote commit, PR, or Maestro flow.
- Any real mainnet broadcast.

## Affected areas

Expected implementation cleanup is limited to:

```text
.maestro/sprint-02/
Scripts/run-maestro.sh
Scripts/run-maestro-s2-06.sh
Scripts/test-run-maestro-s2-06.sh          (remove or reduce to syntax/dispatch)
Scripts/sprint-02-flow-manifest.json       (remove)
Scripts/validate-s2-06-manifest.py         (remove)
Scripts/verify-s2-06-artifacts.py          (remove from the gate; delete if unused)
Scripts/scan-s2-06-ocr.swift               (remove)
Tests/ThorChainKitTests/ExampleAcceptanceManifestTests.swift (remove)
Tests/ThorChainKitTests/KitCompositionTests.swift
iOS Example/FixtureSupport/FixtureScenario.swift
iOS Example/Sources/Core/ExampleRuntime.swift
iOS Example/Sources/Signing/FixtureTransport.swift
iOS Example/Sources/Views/DiagnosticsView.swift
Sources/ThorChainKit/Core/KitFactory.swift  (test-only fixture composition only)
```

No production send state machine, signer, journal, broadcaster, endpoint pool,
or public API change is authorized by this revision.

## Acceptance criteria

S2-06 is accepted when all of the following are true on one local compatible
MacBook toolchain:

1. The focused `Kit.fixture` composition test proves one public send reaches the
   injected transport exactly once and returns `.checkTxAccepted`.
2. The existing focused package tests for retry and restart remain green.
3. Fixture Debug builds, installs, launches, and remains alive long enough to
   begin the flow.
4. Live Release builds successfully and contains no FixtureSupport product.
5. The single `send-checktx-accepted` Maestro flow passes and JUnit contains one
   passing, unskipped testcase.
6. The accepted flow uses the public Kit lifecycle/quote/send facade and shows
   `CheckTx accepted — not confirmed`.
7. No mnemonic, private key, provider credential, or host-local `.env` content
   is tracked or printed by the changed path.
8. The final diff contains no implementation or test-runner machinery that is
   not required by criteria 1–7.

The following are explicitly non-blocking for S2-06 because package tests own
their contracts: UI automation for unknown, retry, fee change, and process
restart; OCR; complete accessibility inventory; artifact provenance manifests;
negative mutations; and exact toolchain fingerprinting.

## Verification plan

Run narrow checks before simulator work:

```text
xcrun swift test --filter KitCompositionTests/testFixtureSendReachesInjectedTransportOnceAndAcceptsCheckTx
xcrun swift test --filter BroadcastRetryTests
xcrun swift test --filter SendJournalRestartTests
bash -n Scripts/run-maestro.sh Scripts/run-maestro-s2-06.sh
git diff --check
```

Then use one available compatible simulator:

```text
xcodebuild \
  -workspace "iOS Example/iOS Example.xcworkspace" \
  -scheme ThorChainExampleFixture \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=<UDID>" \
  SWIFT_SUPPRESS_WARNINGS=NO build

xcodebuild \
  -workspace "iOS Example/iOS Example.xcworkspace" \
  -scheme ThorChainExampleLive \
  -configuration Release \
  -destination "platform=iOS Simulator,id=<UDID>" \
  SWIFT_SUPPRESS_WARNINGS=NO build

THORCHAIN_SIMULATOR_UDID=<UDID> Scripts/run-maestro.sh s2-06
```

Warnings-as-errors may remain enabled. `SWIFT_SUPPRESS_WARNINGS=NO` must be used
when that policy is active so Xcode does not receive conflicting flags.

## Analog delta matrix

| Field | Decision |
|---|---|
| Analog family | Primary: the established `Scripts/run-maestro.sh` single-slice, single-JUnit-flow contract. Supporting: S2-05 `BroadcastRetryTests` and `SendJournalRestartTests`. Rejected counterexample: the S2-06 five-flow/OCR/mutation harness. |
| Coverage | The runner owns local build/install/launch/UI acceptance. Package tests own retry, timeout, duplicate-broadcast, publication, and restart state transitions. |
| Invariants to preserve | Public Kit facade, exactly one broadcast for the accepted path, byte-identical retry, no duplicate send, durable pending state, fixture/live separation, no secrets, local-only test execution. |
| Required differences | S2-06 selects one accepted-send UI flow instead of five; state-error guarantees remain package-test requirements. |
| Rejected differences | No production send refactor, no endpoint-policy weakening, no real network broadcast, no Unstoppable changes, and no new abstraction replacing the existing test seam. |
| Failure modes | A send that never reaches transport, more than one POST, non-zero CheckTx code, build/launch failure, FixtureSupport leakage into Live, or a secret in tracked/output data remains blocking. |
| Tests before code | The already passing focused fixture composition regression and standalone accepted-send flow are the reproduction baseline. |
| Verification | Focused package tests, two local builds, one local Maestro flow, secret/diff hygiene, and reviewer inspection of the reduced surface. |

## Adversarial review

- Removing four UI flows does not remove their product guarantees: the owning
  S2-05 package tests remain mandatory.
- One UI happy path is sufficient to prove Example wiring; UI automation is not
  the owner of retry/journal correctness.
- OCR, complete accessibility scanning, and mutation testing do not detect the
  current product failure class and previously turned a local Maestro service
  problem into a product blocker.
- The smaller alternative is not “no acceptance.” It retains one real
  end-to-end flow plus the state-machine tests at their correct layer.
- High-risk money movement remains protected because S2-06 never performs a
  real network broadcast and does not alter the S2-03–S2-05 implementation.

## Open questions

None. The operator explicitly selected a less rigid acceptance boundary so a
working version can be delivered. Any later request for live mainnet-send
evidence or additional UI automation must be a separate approved task.
