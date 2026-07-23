# THR-139 — resilient native RUNE provider pool

**Design revision:** 5 — discovery 2/2, closure 2/5 pending targeted review.
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
- Live actual-owner observation through the launched kit's existing
  `accountState?.providerFamilyId` boundary. A missing or unapproved observed
  family fails closed; live input does not request or force a family.

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
| Live evidence | Existing iOS simulator/AppTests and public node probes | Add a THR-139 runner that always builds the full three-family manifest, records the launched kit's actual `accountState?.providerFamilyId`, and binds every probe to that observed family pair | Manifest equality, observed-family membership, pair ownership, `thorchain-1`, accepted heights, fail-closed drift |

### Owner-observation contract

The deterministic AppTests and the online runner have different proof duties.
AppTests use the existing ThorChainKit testing transport to retain the complete
three-family manifest and script valid Comet heights so one family is highest in
each fixture. They assert the completed read projection's
`TestingAccountReadSession.read().providerFamilyId` equals the family selected
by the scripted heights. The fixture target is never copied into the
observation; it only controls responses.

The online runner does not accept a caller-supplied owner and cannot force a
selection. It observes the actual launched kit instance after its completed
operation through the existing `accountState?.providerFamilyId` boundary. The
runner records that value as `observedFamily` and fails closed when it is
missing, outside the three-family manifest, or inconsistent with the REST/RPC
pair used for the same operation. This is the only live owner claim; the
deterministic AppTests are the proof that each family can be selected with the
full manifest. No callback/box is added to the production factory seam, and no
production selector or EndpointPool behavior changes.

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
   online runner performs three isolated real-node passes with the same full
   manifest, observes the launched kit's actual
   `accountState?.providerFamilyId`, binds REST and RPC observations to that
   observed family, verifies `thorchain-1` and accepted height/identity
   invariants, and fails closed on missing/unapproved observation, manifest
   drift, or pair mismatch. It does not accept a caller-supplied expected owner
   or claim that three online passes forced one pass per family. The existing
   injected HTTP 503 coordinator case proves complete-operation retry.
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
4. **Verification artifact authoring (ThorChainSwiftEngineer).** Add and
   commit these repository-owned artifacts before any consumer command runs:
   `$THORCHAINKIT_ROOT/Scripts/allowlists/THR-139-thor.txt`;
   `$UW_ROOT/Scripts/allowlists/THR-139-uw.txt`;
   `$UW_ROOT/Scripts/allowlists/THR-139-family-manifest.json`;
   `$UW_ROOT/Scripts/verify-thr-139-scheme.py`;
   `$UW_ROOT/Scripts/verify-thr-139-uw-tests.py`;
   `$UW_ROOT/Scripts/verify-thr-139-live.sh`; and
   `$UW_ROOT/Scripts/verify-thr-139-evidence.py`. The ThorChainKit allowlist
   contains the exact selected test identifiers consumed by the existing
   `Scripts/verify-xcresult.sh`. The UW test verifier rejects missing, extra,
   duplicate, failed, or skipped test nodes. The live/evidence verifiers reject
   missing or unapproved owner observations, manifest drift, pair swaps,
   unapproved hosts, wrong chain identity, invalid heights, and digest
   tampering. Each consumer resolves its allowlist, manifest, and verifier by
   fixed paths relative to its checked-out repository; caller-supplied paths
   and caller-supplied expected-family values are rejected. Only result and
   evidence output directories, simulator identity, and the two repository
   roots are runtime inputs. Test first with `python3 -m py_compile`, shell
   syntax checking, scheme/XML negative fixtures, and negative fixtures for
   each rejection; no production code is changed by these verifier tests.
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
   run the exact class selector with a result bundle, verify its compact summary
   and every test node are `Passed` with zero failures/skips using the checked-in
   `$THR139_UW_ALLOWLIST`, and run the explicit `Debug-Dev` simulator build.
   Check: the test and build both resolve to `PLATFORM_NAME=iphonesimulator`,
   `CONFIGURATION=Debug-Dev`, and no `-only-testing:ThorChain` selector is used.
6. **THR-139 live runner (ThorChainQAEngineer).** Use the exact local
   `$UW_ROOT/Scripts/verify-thr-139-live.sh` runner added alongside the UW
   focused tests, then independently run
   `$UW_ROOT/Scripts/verify-thr-139-evidence.py` against the evidence root. Its
   required mapping is the fixed repository-owned
   `Scripts/allowlists/THR-139-family-manifest.json`,
   `THR139_SIMULATOR_UDID`, and `THR139_EVIDENCE_ROOT`; the launched kit must
   emit its actual selected family through `accountState?.providerFamilyId`,
   and the runner must reject missing or unapproved observations. It
   launches the Development app, injects only public values into simulator
   launchd, and unsets them in a trap. It runs three isolated passes with all
   three families present, uses unique evidence directories, compares
   before/after canonical manifests, and writes only the following canonical
   JSON fields: `schemaVersion`, `observedFamily`, `manifestSha256`, `rest`,
   `rpc`, `chainId`, `height`, and `resultSha256`.
   `manifestSha256` and `resultSha256` are lowercase SHA-256 digests of
   canonical JSON (sorted keys, UTF-8, no trailing newline). The independent
   verifier checks schema version, family equality, six-record equality, digest
   recomputation, `thorchain-1`, and accepted height/identity invariants. Any
   missing field, drift, mismatch, or unapproved record exits non-zero before
   reporting success.
7. **Handoff (CodeReviewer → QA → CTO).** Each reviewer cites the exact pushed
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
scheme="$UW_ROOT/Unstoppable/Unstoppable.xcodeproj/xcshareddata/xcschemes/Development.xcscheme"
set -euo pipefail
python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" "$scheme"
xcodebuild -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -showdestinations
xcodebuild test -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -resultBundlePath "$THR139_UW_RESULT_BUNDLE" \
  -only-testing:AppTests/ThorChainKitManagerTests
xcrun xcresulttool get test-results summary --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | jq -e '(.result == "Passed") and (.failedTests == 0) and (.skippedTests == 0)'
xcrun xcresulttool get test-results tests --path "$THR139_UW_RESULT_BUNDLE" \
  --compact | python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py" "$THR139_UW_ALLOWLIST"

xcodebuild build -project "$UW_ROOT/Unstoppable/Unstoppable.xcodeproj" \
  -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$THR139_SIMULATOR_UDID" \
  -derivedDataPath "$THR139_UW_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO

for family in pass-1 pass-2 pass-3; do
  THR139_SIMULATOR_UDID="$THR139_SIMULATOR_UDID" \
    THR139_EVIDENCE_ROOT="$THR139_EVIDENCE_ROOT/$family" \
    "$UW_ROOT/Scripts/verify-thr-139-live.sh"
done
python3 "$UW_ROOT/Scripts/verify-thr-139-evidence.py" "$THR139_EVIDENCE_ROOT"
```

The XML-safe Python preflight above is run before the `xcodebuild test` block;
the command block is shown compactly here only after its preflight has passed.

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
Revision 5 resolves the closure-2/5 corrections by separating deterministic
full-manifest AppTests from live actual-owner evidence at
`accountState?.providerFamilyId`, binding verifier inputs to repository-owned
paths, making the XML preflight shell-fail-closed before every Xcode command,
and defining complete manifest/result schemas with valid digest vectors. A fresh bounded
adversarial review at closure 2/5
must recheck those allowlisted IDs and direct regressions; it must not reopen
broad discovery. Explicit operator approval of this exact pushed spec and plan
is required before implementation.
