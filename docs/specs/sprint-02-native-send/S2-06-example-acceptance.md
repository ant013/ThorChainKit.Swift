# S2-06 — iOS Example Send Acceptance

**Risk:** high
**Depends on:** S2-01 through S2-05
**Produces:** runnable package-owned fixture/live send demonstration and guarded Maestro evidence

## Goal

Prove the public contract through a real iOS consumer without relying on Unstoppable. The Example must make CheckTx-accepted versus unknown state, byte-identical retry, and restart recovery visible and deterministic.

## Scope Boundary

All UI automation in this slice belongs to `ThorChainKit/iOS Example`. No Maestro files, runner, fixture transport, launch arguments, or acceptance-only branches are copied into Unstoppable.

The Example reuses the TronKit project/workspace composition shape but not its plaintext mnemonic/UserDefaults behavior, live-first ownership, or empty Testables scheme.

## Proposed Areas

```text
iOS Example/
  iOS Example.xcodeproj
  iOS Example.xcworkspace
  Sources/ThorChainExampleApp.swift
  Sources/Core/ExampleRuntime.swift
  Sources/Signing/LiveSendSession.swift
  Sources/Send/SendViewModel.swift
  Sources/Send/SendView.swift
  Sources/Send/SendReviewView.swift
  Sources/Pending/PendingView.swift
  FixtureSupport/FixtureScenario.swift
  FixtureSupport/FixtureSigner.swift
  FixtureSupport/FixtureTransport.swift
.maestro/sprint-02/*.yaml
Scripts/run-maestro.sh
Tests/ThorChainKitTests/ExampleAcceptanceManifestTests.swift
```

Existing Sprint 1 Example files may be evolved rather than duplicated; the responsibilities/accessibility IDs below are fixed. The current project has one native target, so implementation must make the target graph explicit rather than relying on scheme names alone:

- `ThorChainExampleLive` is the Release app target. Its source membership is the shared SwiftUI `Sources/**` set plus the live session; it links only the `ThorChainKit` package product.
- `ThorChainExampleFixture` is the Debug app target. It has the same shared SwiftUI source membership, defines `EXAMPLE_FIXTURE`, and links `ThorChainExampleFixtureSupport`.
- `ThorChainExampleFixtureSupport` is a non-app fixture-support target whose source membership is exactly `FixtureSupport/**`; it contains the fixture signer, transport, clock, scenario table, and reset hook. It is linked only by `ThorChainExampleFixture`.
- `ThorChainExampleLive` and `ThorChainExampleFixture` are separate app products with separate schemes (`ThorChainExampleLive` Release and `ThorChainExampleFixture` Debug). Neither scheme may hide a target dependency.

The fixture-support target is not a Swift Package product, is absent from Live source membership, Live Archive/Profile dependency closure, and the ThorChainKit library target. The Live app must compile without `EXAMPLE_FIXTURE`; the only conditional import of fixture support is in Example-owned SwiftUI composition. A project-graph test compares target dependencies and source membership, and an Archive/Profile/Release audit resolves the built Live executable before scanning it for the fixture module and symbols (`FixtureScenario`, `FixtureTransport`, `FixtureSigner`, and the fixture target product name). Any unresolved executable, unexpected dependency, source overlap, or scanner error fails closed. UIKit imports, AppDelegate, view-controller types, and representable wrappers are prohibited in the Example and library.

## Runtime Modes

### Fixture

- In-memory/deterministic transport and injected clock.
- Fixed public addresses, account/sequence/fee/halt/module responses, codespace-aware CheckTx envelopes, precomputed valid compressed public key and compact signature.
- Each flow receives a committed non-secret `FixtureScenarioID` that derives a unique wallet/journal namespace. The runner performs a fail-closed reset of that namespace before every independent flow. Only `send-restart-pending` deliberately reuses its own namespace across its two launch phases.
- No private key/mnemonic is present; signer returns a precomputed signature only for the exact fixture request digest and rejects all others.
- Visible badge `FIXTURE` and accessibility value `send.mode.fixture`.

### Live

- Explicit opt-in runtime selection and visible `LIVE` badge.
- `LiveSendSession` owns the mode lifecycle. The approved secret format, derivation path, and signing backend remain an operator decision because S2-04 exposes only the host-owned `Signer` protocol and the Example has no approved secp256k1 derivation authority. Until that decision is recorded, Live may render its opt-in/unavailable state but must not construct a signer, Kit, quote, or send session. The selected backend must derive one address, create the signer for that same derived address, and construct `Kit.instance(address:derivedAddress, walletId:stableWalletID, ...)` as one atomic operation; publication occurs only after all three values agree. A failed derivation, signer construction, or Kit construction publishes no partial session. `stableWalletID` is the non-secret string `thor-example/live/` plus lowercase SHA-256 of the canonical compressed public key; it is not displayed or emitted in artifacts. Replacing mode first releases the previous signer/Kit and clears the send form; logout releases both and clears the form/model. The secure field/UI model is cleared immediately after successful signer construction. The design acknowledges transient UI, `String`/`Data`, and crypto-library copies; it promises neither exclusive in-memory ownership nor complete erasure. It never persists the secret to Keychain or UserDefaults, source, YAML, environment echo, logs, screenshots, or JUnit. The app best-effort clears only mutable buffers it owns on background/logout; process termination destroys process memory, but no security claim depends on a termination callback.
- Public endpoints use the production provider policy.
- Destructive send requires a second explicit confirmation displaying amount, native fee, total, and recipient.
- Controlled LIVE observation is a read-only lifecycle check against a purpose-created unfunded wallet. It may observe opt-in, derivation/address agreement, LIVE labelling, quote/review, logout, and mode replacement, but terminates before confirmation and never calls `Kit.send`, `retryBroadcast`, or a broadcaster. The checklist fails if a confirmation/broadcast action, send call, or broadcast log is observed.

Fixture success is never reported as live evidence.

## Screen Contract and Accessibility IDs

Input:

- `send.mode-badge`.
- `send.recipient.input`, `send.amount.input`, `send.memo.input`, `send.quote.button`.

Review:

- `send.review.amount`, `send.review.recipient`, `send.review.memo`, `send.review.native-fee`, `send.review.total`, `send.review.height`, `send.review.expiry`, `send.confirm.button`, `send.refresh.button`.

Fixture-only controls/counters, compiled only into the fixture-support target:

- `send.fixture.advance-to-expiry`, `send.fixture.signer-call-count`.

Result/pending:

- `send.result.state`, `send.result.local-hash`, `send.retry.button`, `send.retry.fee-change`, `send.pending.list`, `send.pending.<hash>.state`.

The node response hash is an internal classifier input, not a second public transaction identity. Fixture unit/integration tests assert that it matched the local hash before CheckTx acceptance; the Example shows only the canonical local hash.

Sensitive bytes, account number/sequence, signature, wallet identifier, and endpoint credentials are never accessibility values.

## View-Model Flow

`SendViewModel.quote()` accepts a positive RUNE amount in the grammar `[0-9]+(\.[0-9]{1,8})?`, with no sign, exponent, grouping separator, or whitespace. It converts the decimal exactly to 1e8 base units by right-padding the fractional part; it never rounds or truncates. The resulting base-unit value must be in `1...2^256-1` and its canonical magnitude must be at most 32 bytes; values above that bound are the defined `BigUInt` overflow rejection. Invalid input has no quote, network/fixture request, signer call, or broadcaster call. It stores exactly one current quote. `confirm()` passes that quote and the mode signer to `Kit.send`; it never calls the codec/broadcaster directly. Expiration disables confirm and requires an explicit refresh/review.

An unknown result keeps the local transaction ID and enables retry. If the fee changes, the UI presents previous/current fee and only then calls `retryBroadcast(...acceptingNativeFee: current)`. Restart reconstructs pending from both public publishers: an empty journal is shown as empty; a read failure preserves the last snapshot but visibly projects `PENDING DATA UNAVAILABLE`/degraded and disables actions that would guess state. It never presents degraded persistence as confirmed or silently replaces it with an empty list.

## Guarded Maestro Suite

`Scripts/run-maestro.sh` is the only supported UI gate. It must:

1. require an exact `THORCHAIN_SIMULATOR_UDID`;
2. build, boot/install, and launch on that same UDID;
3. validate a committed expected-flow manifest and fail on zero/extra/missing flows;
4. run exactly five Sprint 2 fixture flows;
5. emit JUnit and require tests 5, failures 0, errors 0, skipped 0;
6. scan tracked inputs and generated logs/JUnit for byte canaries, and run a Vision/OCR scan over every generated screenshot;
7. assert the runtime accessibility tree contains every required `send.*` ID, including `send.mode-badge`, and scan every runtime node/value (not only the required IDs) for sensitive bytes, account sequence, signature, wallet identifier, credentials, or private material. A negative mutation inserts a sensitive value into an unlisted node and must fail.

The screenshot gate has a mandatory self-test: a temporary screenshot containing a random visible canary must be detected by the same Vision/OCR path before the real artifacts are scanned. Zero screenshots, OCR initialization failure, unreadable images, or a missed self-test fail the runner.

Flows:

- `send-quote-review.yaml`;
- `send-checktx-accepted.yaml`;
- `send-unknown.yaml`;
- `send-retry.yaml`;
- `send-restart-pending.yaml`.

Selectors use IDs only, never localized labels or coordinates. The committed manifest contains an action/assertion matrix for every flow: `send-quote-review` enters a valid RUNE amount and non-empty memo, asserts all review IDs plus the rendered memo and absolute expiry, then advances the injected clock to the exact deadline; confirm becomes unavailable, Refresh is visible, and signer call count remains zero. The accepted flow asserts `CheckTx accepted — not confirmed`; the unknown flow asserts the canonical local hash and retry; the retry flow asserts unchanged signer count, unchanged hash, exact signed bytes, and explicit changed-fee acknowledgement; the restart flow asserts pending before and after relaunch and namespace reuse only within that flow. The runner's manifest test mutates each flow by removing its action or assertion and must fail, so five YAML files or five JUnit cases alone cannot pass. The response-loss scenario occurs after fixture node acceptance so the local state must be unknown while retry returns matching `sdk/19` without another signer request. UI wording never says simply `confirmed` or `sent` for CheckTx acceptance.

## Unit/Component Tests

- fixture signer accepts only exact digest and records one call;
- live mode cannot initialize without secure runtime secret source;
- live start remains unavailable until the approved secret format/derivation/backend decision; the selected backend must derive the address, signer, and Kit atomically, reject mismatch/partial construction, clear the input/model, label `LIVE`, and logout/mode replacement release the session;
- RUNE grammar, exact 1e8 conversion, zero and >256-bit/32-byte overflow rejection, and no-side-effect invalid-input behavior;
- fixture transcript rejects wrong origin, method, path, query, body, order, missing, or extra calls and asserts expected signed bytes/hash;
- restart distinguishes empty from degraded/unavailable persistence using both pending publishers;
- quote expiry/manual refresh and no silent fee refresh, including the exact absolute deadline and zero signer calls;
- unknown preserves hash and exposes retry;
- changed-fee acknowledgement passes exact current amount;
- process reconstruction consumes the real journal/publisher;
- accessibility IDs exist and sensitive fields are absent;
- acceptance manifest and JUnit parser fail closed, including one-action/one-assertion negative mutations for every flow;
- runtime UI-tree/Maestro verification covers every required ID, including the mode badge, scans every node/value, and rejects an unlisted sensitive accessibility mutation;
- secure input/UI state is cleared after signer construction; Vision/OCR screenshot canary self-test detects a rendered canary and fails closed;
- unique namespace/reset behavior for all independent flows and two-phase namespace preservation for restart;
- Live Release/Archive/Profile products do not link fixture target and contain no fixture scenario/transport symbol strings; the scan fails closed on an unresolved or wrong executable.

## Security and Artifact Rules

- No mnemonic/private key/API credential in Git, UserDefaults, fixtures, Maestro YAML, command line, process environment dumps, console, screenshots, or JUnit.
- A canary is injected only into a temporary copy/runtime; byte scanners and the Vision/OCR screenshot self-test each prove detection through their real path.
- Hash/address/amount are public test-account evidence; they are clearly labeled and never reuse a user wallet.
- Fixture transport cannot compile into the library product or a Release Example live mode; project membership and a built-binary audit both enforce this.
- Controlled LIVE evidence must name the purpose-created unfunded wallet by a non-secret test label only and must show zero confirmation, `Kit.send`, retry-broadcast, and broadcaster events.

## Verification

```text
xcodebuild -workspace iOS\ Example/iOS\ Example.xcworkspace -scheme ThorChainExampleLive -configuration Release -destination id=<UDID> build
xcodebuild -workspace iOS\ Example/iOS\ Example.xcworkspace -scheme ThorChainExampleFixture -configuration Debug -destination id=<UDID> build
THORCHAIN_SIMULATOR_UDID=<UDID> Scripts/run-maestro.sh
swift test --filter ExampleAcceptanceManifestTests
Scripts/audit-example-target-graph.sh
Scripts/audit-example-release-binary.sh --scheme ThorChainExampleLive --configuration Release --destination id=<UDID>
secret/canary/artifact scan with output under artifacts/s2-06/<git-head>/<udid>/
opt-in controlled LIVE checklist and UI-tree evidence; controlled LIVE stops before confirmation/broadcast
```

## Acceptance Criteria

- Five fixture flows pass on one exact simulator and JUnit count is enforced.
- CheckTx-accepted, unknown, retry, and restart are driven through public kit APIs and production storage/codec behavior.
- Retry proves the signature call count remains one and local hash remains identical.
- Fixture and live artifacts are visibly/distinctly labeled, and fixture state is flow-order independent.
- Repository and generated artifacts contain no secret.
- Live signer, derived address, and Kit instance are one atomic session only after the operator records the approved secret format/derivation/backend; otherwise Live is explicitly unavailable and cannot send.
- RUNE amount parsing is exact, bounded to eight fractional digits and `1...2^256-1` base units/32-byte magnitude, and invalid input never reaches quote/signing.
- Fixture transport validates the full ordered transcript and expected signed bytes/hash, and restart shows degraded persistence distinctly from empty.
- The committed five-flow action/assertion matrix, full runtime UI-tree scan (including mode badge and unlisted-node mutation), exact-head/UDID artifact manifest, and resolved Live Release binary scan all fail closed on missing, extra, ambiguous, dirty, tampered, or false-green evidence.

## Pinned Decision

The Example is the only Maestro target. Unstoppable acceptance in S2-07 is WalletCore tests plus a manual Development-app scenario.
