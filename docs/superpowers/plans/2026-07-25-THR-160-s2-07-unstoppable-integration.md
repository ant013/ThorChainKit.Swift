# THR-160 — S2-07 Unstoppable Native RUNE Send Integration Plan

Design revision 7 for
`docs/specs/sprint-02-native-send/S2-07-unstoppable-integration.md`, based on
architecture revision 10 at commit
`518835315a65996b9321665213adb0516503df65`. Discovery is bounded at 2/2;
closure is 4/5; revisions 1–6 were returned `REVISE` and implementation
remains approval-gated.

## Goal

Connect native RUNE to the current Unstoppable SendNew flow while keeping
quote/transaction authority in ThorChainKit and signing-key ownership in the
host. The user must see the exact quote and an honest CheckTx/unknown result
with the local transaction hash.

## Steps

- [ ] 1. Adapter, client, and factory boundary
  - Owner: ThorChainSwiftEngineer
  - Acceptance: `ISendThorChainAdapter` exposes account ID, the S1 receive
    address projection, and an actor-safe MainActor client factory; the
    adapter strongly owns the wrapper while the client holds only a
    synchronized monotonic-generation lease with active-use permits. Stop
    revokes before wrapper release and waits for active permits to drain. The
    manager, wrapper, and factory store no signer or
    account secret; the client validates complete quote binding and rejects
    fake/same-client-swapped/cross-client/stopped handles before any signer or
    kit call. Native RUNE is registered through existing
    SendNew handler/pre-handler arrays with no `Core.swift` special case.
  - Paths: `Package.swift`, `Package.resolved`, `.gitignore`,
    `Core/Protocols.swift`, `Core/Managers/ThorChainKitManager.swift`,
    `Core/Factories/ThorChainKitFactory.swift`,
    `Core/Adapters/ThorChain/ThorChainAdapter.swift`, new
    `ThorChainSendClient.swift`, `ThorChainSendData.swift`, and
    `SendHandlerFactory.swift`.
  - Depends on: corrected ThorChainKit `main` merge
    `162cc3165cfbf1023bcb9c7111cc1d059a2fcded` (parent
    `65c8e370db983c6bd500448266a4f8f51561ca5f`); this exact merge preserves
    the S2-06 package graph/source changes and adds the approved GRDB 6.29.3
    compatibility correction, making it the reproducible host dependency pin.
  - Check: WalletCore/AppTests fake/live-handle contract tests and factory
    registration tests.

- [ ] 2. Ephemeral signer and account authorization
  - Owner: ThorChainSwiftEngineer
  - Acceptance: `ThorChainSignerProvider` is the only construction path;
    `ThorChainSigner` is an ephemeral actor exposing only its immutable public
    key and Sendable key-source capability; each public-key/sign operation
    checks unlocked foreground state, monotonic authorization generation,
    current visible
    active-account object/ID/type/key, and fails closed on lock, background,
    account switch, duress/passcode change, same-ID replacement, removal, or
    mismatch immediately before the synchronous crypto call. No signer, seed, private key, `Account`, or `AccountType` is
    stored by adapter/manager/factory or logged.
  - Paths: new `ThorChainSigner.swift`, `ThorChainSignerProvider.swift`,
    `ThorChainSigningKeySource.swift`; manager/factory files from step 1.
  - Depends on: 1 and the approved S2-04 signer boundary.
  - Check: deterministic key/sign tests, zero-call failure cases, secret/log
    canaries, and public-only negative compile tests.

- [ ] 3. SendNew quote, expiry, and outcome UX
  - Owner: ThorChainSwiftEngineer
  - Acceptance: pre-send conversion is exact and fail-closed; the one
    unconditional MainActor `SendViewModel.sendOutcome() async` entry branches
    before reading `ISendData`: outcome-aware handlers read/capture it only on
    MainActor and never pass it across an actor, while legacy handlers call the
    existing no-argument `send()` route, which alone invokes the nonisolated
    `ISendHandler.send(data:)` boundary; a successful legacy dispatch records
    `.sent`; review renders
    the stored handle quote, fee, total, memo, and height; immutable complete
    quote binding rejects same-client swaps; absolute expiry blocks
    send; accepted/unknown outcomes retain the full local hash and bypass the
    generic sent banner; `ISendHandler.sendData(transactionSettings:)`,
    `SendViewModel.init`, `sync()`, `autoQuoteIfRequired()`, and
    `onExpiration()` are MainActor-isolated so non-Sendable legacy `ISendData`
    stays on MainActor during sync; nonisolated timer/foreground callbacks
    schedule a stored MainActor action; legacy-only
    and THOR fake handlers prove `.sent`,
    accepted, and unknown through focused tests; no quote is
    recreated during send and no automatic retry is added.
  - Paths: new `ThorChainPreSendHandler.swift`, `ThorChainSendHandler.swift`,
    `ThorChainSendHelper.swift`, `ThorChainSubmissionView.swift`,
    `IOutcomeSendHandler.swift`; `SendData.swift`, `ISendData.swift`,
    `SendViewModel.swift`, `PreSendView.swift`, `RegularSendView.swift`,
    `SlideButton.swift`, and localization.
  - Depends on: 1 and 2.
  - Check: focused handler/model tests plus direct-navigation and wrapper
    outcome tests proving zero generic success/banner calls.

- [ ] 4. Strict-concurrency and reentrancy gate
  - Owner: ThorChainSwiftEngineer
  - Acceptance: the baseline-delta script builds baseline and HEAD with the
    exact `Development`/`Debug-Dev` strict-concurrency command, compares all
    repository-owned Swift diagnostics including unchanged transitive callers,
    rejects `@unchecked Sendable`, `@preconcurrency`, warning suppression, and
    an invalid actor-boundary canary, compares raw diagnostics without
    replacement false-passes, verifies the exact package/config/toolchain
    inputs, and proves both SlideButton entry paths call one action seam
    exactly once. Its literal Swift 5 probe compiles the MainActor
    `ISendHandler.sendData` requirement, MainActor `sync()` task, MainActor
    expiration path, nonisolated callback schedulers, and both legacy/outcome
    branches without an `ISendData` actor crossing.
  - Paths: `Scripts/CI/check-thorchain-send-concurrency.sh`, its non-target
    canary fixture, and `SlideButton.swift`.
  - Depends on: 2 and 3.
  - Check: script self-tests, valid/invalid swiftc probes, baseline-vs-HEAD
    diagnostic comparison, and source audit.

- [ ] 5. Serialized AppTests and local build
  - Owner: ThorChainQAEngineer
  - Acceptance: `ThorChainGlobalStateTests` is `@Suite(.serialized)`, runs on
    an erased purpose-created simulator/container, snapshots and restores all
    mutated global domains, and its overlap sentinel fails under parallel
    execution. Every named narrow suite has a literal `-only-testing` command
    and nonzero discovery. WalletCore tests and AppTests run locally with
    `-parallel-testing-enabled NO`; the Development build succeeds; no
    Maestro, fixture transport, launch argument, or secret-bearing artifact
    exists in the host diff.
  - Paths: `Unstoppable/Tests/ThorChain/`, WalletCore tests, and local evidence
    manifests under the operator-controlled artifact directory.
  - Depends on: 1–4.
  - Check: exact local `xcodebuild` commands in the spec, nonzero discovered
    test count, overlap sentinel, and artifact/secret scan.

- [ ] 6. Controlled mainnet acceptance and merge gate
  - Owner: ThorChainQAEngineer, then ThorChainCTO
  - Acceptance: after exact identity/network preflight and separate final
    operator approval, a purpose-created controlled mnemonic account capped at
    `0.01 RUNE` sends at most `0.001 RUNE` to a pre-verified operator-owned
    recipient; SendNew shows the exact quote and returns the local hash plus
    honest CheckTx/unknown state, with no duplicate signature or generic sent
    banner. Any unavailable control is recorded `not-run`, never simulated as
    live success.
  - Paths: QA evidence and the exact PR head; no ThorChainKit or Maestro files.
  - Depends on: 5 and explicit approval.
  - Check: local QA comment cites exact PR head, local tests/build, controlled
    observation, and secret/acceptance-only diff audit before CTO merge.

## Scope exclusions

No ThorChainKit protocol implementation, Unstoppable Maestro, fixture
transport, acceptance launch argument, watch-only support, finality/history,
automatic retry, global THOR service, Vultisig KeysignPayload/TSS flow, or
secret-bearing artifact.

## Handoff gate

The design requires bounded adversarial review and explicit operator approval
of the final spec revision before step 1 begins.
