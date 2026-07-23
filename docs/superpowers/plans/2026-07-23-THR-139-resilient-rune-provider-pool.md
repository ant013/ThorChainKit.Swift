# THR-139 — resilient native RUNE provider pool plan

Plan source of truth: [THR-139 spec](../../specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md), design revision 4. Discovery 2/2; closure 2/5 pending targeted review.

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

**Owner:** ThorChainCodeReviewer. **Dependencies:** pushed revision-4 spec,
plan, and Gimle report. Recheck only the frozen D-001 through D-010 allowlist,
discovery 2/2, closure 2/5. Verify the concrete owner-observation seam and
deterministic full-manifest fixtures, artifact ownership/paths, XML-safe
preflight ordering, non-self-referential digest domain, role-bound six-record
equality, cross-family pairing, exact result verification, simulator selectors,
and docs-only delivery.

### 2. Test-first UW contract

**Owner:** ThorChainSwiftEngineer. **Paths:** existing native RUNE provider,
existing manager/descriptor validation seam if required by the failing exact
equality tests, and `AppTests/ThorChainKitManagerTests`.

Add tests before production edits for family count/order, all six exact records,
five-host derivation, exact equality, duplicate/foreign/HTTP/credential/query/
fragment rejection, every REST/RPC pair swap, Liquify absence, and unchanged
multichain ownership. Run
`xcodebuild test ... -only-testing:AppTests/ThorChainKitManagerTests` and capture
a genuine pre-edit failure.

The same test target owns deterministic family-selection coverage: retain the
full three-family manifest, script valid Comet heights so Rorcual, IBS, and
Keplr are each highest in a separate fixture, complete one operation per
fixture, and assert the test-only observation equals the selected
`providerFamilyId`. `THR139_OWNER_FAMILY` is an assertion/fixture label only;
it never removes or reorders production families.

### 3. Minimal native configuration edit

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2 failure evidence.

Use the existing provider/manager seam only. Do not introduce a provider
abstraction, change ThorChainKit, or edit the multichain swap provider. The
exact six role-bound records must be compared for equality; no membership-only
allowlist or silent deduplication is acceptable.

### 4. Verification artifact authoring

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2’s failing tests.
Create these exact files before QA execution:

- ThorChainKit: `Scripts/allowlists/THR-139-thor.txt`.
- UW: `Scripts/allowlists/THR-139-uw.txt`,
  `Scripts/verify-thr-139-uw-tests.py`,
  `Scripts/verify-thr-139-live.sh`, and
  `Scripts/verify-thr-139-evidence.py`.

The allowlists contain the exact observed test identifiers. Test first with
`python3 -m py_compile` for both Python verifiers, `bash -n` for the shell
runner, and bounded negative fixtures for missing/extra/duplicate/failed/
skipped test nodes, absent or mismatched owner observations, manifest drift,
pair swaps, invalid chain/height, and tampered digests. The result verifier
must recompute `resultSha256` from canonical JSON with `resultSha256` omitted;
it must never hash an object containing its own digest.

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

**Owner:** ThorChainQAEngineer. **Dependency:** Step 3.

First parse the exact `Development.xcscheme` as XML and fail closed unless
`TestAction/Testables` contains exactly one unsuppressed
`BuildableReference[BlueprintName="AppTests"]`. This preflight must run before
`xcodebuild -showdestinations`, `xcodebuild test`, or `xcodebuild build`;
`-showdestinations` only verifies simulator availability. Then run
`-only-testing:AppTests/ThorChainKitManagerTests` with a result bundle, verify
the compact summary and exact test nodes against `$THR139_UW_ALLOWLIST`, and
run a `Debug-Dev` simulator build. Reject `-only-testing:ThorChain`, device
artifacts, missing result bundles, failed/skipped nodes, or non-simulator build
settings.

### 6. Three-family online smoke

**Owner:** ThorChainQAEngineer. **Dependency:** Steps 4–5.

Run the exact `$UW_ROOT/Scripts/verify-thr-139-live.sh` harness three times,
with all three families in every manifest and `THR139_OWNER_FAMILY` set to
`rorcual-mainnet`, `ibs-mainnet`, then `keplr-mainnet`. The app test-only seam
must emit the actual selected family; missing or mismatched observation fails
closed. The runner binds REST/RPC observations to that family record, verifies
`thorchain-1`, accepted heights and identity, stores canonical digest-only JSON,
compares pre/post manifests, and unsets simulator launchd variables. Run the
independent `$UW_ROOT/Scripts/verify-thr-139-evidence.py` verifier afterward.
The injected HTTP 503 test is the failover proof; online passes are the
three-family ownership/pair proof. Each pass writes only the canonical fields
`schemaVersion`, `ownerFamily`, `observedFamily`, `manifestSha256`, `rest`,
`rpc`, `chainId`, `height`, and `resultSha256`. `manifestSha256` hashes the
canonical six-record manifest. `resultSha256` hashes the canonical result
object with `resultSha256` omitted, using sorted keys, compact separators,
UTF-8, and no trailing newline.

### 8. Review and merge gate

**Owners:** CodeReviewer, QA, then ThorChainCTO. CR approval and QA PASS must
cite the exact PR head. CTO verifies required checks and conflict-free head,
then waits for explicit operator authorization before merge.
