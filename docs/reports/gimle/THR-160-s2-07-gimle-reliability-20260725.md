# THR-160 S2-07 Gimle Reliability Report

Date: 2026-07-27

Gimle trust: RED.

This report covers formalization revision 7 after discovery 2/2 and closure
4/5 `REVISE`. The current-tree fallback remains the authority for the revised
design; no host implementation was performed. Revision 7 closes the
expiration-caller half of the legacy/outcome dispatch blocker without changing
the selected analog family; the prior allowlisted findings remain unchanged.

The prerequisite gate was rechecked after S2-06 merged: `origin/main` is
`65c8e370db983c6bd500448266a4f8f51561ca5f`, and its canonical roadmap row is
`✅ Implemented — PR #17 — 2026-07-27`. The package pin used by this design is
the required S2-06 package-state head
`65c8e370db983c6bd500448266a4f8f51561ca5f`. The S2-06 merge beneath this
head changes `Package.swift`, `Package.resolved`, and
`Sources/ThorChainKit/Core/KitFactory.swift`; those package graph/source
changes are part of the prerequisite and must be present in the clean host
resolution.

The required codebase-memory project `Users-ant013-Data-AI-thorchain` was
queried first and reported ready. The exact Unstoppable codebase-memory project
also reported ready and supplied symbol candidates, but its indexed commit was
not available for comparison to the active checkout. Current-tree facts were
therefore verified independently with `git grep` and `git show` at
the pinned analog object `520fb7400311b3266cfb6b0db81c3e919e080019` in
`/Users/ant013/Ios/HorizontalSystems/unstoppable-wallet-ios`.

The active Unstoppable checkout is at HEAD
`ad125479984aa66e9bbc9022f5a8cb2e52ef6b6` and is the intended repository by
remote and layout, but is dirty on unrelated branch
`core/uswap-provider-layering`. No files there were changed. Gimle runtime
health was reachable, but it resolved to the
unrelated dirty `/Users/ant013/Android/Gimle-Palace-serving` checkout with
`native-dev` identity. Gimle inventory has no ThorChain project; its `uw-ios-app`
alias points to a different `/Users/Shared/.../unstoppable-wallet-ios` mount.
Serena was not exposed in this run. These are recorded as
`GIMLE-THR160-001` through `GIMLE-THR160-008` in the local checkpoint; none of
their results was used as a load-bearing design fact.

## Revision 4 package-state correction evidence

The exact current-tree checks for the closure blocker passed:

- `git merge-base --is-ancestor 09bb94f8404cd56af3f5ef6169948a4fe1a13195 65c8e370db983c6bd500448266a4f8f51561ca5f` passed.
- `git diff --name-status 4c2e82bb17aa48379235a9f01ccdba489bb46e69 65c8e370db983c6bd500448266a4f8f51561ca5f -- Package.swift Package.resolved Sources/ThorChainKit/Core/KitFactory.swift` reports all three required package/source changes.
- `git show 65c8e370:Package.swift` contains the pinned `HdWalletKit.Swift` dependency, and `git show 65c8e370:Sources/ThorChainKit/Core/KitFactory.swift` contains the native-RUNE endpoint capability wiring.
- The S2-07 spec, plan, and concurrency-gate text contain the single required package-state SHA `65c8e370db983c6bd500448266a4f8f51561ca5f`; the superseded `4c2e82bb` pin is absent from those artifacts.

No implementation, host checkout, build, AppTests, simulator, or mainnet
acceptance was run. Gimle trust remains RED because the previously recorded
runtime/project mapping and Serena availability remain unresolved; this
revision relies on the independently verified Git fallback above.

## Revision 6 actor-safe legacy/outcome dispatch correction evidence

The current Unstoppable analog keeps `SendViewModel.send()` as the existing
transport entry that reads `ISendData` and calls `ISendHandler.send(data:)` from
the legacy nonisolated path
(`packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendViewModel.swift:204-229`).
`RegularSendView` owns the MainActor UI action seam
(`packages/WalletCore/Sources/WalletCore/Modules/SendNew/RegularSendView.swift:23-41`).
Revision 6 preserves that boundary and defines one unconditional MainActor
`sendOutcome()` entry with an early type branch: outcome-aware handlers
read/capture `ISendData` and invoke their MainActor action there; legacy
handlers pass no `ISendData` through MainActor, call the existing no-argument
`send()` route, and map a successful return to `.sent`.

The closure-3 strict probe reproduced the remaining failure in revision 5:
`Task { @MainActor ... }` could not capture a non-Sendable existential handler,
and a nonisolated `sendData` requirement returned non-Sendable `ISendData` into
the MainActor task. The revision-6 correction makes only
`ISendHandler.sendData(transactionSettings:)`, `SendViewModel.init`, and
`SendViewModel.sync()` MainActor-isolated. `send(data:)` remains nonisolated;
the no-argument `send()` method remains the sole legacy transport bridge.
The analog anchors are exact: `ISendHandler.swift:4-17` has the split
`sendData`/`send(data:)` surface, while `SendViewModel.swift:176-209` owns the
existing sync task and MainActor state handoff. The proposed actor annotations
are the smallest delta that removes the new crossing; they do not claim the
analog already has those annotations.
The exact Swift 5 probe with one legacy and one outcome-aware fake compiled
with `-strict-concurrency=complete -warnings-as-errors`; no suppression,
`@preconcurrency`, or `@unchecked Sendable` was used. The tested shape keeps
the legacy `ISendData` result entirely on MainActor during sync and does not
pass it through the new outcome task boundary.

The required implementation probe must contain one legacy-only fake and one
outcome-aware fake. It must verify exactly one legacy `send(data:)` call and a
stored `.sent` result, plus THOR `.checkTxAccepted` and `.unknown` results with
generic completion denied. It must compile with Swift 5 complete concurrency,
including `sync()`'s MainActor task, without `@preconcurrency`, `@unchecked
Sendable`, or warning suppression. The probe must fail if any MainActor branch,
closure, or task accepts the legacy `ISendData`, or if legacy dispatch is
implemented as an outcome-protocol cast that throws `noHandler`.

No host implementation, build, AppTests, simulator, or controlled mainnet
acceptance was run for this revision. Gimle trust remains RED for the same
runtime/project mapping and Serena limitations; the current-tree analog facts
and dispatch correction are based on the independent Git/rg evidence above.

## Revision 7 expiration-caller correction evidence

The pinned analog has four relevant caller shapes: the state timer callback at
`SendViewModel.swift:49-51`, the stale-quote path at `:148-161`, the
foreground publisher callback at `:82-90`, and MainActor SwiftUI refresh
actions at `RegularSendView.swift:40-46` and
`WalletConnect/WalletConnectSendView.swift:40-43`. The closure-4 finding was
correct: making only `sync()` MainActor-isolated leaves the pinned
nonisolated `onExpiration()` call at `SendViewModel.swift:168-170` ill-formed.

Revision 7 makes `autoQuoteIfRequired()` and `onExpiration()` MainActor
methods. The timer and foreground callbacks remain nonisolated but only copy a
stored nonisolated `@MainActor @Sendable` auto-quote action and schedule
`Task { @MainActor in action() }`; the action performs all state reads and may
call `onExpiration()`/`sync()`. MainActor SwiftUI refresh calls remain direct.
The boundary transfers neither `SendViewModel` nor `ISendData` through a
nonisolated task.

The literal Swift 5.8.1 probe now includes the split handler protocol, the
MainActor `sync()` task, MainActor auto-quote/expiration methods, nonisolated
timer/foreground schedulers, the unconditional legacy/outcome dispatch, and
one fake for each branch. It is required to compile with
`-strict-concurrency=complete -warnings-as-errors` and no suppression,
`@preconcurrency`, or `@unchecked Sendable`; any direct nonisolated
`sync()`/`onExpiration()` call is a negative canary.

Verification on Swift `5.8.1` passed: `VALID_PROBE=PASS` and
`INVALID_CANARY=REJECTED` for the direct nonisolated `sync()` call. No host
implementation, build, AppTests, simulator, or controlled mainnet acceptance
was run.

## Accepted current-tree evidence

- `F-160-001`: `ISendTronAdapter` plus `TronPreSendHandler` establish the
  adapter/pre-send boundary and fail-closed input shape.
- `F-160-002`: `TronSendHandler`, `SendHandlerFactory`, and generic `Core.swift`
  registration establish composition and quote/send lifecycle shape.
- `F-160-003`: `SendViewModel` and `RegularSendView` establish the shared
  expiration/state/consumer seam.
- `F-160-004`: `AccountManager.activeAccount`/level and the existing mnemonic
  signer helper establish current account/type vocabulary, while exposing the
  synchronous signer shape that must not be copied.
- `F-160-005`: serialized AppTests and fake-driven tests establish the local
  deterministic verification seam.
- `F-160-006`: wrapper-owned send and synchronous direct signer construction
  are rejected counterexamples for THOR security/ownership.

Three critical slices have one coherent primary, independent supporting
evidence, complete required analog dimensions/roles, and a rejected
counterexample. The resulting design is `verified` for current-tree analog
purposes, with Gimle trust still RED.

## Residual limitations

No host implementation, build, AppTests, simulator, or controlled mainnet
acceptance was run in this formalization phase. Those checks belong to the
approved implementation/QA phases. The dirty external checkout, absent Serena,
and Gimle project/runtime mapping must be rechecked on the fresh implementation
branch before relying on any line-level evidence. Revision 4 specifically adds
an exact package SHA, tracked resolution/config inputs, raw diagnostic
comparison, hermetic global-state tests, and a bounded no-run/no-broadcast
mainnet protocol; these remain unverified until implementation/QA.
