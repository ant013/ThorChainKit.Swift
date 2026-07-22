# THR-104 — S1-06 UW lifecycle composition plan

**Status:** design revision 3; discovery 2/2, closure 0/5; implementation is
blocked until adversarial review and explicit approval of the linked spec.

**Spec:** [`docs/specs/sprint-01-foundation/S1-06-unstoppable-lifecycle-composition.md`](../../specs/sprint-01-foundation/S1-06-unstoppable-lifecycle-composition.md)

**Base:** clean `origin/main` at
`0f572e455be07df798a233eff31bbc27bb0940c5`.

**UW evidence base:** detached clean worktree at
`db86b99e9a12d758729a41c83a514b709df0a525` from fetched `origin/master`.
No host repository is modified during phase 1.

## Goal and boundaries

Connect the standalone ThorChainKit S1-05 facade to the current WalletCore host
for a manually constructed native RUNE wallet. The manager constructs and
caches an unstarted wrapper; the adapter owns `start`, `stop`, and `refresh`;
generic `AdapterManager` lifecycle reaches the kit; Combine state publishers
bridge to the existing Rx adapter contracts.

In scope: local package/product integration, the existing
`AccountAddress.swift` mnemonic boundary, manager/wrapper/factory, native
adapter and publisher bridge, `Core` construction, native route, and bounded
`AppTests` coverage.

Out of scope: S1-07 discovery/metadata/restart UI, signer/send/history/swap,
custom node UI, private-key/watch-only accounts, default-enable, changes to
the existing TRON refresh branch, GitHub Actions, simulators, Maestro, and
any host-repository edit before approval.

The current host MarketKit pin is `3.6.12` at
`95c92c876c3f40c28816e8e9891d6ffaf6eb0828`; it has no THOR chain metadata.
S1-06 cannot claim a buildable `.native/.thorChain` route against that pin.
S1-07 must release the metadata revision before the route and its integration
test are enabled. No temporary local enum or wrong-chain mapping is allowed.

## Analog spine and decisions

- Primary lifecycle: current `MoneroAdapter` for non-empty adapter-owned
  start/stop/refresh behavior.
- Primary composition: current `TronKitManager` vertical in the exact UW
  evidence worktree for wrapper cache, account derivation boundary, and
  Core/Factory composition.
- Supporting: current `AdapterManager` generic start/stop/refresh consumer,
  `AdapterFactory` route/injection, `TronAdapter` Rx mapping, current protocol
  surface, and the existing `AppTests` target.
- Rejected counterexample: current `TronKitManager` calls `tronKit.start()`
  and current `TronAdapter.start/stop/refresh` are empty. That split ownership
  is the defect S1-06 corrects.
- Current-tree correction: no `AccountAddressProvider.swift` or
  `IAccountAddressProvider` exists. The new THOR derivation method is added to
  the existing direct static `AccountAddress` boundary.

## Execution steps

### 1. Freeze host contracts and write red AppTests

**Owner:** ThorChainSwiftEngineer. **Depends on:** approved spec.

**Paths:** `Unstoppable/Tests/ThorChain/ThorChainKitManagerTests.swift`,
`ThorChainAdapterTests.swift`, and `ThorChainIntegrationTests.swift` in the
existing `AppTests` target; exact current protocol files are read-only inputs.

**Acceptance:** spies cover same-account-ID caching, different-account
replacement, mnemonic/no-seed and unsupported-account failures, exact factory
arguments, no manager start, adapter lifecycle forwarding, exhaustive
four-state/seven-error mapping, stale-balance/error preservation, exact
8-decimal RUNE conversion including overflow/precision cases, canonical
deposit address, generic adapter-manager start/stop/refresh, and unsupported
non-native THOR tokens once the MarketKit prerequisite is released. Tests use
runtime-generated synthetic mnemonic material, internal production seams, and
normal imports; no literal mnemonic, `@_spi(Testing)`, or host launch
arguments.

### 2. Add the minimal host composition and address boundary

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 1.

**Paths:** `packages/WalletCore/Package.swift`,
`packages/WalletCore/Sources/WalletCore/Models/AccountAddress.swift`,
`packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift`,
`packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift`,
and the exact current `Core.swift`/`AdapterFactory.swift` wiring points.

**Acceptance:** ThorChainKit is imported from
`https://github.com/ant013/ThorChainKit.Swift.git` at the immutable post-merge
SHA recorded in `Package.resolved`, never a host-local path; the existing
`AppTests` target has a direct product dependency. Mnemonic derivation uses the
approved S1-03 boundary and deterministic full-address vector; the manager
caches by account ID, holds only an unstarted wrapper, and receives a provider
and factory by injection. The provider enforces approved HTTPS mainnet hosts;
production factory delegates exactly once to `Kit.instance` and never starts
work. No new provider file, signer, or temporary chain enum is introduced.

### 3. Implement the adapter lifecycle and Rx bridge

**Owner:** ThorChainSwiftEngineer. **Depends on:** Step 2.

**Paths:** `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift`
and the exact current WalletCore adapter protocol definitions.

**Acceptance:** `ThorChainAdapter` implements `IAdapter`, `IBalanceAdapter`, and
`IDepositAdapter`; `start/stop/refresh` forward exactly once to the kit;
Combine publishers map to the existing Rx observables; cached balance remains
visible on sync failure; RUNE conversion avoids a `Double` intermediate,
rejects invalid decimals, and fails closed on overflow/precision loss; stop is
an idempotent release barrier with no post-stop request/event; status/debug
output is sanitized; receive address is the validated canonical address; no
activation semantics are added.

### 4. Add routing and generic lifecycle integration

**Owner:** ThorChainSwiftEngineer. **Depends on:** Steps 2–3.

**Paths:** current `AdapterFactory.swift`, `Core.swift`, and the three S1-06
AppTests files.

**Acceptance:** after the S1-07 MarketKit prerequisite is released,
`.native/.thorChain` creates the adapter through the injected manager; other
THOR token types return nil. Until then, the route is explicitly unavailable
and the compile-time proof records the missing dependency rather than guessing.
`Core` constructs and injects the manager/factory without exposing a new stored
manager property; existing `AdapterManager` receives no THOR-specific refresh
branch and its generic adapter lifecycle starts/stops/refreshes the kit through
the adapter. Global and wallet-scoped refresh each prove exactly one adapter
refresh and no direct manager call.

### 5. Verify locally and hand off role-separated review

**Owner:** ThorChainSwiftEngineer → ThorChainCodeReviewer →
ThorChainQAEngineer → ThorChainCTO. **Depends on:** Steps 1–4 and explicit
approval.

**Verification:** local MacBook-only syntax and focused AppTests using the
`Wallet.xcworkspace` / `Development` scheme, stable
`-only-testing:AppTests/ThorChainKitManagerTests` and
`-only-testing:AppTests/ThorChainAdapterTests` selectors, a named physical
iPhone destination, and a result bundle path. Before and after, assert clean
status, exact approved HEAD, and the implementation file allowlist. WalletCore
builds against the immutable package revision. Exact `rg`/diff checks cover no
`@_spi(Testing)`, no new `AdapterManager` THOR branch, no signer/history/swap/
S1-07 files, no literal mnemonic, no secrets, and no post-stop work. Manual
acceptance is gated on the MarketKit prerequisite and uses lifecycle counters.
Do not use GitHub Actions, simulators, Maestro, or Unstoppable acceptance
automation.

**Acceptance:** all focused tests and local build pass; manual evidence shows
one kit per account, one start/stop/refresh forwarding path, sync/balance/
deposit surfaces, and no lifecycle work after removal; reviewer and QA verify
the exact pushed implementation head before CTO merge.

## Required approval gate

This plan and the linked spec must be adversarially reviewed, hashed into the
Gimle checkpoint, pushed as a spec-only commit, and explicitly approved for
this exact revision. No implementation subtask or host feature worktree may be
created before that approval.
