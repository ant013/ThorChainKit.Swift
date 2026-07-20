# Gimle reliability report — THR-52 hosted acceptance recovery revision 10

## Scope and identity

This report covers a spec-only correction after exact local toolchain evidence
invalidated revision 9's local iOS 26.2 prerequisite. The implementation base
remains `64575a9aea42201b31f3549ba517f1e02017199d`; the new spec-only revision
head is `c09f7e8`. Spec SHA-256:
`0d8bc82c234bbf1411d198b8c9a5841f6c2828413130ebab2db0052bdef09f61`. No
implementation, hosted rerun, merge, or approval interaction was created
before adversarial review.

## Gimle trust

Gimle trust remains **RED** because the target project mapping is unavailable.
The `Users-ant013-Data-AI-thorchain` codebase-memory index is `ready`; Serena,
targeted `rg`, and Git independently verified the current selector and Maestro
lifecycle. Official runner-image evidence was checked directly. Gimle's
mapping failure was not treated as repository evidence.

## Exact local and hosted evidence

The operator completed exact local toolchain verification on spec-only head
`d764824acff10eea83e9d44a7b2071175d7e9c2b` without changing implementation
files:

- Maestro 2.6.1 asset SHA-256:
  `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`;
- Temurin JRE SHA-256:
  `cef790b404cf168fd1a8a7abc5054fbb442c7d4bfe390cceccfe3f64b9b776a9`;
- Java identity `Temurin-17.0.19+10`;
- Xcode 26.3 build `17C529`, iPhoneSimulator SDK 26.2;
- local iPhone 17 Pro iOS 26.3, UDID
  `9F8C536F-C2BF-44A0-B315-85E7405D5F76`;
- canonical S1-01 passed in 7s and S1-02 passed in 16s, with OCR scans passing.

The hosted contrast is Xcode 26.3 selecting iOS 26.4.1 through the
first-shutdown-iPhone selector; install/launch passed, then Maestro failed at
`127.0.0.1:50637` before assertions. This supports a runtime compatibility
hypothesis but does not prove iOS 26.2 will pass.

## Revision-10 recovery boundary

Revision 10 removes the impossible local iOS 26.2 A/B prerequisite. After
approval, the narrow implementation must make the workflow select only
`com.apple.CoreSimulator.SimRuntime.iOS-26-2`, select one deterministic
shutdown iPhone in that bucket, log Xcode/runtime/device identity, and fail
closed on missing runtime/device or any newer/all-runtime fallback. The policy
verifier must prove these properties with positive checks and temporary-copy
mutants. Existing Maestro, Temurin, ripgrep, permission, and flow semantics
remain unchanged.

Fresh adversarial CodeReviewer and QA evidence are required at the new exact
head. One hosted run is authorized after those gates; if iOS 26.2 still shows
the driver failure, a separate Maestro/XCUITest design is required.

## Verification

Completed: codebase-memory status/search, Serena activation, targeted selector
and lifecycle reads, Git identity checks, operator-supplied exact local tuple
and flow results, and direct review of official macos-26-arm64 image evidence.

Not run by design: hosted CI, merge, implementation tests, and workflow or
verifier edits. Adversarial CodeReviewer review is the next phase before a new
revision-bound approval interaction.

## Residual risk

The local iOS 26.3 pass versus hosted iOS 26.4.1 failure is strong compatibility
evidence but not proof of iOS 26.2 behavior. The new hosted run is deliberately
reserved for after the selector implementation, fresh CR/QA, and exact-head
binding. Gimle remains RED until target project mapping is repaired.
