# THR-139 — resilient native RUNE provider pool plan

Plan source of truth: [THR-139 spec](../../specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md), design revision 9. Discovery 2/2; closure 5/5 pending targeted review.

No implementation, UW commit, push, PR, CI, Maestro, or remote smoke is
authorized until the exact spec and this plan are explicitly approved.

## Fixed substrate

- Exact local UW v0.50 Development checkout: `$UW_ROOT`
- ThorChainKit checkout: `$THORCHAINKIT_ROOT`
- UW project/scheme/configuration: `Unstoppable/Unstoppable.xcodeproj`,
  `Development`, `Debug-Dev`
- Simulator: `platform=iOS Simulator,id=$THR139_SIMULATOR_UDID`, iOS 26.2
- Evidence: `$THR139_EVIDENCE_ROOT`, unique directory per family pass

## Steps

### 1. Fresh bounded design review

**Owner:** ThorChainCodeReviewer. **Dependencies:** pushed revision-9 spec,
plan, and Gimle report. Recheck only the frozen D-001 through D-010 allowlist,
discovery 2/2, closure 5/5. Verify that no UW acceptance transport, launch-
argument branch, adapter sink, or production observation callback is introduced;
verify deterministic full-manifest fixtures, reuse of the existing S1-04 family
live-smoke runner, XML-safe preflight ordering, fresh result-bundle binding,
repository-derived verifier paths, role-bound six-record equality,
cross-family pairing, exact repository-schema evidence verification, simulator selectors, and
docs-only delivery.

### 2. Existing verification gates and UW verifier artifacts

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 1 review disposition.
Reuse `Scripts/verify-s1-02.sh`, `Scripts/verify-s1-04.sh`,
`Scripts/verify-xcresult.sh`, and `Scripts/verify-s1-04-live.sh` from the
ThorChainKit checkout. Do not create THR-139 ThorChainKit allowlists or
wrappers, and never pass a caller-supplied allowlist path. The existing
scripts use `set -euo pipefail`, derive checked-in fixtures from their own
repository root, create fresh result bundles, and reject stale bundles.
Verify the exact expected HEAD, clean worktree, `origin/main` equality, and
base ancestry before any script can emit `PASS`. Then run `bash -n` on the
three existing wrappers and the existing `Scripts/verify-s1-04.sh
--source-only` and `--fixtures-only` modes. These commands run before
`verify-s1-02.sh` and before any Xcode command; no unsupported script mode is
invented.

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
  Scripts/verify-s1-04.sh --fixtures-only)
```

Before any UW Xcode command, the ThorChainSwiftEngineer authors and owns these
repository-derived verifier files in the exact UW checkout:

```text
$UW_ROOT/Scripts/verify-thr-139-scheme.py
$UW_ROOT/Scripts/verify-thr-139-uw-tests.py
```

The first must reject malformed XML, missing/extra testables, and suppressed
`AppTests`; the second must reject a missing result bundle and every failed or
skipped test node. Both expose runnable `--self-test` modes that create bounded
temporary mutants and return nonzero if any mutant passes. Run
`python3 -m py_compile` and both self-tests before the first `xcodebuild`
command. QA invokes these exact checked-in paths; no inline replacement
verifier or caller-supplied allowlist is permitted.

```text
set -euo pipefail
python3 -m py_compile \
  "$UW_ROOT/Scripts/verify-thr-139-scheme.py" \
  "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py"
python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" --self-test
python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py" --self-test
```

### 3. Test-first UW contract

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2 gate checks and their
static/negative checks. **Paths:** existing native RUNE provider, existing
manager/descriptor validation seam if required by the failing exact equality
tests, and `AppTests/ThorChainKitManagerTests`.

In the same shell, run the repository-owned scheme preflight before the first
Xcode command, including this pre-edit test. Then add tests before production
edits for family count/order, all six exact records, five-host derivation,
exact equality, duplicate/foreign/HTTP/credential/query/fragment rejection,
every REST/RPC pair swap, Liquify absence, and unchanged multichain ownership.
Run `xcodebuild test ... -only-testing:AppTests/ThorChainKitManagerTests` and
capture a genuine pre-edit failure.

The same test target owns deterministic family-selection coverage: retain the
full three-family manifest, script valid Comet heights so Rorcual, IBS, and
Keplr are each highest in a separate fixture, complete one operation per
fixture, and assert `TestingAccountReadSession.read().providerFamilyId` equals
the actually selected family. The fixture target controls only scripted
responses; it is never copied into the live observation.

### 4. Minimal native configuration edit

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 3 failure evidence.

Use the existing provider/manager seam only. Do not introduce a provider
abstraction, change ThorChainKit, or edit the multichain swap provider. The
exact six role-bound records must be compared for equality; no membership-only
allowlist or silent deduplication is acceptable.

### 5. ThorChainKit simulator invariants

**Owner:** ThorChainQAEngineer. **Dependency:** exact implementation head.

Run the existing `Scripts/verify-s1-02.sh` gate, then
`Scripts/verify-s1-04.sh --expected-base <40-char SHA> --expected-head
<40-char SHA>` with `THORCHAIN_SIMULATOR_UDID` set to the approved simulator.
The S1-04 gate internally derives its complete checked-in test manifest and
result-bundle verifier; it includes these required selectors:

```text
ThorChainKitTests/EndpointPoolTests
ThorChainKitTests/ReadOperationCoordinatorS1_04Tests
ThorChainKitTests/LiveNodeProbeTests
ThorChainKitTests/LiveThorNodeClientS1_04Tests
```

Do not pass an allowlist path. The complete-operation retry test is the existing
`testRetryRepeatsTheCompleteOperationOnTheNextFamily` case with an injected
HTTP 503 from the first family; it preserves height/identity rejection.
`swift test` is explicitly not a verification command for this iOS-only
substrate. Require the verifier to report zero skipped nodes.

### 6. UW simulator tests and build

**Owner:** ThorChainQAEngineer. **Dependency:** Steps 2 and 4.

Run `set -euo pipefail` and the repository-owned XML verifier before any Xcode
command. It must parse the exact `Development.xcscheme` as XML and fail closed unless
`TestAction/Testables` contains exactly one unsuppressed
`BuildableReference[BlueprintName="AppTests"]`. This preflight must run before
`xcodebuild -showdestinations`, `xcodebuild test`, or `xcodebuild build`;
`-showdestinations` only verifies simulator availability. Then run
`-only-testing:AppTests/ThorChainKitManagerTests` with a newly-created result
bundle, verify the compact summary and exact test nodes against the verifier's
repository-derived allowlist, and
run a `Debug-Dev` simulator build. Reject `-only-testing:ThorChain`, device
artifacts, missing result bundles, failed/skipped nodes, or non-simulator build
settings.

### 7. Three-family online smoke

**Owner:** ThorChainQAEngineer. **Dependency:** Steps 4–6.

Run the existing `$THORCHAINKIT_ROOT/Scripts/verify-s1-04-live.sh` runner in
three explicit invocations, one each for `rorcual-mainnet`, `ibs-mainnet`, and
`keplr-mainnet`. Each invocation must set the exact fixed family ID, its fixed
REST and RPC URL pair from the spec, the same reviewed expected HEAD, audited
public existing/absent addresses, simulator UUID, and a unique evidence root.
Independently verify each fresh result with the existing S1-04 evidence
verifier. Its actual schema is `schemaVersion`, `head`, `familyId`, `chainId`,
timestamp, the three heights, and the exact existing/absent account records.
The fixed REST/RPC pair is bound by each command invocation; stored evidence
does not attest the literal URL pair. Deterministic AppTests
prove provider-pool selection with the complete three-family manifest. No Unstoppable acceptance transport,
launch argument, adapter sink, or new live runner is added. The injected HTTP
503 test is the failover proof; online passes are network identity/pair
evidence, not a caller-selected owner oracle.

### 8. Review and merge gate

**Owners:** CodeReviewer, QA, then ThorChainCTO. CR approval and QA PASS must
cite the exact PR head. CTO verifies required checks and conflict-free head,
then waits for explicit operator authorization before merge.
