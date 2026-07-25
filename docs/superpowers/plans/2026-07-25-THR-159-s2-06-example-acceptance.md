# THR-159 — S2-06 iOS Example Send Acceptance Plan

Design revision 5 for `docs/specs/sprint-02-native-send/S2-06-example-acceptance.md`,
based on architecture revision 10 at commit
`518835315a65996b9321665213adb0516503df65`. The prior draft was superseded by
the discovery-1/2 adversarial findings. Discovery is frozen at 2/2;
implementation remains approval-gated. The Board selected a dedicated BIP39
test wallet; revision 4 specifies fail-closed local loading and THOR derivation.

Revision 5 reopens only the package-graph compatibility gate for Xcode 26.3
(17C529) with the iOS 26.2 simulator runtime. The exact-head failure is in the
shared HsCryptoKit → swift-crypto wrapper, even for Fixture without LiveSupport.
No safe repository-only delta is currently proven. Implementation is paused at
this gate; direct-Crypto and static-product experiments are rejected and must
not recur.

## Goal

Implement only the package-owned iOS Example live/fixture boundary and guarded
five-flow Maestro acceptance described by the authoritative spec.

## Steps

- [ ] 0. Xcode 26.3 package-graph compatibility decision
  - Owner: ThorChainCTO / separately approved compatibility slice.
  - Acceptance: On exact Xcode `26.3 (17C529)` and iOS `26.2`, the chosen delta
    produces one valid Crypto executable per package closure, keeps one owner
    for ThorChainKit linkage, preserves FixtureSupport exclusion from Live,
    and passes both Fixture Debug and Live Release package-graph preparation.
    Missing/unresolved wrappers, duplicate linkage, external checkout edits,
    copied binaries, weaker pins, or guessed linker flags fail closed.
  - Paths: `Package.swift`, `iOS Example/iOS Example.xcodeproj/project.pbxproj`,
    and any separately approved compatibility design only.
  - Depends on: none; blocks Steps 1–4.
  - Check: exact-head package-graph build logs plus target-graph and resolved
    executable audits. The current saved log fails at the hashed Crypto
    wrapper, so no implementation or acceptance evidence is claimed.

- [ ] 1. Example targets and runtime composition
  - Owner: ThorChainSwiftEngineer
  - Acceptance: `ThorChainExampleLive` (Release) and `ThorChainExampleFixture`
    (Debug) are separate app targets/products; `ThorChainExampleFixtureSupport`
    is linked only by Fixture and contains exactly `FixtureSupport/**`.
    `ThorChainExampleLiveSupport` contains only the BIP39 loader, THOR derivation
    adapter, and Live signer; Live/Archive/Profile dependency closure and source membership contain no
    fixture target or source. The SwiftUI App composes the selected runtime
    without UIKit, AppDelegate, view controllers, or representable wrappers.
  - Paths: `iOS Example/iOS Example.xcodeproj/project.pbxproj`,
    `iOS Example/iOS Example.xcworkspace`, `iOS Example/Sources/**`,
    `iOS Example/LiveSupport/**`, `iOS Example/FixtureSupport/**`.
  - Depends on: none.
  - Check: target-graph/source-membership audit; Live Release Archive/Profile
    show-build-settings audit; both exact-destination xcodebuilds; resolved
    Live executable fixture-symbol scan. Any unresolved artifact or unexpected
    dependency fails closed.

- [ ] 2. Send/review/pending projections
  - Owner: ThorChainSwiftEngineer
  - Acceptance: SwiftUI view models consume only public quote/send/retry and
    both pending publishers; RUNE text uses exact 1e8 conversion, accepts only
    `1...2^256-1` base units/32-byte magnitudes, and invalid input has no side
    effects. Review expiry, CheckTx-accepted, unknown, changed-fee retry,
    empty-versus-degraded restart state, and all fixed IDs including
    `send.mode-badge` are visible with no sensitive values. Live remains
    requires `THORCHAIN_NETWORK=mainnet`, loads exactly twelve lowercase
    English BIP39 words from local-only `THORCHAIN_MAINNET_MNEMONIC`, and uses
    `THORCHAIN_MAINNET_RECIPIENT_ADDRESS` for the controlled-smoke recipient;
    it never infers network from the address, rejects every malformed or extra
    input without logging it, and derives `m/44'/931'/0'/0/0` through the pinned
    Example-only backend; then start/replace/logout atomically owns signer + derived address
    + matching Kit and clears the input/model. Controlled LIVE stops before
    confirmation/broadcast.
  - Paths: `iOS Example/Sources/Send`, `iOS Example/Sources/Pending`,
    `iOS Example/LiveSupport`, tests.
  - Depends on: 1 and S2-01 through S2-05.
  - Check: focused unit/component tests; runtime accessibility-tree/Maestro ID
    assertions and sensitive-value negatives; controlled LIVE observation.

- [ ] 3. Fixture signer, transport, scenarios, and namespace lifecycle
  - Owner: ThorChainSwiftEngineer
  - Acceptance: exact-digest signer, deterministic transport/clock, and a
    strict ordered transcript (origin/method/path/query/body/order/extra-call)
    drive the real Kit facade. Five scenarios use independent reset, with
    restart-only namespace reuse; expected signed bytes/hash are asserted and
    all invalid transcript/input cases fail closed. No private material is
    present.
  - Paths: `iOS Example/FixtureSupport`, `iOS Example/Sources/Signing`, tests.
  - Depends on: 1 and 2.
  - Check: signer-call, exact-hash, transcript, amount grammar/conversion,
    retry, restart empty/degraded, namespace, and secret/artifact tests.

- [ ] 4. Guarded Maestro runner and evidence
  - Owner: ThorChainSwiftEngineer
  - Acceptance: exact UDID is used for build/boot/install/launch/Maestro;
    committed five-flow manifest has a non-trivial action/assertion matrix;
    negative mutations for missing actions/assertions, expiry wording,
    CheckTx wording, unknown/retry signer count, and restart cannot pass.
    JUnit counts, byte canaries, full runtime-tree ID/sensitive-value checks
    with an unlisted-node negative mutation, Vision/OCR screenshot self-test,
    and resolved Release fixture-symbol exclusion all fail closed. A versioned
    manifest records the complete tracked input inventory, per-file SHA-256
    digests, clean-input result, exact HEAD, UDID, scheme/configuration,
    resolved executable and artifact digests; wrong-head, dirty, missing,
    extra, ambiguous, or tampered inputs/artifacts fail closed.
  - Paths: `.maestro/sprint-02`, `Scripts/run-maestro.sh`,
    `Scripts/test-run-maestro.sh`, `Tests/ThorChainKitTests/ExampleAcceptanceManifestTests.swift`.
  - Depends on: 1–3.
  - Check: runner shim/mutant tests; local exact-UDID Maestro; and an evidence
    manifest under `artifacts/s2-06/<git-head>/<udid>/` containing exact head,
    UDID, scheme/configuration, resolved executable, JUnit, logs, screenshot
    inventory/OCR results, and failure artifacts. Missing, extra, ambiguous,
    or wrong-head evidence fails closed.

## Scope exclusions

No Unstoppable changes, no Unstoppable Maestro, no library secret storage, no
host integration, and no S2-07 work.

## Discovery-2 blocker disposition

- `THR-159-SEC-H01`: resolved in design revision 4 by the Board's BIP39 choice:
  explicit `THORCHAIN_NETWORK=mainnet`, local-only
  `THORCHAIN_MAINNET_MNEMONIC` and `THORCHAIN_MAINNET_RECIPIENT_ADDRESS`
  values in the ignored root `.env`, exact twelve-word validation, standard
  BIP39 seed derivation, and
  `m/44'/931'/0'/0/0` through the pinned Example-only backend. The app never
  generates or funds the wallet. The non-secret wallet ID rule is fixed as the
  domain prefix plus SHA-256 of the canonical compressed public key.
- `THR-159-SEC-H02`: resolved by the exact Example input bound
  `1...2^256-1` base units and a canonical magnitude of at most 32 bytes.
- `THR-159-UI-H01`: resolved by `send.mode-badge`, a full runtime accessibility
  node/value scan, and an unlisted-node sensitive-value mutation.
- `THR-159-VOP-H01`: resolved by the versioned digest-bound manifest and
  fail-closed clean-input, wrong-head, extra/missing/tampered checks.
- `THR-159-VOP-H02`: resolved by a purpose-created low-balance mainnet QA wallet
  whose existing funding does not authorize an irreversible send, plus a
  controlled LIVE checklist that terminates before confirmation/broadcast and
  proves zero send/retry/broadcaster events.

## Handoff gate

Implementation starts only after this plan and the evidence-backed design pass
adversarial review and receive explicit operator approval.
