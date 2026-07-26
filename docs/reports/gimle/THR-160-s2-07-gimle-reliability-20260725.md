# THR-160 S2-07 Gimle Reliability Report

Date: 2026-07-27

Gimle trust: RED.

This report covers formalization revision 5 after discovery 2/2 and closure
2/5 `REVISE`. The current-tree fallback remains the authority for the revised
design; no host implementation was performed. Revision 5 resolves the
legacy/outcome dispatch blocker without changing the selected analog family;
the prior allowlisted findings remain unchanged.

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
`520fb7400311b3266cfb6b0db81c3e919e080019` in
`/Users/ant013/Ios/HorizontalSystems/unstoppable-wallet-ios`.

The active Unstoppable checkout is the intended repository by remote and layout,
but is dirty on unrelated branch `core/uswap-provider-layering`. No files there
were changed. Gimle runtime health was reachable, but it resolved to the
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

## Revision 5 legacy/outcome dispatch correction evidence

The current Unstoppable analog keeps `SendViewModel.send()` as the existing
transport entry that reads `ISendData` and calls `ISendHandler.send(data:)` from
the legacy nonisolated path
(`packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendViewModel.swift:204-229`).
`RegularSendView` owns the MainActor UI action seam
(`packages/WalletCore/Sources/WalletCore/Modules/SendNew/RegularSendView.swift:23-41`).
Revision 5 preserves that boundary and defines one unconditional MainActor
`sendOutcome()` entry with an early type branch: outcome-aware handlers
read/capture `ISendData` and invoke their MainActor action there; legacy
handlers pass no `ISendData` through MainActor, call the existing no-argument
`send()` route, and map a successful return to `.sent`.

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
