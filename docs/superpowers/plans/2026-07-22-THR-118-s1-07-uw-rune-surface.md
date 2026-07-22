# THR-118 S1-07 plan — UW v0.50 native RUNE surface

Status: design revision 3; docs-only plan awaiting exact-head
`ThorChainCodeReviewer` adversarial review. Implementation starts only after
reviewer ACCEPT and a fresh operator approval interaction.

## Step 1 — Release metadata and explorer dependency gate

- Owner: MarketKit/backend owner, coordinated by CTO.
- Paths: local MarketKit metadata tests/fixtures; ThorChainKit spec and report.
- Acceptance: released/cache data proves `thorchain` blockchain, native RUNE,
  8 decimals, and a non-null explorer URL with the exact approved template.
  Null or unverified explorer data is a hard blocked dependency.
- Verification: deterministic metadata fixture/test and captured exact URL
  value; no Unstoppable source change.
- Dependency: none. Steps 2–5 are blocked until this gate is resolved.

## Step 2 — Mnemonic AccountType and discovery/restore policy

- Owner: ThorChainSwiftEngineer after approval.
- Paths: UW `AccountType`, Manage Wallets fetch/view model, RestoreHelper,
  focused AppTests.
- Acceptance: mnemonic supports only THOR native RUNE; RUJI, TCY, and other
  non-native THOR assets are rejected; Manage Wallets and create/import restore
  expose RUNE without changing unrelated account behavior.
- Verification: positive native fixture and negative RUJI/TCY/non-native
  fixtures, plus hermetic Manage Wallets and restore tests.
- Dependency: Step 1.

## Step 3 — Receive-only capability surfaces

- Owner: ThorChainSwiftEngineer after approval.
- Paths: wallet/token button view models, SendTokenList, AddressEventHandler
  and its send-page consumer, MultiSwap token selection/default resolution.
- Acceptance: RUNE retains address/balance/receive, while Send/Swap buttons,
  SendTokenList, QR/address-to-Send, and MultiSwap token-in exclude it. Generic
  non-THOR routes remain unchanged. Send/swap implementation is not added.
- Verification: focused view-model/event tests with direct assertions on all
  five prohibited ingress paths.
- Dependency: Step 2.

## Step 4 — Durable cache, migration, restart, and failure recovery

- Owner: ThorChainSwiftEngineer after approval.
- Paths: WalletStorage, WalletManager, cache doubles, AppTests.
- Acceptance: isolated fresh-cache and existing-v2-cache migration tests prove
  persistence through terminate/relaunch. Missing token, missing chain, and
  thrown query retain the enabled record/account identity and expose a
  diagnosable unavailable/retry state; no silent wallet disappearance.
- Verification: three failure-injection tests plus restart assertions.
- Dependency: Steps 1–2; recovery contract must be agreed in review before
  implementation.

## Step 5 — Address, balance, and status host integration

- Owner: ThorChainSwiftEngineer after approval.
- Paths: existing S1-06 ThorChainKitManager/ThorChainAdapter integration seams,
  AppStatus mapping, focused AppTests.
- Acceptance: canonical `thor1` address and native RUNE balance render after
  enable/restore and after relaunch; endpoint validation and adapter lifecycle
  remain unchanged.
- Verification: focused local AppTests and manual MacBook launch/terminate/
  relaunch evidence. No Maestro in Unstoppable and no CI device execution.
- Dependency: Steps 1, 2, and 4.

## Step 6 — Review and approval gates

- Owner: ThorChainCodeReviewer, then operator, then CTO.
- Paths: exact docs commit, Gimle state/report, issue handoff.
- Acceptance: reviewer posts a severity-tagged ACCEPT for the exact commit;
  only then does CTO request fresh operator confirmation. No implementation
  child issue, UW source edit, commit, push, or PR precedes that confirmation.
- Verification: state validates at `adversarial_review`; later state transition
  to `awaiting_approval` includes reviewer decisions and exact revision.
- Dependency: Steps 1–5 plan coverage and docs-only push.
