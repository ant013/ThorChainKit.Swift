# THR-139 — resilient native RUNE provider pool plan

Plan source of truth: [THR-139 spec](../../specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md), design revision 6. Discovery 2/2; closure 2/5 pending targeted review.

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

**Owner:** ThorChainCodeReviewer. **Dependencies:** pushed revision-6 spec,
plan, and Gimle report. Recheck only the frozen D-001 through D-010 allowlist,
discovery 2/2, closure 2/5. Verify the concrete fresh `.synced` owner-
observation seam and cached-family negative fixture, deterministic full-manifest fixtures,
XML-safe preflight ordering, non-self-referential digest domain, role-bound
six-record equality, cross-family pairing, exact result verification, simulator
selectors, and docs-only delivery.

### 2. Verification artifact authoring

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 1 review disposition.
Create and commit these exact repository-owned files before any Xcode or
consumer command runs:

- ThorChainKit: `Scripts/allowlists/THR-139-thor.txt`.
- UW: `Scripts/allowlists/THR-139-uw.txt`,
  `Scripts/allowlists/THR-139-family-manifest.json`,
  `Scripts/verify-thr-139-scheme.py`, `Scripts/verify-thr-139-uw-tests.py`,
  `Scripts/verify-thr-139-live.sh`, and `Scripts/verify-thr-139-evidence.py`.

Every consumer derives these paths from its own repository root or script
directory. The allowlist, manifest, verifier, and expected-family value cannot
be overridden by caller environment variables or arguments. Only simulator
identity, repository roots, and output directories are runtime inputs. Test
first with `python3 -m py_compile` for the three Python verifiers, `bash -n`
for the shell runner, and bounded negative fixtures for missing/extra/
duplicate/failed/skipped test nodes, absent or mismatched owner observations,
manifest drift, pair swaps, invalid chain/height, and tampered digests. The
result verifier must recompute `resultSha256` from canonical JSON with
`resultSha256` omitted; it must never hash an object containing its own digest.

### 3. Test-first UW contract

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2 artifacts and their
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

Run simulator `xcodebuild` selectors:

```text
ThorChainKitTests/EndpointPoolTests
ThorChainKitTests/ReadOperationCoordinatorS1_04Tests
ThorChainKitTests/LiveNodeProbeTests
ThorChainKitTests/LiveThorNodeClientS1_04Tests
```

Use the repository result-bundle allowlist/verifier. The complete-operation
retry test is the existing
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
`-only-testing:AppTests/ThorChainKitManagerTests` with a result bundle, verify
the compact summary and exact test nodes against the repository-derived
`$UW_ROOT/Scripts/allowlists/THR-139-uw.txt`, and
run a `Debug-Dev` simulator build. Reject `-only-testing:ThorChain`, device
artifacts, missing result bundles, failed/skipped nodes, or non-simulator build
settings.

### 7. Three-family online smoke

**Owner:** ThorChainQAEngineer. **Dependency:** Steps 4–6.

Run the exact `$UW_ROOT/Scripts/verify-thr-139-live.sh` harness three times with
all three families in every manifest. The exact live emission boundary is the
existing `IThorChainKit.syncStatePublisher` subscription in
`packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift`;
the test-only `THR139_LIVE_EVIDENCE` sink writes an atomic
`Documents/THR139/live-state.json` record only for `.synced(AccountState)`. The
runner resolves the launched app container with `xcrun simctl get_app_container`,
removes the prior record before launch, and accepts only a new record observed
after launch. `.idle(cached: true)` and `.notSynced(..., cached: ...)` never
produce an owner record. A cached-family negative fixture preloads family A,
then requires a fresh `.synced` record for family B; cached A alone times out
and fails closed. The runner binds REST/RPC observations to that fresh family
record, verifies `thorchain-1`, accepted heights and identity, stores canonical
digest-only JSON, compares pre/post manifests, and unsets simulator launchd
variables. It does not accept a caller-supplied expected family. The script
derives its manifest and verifier paths from its own repository directory. Run
the independent `$UW_ROOT/Scripts/verify-thr-139-evidence.py` verifier afterward.
The injected HTTP 503 test is the failover proof; deterministic AppTests are
the three-family selection proof; online passes are actual-owner/pair evidence.
Each pass writes only `schemaVersion`, `observedFamily`, `manifestSha256`,
`rest`, `rpc`, `chainId`, `height`, and `resultSha256`. `manifestSha256` hashes
the canonical six-record manifest. `resultSha256` hashes the canonical result
object with `resultSha256` omitted, using sorted keys, compact separators,
UTF-8, and no trailing newline.

### 8. Review and merge gate

**Owners:** CodeReviewer, QA, then ThorChainCTO. CR approval and QA PASS must
cite the exact PR head. CTO verifies required checks and conflict-free head,
then waits for explicit operator authorization before merge.
