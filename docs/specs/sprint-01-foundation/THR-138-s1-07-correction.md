# THR-138 — S1-07 native RUNE sync correction

**Status:** design revision 2; discovery 1/2, closure 0/5. Implementation is blocked pending adversarial re-review and explicit approval of this exact revision.

## Goal

Make the exact local Unstoppable Wallet v0.50 Development sync path treat the
verified Liquify missing-account response as an absent account, so a no-funds
RUNE wallet can complete its normal sync without weakening unrelated error
handling.

## Observed failure

On 2026-07-23T03:29:05Z, an exact read-only `GET` of the official Liquify
Cosmos REST path returned this response for the frozen public no-funds test
address `thor1le9eykyndunax8k24w8fykd8ndx35w2h27c008`:

`GET https://gateway.liquify.com/chain/thorchain_api/cosmos/auth/v1beta1/accounts/thor1le9eykyndunax8k24w8fykd8ndx35w2h27c008`

- HTTP status: `404`
- body code: `5`
- message: `account <requested-address> not found`
- details: `[]`
- Cosmos height header: present (`27120711` in the reproduction)

The redacted response artifact is
[`THR-138-liquify-account-404-20260723.json`](../../reports/gimle/THR-138-liquify-account-404-20260723.json).
Its SHA-256 is recorded in the Gimle report and must be captured again if the
provider observation is repeated.

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
- The accepted short message is exactly `account <requested-address> not found`
  after substituting the requested address. Matching is full-string equality;
  containment, prefix, suffix, trimming, normalization, or whitespace
  tolerance is forbidden. Generic or foreign-address messages are not absence.
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
   and full-string equality with either
   `rpc error: code = NotFound desc = account <requested-address> not found: key not found`
   or `account <requested-address> not found`.
3. Prefix, suffix, leading/trailing/internal-whitespace, foreign-address,
   wrong-code, nonempty-details, malformed-JSON, exact-body-under-non-404, and
   balance-404-with-the-same-body cases retain typed fail-closed errors. The
   balance case remains `.httpStatus(.balances, 404)`.
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

- Vertical state roles: `ReadOperationCoordinator` owns the account-read
  completion, `StorageRecord` carries the persisted account/balance boundary,
  `LifecycleGate` validates the active identity before publication, and
  `StateSnapshot` exposes `.synced` with the zero native RUNE projection.

Rejected counterexample: `LiveThorNodeClient.balances`. It treats every
non-2xx response as a balances HTTP error and must not inherit account-absence
special handling. No composition analog is required because no factory or
registration changes are proposed.

## Delta matrix

| Area | Preserve | Required difference | Rejected difference | Failure mode | Test / verification |
|---|---|---|---|---|---|
| Account 404 classifier | code `5`, empty details, address binding, typed errors | Accept the two verified messages by full-string equality only | `contains`, prefix/suffix matching, whitespace normalization, any `404`, generic text, or foreign address | A malformed/foreign response could be treated as an absent account | Focused exact long/short positives plus prefix/suffix/whitespace/foreign negatives |
| Account consumer | `nil` absent account and existing adapter lifecycle | No consumer API or lifecycle change | Add UW-specific fallback or zero-balance behavior | Missing account could mask a real provider failure | Local Development live-smoke and WalletCore tests |
| Balance/error boundary | All balance non-2xx errors remain typed | None | Reuse account absence matcher for balances | Provider outage could be hidden as empty balance | Focused balances 404 with the same body asserts `.httpStatus(.balances, 404)` |

## Test-first plan

1. Update the existing account absence test contract to assert exact full-string
   equality for both accepted messages. Add prefix, suffix, leading/trailing/
   internal-whitespace, foreign-address, wrong-code, nonempty-details,
   malformed-JSON, exact-body-under-non-404, and balances-404-with-the-same-body
   cases; the latter must remain `.httpStatus(.balances, 404)`.
2. Run the focused ThorChainKit test and capture the pre-fix failure against
   the short form.
3. Implement the smallest predicate-only correction.
4. Re-run the focused test, the directly affected ThorChainKit suite, relevant
   WalletCore tests, and the exact local Development build command in the plan.
5. Run the real local Development live-smoke against the exact Liquify REST/RPC
   pair. The pre-fix run must capture the short 404 and old unavailable/closed
   result. The post-fix pass is only valid when the app is online and `.synced`,
   the account is absent, native RUNE is exactly zero, a positive accepted
   height is shown, and no closed/unavailable diagnostic is present. Relaunch
   and offline behavior are separate regression checks. No mnemonic or private
   material is recorded.

## Verification commands and evidence

- ThorChainKit focused test: `swift test --package-path /Users/ant013/Data/AI/thorchain --filter LiveThorNodeClientS1_04Tests/testAccountAcceptsOnlyExactObservedAbsenceEnvelope`
- ThorChainKit directly affected suite: `swift test --package-path /Users/ant013/Data/AI/thorchain --filter LiveThorNodeClientS1_04Tests`
- Exact UW package/test command: `xcodebuild -workspace /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/Wallet.xcworkspace -scheme WalletCore -configuration Debug-Dev -destination 'generic/platform=iOS' -derivedDataPath /tmp/THR-138-WalletCore-DD test -resultBundlePath /tmp/THR-138-WalletCore.xcresult`
- Exact UW Development build: `xcodebuild -workspace /Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50/Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination 'generic/platform=iOS' -derivedDataPath /tmp/THR-138-Development-DD build -resultBundlePath /tmp/THR-138-Development.xcresult`
- Exact source roots: UW `/Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50`, MarketKit `/Users/ant013/Data/AI/MarketKit.Swift-THR-104`, ThorChainKit `/Users/ant013/Data/AI/thorchain`. The UW package manifest must continue to resolve the latter two paths; capture `git rev-parse HEAD`, `git status --porcelain=v1`, and the manifest resolution before and after each run. Any SHA, status, or resolution change invalidates the evidence and requires a fresh capture.
- Live-smoke: launch the local Development app on the MacBook with the exact
  Liquify REST/RPC pair and frozen address above. Record the pre-fix failure,
  post-fix `.synced`/zero-RUNE/positive-height pass, and separate relaunch and
  offline regression observations in `/tmp/THR-138-live-smoke.txt` or a QA
  artifact. Never record mnemonic, private, credential, or cookie material.

## Open gates

- Adversarial review must confirm the short-form matcher remains address-bound
  and does not alter balance or generic HTTP error semantics.
- Explicit user approval is required for this design revision before any
  implementation edit.
- The separate provider evidence audit must be attached before Sprint 2 or
  final acceptance resumes.
