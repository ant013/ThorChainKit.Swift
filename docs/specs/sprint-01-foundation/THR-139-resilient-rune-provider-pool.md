# THR-139 — resilient native RUNE provider pool

**Design revision:** 8 — discovery 2/2, closure 4/5 pending targeted review.
**Status:** revised
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
- Deterministic full-manifest family-selection fixtures in AppTests. They vary
  only scripted Comet heights so Rorcual, IBS, and Keplr are each selected in a
  separate fixture pass.
- Online native-RUNE smoke using the existing S1-04 family live-smoke runner,
  once for each of Rorcual, IBS, and Keplr. This reuses the approved public
  endpoint, REST/RPC identity, height, manifest, and evidence boundary; it adds
  no Unstoppable acceptance transport, test launch-argument branch, adapter
  sink, or production observation callback.

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
| Online network smoke | Existing S1-04 family live-smoke runner and public node probes | Run the approved runner once per production family; do not add a UW acceptance transport, launch-argument branch, adapter sink, or production selector | Per-family manifest/evidence freshness, REST/RPC pair ownership, `thorchain-1`, accepted heights, and fail-closed drift |

### Selection and live-smoke contract

The deterministic AppTests and the online runner have different proof duties.
AppTests use the existing ThorChainKit testing transport to retain the complete
three-family manifest and script valid Comet heights so one family is highest in
each fixture. They assert the completed read projection's
`TestingAccountReadSession.read().providerFamilyId` equals the family selected
by the scripted heights. The fixture target is never copied into the
observation; it only controls responses.

The online smoke intentionally does not claim ownership of a family from an
Unstoppable app event. The approved S1-04 runner supplies one audited public
family input per isolated pass and independently verifies that family's REST/RPC
pair, chain identity, accepted height, and digest-only evidence. The
deterministic AppTests are the provider-pool ownership proof: every fixture
constructs the complete three-family manifest, varies only scripted valid
Comet heights, and asserts the completed projection's
`providerFamilyId` equals the family selected by the operation. No callback,
file sink, acceptance transport, launch-argument branch, or production
selector is added to Unstoppable or ThorChainKit.

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
7. The deterministic AppTests perform three isolated fixture passes. Each pass
   constructs all three families from the checked-in table, scripts one family
   to have the greatest valid Comet height, and verifies the completed
   projection's `providerFamilyId` equals the actually selected family. The
   existing S1-04 family live-smoke runner performs three isolated real-node
   passes, one for each approved family, and independently verifies each
   REST/RPC pair, `thorchain-1`, accepted height/identity invariants, fresh
   digest-only evidence, and manifest stability. It does not claim that online
   passes forced provider selection. No Unstoppable acceptance transport,
   launch-argument branch, adapter sink, or production selector is added. The
   existing injected HTTP 503 coordinator case proves complete-operation retry.
8. CodeReviewer approval, QA pass, CTO merge-gate evidence, and explicit
   operator authorization remain required before any merge. THR-135 and Sprint
   2 remain blocked until then.

## Test-first implementation and verification plan

1. **Existing verification gates (ThorChainSwiftEngineer).** Reuse the
   existing repository-owned `Scripts/verify-s1-02.sh`, `Scripts/verify-s1-04.sh`,
   `Scripts/verify-xcresult.sh`, and `Scripts/verify-s1-04-live.sh` contracts.
   Do not add THR-139 ThorChainKit allowlists, result-bundle wrappers, or
   allowlist arguments. Those scripts use `set -euo pipefail`, derive their
   checked-in fixtures from the repository root, create fresh result bundles,
   and reject stale bundles internally. Run their existing shell syntax and
   negative-fixture checks; no caller-supplied allowlist path is permitted.
2. **Pre-edit contract tests (ThorChainSwiftEngineer).** In the exact UW
   checkout, run the repository-owned scheme preflight before this first Xcode
   command, then replace the old one-Liquify expectation with exact order, URL,
   role-bound record, ownership, duplicate, superset, foreign, and pair-swap
   tests. Run them before editing production; the old provider must fail the
   new contract. Check: `xcodebuild ... -only-testing:AppTests/ThorChainKitManagerTests test`
   returns a real failing XCTest result, not a selector/compilation error.
3. **Small production edit (ThorChainSwiftEngineer).** Edit only the existing
   native RUNE provider and, if required by the failing exact-equality tests,
   its existing manager/descriptor validation seam. Do not add an abstraction,
   touch ThorChainKit, or touch the multichain provider. Check: focused tests
   pass and `git diff --name-only` is limited to the approved UW paths.
4. **ThorChainKit invariants (ThorChainQAEngineer).** From
   `$THORCHAINKIT_ROOT`, run the existing `Scripts/verify-s1-02.sh` and
   `Scripts/verify-s1-04.sh --expected-base ... --expected-head ...` gates with
   the reviewed simulator UUID. Their repository-derived fixtures and
   `Scripts/verify-xcresult.sh` invocation must report `PASS`, with zero
   failures, errors, and skips; do not pass an allowlist path. The S1-04 gate's
   internal manifest includes `EndpointPoolTests`,
   `ReadOperationCoordinatorS1_04Tests`, `LiveNodeProbeTests`, and
   `LiveThorNodeClientS1_04Tests`. `swift test` is not evidence because the
   documented iOS-only SwiftPM path fails before XCTest on the audited
   toolchain. The retry proof is the existing HTTP 503 case named above;
   height and identity rejection tests remain selected separately.
5. **UW tests/build (ThorChainQAEngineer).** First run this XML-safe preflight
   against the exact shared scheme, before any test or build command:

   ```text
   set -euo pipefail
   python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" \
     "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj/xcshareddata/xcschemes/Development.xcscheme"
   ```

   The `set -euo pipefail` wrapper is mandatory: a non-zero XML check stops the
   shell before any Xcode command. Only after that preflight, use
   `-showdestinations` for simulator availability,
   run the exact class selector with a newly-created result bundle, verify its
   compact summary and every test node are `Passed` with zero failures/skips
   using the verifier's internally-derived checked-in allowlist, and run the
   explicit `Debug-Dev` simulator build.
   Check: the test and build both resolve to `PLATFORM_NAME=iphonesimulator`,
   `CONFIGURATION=Debug-Dev`, and no `-only-testing:ThorChain` selector is used.
6. **Three-family online smoke (ThorChainQAEngineer).** Use the existing
   `$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh` runner once per approved
   family with unique evidence roots and the already audited public inputs.
   Verify each fresh digest-only result with the existing S1-04 evidence
   verifier. This is network identity/height/pair evidence, not an Unstoppable
   owner-selection oracle; no UW acceptance transport, launch argument,
   adapter sink, or new live runner is added.
7. **Handoff (CodeReviewer → QA → CTO).** Each reviewer cites the exact pushed
   PR head and concrete output. CTO checks CI, conflict-free head, CR approval,
   QA pass, and explicit operator authorization; only CTO merges.

## Exact command shapes

The ThorChainKit test command is a simulator Xcode command, not `swift test`:

```text
set -euo pipefail
: "${THR139_EXPECTED_BASE:?set to the reviewed 40-character origin/main SHA}"
: "${THR139_EXPECTED_HEAD:?set once to the reviewed 40-character ThorChainKit HEAD}"
(cd "$THORCHAINKIT_ROOT" && \
  THORCHAIN_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
  Scripts/verify-s1-02.sh)
(cd "$THORCHAINKIT_ROOT" && \
  THORCHAIN_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
  Scripts/verify-s1-04.sh \
    --expected-base "$THR139_EXPECTED_BASE" \
    --expected-head "$THR139_EXPECTED_HEAD")
```

The UW test command is:

```text
scheme="$UW_ROOT/Unstoppable/Unstoppable.xcodeproj/xcshareddata/xcschemes/Development.xcscheme"
set -euo pipefail
uw_result_root="$(mktemp -d)"
THR139_UW_RESULT_BUNDLE="$uw_result_root/THR-139-uw.xcresult"
test ! -e "$THR139_UW_RESULT_BUNDLE"
python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" "$scheme"
xcodebuild -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -showdestinations
xcodebuild test -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -resultBundlePath "$THR139_UW_RESULT_BUNDLE" \
  -only-testing:AppTests/ThorChainKitManagerTests
test -d "$THR139_UW_RESULT_BUNDLE"
xcrun xcresulttool get test-results summary --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | jq -e '(.result == "Passed") and (.failedTests == 0) and (.skippedTests == 0)'
xcrun xcresulttool get test-results tests --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py"

xcodebuild build -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -derivedDataPath "$THR139_UW_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO

: "${THR139_EXISTING_ADDRESS:?set to the audited public existing thor1 address}"
: "${THR139_ABSENT_ADDRESS:?set to the audited public absent thor1 address}"
: "${THR139_SIMULATOR_UDID:?set to the approved iOS 26.2 simulator UUID}"

THORCHAIN_S1_04_LIVE=1 \
THORCHAIN_S1_04_EXPECTED_HEAD="$THR139_EXPECTED_HEAD" \
THORCHAIN_S1_04_FAMILY_ID="rorcual-mainnet" \
THORCHAIN_S1_04_EVIDENCE_ROOT="$THR139_EVIDENCE_ROOT/rorcual-mainnet" \
THORCHAIN_S1_04_COSMOS_URL="https://api-thorchain.rorcual.xyz" \
THORCHAIN_S1_04_COMET_URL="https://rpc-thorchain.rorcual.xyz" \
THORCHAIN_S1_04_EXISTING_ADDRESS="$THR139_EXISTING_ADDRESS" \
THORCHAIN_S1_04_ABSENT_ADDRESS="$THR139_ABSENT_ADDRESS" \
THORCHAIN_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
"$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh"

THORCHAIN_S1_04_LIVE=1 \
THORCHAIN_S1_04_EXPECTED_HEAD="$THR139_EXPECTED_HEAD" \
THORCHAIN_S1_04_FAMILY_ID="ibs-mainnet" \
THORCHAIN_S1_04_EVIDENCE_ROOT="$THR139_EVIDENCE_ROOT/ibs-mainnet" \
THORCHAIN_S1_04_COSMOS_URL="https://thorchain.ibs.team/api" \
THORCHAIN_S1_04_COMET_URL="https://thorchain.ibs.team/rpc" \
THORCHAIN_S1_04_EXISTING_ADDRESS="$THR139_EXISTING_ADDRESS" \
THORCHAIN_S1_04_ABSENT_ADDRESS="$THR139_ABSENT_ADDRESS" \
THORCHAIN_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
"$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh"

THORCHAIN_S1_04_LIVE=1 \
THORCHAIN_S1_04_EXPECTED_HEAD="$THR139_EXPECTED_HEAD" \
THORCHAIN_S1_04_FAMILY_ID="keplr-mainnet" \
THORCHAIN_S1_04_EVIDENCE_ROOT="$THR139_EVIDENCE_ROOT/keplr-mainnet" \
THORCHAIN_S1_04_COSMOS_URL="https://lcd-thorchain.keplr.app" \
THORCHAIN_S1_04_COMET_URL="https://rpc-thorchain.keplr.app" \
THORCHAIN_S1_04_EXISTING_ADDRESS="$THR139_EXISTING_ADDRESS" \
THORCHAIN_S1_04_ABSENT_ADDRESS="$THR139_ABSENT_ADDRESS" \
THORCHAIN_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
"$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh"
```

The XML-safe Python preflight above is run before the `xcodebuild test` block;
the command block is shown compactly here only after its preflight has passed.
The three live invocations are intentionally explicit: the family ID and both
URLs are fixed literals, while the expected HEAD, public addresses, simulator
UUID, and evidence root are required inputs shared across the isolated passes.
The expected HEAD is captured once from the clean exact checkout and is
not recomputed between families.

### Canonical digest domains

`manifestSha256` is the lowercase SHA-256 of the UTF-8 bytes of canonical JSON
for the checked-in manifest object `{"families":[six role-bound records]}`,
with recursively sorted object keys, compact separators, and no trailing
newline. Every manifest record has exactly the keys `basePath`, `family`,
`host`, `port`, `role`, and `scheme`. `resultSha256` is the lowercase SHA-256
of the same canonical encoding for the result object with the `resultSha256`
field omitted. `rest` and `rpc` each have exactly the six record keys plus
`chainId` and `height`; the top-level result has exactly `chainId`, `height`,
`manifestSha256`, `observedFamily`, `rest`, `rpc`, and `schemaVersion` before
`resultSha256` is added:

```json
{"chainId":"thorchain-1","height":12345678,"manifestSha256":"2b103c56a8e8020e210d9e589150420618de663b2184c39e0a1140000c5d712b","observedFamily":"rorcual-mainnet","rest":{"basePath":"/","chainId":"thorchain-1","family":"rorcual-mainnet","height":12345678,"host":"api-thorchain.rorcual.xyz","port":443,"role":"rest","scheme":"https"},"rpc":{"basePath":"/","chainId":"thorchain-1","family":"rorcual-mainnet","height":12345678,"host":"rpc-thorchain.rorcual.xyz","port":443,"role":"rpc","scheme":"https"},"schemaVersion":1}
```

For that fixed fixture, the manifest digest is
`2b103c56a8e8020e210d9e589150420618de663b2184c39e0a1140000c5d712b` and the
result digest is
`356b6fe7d87d023a26cd4422da72dac1df226ed055508821b104717180d2a22c`.
The independent verifier reconstructs both preimages, rejects any extra or
missing field, and compares the resulting digests before reporting success. No
digest is computed over an object containing itself.

No raw endpoint responses, credentials, cookies, mnemonics, absolute operator
paths, or private values may enter committed evidence.

## Gimle and review gate

The Gimle report is RED because the EvmKit snippet freshness is contradictory
and semantic searches have coverage gaps. Exact local Serena, targeted `rg`,
and Git verification are the accepted fallback; the defects remain recorded.
Revision 8 resolves the board's closure 4/5 correction by reusing the existing
S1-02 and S1-04 repository gates, removing THR-139-specific ThorChainKit
allowlists/wrappers, and spelling three executable fixed family-to-REST/RPC
live invocations with every required public runner input. The unapproved
Unstoppable live evidence sink/adapter branch remains removed. Discovery
remains frozen at 2/2; closure remains bounded to the frozen IDs and direct
regressions. Explicit operator approval of this exact pushed spec and plan is
required before implementation.
