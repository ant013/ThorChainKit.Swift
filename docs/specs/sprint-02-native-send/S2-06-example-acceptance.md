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
  ThorChainKitExample.xcodeproj
  ThorChainKitExample.xcworkspace
  Sources/App/AppDelegate.swift
  Sources/Core/ExampleRuntime.swift
  Sources/Signing/EphemeralLiveSigner.swift
  Sources/Send/SendViewModel.swift
  Sources/Send/SendViewController.swift
  Sources/Send/SendReviewViewController.swift
  Sources/Pending/PendingViewController.swift
  FixtureSupport/FixtureScenario.swift
  FixtureSupport/FixtureSigner.swift
  FixtureSupport/FixtureTransport.swift
.maestro/sprint-02/*.yaml
Scripts/run-maestro.sh
Tests/ThorChainKitTests/ExampleAcceptanceManifestTests.swift
```

Existing Sprint 1 Example files may be evolved rather than duplicated; the responsibilities/accessibility IDs below are fixed. The Xcode project defines two app schemes/configurations:

- `ThorChainKitExampleLive` builds the production Example app and never links fixture support;
- `ThorChainKitExampleFixture` is a Debug-only Maestro scheme that links a separate `ThorChainKitExampleFixtureSupport` target.

The fixture-support target is not a Swift Package product, is absent from Live/Archive/Profile target dependencies and source membership, and cannot be imported by library sources. A Release link/binary-string audit proves fixture scenario/transport symbols are absent.

## Runtime Modes

### Fixture

- In-memory/deterministic transport and injected clock.
- Fixed public addresses, account/sequence/fee/halt/module responses, codespace-aware CheckTx envelopes, precomputed valid compressed public key and compact signature.
- Each flow receives a committed non-secret `FixtureScenarioID` that derives a unique wallet/journal namespace. The runner performs a fail-closed reset of that namespace before every independent flow. Only `send-restart-pending` deliberately reuses its own namespace across its two launch phases.
- No private key/mnemonic is present; signer returns a precomputed signature only for the exact fixture request digest and rejects all others.
- Visible badge `FIXTURE` and accessibility value `send.mode.fixture`.

### Live

- Explicit opt-in runtime selection and visible `LIVE` badge.
- Purpose-created secret entered through a secure runtime field and transferred to a session-memory signer. The secure field/UI model is cleared immediately after successful signer construction. The design acknowledges transient UI, `String`/`Data`, and crypto-library copies; it promises neither exclusive in-memory ownership nor complete erasure. It never persists the secret to Keychain or UserDefaults, source, YAML, environment echo, logs, screenshots, or JUnit. The app best-effort clears only mutable buffers it owns on background/logout; process termination destroys process memory, but no security claim depends on a termination callback.
- Public endpoints use the production provider policy.
- Destructive send requires a second explicit confirmation displaying amount, native fee, total, and recipient.

Fixture success is never reported as live evidence.

## Screen Contract and Accessibility IDs

Input:

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

`SendViewModel.quote()` converts validated text to public kit values and calls `Kit.quote`. It stores exactly one current quote. `confirm()` passes that quote and the mode signer to `Kit.send`; it never calls the codec/broadcaster directly. Expiration disables confirm and requires an explicit refresh/review.

An unknown result keeps the local transaction ID and enables retry. If the fee changes, the UI presents previous/current fee and only then calls `retryBroadcast(...acceptingNativeFee: current)`. Restart reconstructs pending from the public publisher.

## Guarded Maestro Suite

`Scripts/run-maestro.sh` is the only supported UI gate. It must:

1. require an exact `THORCHAIN_SIMULATOR_UDID`;
2. build, boot/install, and launch on that same UDID;
3. validate a committed expected-flow manifest and fail on zero/extra/missing flows;
4. run exactly five Sprint 2 fixture flows;
5. emit JUnit and require tests 5, failures 0, errors 0, skipped 0;
6. scan tracked inputs and generated logs/JUnit for byte canaries, and run a Vision/OCR scan over every generated screenshot.

The screenshot gate has a mandatory self-test: a temporary screenshot containing a random visible canary must be detected by the same Vision/OCR path before the real artifacts are scanned. Zero screenshots, OCR initialization failure, unreadable images, or a missed self-test fail the runner.

Flows:

- `send-quote-review.yaml`;
- `send-checktx-accepted.yaml`;
- `send-unknown.yaml`;
- `send-retry.yaml`;
- `send-restart-pending.yaml`.

Selectors use IDs only, never localized labels or coordinates. `send-quote-review` enters a non-empty memo, asserts the rendered memo and absolute expiry, then advances the injected clock to the exact deadline: confirm becomes unavailable, Refresh is visible, and signer call count remains zero. The response-loss scenario occurs after fixture node acceptance so the local state must be unknown while retry returns matching `sdk/19` without another signer request. UI wording says `CheckTx accepted — not confirmed`, never simply `confirmed` or `sent`.

## Unit/Component Tests

- fixture signer accepts only exact digest and records one call;
- live mode cannot initialize without secure runtime secret source;
- quote expiry/manual refresh and no silent fee refresh, including the exact absolute deadline and zero signer calls;
- unknown preserves hash and exposes retry;
- changed-fee acknowledgement passes exact current amount;
- process reconstruction consumes the real journal/publisher;
- accessibility IDs exist and sensitive fields are absent;
- acceptance manifest and JUnit parser fail closed.
- secure input/UI state is cleared after signer construction; Vision/OCR screenshot canary self-test detects a rendered canary and fails closed;
- unique namespace/reset behavior for all independent flows and two-phase namespace preservation for restart;
- Live Release product does not link fixture target and contains no fixture scenario/transport symbol strings.

## Security and Artifact Rules

- No mnemonic/private key/API credential in Git, UserDefaults, fixtures, Maestro YAML, command line, process environment dumps, console, screenshots, or JUnit.
- A canary is injected only into a temporary copy/runtime; byte scanners and the Vision/OCR screenshot self-test each prove detection through their real path.
- Hash/address/amount are public test-account evidence; they are clearly labeled and never reuse a user wallet.
- Fixture transport cannot compile into the library product or a Release Example live mode; project membership and a built-binary audit both enforce this.

## Verification

```text
xcodebuild -workspace iOS\ Example/ThorChainKitExample.xcworkspace -scheme ThorChainKitExampleLive -configuration Release -destination id=<UDID> build
xcodebuild -workspace iOS\ Example/ThorChainKitExample.xcworkspace -scheme ThorChainKitExampleFixture -configuration Debug -destination id=<UDID> build
THORCHAIN_SIMULATOR_UDID=<UDID> Scripts/run-maestro.sh
swift test --filter ExampleAcceptanceManifestTests
secret/canary artifact scan
opt-in controlled LIVE checklist
```

## Acceptance Criteria

- Five fixture flows pass on one exact simulator and JUnit count is enforced.
- CheckTx-accepted, unknown, retry, and restart are driven through public kit APIs and production storage/codec behavior.
- Retry proves the signature call count remains one and local hash remains identical.
- Fixture and live artifacts are visibly/distinctly labeled, and fixture state is flow-order independent.
- Repository and generated artifacts contain no secret.

## Pinned Decision

The Example is the only Maestro target. Unstoppable acceptance in S2-07 is WalletCore tests plus a manual Development-app scenario.
