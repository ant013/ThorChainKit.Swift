# THR-139 — resilient native RUNE provider pool

**Design revision:** 11 — discovery 2/2, closure 5/5 pending targeted review.
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
- The operator-approved exact UW v0.50 Development checkout resolves to
  `$UW_ROOT`, expected HEAD `8a63bfda028dd8543115b26dd777235a53304311`, and
  branch `local/THR-104-thorchain-lifecycle-v0.50`. Its intentionally dirty
  S1-07 state is evidence-only during design; it will not be edited until this
  revision is approved. UW edits and evidence remain local to that checkout:
  this ThorChainKit branch does not commit, push, PR, or merge UW files.
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
  behavior, plus the one approved source-gate repair and focused absence-envelope
  regression test described below.
- Deterministic full-manifest family-selection fixtures in AppTests. They vary
  only scripted Comet heights so Rorcual, IBS, and Keplr are each selected in a
  separate fixture pass.
- Operator-local UW verification artifacts: `$UW_ROOT/Scripts/verify-thr-139-scheme.py`
  and `$UW_ROOT/Scripts/verify-thr-139-uw-tests.py`, plus the established
  ThorChainKit utility `$THORCHAINKIT_ROOT/Scripts/capture-s1-07-inputs.py`.
  Invoke that utility twice with `--root "$UW_ROOT"` and
  `--root-label before|after`. The implementation
  owner authors and negatively verifies the two verifier scripts in the exact
  UW checkout before the first Xcode command. Before and after local work, the
  capture contract records UW `HEAD`, `statusSha256`, and per-file SHA-256
  records; each manifest must bind `head` to
  `8a63bfda028dd8543115b26dd777235a53304311`, and the two snapshots must bind
  all evidence to the same UW `HEAD`.
  If the established capture script is absent, the local preflight fails closed;
  do not substitute an ad hoc manifest. None of these local artifacts is copied
  into or committed by this repository.
- Online native-RUNE smoke using the existing S1-04 family live-smoke runner,
  once for each of Rorcual, IBS, and Keplr. This reuses the approved public
  endpoint, REST/RPC identity, height, and repository-defined evidence boundary; it adds
  no Unstoppable acceptance transport, test launch-argument branch, adapter
  sink, or production observation callback.

Out of scope:

- A new provider abstraction, ThorChainKit implementation/lifecycle/API changes
  other than the single behavior-equivalent parser repair below, request-level
  retry, or identity/height-policy changes.
- The existing multichain swap provider, including its Liquify configuration.
- Liquify as a native RUNE family; it is a rejected one-provider counterexample.
- THR-135, Sprint 2, Maestro, GitHub Actions, remote simulators, or remote
  live-smoke execution.
- Any implementation edit, commit, push, PR, or merge before explicit approval
  of this revision. After approval, UW remains subject to an operator-controlled
  local final-commit gate; no UW PR or merge is part of this slice.

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

## Approved ThorChainKit gate repair

The reviewed ThorChainKit base has one source-contract failure that prevents
both `Scripts/verify-s1-04.sh --source-only` and `--fixtures-only`:
`Sources/ThorChainKit/Network/LiveThorNodeClient.swift:358` contains
`try? JSONSerialization`. The only permitted ThorChainKit correction in this
slice is a behavior-equivalent `do/catch` at that expression, preserving
successful `String` decoding and returning `nil` for JSON or cast failure. It
must not change endpoint, selection, health, retry, height, identity, or
acceptance semantics. Extend or verify the focused
`testAccountAcceptsOnlyExactObservedAbsenceEnvelope` coverage so malformed
message tokens remain rejected while the two approved absence messages still
return `nil`.

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
| Online network smoke | Existing S1-04 family live-smoke runner and public node probes | Run the approved runner once per production family with the fixed REST/RPC pair in the invocation; do not add a UW acceptance transport, launch-argument branch, adapter sink, or production selector | Per-family fresh evidence, family/chain/height/account invariants, and fail-closed drift; the full manifest is checked by deterministic AppTests |

### Selection and live-smoke contract

The deterministic AppTests and the online runner have different proof duties.
AppTests use the existing ThorChainKit testing transport to retain the complete
three-family manifest and script valid Comet heights so one family is highest in
each fixture. They assert the completed read projection's
`TestingAccountReadSession.read().providerFamilyId` equals the family selected
by the scripted heights. The fixture target is never copied into the
observation; it only controls responses.

The online smoke intentionally does not claim ownership of a family from an
Unstoppable app event. The approved S1-04 runner receives one audited public
family input and its fixed REST/RPC pair per isolated pass. The stored result
verifies the family, chain identity, accepted height, and repository-defined
evidence JSON; it does not attest the literal URL pair supplied by the command.
The
deterministic AppTests are the provider-pool ownership proof: every fixture
constructs the complete three-family manifest, varies only scripted valid
Comet heights, and asserts the completed projection's
`providerFamilyId` equals the family selected by the operation. No callback,
file sink, acceptance transport, launch-argument branch, or production
selector is added to Unstoppable or ThorChainKit.

## Acceptance criteria

1. THR-138 is done and this issue is the sole activated correction slice.
2. This spec, plan, and Gimle report are committed and pushed as one docs-only
   ThorChainKit revision before implementation approval. UW local files,
   manifests, and snapshots are not committed or pushed here.
3. The exact UW provider returns exactly the three ordered families and the
   six role-bound endpoint records above. Liquify is absent from native RUNE;
   the existing multichain swap provider is unchanged.
4. Exact equality rejects duplicate IDs, missing or extra records, foreign
   hosts, HTTP/credential/query/fragment URLs, and every REST/RPC family swap.
5. Focused tests prove complete-operation failover and preserve height and
   identity rejection; no request-level retry or check weakening is added.
6. On the MacBook, the exact ThorChainKit simulator tests (including the
   behavior-equivalent parser repair), UW `AppTests`, and Development simulator
   build pass at the reviewed implementation head. Both no-Xcode S1-04 modes
   pass before Xcode.
7. The deterministic AppTests perform three isolated fixture passes. Each pass
   constructs all three families from the checked-in table, scripts one family
   to have the greatest valid Comet height, and verifies the completed
   projection's `providerFamilyId` equals the actually selected family. The
   existing S1-04 family live-smoke runner performs three isolated real-node
   passes, one for each approved family. Each invocation supplies its fixed
   REST/RPC pair; the stored result verifies `thorchain-1`, accepted
   height/identity invariants, and fresh repository-schema evidence, but does
   not attest the literal URL pair. The full manifest is stable and verified in the
   deterministic AppTests; the online JSON does not duplicate it or the URL
   records. It does not claim that online
   passes forced provider selection. No Unstoppable acceptance transport,
   launch-argument branch, adapter sink, or production selector is added. The
   existing injected HTTP 503 coordinator case proves complete-operation retry.
8. CodeReviewer approval, QA pass, CTO exact-head evidence, and explicit
   operator authorization remain required. The UW final commit is an
   operator-controlled local gate; no UW PR or merge is implied. THR-135 and
   Sprint 2 remain blocked until then.

## Test-first implementation and verification plan

1. **Existing verification gates (ThorChainSwiftEngineer).** Reuse the
   existing repository-owned `Scripts/verify-s1-02.sh`, `Scripts/verify-s1-04.sh`,
   `Scripts/verify-xcresult.sh`, and `Scripts/verify-s1-04-live.sh` contracts.
   Do not add THR-139 ThorChainKit allowlists, result-bundle wrappers, or
   allowlist arguments. Those scripts use `set -euo pipefail`, derive their
   checked-in fixtures from the repository root, create fresh result bundles,
   and reject stale bundles internally. Run their existing shell syntax and
   negative-fixture checks; no caller-supplied allowlist path is permitted.
   Before `verify-s1-02.sh` can run or emit any `PASS`, perform the exact
   expected-HEAD, clean-worktree, `origin/main` equality, and base-ancestry
   preflight shown below. Then run `bash -n` plus the existing
   `verify-s1-04.sh --source-only` and `--fixtures-only` modes; these are the
   checked-in no-Xcode static/negative gates at the reviewed ThorChainKit HEAD.
   Before the UW-specific commands below, author and own the exact operator-local
   `$UW_ROOT/Scripts/verify-thr-139-scheme.py` and
   `$UW_ROOT/Scripts/verify-thr-139-uw-tests.py` files. Their
   negative fixtures must reject a malformed scheme, an extra/suppressed
   testable, a missing result bundle, and any failed or skipped test node.
   Each script exposes a `--self-test` mode that creates bounded temporary
   mutants, asserts every rejection, and exits nonzero if a mutant passes.
   Run `python3 -m py_compile` and both self-tests before the first Xcode
   command; no prose-only negative claim is accepted. Capture the UW manifest
   before and after local edits with
   `$THORCHAINKIT_ROOT/Scripts/capture-s1-07-inputs.py --root "$UW_ROOT"`
   and labels `before` and `after`; require each manifest `head` to equal
   `8a63bfda028dd8543115b26dd777235a53304311`, equal before/after `HEAD`
   values, and recorded `statusSha256` and per-file SHA-256 maps.
2. **Pre-edit contract tests (ThorChainSwiftEngineer).** In the exact UW
   checkout, run the operator-local scheme preflight before this first Xcode
   command, then replace the old one-Liquify expectation with exact order, URL,
   role-bound record, ownership, duplicate, superset, foreign, and pair-swap
   tests. Run them before editing production; the old provider must fail the
   new contract. Check: `xcodebuild ... -only-testing:AppTests/ThorChainKitManagerTests test`
   returns a real failing XCTest result, not a selector/compilation error.
3. **Small production edit (ThorChainSwiftEngineer).** Edit only the existing
   native RUNE provider and, if required by the failing exact-equality tests,
   its existing manager/descriptor validation seam. Separately apply only the
   approved `LiveThorNodeClient.swift:358` do/catch repair and focused
   absence-envelope test in ThorChainKit. Do not add an abstraction or touch the
   multichain provider. Check: focused tests pass; the UW manifest binds before
   and after evidence to one unchanged UW `HEAD`; and each repository's diff is
   limited to its approved paths.
4. **ThorChainKit invariants (ThorChainQAEngineer).** From
   `$THORCHAINKIT_ROOT`, run the existing `Scripts/verify-s1-02.sh` and
   `Scripts/verify-s1-04.sh --expected-base ... --expected-head ...` gates with
   the reviewed simulator UUID. First verify that the approved parser repair
   makes both `--source-only` and `--fixtures-only` pass. Their repository-derived fixtures and
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
   using the operator-local verifier's internally-derived allowlist, and run the
   explicit `Debug-Dev` simulator build.
   Check: the test and build both resolve to `PLATFORM_NAME=iphonesimulator`,
   `CONFIGURATION=Debug-Dev`, and no `-only-testing:ThorChain` selector is used.
6. **Three-family online smoke (ThorChainQAEngineer).** Use the existing
   `$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh` runner once per approved
   family with unique evidence roots and the already audited public inputs.
   Verify each fresh result with the existing S1-04 evidence verifier and its
   actual schema: `schemaVersion`, `head`, `familyId`, `chainId`, timestamp,
   `cosmosHeight`, `cometHeight`, `acceptedHeight`, and the exact existing and
   absent account records. Each command supplies its fixed REST/RPC pair; the
   stored result does not attest that literal pair. This is network
   identity/height/account evidence, not an Unstoppable owner-selection oracle;
   no UW acceptance transport, launch argument, adapter sink, or new live
   runner is added.
7. **Handoff (CodeReviewer → QA → CTO).** Reviewers cite the exact ThorChainKit
   implementation head and concrete output. QA also cites the before/after UW
   manifest pair, equal UW `HEAD`, both `statusSha256` values, and per-file
   SHA-256 records. CTO verifies the docs branch exact head, CR approval, QA
   pass, and explicit operator authorization. The UW final commit remains an
   operator-controlled local action; no UW PR or merge is required.

## Exact command shapes

The ThorChainKit test command is a simulator Xcode command, not `swift test`:

```text
set -euo pipefail
: "${THR139_EXPECTED_BASE:?set to the reviewed 40-character origin/main SHA}"
: "${THR139_EXPECTED_HEAD:?set once to the reviewed 40-character ThorChainKit HEAD}"
(cd "$THORCHAINKIT_ROOT" && \
  test "$(git rev-parse HEAD)" = "$THR139_EXPECTED_HEAD" && \
  test -z "$(git status --porcelain)" && \
  test "$(git rev-parse refs/remotes/origin/main)" = "$THR139_EXPECTED_BASE" && \
  git merge-base --is-ancestor "$THR139_EXPECTED_BASE" "$THR139_EXPECTED_HEAD" && \
  bash -n Scripts/verify-s1-02.sh Scripts/verify-s1-04.sh Scripts/verify-s1-04-live.sh && \
  Scripts/verify-s1-04.sh --source-only && \
  Scripts/verify-s1-04.sh --fixtures-only && \
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
python3 -m py_compile \
  "$UW_ROOT/Scripts/verify-thr-139-scheme.py" \
  "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py"
python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" --self-test
python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py" --self-test
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

: "${THR139_EXPECTED_HEAD:?set to the reviewed 40-character ThorChainKit HEAD}"
: "${THR139_EVIDENCE_ROOT:?set to a non-empty evidence root}"
test -n "$THR139_EVIDENCE_ROOT"
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

### Existing S1-04 evidence contract

The existing S1-04 runner and verifier are the evidence producer and consumer.
Their committed result schema is exactly `schemaVersion`, `head`, `familyId`,
`chainId`, `timestamp`, `cosmosHeight`, `cometHeight`, `acceptedHeight`,
`existing`, and `absent`. The verifier requires `schemaVersion == 1`, the
reviewed HEAD and fixed family ID, `chainId == "thorchain-1"`, positive integer
heights, `acceptedHeight == cosmosHeight`, a Comet/Cosmos difference of at most
five, an existing account with matching raw/implementation RUNE amounts, and
an absent account with no balances. It rejects credential-bearing or URL-like
strings in the serialized evidence and binds the fresh result bundle to the
repository-derived S1-04 allowlist.

This contract intentionally does not claim manifest or result digest fields,
or REST/RPC URL records because the existing runner does not emit them. The
three command invocations above are the source of the fixed URL-pair binding;
the live result provides network identity/height/account evidence from the
supplied pair; it does not attest the literal URL pair or map it to a family.
Full-manifest stability is proven by the deterministic AppTests,
which construct and exercise all three families. Adding a second live producer
or verifier is outside this correction slice.

No raw endpoint responses, credentials, cookies, mnemonics, absolute operator
paths, or private values may enter committed evidence.

## Gimle and review gate

The Gimle report is RED because the EvmKit snippet freshness is contradictory
and semantic searches have coverage gaps. Exact local Serena, targeted `rg`,
and Git verification are the accepted fallback; the defects remain recorded.
Revision 10 resolves the reviewer correction set by reusing the existing
S1-02 and S1-04 repository gates, removing THR-139-specific ThorChainKit
allowlists/wrappers, and spelling three executable fixed family-to-REST/RPC
live invocations with every required public runner input. The exact HEAD,
clean-worktree, origin/main, and ancestry preflight now precedes every
ThorChainKit PASS-capable command; checked-in shell/static gates and the two
UW verifier self-tests precede Xcode. The unapproved
Unstoppable live evidence sink/adapter branch remains removed. Discovery
remains frozen at 2/2; closure remains bounded to the frozen IDs and direct
regressions, authoring the two operator-local UW verifier artifacts, binding
before/after capture manifests to one UW `HEAD`, repairing the single
ThorChainKit source-gate expression, and asserting a non-empty evidence root
before child paths are built. Explicit operator approval of this exact pushed
spec and plan is
required before implementation.
