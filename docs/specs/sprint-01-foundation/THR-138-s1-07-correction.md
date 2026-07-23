# THR-138 — S1-07 native RUNE sync correction

**Status:** design revision 4; discovery 1/2, closure 1/5. Implementation is blocked pending adversarial re-review and explicit approval of this exact revision.

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

The leased-height check is load-bearing: the account reader currently checks
the 404 absence body before validating that response's Cosmos height. A 404
from a backend serving a different height can therefore be misclassified as an
absent account.

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
- The provider audit must supply a redacted, hash-bound input record naming the
  exact public Rorcual, IBS, and Keplr family inputs before QA runs them. This
  slice does not infer or add those inputs.
- The accepted short message is exactly `account <requested-address> not found`
  after substituting the requested address. Matching is full-string equality;
  containment, prefix, suffix, trimming, normalization, or whitespace
  tolerance is forbidden. Generic or foreign-address messages are not absence.
- The existing long-form response remains valid and must continue to be
  accepted.
- The response's leased Cosmos height must be validated before any 404 absence
  classification. Missing, malformed, or mismatched height is a typed
  `heightMismatch`, never an absent account.
- Duplicate JSON object keys are malformed for this envelope. The classifier
  rejects any duplicate key before decoding or absence classification,
  including both conflicting and same-value duplicates of `code`, `message`,
  or `details`.

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
2. Account absence is returned only after the response matches the leased
   Cosmos height, and only for HTTP 404 with code `5`, empty details, no
   duplicate JSON object keys, and full-string equality with either
   `rpc error: code = NotFound desc = account <requested-address> not found: key not found`
   or `account <requested-address> not found`.
3. Prefix, suffix, leading/trailing/internal-whitespace, foreign-address,
   wrong-code, nonempty-details, duplicate-key, malformed-JSON,
   missing/malformed/mismatched-height, exact-body-under-non-404, and
   balance-404-with-the-same-body cases retain typed fail-closed errors. The
   balance case remains `.httpStatus(.balances, 404)`.
4. The focused ThorChainKit regression test, relevant ThorChainKit and
   WalletCore tests, and the local Development application build pass. No
   GitHub Actions run is used.
5. Post-fix exact local S1-04 live acceptance passes once per already audited
   family—Rorcual, IBS, and Keplr—with one unique evidence directory and one
   family owner for each run. This consumes existing verified family inputs
   only; it does not add provider configuration to this slice.
6. The final QA evidence cites the exact local PR head, canonical digest-only
   input manifests, reproducible simulator launchd injection and cleanup, and
   the real device/app/OS/endpoint results without sensitive material. THR-139
   owns the next production provider-pool correction; this slice does not
   resume Sprint 2 or implement provider selection.

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
| Account 404 classifier | leased-height validation, code `5`, empty details, address binding, typed errors | Accept the two verified messages by full-string equality only after height validation and duplicate-key rejection | `contains`, prefix/suffix matching, whitespace normalization, any `404`, generic text, foreign address, duplicate-key first-value decoding, or bypassing height validation | A cross-backend height failure or ambiguous body could be treated as an absent account | Focused exact long/short positives plus height, duplicate-key, prefix/suffix/whitespace/foreign negatives |
| Account consumer | `nil` absent account and existing adapter lifecycle | No consumer API or lifecycle change | Add UW-specific fallback or zero-balance behavior | Missing account could mask a real provider failure | Local Development live-smoke and WalletCore tests |
| Balance/error boundary | All balance non-2xx errors remain typed | None | Reuse account absence matcher for balances | Provider outage could be hidden as empty balance | Focused balances 404 with the same body asserts `.httpStatus(.balances, 404)` |

## Test-first plan

1. Update the existing account absence test contract to assert exact full-string
   equality for both accepted messages. Validate the response height before
   classification. Add prefix, suffix, leading/trailing/internal-whitespace,
   foreign-address, wrong-code, nonempty-details, same-value and conflicting
   duplicate-key, malformed-JSON, missing/malformed/mismatched-height, exact
   body under non-404, and balances-404-with-the-same-body cases; the latter
   must remain `.httpStatus(.balances, 404)`.
2. Run the focused ThorChainKit test and capture the pre-fix failure against
   the short form.
3. Implement the smallest account-classification correction in the existing
   client file; do not change consumer or provider configuration.
4. Re-run the focused test, the directly affected ThorChainKit suite, relevant
   WalletCore tests, and the exact local Development build command in the plan.
5. Run the real local Development live-smoke against the exact Liquify REST/RPC
   pair. The pre-fix run must capture the short 404 and old unavailable/closed
   result. The post-fix pass is only valid when the app is online and `.synced`,
   the account is absent, native RUNE is exactly zero, a positive accepted
   height is shown, and no closed/unavailable diagnostic is present. Relaunch
   and offline behavior are separate regression checks.
6. Run the exact local S1-04 live acceptance three times, once each for
   Rorcual, IBS, and Keplr, using only the hash-bound family inputs from the
   attached provider audit. The runner is invoked once per family with a
   family-specific output root. A QA wrapper sets every public test variable
   into simulator launchd with `xcrun simctl spawn "$UDID" launchctl setenv`,
   exports the same values for the runner's shell contract, and uses a trap to
   `launchctl unsetenv` every variable after that family exits. Shell-only
   export is invalid. No mnemonic, credential, or private material is
   recorded.

## Verification commands and evidence

- ThorChainKit focused test: `swift test --package-path "$THORCHAINKIT_ROOT" --filter LiveThorNodeClientS1_04Tests/testAccountAcceptsOnlyExactObservedAbsenceEnvelope`
- ThorChainKit directly affected suite: `swift test --package-path "$THORCHAINKIT_ROOT" --filter LiveThorNodeClientS1_04Tests`
- Exact UW AppTests command (the `Development` scheme's `AppTests` testable):
  `xcodebuild -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$THR138_SIMULATOR_UDID" -derivedDataPath "$QA_ARTIFACT_ROOT/THR-138-AppTests-DD" test -only-testing:AppTests -resultBundlePath "$QA_ARTIFACT_ROOT/THR-138-AppTests.xcresult"`
- Exact UW Development build: `xcodebuild -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" -scheme Development -configuration Debug-Dev -destination 'generic/platform=iOS' -derivedDataPath "$QA_ARTIFACT_ROOT/THR-138-Development-DD" build`
- Exact source roots are symbolic operator inputs: `UW_ROOT`, `MARKETKIT_ROOT`,
  and `THORCHAINKIT_ROOT`; the UW project is
  `$UW_ROOT/Unstoppable/Unstoppable.xcodeproj`. The UW package manifest must
  resolve the latter two roots. Do not commit resolved values in repository
  documents.
- Before and after every test, build, and smoke run, invoke the planned
  digest-only input-manifest helper for each root. Its canonical JSON schema is
  `{"schemaVersion":1,"rootLabel":"...","head":"<40-hex>","statusSha256":"<64-hex>","files":[{"path":"<JSON-escaped UTF-8 relative path>","state":"present|deleted|symlink-rejected","size":<integer>,"sha256":"<64-hex>"}]}`.
  Membership is the bytewise-UTF-8 sorted union of `git ls-files -c -o
  --exclude-standard -z`; tracked deletions are retained as `deleted`, regular
  files are hashed from their working-tree bytes, and symlinks fail closed.
  JSON uses UTF-8, `ensure_ascii=true`, sorted keys, compact separators, and one
  final newline. `statusSha256` is the SHA-256 of the raw NUL-delimited
  `git status --porcelain=v1 --untracked-files=all -z` bytes; the status bytes
  and all patches are discarded and never written to evidence. The helper
  separately records the SHA-256 of each resolved local package path. Require
  ThorChainKit's `head` to equal the exact implementation PR head and require
  every other manifest, status digest, and package-resolution digest to be
  identical before and after each run. Any mismatch invalidates that run.
- Family live-smoke: the runner accepts a required family label and unique
  evidence root, so the exact invocations are
  `THORCHAIN_S1_04_FAMILY_ID=Rorcual THORCHAIN_S1_04_EVIDENCE_ROOT="$QA_ARTIFACT_ROOT/THR-138-live/Rorcual" Scripts/verify-s1-04-live.sh`, then the same command with `IBS` and `Keplr`. The wrapper injects the provider-audit public variables into simulator launchd before each invocation and removes them in its exit trap. Each evidence record owns only its family label, result bundle, input-manifest digests, and redacted heights/classes; no mnemonic, private, credential, cookie, raw status, or patch material is recorded.
- Development-app smoke: after the `Development` build, install
  `$QA_ARTIFACT_ROOT/THR-138-Development-DD/Build/Products/Debug-Dev-iphonesimulator/Unstoppable.app`
  with `xcrun simctl install "$THR138_SIMULATOR_UDID" "$QA_ARTIFACT_ROOT/THR-138-Development-DD/Build/Products/Debug-Dev-iphonesimulator/Unstoppable.app"`, then launch bundle
  `io.horizontalsystems.bank-wallet.dev` with
  `xcrun simctl launch "$THR138_SIMULATOR_UDID" io.horizontalsystems.bank-wallet.dev`.
  Using the pre-provisioned public no-funds account fixture, QA records: the
  pre-fix short-404 and closed/unavailable result; post-fix online `.synced`,
  absent account, exactly zero native RUNE, and positive accepted height;
  terminate/relaunch with the same address and values; then offline relaunch
  with unchanged address and an explicit unavailable/stale state followed by
  online recovery. Screenshot or structured observation files go under
  `$QA_ARTIFACT_ROOT/THR-138-development-smoke/`; secrets are excluded.

## Open gates

- Adversarial review must confirm the short-form matcher remains address-bound
  and does not alter balance or generic HTTP error semantics; it must also
  confirm duplicate-key rejection and height validation precede absence.
- QA must pass three distinct exact local runs—Rorcual, IBS, and Keplr—with
  family-owned evidence, prove simulator launchd injection and cleanup, and
  attach the provider-audit input manifest.
- Explicit user approval is required for this design revision before any
  implementation edit.
- THR-139 is the required next production provider-pool correction after this
  slice. Sprint 2 remains paused, and the provider evidence audit must be
  attached before either issue is accepted as the Sprint 1 correction gate.
