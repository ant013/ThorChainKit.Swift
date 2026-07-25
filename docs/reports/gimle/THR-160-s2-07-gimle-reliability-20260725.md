# THR-160 S2-07 Gimle Reliability Report

Date: 2026-07-25

Gimle trust: RED.

This report covers formalization revision 2 after discovery 1/2 adversarial
`REVISE`. The current-tree fallback remains the authority for the revised
design; no host implementation was performed.

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
branch before relying on any line-level evidence. Revision 2 specifically adds
an exact package SHA, tracked resolution/config inputs, raw diagnostic
comparison, hermetic global-state tests, and a bounded no-run/no-broadcast
mainnet protocol; these remain unverified until implementation/QA.
