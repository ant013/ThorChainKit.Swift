# THR-138 — S1-07 native RUNE sync correction

**Status:** design revision 1; implementation is blocked pending adversarial review and explicit approval of this exact revision.

## Goal

Make the exact local Unstoppable Wallet v0.50 Development sync path treat the
verified Liquify missing-account response as an absent account, so a no-funds
RUNE wallet can complete its normal sync without weakening unrelated error
handling.

## Observed failure

On 2026-07-23, the official Liquify Cosmos REST endpoint returned this response
for the frozen non-secret test address:

- HTTP status: `404`
- body code: `5`
- message: `account <requested-address> not found`
- details: `[]`
- Cosmos height header: present (`27120711` in the reproduction)

The current `LiveThorNodeClient.isExactAbsence` accepts only the older,
long-form address-specific message ending in `key not found`. The current
regression test explicitly rejects the shorter form, so the existing kit
surfaces a missing account as an HTTP error and the UW adapter publishes a
closed sync state.

## Assumptions and scope

Assumptions:

- The exact local UW v0.50 checkout, adjacent local MarketKit checkout, and
  local ThorChainKit checkout are the only acceptance substrate.
- The separate provider audit owns provider selection and any additional
  provider family. This correction uses only the already configured official
  Liquify pair.
- The exact short message is address-specific: the requested address must be
  present in the message. Generic or foreign-address messages are not absence.
- The existing long-form response remains valid and must continue to be
  accepted.

In scope:

- `LiveThorNodeClient.isExactAbsence` response matching.
- The existing S1-04 account response regression test.
- Local ThorChainKit tests, relevant WalletCore tests, the local Development
  app build, and the real local Development live-smoke.

Out of scope:

- New providers, endpoint-family policy, or provider selection.
- UW lifecycle composition, address derivation, metadata, storage, UI routing,
  send/swap, or generic balance error handling.
- GitHub Actions, Maestro, secrets, mnemonic fixtures, or any commit/push/PR
  to the Unstoppable checkout.

## Acceptance criteria

1. The real local UW v0.50 + local MarketKit + local ThorChainKit Development
   live-smoke reproduces the short Liquify response before the correction and
   completes the no-funds native RUNE sync after the correction.
2. Account absence is returned only for HTTP 404 with code `5`, empty details,
   and either the verified long-form message or the verified short-form
   message containing the requested address.
3. Generic, malformed, foreign-address, non-404, and balance-operation errors
   retain their existing typed error behavior.
4. The focused ThorChainKit regression test, relevant ThorChainKit and
   WalletCore tests, and the local Development application build pass. No
   GitHub Actions run is used.
5. The final QA evidence cites the exact local PR head and records the real
   device/app/OS/endpoint result without sensitive material. Sprint 2 remains
   paused until this correction and the separate provider audit are accepted.

## Verified analog family

Primary spine: `LiveThorNodeClient.account` and its private
`isExactAbsence` predicate in `Sources/ThorChainKit/Network/LiveThorNodeClient.swift`.
It owns the account endpoint boundary, 404 classification, typed error path,
and address-specific response validation.

Supporting roles:

- `AbsenceEnvelope` in the same file: preserves the code/details/message
  contract without introducing a new response model.
- `LiveThorNodeClientS1_04Tests.testAccountAcceptsOnlyExactObservedAbsenceEnvelope`:
  existing transport-level test seam and negative-error assertion.
- UW `ThorChainAdapter` current consumer: maps kit `notSynced` states to the
  existing closed adapter diagnostics and does not fabricate a zero balance.

Rejected counterexample: `LiveThorNodeClient.balances`. It treats every
non-2xx response as a balances HTTP error and must not inherit account-absence
special handling. No composition analog is required because no factory or
registration changes are proposed.

## Delta matrix

| Area | Preserve | Required difference | Rejected difference | Failure mode | Test / verification |
|---|---|---|---|---|---|
| Account 404 classifier | code `5`, empty details, address binding, typed errors | Accept the verified short message in addition to the verified long message | Accept any `404`, generic text, or foreign address | A malformed/foreign response could be treated as an absent account | Focused long + short + generic + foreign-address cases |
| Account consumer | `nil` absent account and existing adapter lifecycle | No consumer API or lifecycle change | Add UW-specific fallback or zero-balance behavior | Missing account could mask a real provider failure | Local Development live-smoke and WalletCore tests |
| Balance/error boundary | All balance non-2xx errors remain typed | None | Reuse account absence matcher for balances | Provider outage could be hidden as empty balance | Existing balances error tests plus changed-line review |

## Test-first plan

1. Update the existing account absence test contract to assert that the short
   address-specific body returns `nil` and that generic and foreign-address
   bodies still throw the typed 404 error.
2. Run the focused ThorChainKit test and capture the pre-fix failure against
   the short form.
3. Implement the smallest predicate-only correction.
4. Re-run the focused test, the directly affected ThorChainKit suite, relevant
   WalletCore/ThorChain tests, and the local Development build.
5. Run the real local Development live-smoke against the official Liquify REST
   and RPC pair and record the observed sync state, accepted height, and exact
   RUNE projection. No mnemonic or private material is recorded.

## Verification commands and evidence

- ThorChainKit focused test: `swift test --filter LiveThorNodeClientS1_04Tests/testAccountAcceptsOnlyExactObservedAbsenceEnvelope`
- ThorChainKit directly affected suite: `swift test --filter LiveThorNodeClientS1_04Tests`
- Local UW relevant tests/build: the existing local `Wallet.xcworkspace`
  Development scheme and ThorChain test target, using local package checkouts;
  exact command and destination must be recorded by the implementer/QA from
  the checkout actually used.
- Live-smoke: launch the local Development app on the MacBook with the exact
  Liquify REST/RPC pair, reproduce the short 404 on a no-funds address, then
  verify native RUNE address, zero balance, synced/unavailable state, and
  terminate/relaunch restoration as applicable to the existing S1-07 harness.

## Open gates

- Adversarial review must confirm the short-form matcher remains address-bound
  and does not alter balance or generic HTTP error semantics.
- Explicit user approval is required for this design revision before any
  implementation edit.
- The separate provider evidence audit must be attached before Sprint 2 or
  final acceptance resumes.
