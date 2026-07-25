# THR-160 — S2-07 Unstoppable Native RUNE Send Integration Plan

Design revision 1 for
`docs/specs/sprint-02-native-send/S2-07-unstoppable-integration.md`, based on
architecture revision 10 at commit
`518835315a65996b9321665213adb0516503df65`. Discovery is bounded at 1/2;
implementation remains approval-gated.

## Goal

Connect native RUNE to the current Unstoppable SendNew flow while keeping
quote/transaction authority in ThorChainKit and signing-key ownership in the
host. The user must see the exact quote and an honest CheckTx/unknown result
with the local transaction hash.

## Steps

- [ ] 1. Adapter, client, and factory boundary
  - Owner: ThorChainSwiftEngineer
  - Acceptance: `ISendThorChainAdapter` exposes only the internal send client
    and account ID; the manager, wrapper, and factory store no signer or
    account secret; `ThorChainSendClient` validates its own live quote handle,
    maps kit submission outcomes, and rejects fake/cross-client handles before
    any signer or kit call. Native RUNE is registered through existing
    SendNew handler/pre-handler arrays with no `Core.swift` special case.
  - Paths: `Core/Protocols.swift`, `Core/Managers/ThorChainKitManager.swift`,
    `Core/Factories/ThorChainKitFactory.swift`,
    `Core/Adapters/ThorChain/ThorChainAdapter.swift`, new
    `ThorChainSendClient.swift`, `ThorChainSendData.swift`, and
    `SendHandlerFactory.swift`.
  - Depends on: approved S2-01 through S2-06 package revision.
  - Check: WalletCore/AppTests fake/live-handle contract tests and factory
    registration tests.

- [ ] 2. Ephemeral signer and account authorization
  - Owner: ThorChainSwiftEngineer
  - Acceptance: `ThorChainSignerProvider` is the only construction path;
    `ThorChainSigner` is an ephemeral actor exposing only its immutable public
    key and signing capability; each public-key/sign operation reads the
    currently authorized active mnemonic account, rechecks account ID/type/key,
    and fails closed on account switch, duress/passcode change, removal, or
    mismatch. No signer, seed, private key, `Account`, or `AccountType` is
    stored by adapter/manager/factory or logged.
  - Paths: new `ThorChainSigner.swift`, `ThorChainSignerProvider.swift`,
    `ThorChainSigningKeySource.swift`; manager/factory files from step 1.
  - Depends on: 1 and the approved S2-04 signer boundary.
  - Check: deterministic key/sign tests, zero-call failure cases, secret/log
    canaries, and public-only negative compile tests.

- [ ] 3. SendNew quote, expiry, and outcome UX
  - Owner: ThorChainSwiftEngineer
  - Acceptance: pre-send conversion is exact and fail-closed; review renders
    the stored quote, fee, total, memo, and height; absolute expiry blocks
    send; accepted/unknown outcomes retain the full local hash and bypass the
    generic sent banner; legacy handlers still produce `.sent`; no quote is
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
    an invalid actor-boundary canary, and proves both SlideButton entry paths
    call one action seam exactly once.
  - Paths: `Scripts/CI/check-thorchain-send-concurrency.sh`, its non-target
    canary fixture, and `SlideButton.swift`.
  - Depends on: 2 and 3.
  - Check: script self-tests, valid/invalid swiftc probes, baseline-vs-HEAD
    diagnostic comparison, and source audit.

- [ ] 5. Serialized AppTests and local build
  - Owner: ThorChainQAEngineer
  - Acceptance: `ThorChainGlobalStateTests` is `@Suite(.serialized)`, snapshots
    and restores global registries/active-account state, and its overlap
    sentinel fails under parallel execution. WalletCore tests and AppTests
    run locally with `-parallel-testing-enabled NO`; the Development build
    succeeds; no Maestro, fixture transport, launch argument, or secret-bearing
    artifact exists in the host diff.
  - Paths: `Unstoppable/Tests/ThorChain/`, WalletCore tests, and local evidence
    manifests under the operator-controlled artifact directory.
  - Depends on: 1–4.
  - Check: exact local `xcodebuild` commands in the spec, nonzero discovered
    test count, overlap sentinel, and artifact/secret scan.

- [ ] 6. Controlled mainnet acceptance and merge gate
  - Owner: ThorChainQAEngineer, then ThorChainCTO
  - Acceptance: on a purpose-created controlled mnemonic account, native RUNE
    SendNew shows the exact quote and returns the local hash plus honest
    CheckTx/unknown state; no duplicate signature or generic sent banner is
    observed. Any unavailable controlled ambiguous-response environment is
    recorded as deterministic kit evidence, never simulated as live success.
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
