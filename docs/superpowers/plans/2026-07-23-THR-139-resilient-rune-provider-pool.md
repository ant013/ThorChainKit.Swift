# THR-139 — resilient native RUNE provider pool plan

Plan source of truth: [THR-139 spec](../../specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md), design revision 3. Discovery 2/2; closure 0/5.

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

**Owner:** ThorChainCodeReviewer. **Dependencies:** pushed revision-3 spec,
plan, and Gimle report. Recheck only D-001 through D-010, discovery 2/2,
closure 0/5. Verify role-bound six-record equality, cross-family pairing,
owner observation fail-closed behavior, exact result verification, simulator
selectors, and docs-only delivery.

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

### 3. Minimal native configuration edit

**Owner:** ThorChainSwiftEngineer. **Dependency:** Step 2 failure evidence.

Use the existing provider/manager seam only. Do not introduce a provider
abstraction, change ThorChainKit, or edit the multichain swap provider. The
exact six role-bound records must be compared for equality; no membership-only
allowlist or silent deduplication is acceptable.

### 4. ThorChainKit simulator invariants

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

### 5. UW simulator tests and build

**Owner:** ThorChainQAEngineer. **Dependency:** Step 3.

Inspect `Development.xcscheme` and require an unsuppressed `AppTests`
`TestableReference`; `-showdestinations` only verifies simulator availability.
Then run `-only-testing:AppTests/ThorChainKitManagerTests` with a result bundle,
verify the compact summary and exact test nodes against `$THR139_UW_ALLOWLIST`,
and run a `Debug-Dev` simulator build. Reject `-only-testing:ThorChain`, device
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
three-family ownership/pair proof.

### 7. Review and merge gate

**Owners:** CodeReviewer, QA, then ThorChainCTO. CR approval and QA PASS must
cite the exact PR head. CTO verifies required checks and conflict-free head,
then waits for explicit operator authorization before merge.
