# THR-164 — Test plan

**Revision:** 2

## Tests before implementation

1. Add a focused `PendingTransactionRepositoryTests` case using
   `TestObservationSource` with a deterministic queue gate. The source retains
   both callbacks and the supplied `stateQueue`; the gate signals that the
   queue is occupied and waits on a release semaphore. Emit change and error
   while the repository is alive, set the repository variable to `nil`, assert
   the weak reference is `nil` before releasing the gate, then release and
   drain the queue with `stateQueue.sync {}`. The test uses no sleeps. It must
   fail if either outer callback strongly binds `self` before `async` and pass
   for the accepted inner weak capture.
2. Keep the existing `testObservationPublishesCommittedTransition` and
   `testObservationAcknowledgesBroadcastingGeneration` as change-publication
   and barrier contracts.
3. Keep
   `testObservationErrorRejectsStaleCallbackAndInstallsReplacement` as the
   generation/error/reinstall contract, including the stale callback after the
   first source is replaced.
4. Keep `testRefreshFailurePreservesLastSnapshotAsDegraded` as the cached-state
   failure contract.

## Verification sequence

1. Freeze the repository and host identities before each build. In the
   ThorChainKit checkout, require
   `git rev-parse HEAD == 922a5badac5a9b80361a02dff5c75711f00da53c` for the
   baseline and require the implementation head to be a descendant of that
   SHA. In the host checkout, verify the four approved pin locations with
   `rg`, reject `162cc316...` and `6172fb05...`, and require
   `git -C <SourcePackages>/checkouts/ThorChainKit.Swift rev-parse HEAD` to
   equal the resolved SHA. Record `xcodebuild -version`, the toolchain path,
   resolved package graph, derived-data path, and checkout status.
2. Run the focused test command exactly (from the ThorChainKit checkout):

   ```sh
   set -o pipefail
   derived_data="$(mktemp -d)"
   result_bundle="$derived_data/PendingTransactionRepositoryTests.xcresult"
   xcodebuild -scheme ThorChainKit \
     -destination 'platform=iOS Simulator,id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' \
     -derivedDataPath "$derived_data" -resultBundlePath "$result_bundle" \
     SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
     SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO \
     -only-testing:ThorChainKitTests/PendingTransactionRepositoryTests test
   test -d "$result_bundle"
   ```

   Require exit 0 and a non-empty result bundle.
3. Run the ThorChainKit package compile probe exactly (once at the approved
   base in a disposable detached worktree and once at the implementation
   head), saving each output to a distinct durable log:

   ```sh
   set -o pipefail
   xcodebuild -scheme ThorChainKit \
     -destination 'platform=iOS Simulator,id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' \
     -derivedDataPath "$derived_data" \
     SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
     SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO \
     OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' build-for-testing \
     2>&1 | tee "$compile_log"
   rg -q 'SwiftCompile .*PendingTransactionRepository.swift' "$compile_log"
   ```

   The baseline must contain the two named diagnostics; the implementation log
   must contain neither named diagnostic and must report its actual exit.
4. Run the canonical Xcode 26.6 host command exactly from the already proven
   THR-160 mirror environment. The environment variables are required inputs,
   and their resolved values must be recorded in the evidence manifest:

   ```sh
   set -o pipefail
   : "${THR160_HOST_ROOT:?set to the verified Unstoppable checkout}"
   : "${THR159_MIRROR_GITCONFIG:?set to the verified mirror gitconfig}"
   : "${THR160_SOURCE_PACKAGES:?set to the verified resolved SourcePackages path}"
   host_derived_data="$(mktemp -d)"
   host_log="$host_derived_data/xcodebuild.log"
   (
     cd "$THR160_HOST_ROOT"
     GIT_CONFIG_GLOBAL="$THR159_MIRROR_GITCONFIG" xcodebuild \
       -workspace Wallet.xcworkspace -scheme Development \
       -configuration Debug-Dev -destination 'generic/platform=iOS Simulator' \
       -derivedDataPath "$host_derived_data" \
       -clonedSourcePackagesDirPath "$THR160_SOURCE_PACKAGES" \
       -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
       SWIFT_SUPPRESS_WARNINGS=NO SWIFT_STRICT_CONCURRENCY=complete \
       'OTHER_SWIFT_FLAGS=$(inherited) -warn-concurrency' build-for-testing
   ) 2>&1 | tee "$host_log"
   rg -q 'SwiftCompile .*PendingTransactionRepository.swift' "$host_log"
   ```

   Before invoking it, verify the four pins with
   `rg -n --fixed-strings 922a5badac5a9b80361a02dff5c75711f00da53c
   packages/WalletCore/Package.swift packages/WalletCore/Package.resolved
   Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved
   Unstoppable/Unstoppable.xcodeproj/project.pbxproj`, reject
   `162cc316` and `6172fb05`, and require
   `git -C "$THR160_SOURCE_PACKAGES/checkouts/ThorChainKit.Swift" rev-parse HEAD`
   to equal the resolved SHA. After invoking it, compare raw diagnostics and
   exit status against the baseline. Do not claim success if compilation never
   reached the kit target.
5. Save the command text, exact heads/pins, toolchain and Xcode versions,
   exit statuses, log SHA-256 values, and selected positive compile/diagnostic
   lines in
   `docs/reports/gimle/THR-164-canonical-baseline-20260727.md` (or its
   revisioned successor). Audit `git diff --stat`, exact changed lines, and
   all residual diagnostics; do not expand scope for unrelated failures.

## Non-goals

No live transaction, simulator, Maestro, mutation, dependency, or hosted CI
verification is part of this slice.
