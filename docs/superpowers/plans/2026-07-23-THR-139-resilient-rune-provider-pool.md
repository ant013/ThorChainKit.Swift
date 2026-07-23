# THR-139 — resilient native RUNE provider pool plan

Plan source of truth: [THR-139 spec](../../specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md), design revision 17. Discovery 2/2; closure 5/5 remains frozen; targeted correction review is pending. This is the bounded verifier-contract successor to revision 16.

No implementation, UW commit, push, PR, CI, Maestro, or remote smoke is
authorized until the exact spec and this plan are explicitly approved. This
branch may push only the ThorChainKit docs revision; UW files and evidence stay
local and finish under an operator-controlled commit gate.

## Fixed substrate

- Exact local UW v0.50 Development checkout: `$UW_ROOT`, expected HEAD
  `8a63bfda028dd8543115b26dd777235a53304311`, branch
  `local/THR-104-thorchain-lifecycle-v0.50`
- ThorChainKit checkout: `$THORCHAINKIT_ROOT`
- UW project/scheme/configuration: `Unstoppable/Unstoppable.xcodeproj`,
  `Development`, `Debug-Dev`
- Simulator: `platform=iOS Simulator,id=$THR139_SIMULATOR_UDID`, iOS 26.2
- Evidence: `$THR139_EVIDENCE_ROOT`, unique directory per family pass

## Steps

### 1. Fresh bounded design review

**Owner:** ThorChainCodeReviewer. **Dependencies:** pushed revision-16 spec,
plan, and Gimle report. Recheck only the frozen D-001 through D-022 allowlist,
discovery 2/2, closure 5/5. Verify that no UW acceptance transport, launch-
argument branch, adapter sink, or production observation callback is introduced;
verify deterministic full-manifest fixtures, reuse of the existing S1-04 family
live-smoke runner, XML-safe preflight ordering, fresh result-bundle binding,
operator-local verifier paths and before/after manifest binding, role-bound six-record equality,
cross-family pairing, exact repository-schema evidence verification, simulator selectors, and
docs-only delivery.

### 2. Baseline gates, verifier-contract repairs, artifacts, and initial capture

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 1 review disposition.
Reuse `Scripts/verify-s1-02.sh`, `Scripts/verify-s1-04.sh`,
`Scripts/verify-xcresult.sh`, and `Scripts/verify-s1-04-live.sh` from the
ThorChainKit checkout. Do not create THR-139 ThorChainKit allowlists or
wrappers, and never pass a caller-supplied allowlist path. The existing
scripts use `set -euo pipefail`, derive checked-in fixtures from their own
repository root, create fresh result bundles, and reject stale bundles.
Before approval, verify only the exact expected HEAD, the preserved-worktree
guard below, `origin/main` equality, base ancestry, and `bash -n`. The assigned
worktree intentionally preserves exactly two untracked reports; do not delete,
move, modify, stage, or commit them. Their raw file SHA-256 values below are
independent of the Gimle `repository.base_worktree_manifest` composite hashes.
Reject all tracked dirt and any unexpected untracked path. Then reproduce both
known no-Xcode failures with the existing `--source-only` and `--fixtures-only` modes;
both must exit 1 and emit the generic verifier failure. Bind the reproduced
cause separately to the exact source line. Do not claim PASS on the unmodified
base.

```text
set -euo pipefail
: "${THR139_EXPECTED_BASE:?set to the reviewed 40-character origin/main SHA}"
: "${THR139_EXPECTED_HEAD:?set once to the reviewed 40-character ThorChainKit HEAD}"
(cd "$THORCHAINKIT_ROOT" && \
  test "$(git rev-parse HEAD)" = "$THR139_EXPECTED_HEAD" && \
  expected_report_1='docs/reports/gimle/THR-118-s1-07-closure-2-verification-20260722.md' && \
  expected_report_2='docs/reports/gimle/THR-138-implementation-verification-20260723.md' && \
  test -z "$(git status --porcelain=v1 --untracked-files=all | awk 'substr($0,1,2) != "??"')" && \
  test "$(git ls-files --others --exclude-standard | LC_ALL=C sort)" = \
    "$(printf '%s\n' "$expected_report_1" "$expected_report_2" | LC_ALL=C sort)" && \
  test "$(shasum -a 256 "$expected_report_1" | awk '{print $1}')" = \
    094d56fb8ac1f6a4b604b3df6e8ab7a47ee457edcca26b6d9f5912277ad02307 && \
  test "$(shasum -a 256 "$expected_report_2" | awk '{print $1}')" = \
    6e4735f7666b89f7af5b1a8b3f9888e18909faa0adb128d5fe6ec6497cb3d9fe && \
  test "$(git rev-parse refs/remotes/origin/main)" = "$THR139_EXPECTED_BASE" && \
  git merge-base --is-ancestor "$THR139_EXPECTED_BASE" "$THR139_EXPECTED_HEAD" && \
  bash -n Scripts/verify-s1-02.sh Scripts/verify-s1-04.sh Scripts/verify-s1-04-live.sh)
(
  cd "$THORCHAINKIT_ROOT"
  set +e
  Scripts/verify-s1-04.sh --source-only > "$THR139_SOURCE_LOG" 2>&1
  source_status=$?
  Scripts/verify-s1-04.sh --fixtures-only > "$THR139_FIXTURE_LOG" 2>&1
  fixture_status=$?
  set -e
  test "$source_status" -eq 1
  test "$fixture_status" -eq 1
  rg -Fq 'FAIL verify-s1-04: source, SPI, Example, or fixture contract differs' "$THR139_SOURCE_LOG"
  rg -Fq 'FAIL verify-s1-04: source, SPI, Example, or fixture contract differs' "$THR139_FIXTURE_LOG"
)
rg -Fq 'return try? JSONSerialization.jsonObject(with: token, options: [.fragmentsAllowed]) as? String' \
  "$THORCHAINKIT_ROOT/Sources/ThorChainKit/Network/LiveThorNodeClient.swift"
```

After explicit approval and the baseline failure captures, repair only the
three existing ThorChainKit verifier contracts before the parser repair:

- add the 21 already-tracked S1-04/S1-05 production paths named in the spec to
  the exact `Scripts/verify-s1-02.sh` source manifest;
- include the existing `Tests/ThorChainKitTests/Fixtures/S1-05-tests.txt` in
  `Scripts/verify-s1-04.sh`'s derived full-target allowlist; and
- make `Scripts/verify-xcresult.sh` derive one prefix from the allowlist,
  accept only `ThorChainKitTests` or `ThorChainKitLiveTests`, and reject empty,
  mixed, or unknown prefixes before observed-name comparison.

Verify the source manifest against the current tracked source list, verify the
derived full allowlist includes the existing S1-05 manifest, and run synthetic
unit/live prefix fixtures proving mixed and unknown prefixes fail closed. These
are the only repository verifier edits; no THR-139-specific wrapper, caller
allowlist, or product-source change is permitted.

Before any UW Xcode command, the ThorChainSwiftEngineer authors and owns these
operator-local verifier files in the exact UW checkout:

```text
$UW_ROOT/Scripts/verify-thr-139-scheme.py
$UW_ROOT/Scripts/verify-thr-139-uw-tests.py
```

The first must reject malformed XML, missing/extra testables, and suppressed
`AppTests`; the second must reject a missing result bundle and every failed or
skipped test node. Both expose runnable `--self-test` modes that create bounded
temporary mutants and return nonzero if any mutant passes. Author both files,
then run `python3 -m py_compile` and both self-tests before the initial `before`
capture. QA invokes these exact local paths; no inline replacement verifier or
caller-supplied allowlist is permitted. Invoke the established ThorChainKit
utility for the initial `before` capture immediately after these self-tests:

```text
python3 "$THORCHAINKIT_ROOT/Scripts/capture-s1-07-inputs.py" \
  --root "$UW_ROOT" --root-label before > "$THR139_UW_BEFORE_MANIFEST"
```

Each manifest must record schema 1, UW `HEAD`, a lowercase 64-character
`statusSha256`, and valid per-file SHA-256 records; each `head` must equal
`8a63bfda028dd8543115b26dd777235a53304311`, and the before/after manifests
must have equal `HEAD` values. Do not copy these artifacts into this repository
or commit/push them from this branch. If the ThorChainKit capture utility is
absent, stop before implementation; do not replace it with an ad hoc manifest
command.

```text
set -euo pipefail
python3 -m py_compile \
  "$UW_ROOT/Scripts/verify-thr-139-scheme.py" \
  "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py"
python3 "$UW_ROOT/Scripts/verify-thr-139-scheme.py" --self-test
python3 "$UW_ROOT/Scripts/verify-thr-139-uw-tests.py" --self-test
```

### 3. Approved parser repair and no-Xcode gate closure

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2 failure evidence,
initial capture, and explicit spec approval.

Apply only the behavior-equivalent `LiveThorNodeClient.swift:358` do/catch
repair and its focused absence-envelope test. Rerun the exact
`Scripts/verify-s1-04.sh --source-only` and `--fixtures-only` commands; both
must PASS. No Xcode command is permitted before both post-repair no-Xcode modes
pass.

### 4. Test-first UW contract and minimal native configuration edit

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 3 PASS results.

Now that the parser repair and both no-Xcode gates pass, run the operator-local
scheme preflight and add tests before the native provider edit for family
count/order, all six exact records, five-host derivation, exact equality,
duplicate/foreign/HTTP/credential/query/fragment rejection, every REST/RPC pair
swap, Liquify absence, and unchanged multichain ownership. Run
`xcodebuild test ... -only-testing:AppTests/ThorChainKitManagerTests` and
capture a genuine pre-edit failure.

The same test target owns deterministic family-selection coverage: retain the
full three-family manifest, script valid Comet heights so Rorcual, IBS, and
Keplr are each highest in a separate fixture, complete one operation per
fixture, and assert `TestingAccountReadSession.read().providerFamilyId` equals
the actually selected family. The fixture target controls only scripted
responses; it is never copied into the live observation.

After the failing tests are recorded, edit only the existing native RUNE
provider and its existing manager/descriptor validation seam if required. Do
not introduce an abstraction or edit the multichain swap provider. The exact
six role-bound records must be compared for equality; no membership-only
allowlist or silent deduplication is acceptable.

Only after all approved local edits, capture `after` and run this exact
fail-closed validator against the canonical capture manifests:

```text
set -euo pipefail
python3 "$THORCHAINKIT_ROOT/Scripts/capture-s1-07-inputs.py" \
  --root "$UW_ROOT" --root-label after > "$THR139_UW_AFTER_MANIFEST"
expected_head=8a63bfda028dd8543115b26dd777235a53304311
scheme_path=Scripts/verify-thr-139-scheme.py
tests_path=Scripts/verify-thr-139-uw-tests.py
validate_manifest() {
  manifest="$1"
  expected_root_label="$2"
  jq -e --arg expected_head "$expected_head" \
    --arg expected_root_label "$expected_root_label" \
    --arg scheme_path "$scheme_path" --arg tests_path "$tests_path" '
    .schemaVersion == 1
    and (.rootLabel == $expected_root_label)
    and (.head == $expected_head)
    and ((.statusSha256 | type) == "string")
    and (.statusSha256 | test("^[0-9a-f]{64}$"))
    and ((.files | type) == "array" and (.files | length) > 0)
    and (([.files[].path] | length) == ([.files[].path] | unique | length))
    and all(.files[];
      ((.path | type) == "string")
      and (.state == "present" or .state == "deleted")
      and ((.size | type) == "number" and (.size | floor) == .size and .size >= 0)
      and ((.sha256 | type) == "string")
      and (.sha256 | test("^[0-9a-f]{64}$")))
    and ([.files[] | select(.path == $scheme_path and .state == "present" and (.sha256 | test("^[0-9a-f]{64}$")))] | length == 1)
    and ([.files[] | select(.path == $tests_path and .state == "present" and (.sha256 | test("^[0-9a-f]{64}$")))] | length == 1)
  ' "$manifest"
}
validate_manifest "$THR139_UW_BEFORE_MANIFEST" before
validate_manifest "$THR139_UW_AFTER_MANIFEST" after
test "$(jq -er '.head' "$THR139_UW_BEFORE_MANIFEST")" = \
  "$(jq -er '.head' "$THR139_UW_AFTER_MANIFEST")"
```

### 5. ThorChainKit simulator invariants

**Owner:** ThorChainQAEngineer. **Dependency:** exact implementation head.

First verify that the three verifier-contract repairs and approved
`LiveThorNodeClient.swift:358` repair make both
`Scripts/verify-s1-04.sh --source-only` and `--fixtures-only` pass. Then run the
preserved-worktree guard for the exact two intentional untracked reports and
their raw SHA-256 values, followed by the existing `Scripts/verify-s1-02.sh`
gate and the full exact-head verifier. The raw digests are not the Gimle
`repository.base_worktree_manifest` composite hashes. For the full verifier
only, after the guard, set command-local
`GIT_CONFIG_COUNT=1`, `GIT_CONFIG_KEY_0=status.showUntrackedFiles`, and
`GIT_CONFIG_VALUE_0=no`; never persist an exclude rule or weaken the script.
Run the
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

For each of the three existing `Scripts/verify-s1-04-live.sh` family commands
in the spec, call `guard_preserved_reports` immediately before the invocation,
then pass the same command-local Git configuration shown here:

```text
guard_preserved_reports
THORCHAIN_S1_04_LIVE=1 \
GIT_CONFIG_COUNT=1 \
GIT_CONFIG_KEY_0=status.showUntrackedFiles \
GIT_CONFIG_VALUE_0=no \
.../Scripts/verify-s1-04-live.sh
```

The guard rejects tracked dirt, rejects any unexpected untracked path, and
checks both intentional report digests before each run. The command-local
configuration hides only those untracked reports from the existing live
runner's clean-tree check; it is never persisted and does not weaken tracked-
dirt rejection.

### 6. UW simulator tests and build

**Owner:** ThorChainQAEngineer. **Dependency:** Steps 2 and 4.

Run `set -euo pipefail` and the operator-local XML verifier before any Xcode
command. It must parse the exact `Development.xcscheme` as XML and fail closed unless
`TestAction/Testables` contains exactly one unsuppressed
`BuildableReference[BlueprintName="AppTests"]`. This preflight must run before
`xcodebuild -showdestinations`, `xcodebuild test`, or `xcodebuild build`;
`-showdestinations` only verifies simulator availability. Then run
`-only-testing:AppTests/ThorChainKitManagerTests` with a newly-created result
bundle, verify the compact summary and exact test nodes against the operator-local
verifier's internally-derived allowlist, and
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
503 test is the failover proof; online passes are network identity/height/account
evidence from the supplied pair, not a proof of family ownership or a
caller-selected owner oracle.

### 8. Review and operator gate

**Owners:** CodeReviewer, QA, then ThorChainCTO. CR approval and QA PASS must
cite the exact ThorChainKit implementation head. QA also attaches the before/
after UW capture manifests, equal UW `HEAD`, both `statusSha256` values, and
per-file SHA-256 records. CTO verifies the pushed ThorChainKit docs head, CR
approval, QA PASS, and explicit operator authorization. Any UW final commit is
an operator-controlled local action; no UW PR or merge is part of this slice.
