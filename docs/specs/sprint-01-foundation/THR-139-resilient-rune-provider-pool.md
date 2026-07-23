# THR-139 — resilient native RUNE provider pool

**Design revision:** 3 — discovery 2/2, closure 0/5. **Status:** revised
design; implementation remains blocked until this exact revision is accepted by
the adversarial reviewer and explicitly approved by the operator.

## Goal

Configure the exact Unstoppable Wallet v0.50 native RUNE integration with three
ordered endpoint families—Rorcual, IBS, Keplr—while preserving ThorChainKit's
whole-operation failover, height, identity, cancellation, and lifecycle
contracts.

## Assumptions and boundaries

- `origin/main` at `6462bec2604db4d3d05b3cfccde1ff5b768c86e0` is the approved
  ThorChainKit documentation-only base. THR-138 is complete and explicitly
  activates this correction as the sole current slice.
- The exact UW v0.50 Development checkout is the implementation and acceptance
  substrate. Its current dirty state is evidence-only during design; it will
  not be edited or committed until this revision is approved.
- The six public endpoint entries below were independently verified read-only
  on 2026-07-23. Base paths are significant because ThorChainKit appends request
  paths to the configured URL.
- No credentials, cookies, mnemonic material, provider keys, or private data
  are required or permitted.

In scope:

- The existing `ThorChainEndpointConfigurationProvider` native RUNE
  composition seam, its existing manager/descriptor validation seam, and the
  exact focused AppTests.
- Exact family ordering, role-bound REST/RPC pairing, fail-closed URL
  validation, and the deterministic three-family live-smoke harness.
- ThorChainKit simulator tests that prove the existing pool/coordinator
  behavior without changing ThorChainKit.
- A test-only owner-observation seam at the existing UW native RUNE composition
  boundary. It must report the family actually used by the completed operation;
  a missing or mismatched observation is unavailable evidence and fails closed.

Out of scope:

- A new provider abstraction, ThorChainKit implementation/lifecycle/API
  changes, request-level retry, or identity/height-policy changes.
- The existing multichain swap provider, including its Liquify configuration.
- Liquify as a native RUNE family; it is a rejected one-provider counterexample.
- THR-135, Sprint 2, Maestro, GitHub Actions, remote simulators, or remote
  live-smoke execution.
- Any implementation commit or PR before explicit approval of this revision.

## Exact native RUNE configuration

The production provider returns exactly three families in this deterministic
order:

| Order | Family ID | REST base | RPC base |
|---:|---|---|---|
| 1 | `rorcual-mainnet` | `https://api-thorchain.rorcual.xyz` | `https://rpc-thorchain.rorcual.xyz` |
| 2 | `ibs-mainnet` | `https://thorchain.ibs.team/api` | `https://thorchain.ibs.team/rpc` |
| 3 | `keplr-mainnet` | `https://lcd-thorchain.keplr.app` | `https://rpc-thorchain.keplr.app` |

The security boundary is six role-bound endpoint records, not a six-element
host set:

```text
(rorcual-mainnet, rest, https, api-thorchain.rorcual.xyz, 443, /)
(rorcual-mainnet, rpc,  https, rpc-thorchain.rorcual.xyz, 443, /)
(ibs-mainnet,     rest, https, thorchain.ibs.team,         443, /api)
(ibs-mainnet,     rpc,  https, thorchain.ibs.team,         443, /rpc)
(keplr-mainnet,   rest, https, lcd-thorchain.keplr.app,    443, /)
(keplr-mainnet,   rpc,  https, rpc-thorchain.keplr.app,    443, /)
```

There are five unique DNS hosts because IBS REST and RPC intentionally share
`thorchain.ibs.team`. Validation is exact equality of the six normalized
`(family, role, scheme, host, effective port, base path)` records. It is not
host-set membership. A configured subset, superset, duplicate, HTTP URL,
credential, query, fragment, foreign host, or cross-family REST/RPC pairing
fails closed. This preserves the existing manager/descriptor seam and does not
create another abstraction.

## Verified analog family

Primary spine: ThorChainKit `EndpointConfiguration`, `EndpointPool`, and
`ReadOperationCoordinator`. They own endpoint-family validation, probing,
health, selection, complete-operation retry, identity locking, height checks,
cancellation, and lifecycle behavior.

Supporting analogs, with deliberately limited deltas:

- EvmKit `RpcSource.http` and `NodeApiProvider`: ordered URL-source shape only.
  Its request-level recursive rotation is rejected; ThorChainKit remains the
  whole-operation safety owner.
- TronKit `RpcSource` and `Kit.instance`: centralized source ownership and
  composition boundary only. Its current first-URL consumption is not treated
  as failover evidence.
- UW v0.50 `ThorChainEndpointConfigurationProvider` and manager tests: exact
  consumer/composition and test seam. The current one-family Liquify behavior
  is the current seam, not the target behavior.

Rejected counterexamples:

- `productionEndpointConfigurationUsesOfficialLiquifyPair`, which pins one
  Liquify family and therefore contradicts the three-family acceptance.
- Any one-family environment-supplied live test with `maximumAttempts=1`; it
  cannot prove family ownership or complete-operation failover and is not a
  THR-139 harness.

## Delta matrix

| Area | Preserve | Required delta | Failure/test proof |
|---|---|---|---|
| Provider composition | Existing provider and ThorChainKit factory seam | Return exactly Rorcual, IBS, Keplr in order | Exact count/order/ID/URL assertions |
| URL trust boundary | Existing HTTPS and URL-component validation | Compare exactly six role-bound records; reject subset/superset and cross-family pairs | Duplicate, foreign, superset, HTTP, credential/query/fragment, and pair-swap negatives |
| Failover lifecycle | EndpointPool health/selection and ReadOperationCoordinator complete-operation retry | Supply all three families; do not alter ThorChainKit | Use the existing `testRetryRepeatsTheCompleteOperationOnTheNextFamily` proof, whose injected first-family `ThorNodeReadError.httpStatus(... code: 503 ...)` causes one complete retry; assert unchanged height/identity checks |
| Ownership | Native RUNE provider owns native endpoints; multichain owns swaps | Keep Liquify out of native RUNE and leave multichain source untouched | Source diff plus native/multichain composition negatives |
| Live evidence | Existing iOS simulator/AppTests and public node probes | Add a THR-139 runner that always builds the full three-family manifest, requires an observed selected family equal to `THR139_OWNER_FAMILY`, and binds every probe to its family pair | Manifest equality, owner observation equality, pair ownership, `thorchain-1`, accepted heights, fail-closed drift |

## Acceptance criteria

1. THR-138 is done and this issue is the sole activated correction slice.
2. This spec, plan, and Gimle report are committed and pushed as one docs-only
   revision before implementation approval.
3. The exact UW provider returns exactly the three ordered families and the
   six role-bound endpoint records above. Liquify is absent from native RUNE;
   the existing multichain swap provider is unchanged.
4. Exact equality rejects duplicate IDs, missing or extra records, foreign
   hosts, HTTP/credential/query/fragment URLs, and every REST/RPC family swap.
5. Focused tests prove complete-operation failover and preserve height and
   identity rejection; no request-level retry or check weakening is added.
6. On the MacBook, the exact ThorChainKit simulator tests, UW `AppTests`, and
   Development simulator build pass at the reviewed implementation head.
7. The THR-139 live runner performs three isolated passes. Each pass constructs
   all three families from the checked-in table, records a digest-only manifest,
   requires the app's test-only owner observation to equal the requested
   `THR139_OWNER_FAMILY` (`rorcual-mainnet`, then `ibs-mainnet`, then
   `keplr-mainnet`), binds REST and RPC observations to that same family ID,
   verifies `thorchain-1` and accepted height/identity invariants, and fails
   closed on missing/mismatched owner observation, manifest drift, or pair
   mismatch. The existing injected HTTP 503 coordinator case proves complete-
   operation retry; public online passes provide the three-family ownership
   evidence.
8. CodeReviewer approval, QA pass, CTO merge-gate evidence, and explicit
   operator authorization remain required before any merge. THR-135 and Sprint
   2 remain blocked until then.

## Test-first implementation and verification plan

1. **Pre-edit contract tests (ThorChainSwiftEngineer).** In the exact UW
   checkout, replace the old one-Liquify expectation with exact order, URL,
   role-bound record, ownership, duplicate, superset, foreign, and pair-swap
   tests. Run them before editing production; the old provider must fail the
   new contract. Check: `xcodebuild ... -only-testing:AppTests/ThorChainKitManagerTests test`
   returns a real failing XCTest result, not a selector/compilation error.
2. **Small production edit (ThorChainSwiftEngineer).** Edit only the existing
   native RUNE provider and, if required by the failing exact-equality tests,
   its existing manager/descriptor validation seam. Do not add an abstraction,
   touch ThorChainKit, or touch the multichain provider. Check: focused tests
   pass and `git diff --name-only` is limited to the approved UW paths.
3. **ThorChainKit invariants (ThorChainQAEngineer).** From
   `$THORCHAINKIT_ROOT`, run one iOS Simulator `xcodebuild` test with these
   exact selectors: `ThorChainKitTests/EndpointPoolTests`,
   `ThorChainKitTests/ReadOperationCoordinatorS1_04Tests`,
   `ThorChainKitTests/LiveNodeProbeTests`, and
   `ThorChainKitTests/LiveThorNodeClientS1_04Tests`. Write the result bundle to
   `$THR139_THOR_RESULT_BUNDLE` and pass the checked-in exact test-name file
   `$THR139_THOR_ALLOWLIST` to `Scripts/verify-xcresult.sh`; the verifier must
   report `PASS`, with zero failures, errors, and skips. `swift test` is not
   evidence because the documented iOS-only SwiftPM path fails before XCTest on
   the audited toolchain. The retry proof is the existing HTTP 503 case named
   above; height and identity rejection tests remain selected separately.
4. **UW tests/build (ThorChainQAEngineer).** First inspect the exact shared
   scheme XML and fail closed unless its `TestAction.Testables` contains an
   unsuppressed `BlueprintName="AppTests"`; `-showdestinations` is only the
   simulator availability check. Then run the exact class selector with a
   result bundle, verify its compact summary and every test node are `Passed`
   with zero failures/skips using the checked-in `$THR139_UW_ALLOWLIST`, and
   run the explicit `Debug-Dev` simulator build. Check: the test and build both
   resolve to `PLATFORM_NAME=iphonesimulator`, `CONFIGURATION=Debug-Dev`, and
   no `-only-testing:ThorChain` selector is used.
5. **THR-139 live runner (ThorChainQAEngineer).** Use the exact local
   `$UW_ROOT/Scripts/verify-thr-139-live.sh` runner added alongside the UW
   focused tests, then independently run
   `$UW_ROOT/Scripts/verify-thr-139-evidence.py` against the evidence root. Its
   required mapping is `THR139_FAMILY_TABLE` (the six checked-in records),
   `THR139_SIMULATOR_UDID`, `THR139_EVIDENCE_ROOT`, and
   `THR139_OWNER_FAMILY`; the app test-only seam must emit the selected family
   ID, and the runner must reject missing or mismatched observations. It
   launches the Development app, injects only public values into simulator
   launchd, and unsets them in a trap. It runs once for each owner label with
   all three families present, uses unique evidence directories, compares
   before/after canonical manifests, and writes only the following canonical
   JSON fields: `schemaVersion`, `ownerFamily`, `observedFamily`,
   `manifestSha256`, `rest`, `rpc`, `chainId`, `height`, and `resultSha256`.
   `manifestSha256` and `resultSha256` are lowercase SHA-256 digests of
   canonical JSON (sorted keys, UTF-8, no trailing newline). The independent
   verifier checks schema version, family equality, six-record equality, digest
   recomputation, `thorchain-1`, and accepted height/identity invariants. Any
   missing field, drift, mismatch, or unapproved record exits non-zero before
   reporting success.
6. **Handoff (CodeReviewer → QA → CTO).** Each reviewer cites the exact pushed
   PR head and concrete output. CTO checks CI, conflict-free head, CR approval,
   QA pass, and explicit operator authorization; only CTO merges.

## Exact command shapes

The ThorChainKit test command is a simulator Xcode command, not `swift test`:

```text
(cd "$THORCHAINKIT_ROOT" && xcodebuild -scheme ThorChainKit \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -derivedDataPath "$THR139_THOR_DERIVED_DATA" \
  -resultBundlePath "$THR139_THOR_RESULT_BUNDLE" \
  -only-testing:ThorChainKitTests/EndpointPoolTests \
  -only-testing:ThorChainKitTests/ReadOperationCoordinatorS1_04Tests \
  -only-testing:ThorChainKitTests/LiveNodeProbeTests \
  -only-testing:ThorChainKitTests/LiveThorNodeClientS1_04Tests \
  SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO test)
Scripts/verify-xcresult.sh THR-139-thor "$THR139_THOR_RESULT_BUNDLE" \
  "$THR139_THOR_ALLOWLIST"
```

The UW test command is:

```text
xcodebuild test -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -resultBundlePath "$THR139_UW_RESULT_BUNDLE" \
  -only-testing:AppTests/ThorChainKitManagerTests
xcrun xcresulttool get test-results summary --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | jq -e '(.result == "Passed") and (.failedTests == 0) and (.skippedTests == 0)'
xcrun xcresulttool get test-results tests --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py" "$THR139_UW_ALLOWLIST"

scheme="$UW_ROOT/Unstoppable/Unstoppable.xcodeproj/xcshareddata/xcschemes/Development.xcscheme"
plutil -extract TestAction.Testables xml1 -o - "$scheme" \
  | rg -q 'BlueprintName="AppTests"[^>]*skipped="NO"|skipped="NO"[^>]*BlueprintName="AppTests"'
xcodebuild build -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -derivedDataPath "$THR139_UW_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO

for family in rorcual-mainnet ibs-mainnet keplr-mainnet; do
  THR139_OWNER_FAMILY="$family" \
    THR139_FAMILY_TABLE="$THR139_FAMILY_TABLE" \
    THR139_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
    THR139_EVIDENCE_ROOT="$THR139_EVIDENCE_ROOT/$family" \
    "$UW_ROOT/Scripts/verify-thr-139-live.sh"
done
python3 "$UW_ROOT/Scripts/verify-thr-139-evidence.py" "$THR139_EVIDENCE_ROOT"
```

No raw endpoint responses, credentials, cookies, mnemonics, absolute operator
paths, or private values may enter committed evidence.

## Gimle and review gate

The Gimle report is RED because the EvmKit snippet freshness is contradictory
and semantic searches have coverage gaps. Exact local Serena, targeted `rg`,
and Git verification are the accepted fallback; the defects remain recorded.
The revised report records D-001 through D-010 as resolved design decisions
only after the exact docs revision is pushed. D-008 remains a medium
reproducibility limitation until the runner artifacts exist, but it is no longer
a design blocker. A fresh bounded adversarial review
must recheck those allowlisted IDs and direct regressions; it must not reopen
broad discovery. Explicit operator approval of this exact pushed spec and plan
is required before implementation.
