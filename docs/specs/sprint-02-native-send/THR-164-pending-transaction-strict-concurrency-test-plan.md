# THR-164 — Test plan

**Revision:** 4 — VOP-02 correction; discovery 1/2; closure 0/5

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

1. Use an explicitly selected Bash shell and make every run carry its own
   expected SHA and output paths. Run the following once from a disposable
   detached baseline checkout and once from the implementation checkout. The
   positional `expected_thorchain_sha` parameter is mandatory for each run;
   baseline/implementation expected statuses are `65`/`0`.

   ```sh
   #!/bin/bash
   set -euo pipefail

   baseline_sha="922a5badac5a9b80361a02dff5c75711f00da53c"
   : "${THR164_BASELINE_KIT_ROOT:?set to the prepared detached baseline checkout}"
   : "${THR164_IMPLEMENTATION_KIT_ROOT:?set to the prepared implementation checkout}"
   : "${IMPLEMENTATION_THORCHAIN_SHA:?set to the exact implementation head}"

   run_kit_probe() {
     local run_label="$1"
     local kit_root="$2"
     local expected_thorchain_sha="$3"
     local expected_exit_status="$4"
     local run_dir
     run_dir="$(mktemp -d -t "thr164-${run_label}.XXXXXX")"
     local derived_data="$run_dir/DerivedData"
     local compile_log="$run_dir/xcodebuild.log"
     mkdir -p "$derived_data"

     xcodebuild -version > "$run_dir/xcodebuild-version.txt"
     xcode-select -p > "$run_dir/xcode-select-path.txt"
     xcrun --find swiftc > "$run_dir/swiftc-path.txt"
     xcrun swiftc --version > "$run_dir/swiftc-version.txt"
     git -C "$kit_root" rev-parse HEAD > "$run_dir/checkout-sha.txt"
     git -C "$kit_root" status --short > "$run_dir/checkout-status.txt"
     swift package --package-path "$kit_root" show-dependencies --format json > "$run_dir/resolved-package-graph.json"
     actual_kit_sha="$(cat "$run_dir/checkout-sha.txt")"
     test "$actual_kit_sha" = "$expected_thorchain_sha"
     if [[ "$run_label" != baseline ]]; then
       git -C "$kit_root" merge-base --is-ancestor "$baseline_sha" "$actual_kit_sha"
     fi

     set +e
     (
       cd "$kit_root"
       xcodebuild -scheme ThorChainKit \
         -destination 'platform=iOS Simulator,id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' \
         -derivedDataPath "$derived_data" \
         SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
         SWIFT_TREAT_WARNINGS_AS_ERRORS=YES SWIFT_SUPPRESS_WARNINGS=NO \
         CODE_SIGNING_ALLOWED=NO \
         OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' build-for-testing
     ) 2>&1 | tee "$compile_log"
     xcodebuild_status="${PIPESTATUS[0]}"
     set -e
     printf '%s\n' "$xcodebuild_status" > "$run_dir/xcodebuild.exit"
     shasum -a 256 "$compile_log" > "$run_dir/xcodebuild.log.sha256"

     test "$xcodebuild_status" -eq "$expected_exit_status"
     rg -q 'SwiftCompile .*PendingTransactionRepository\.swift' "$compile_log"
     if [[ "$run_label" == baseline ]]; then
       rg -q 'PendingTransactionRepository\.swift:77|PendingTransactionRepository\.swift:92' "$compile_log"
     else
       ! rg -q 'PendingTransactionRepository\.swift:77|PendingTransactionRepository\.swift:92' "$compile_log"
     fi
     printf 'run_dir=%s derived_data=%s exit=%s log_sha256=' "$run_dir" "$derived_data" "$xcodebuild_status"
     awk '{print $1}' "$run_dir/xcodebuild.log.sha256"
   }

   run_kit_probe baseline "$THR164_BASELINE_KIT_ROOT" "$baseline_sha" 65
   run_kit_probe implementation "$THR164_IMPLEMENTATION_KIT_ROOT" \
     "$IMPLEMENTATION_THORCHAIN_SHA" 0
   ```

   The two required checkout variables must name separately prepared
   worktrees; the baseline invocation cannot mutate or be reused as the
   implementation invocation. `PIPESTATUS[0]` is assigned immediately after
   each piped `xcodebuild`, before any later `rg`, hash, or bundle check can
   overwrite the compiler status. Each run's `DerivedData`, graph, checkout
   status, exit status, and log hash are retained under its printed `run_dir`.

2. Run the focused test command exactly (from the implementation ThorChainKit
   checkout), with the same explicit Bash/status-capture discipline:

   ```sh
   #!/bin/bash
   set -euo pipefail
   run_dir="$(mktemp -d -t thr164-focused.XXXXXX)"
   derived_data="$run_dir/DerivedData"
   result_bundle="$derived_data/PendingTransactionRepositoryTests.xcresult"
   test_log="$run_dir/focused-tests.log"
   : "${IMPLEMENTATION_THORCHAIN_SHA:?set to the exact implementation head}"
   mkdir -p "$derived_data"
   xcodebuild -version > "$run_dir/xcodebuild-version.txt"
   xcode-select -p > "$run_dir/xcode-select-path.txt"
   xcrun --find swiftc > "$run_dir/swiftc-path.txt"
   xcrun swiftc --version > "$run_dir/swiftc-version.txt"
   git rev-parse HEAD > "$run_dir/checkout-sha.txt"
   actual_implementation_sha="$(cat "$run_dir/checkout-sha.txt")"
   test "$actual_implementation_sha" = "$IMPLEMENTATION_THORCHAIN_SHA"
   set +e
   xcodebuild -scheme ThorChainKit \
     -destination 'platform=iOS Simulator,id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' \
     -derivedDataPath "$derived_data" -resultBundlePath "$result_bundle" \
     SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
     SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
     SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO \
     -only-testing:ThorChainKitTests/PendingTransactionRepositoryTests test \
     2>&1 | tee "$test_log"
   test_status="${PIPESTATUS[0]}"
   set -e
   printf '%s\n' "$test_status" > "$run_dir/xcodebuild.exit"
   shasum -a 256 "$test_log" > "$run_dir/focused-tests.log.sha256"
   test "$test_status" -eq 0
   test -d "$result_bundle"
   test -n "$(find "$result_bundle" -type f -print -quit)"
   ```

   Require the captured exit to be 0 and the result bundle to contain a file.

3. The package harness above is the exact ThorChainKit compile probe. Its
   `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` setting matches the warnings-as-errors
   acceptance criterion, while `SWIFT_SUPPRESS_WARNINGS=NO` and
   `-warn-concurrency` keep the two named diagnostics visible. The baseline
   must contain the two named diagnostics; the implementation log must contain
   neither named diagnostic and must record exit 0.

4. Run the canonical Xcode 26.6 host command exactly from the already proven
   THR-160 mirror environment. The environment variables are required inputs;
   capture their resolved values in the local run artifacts and publish only
   the sanitized evidence fields described in step 5:

   ```sh
   #!/bin/bash
   set -euo pipefail
   : "${IMPLEMENTATION_THORCHAIN_SHA:?set to the exact implementation head}"
   : "${THR164_BASELINE_HOST_ROOT:?set to the prepared baseline Unstoppable checkout}"
   : "${THR164_BASELINE_SOURCE_PACKAGES:?set to the prepared baseline SourcePackages path}"
   : "${THR164_BASELINE_MIRROR_GITCONFIG:?set to the baseline mirror gitconfig}"
   : "${THR164_IMPLEMENTATION_HOST_ROOT:?set to the prepared implementation Unstoppable checkout}"
   : "${THR164_IMPLEMENTATION_SOURCE_PACKAGES:?set to the prepared implementation SourcePackages path}"
   : "${THR164_IMPLEMENTATION_MIRROR_GITCONFIG:?set to the implementation mirror gitconfig}"

   run_host_probe() {
     local run_label="$1"
     local host_root="$2"
     local source_packages="$3"
     local mirror_gitconfig="$4"
     local expected_thorchain_sha="$5"
     local expected_exit_status="$6"
     local run_dir
     run_dir="$(mktemp -d -t "thr164-host-${run_label}.XXXXXX")"
     local host_derived_data="$run_dir/DerivedData"
     local host_log="$run_dir/xcodebuild.log"
     local host_pin_files=(
       packages/WalletCore/Package.swift
       packages/WalletCore/Package.resolved
       Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved
       Unstoppable/Unstoppable.xcodeproj/project.pbxproj
     )
     mkdir -p "$host_derived_data"

     xcodebuild -version > "$run_dir/xcodebuild-version.txt"
     xcode-select -p > "$run_dir/xcode-select-path.txt"
     xcrun --find swiftc > "$run_dir/swiftc-path.txt"
     xcrun swiftc --version > "$run_dir/swiftc-version.txt"
     git -C "$source_packages/checkouts/ThorChainKit.Swift" rev-parse HEAD > "$run_dir/resolved-checkout-sha.txt"
     resolved_sha="$(cat "$run_dir/resolved-checkout-sha.txt")"
     test "$resolved_sha" = "$expected_thorchain_sha"
     test -s "$source_packages/workspace-state.json"
     cp "$source_packages/workspace-state.json" "$run_dir/resolved-host-package-graph.json"
     shasum -a 256 "$run_dir/resolved-host-package-graph.json" > "$run_dir/resolved-host-package-graph.sha256"

     local pin_file pin_path pin_key
     for pin_file in "${host_pin_files[@]}"; do
       pin_path="$host_root/$pin_file"
       pin_key="${pin_file//\//_}"
       test -f "$pin_path"
       rg -n --fixed-strings "$expected_thorchain_sha" "$pin_path" > "$run_dir/${pin_key}.expected"
       ! rg -n --fixed-strings '162cc316' "$pin_path"
       ! rg -n --fixed-strings '6172fb05' "$pin_path"
     done

     git -C "$source_packages/checkouts/ThorChainKit.Swift" status --short > "$run_dir/resolved-checkout-status.txt"
     printf '%s\n' "$host_root" > "$run_dir/host-root.txt"
     printf '%s\n' "$source_packages" > "$run_dir/source-packages.txt"
     printf '%s\n' "$host_derived_data" > "$run_dir/derived-data-path.txt"

     set +e
     (
       cd "$host_root"
       GIT_CONFIG_GLOBAL="$mirror_gitconfig" xcodebuild \
         -workspace Wallet.xcworkspace -scheme Development \
         -configuration Debug-Dev -destination 'generic/platform=iOS Simulator' \
         -derivedDataPath "$host_derived_data" \
         -clonedSourcePackagesDirPath "$source_packages" \
         -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
         SWIFT_SUPPRESS_WARNINGS=NO SWIFT_STRICT_CONCURRENCY=complete \
         SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
         'OTHER_SWIFT_FLAGS=$(inherited) -warn-concurrency' build-for-testing
     ) 2>&1 | tee "$host_log"
     host_status="${PIPESTATUS[0]}"
     set -e
     printf '%s\n' "$host_status" > "$run_dir/xcodebuild.exit"
     shasum -a 256 "$host_log" > "$run_dir/xcodebuild.log.sha256"
     test "$host_status" -eq "$expected_exit_status"
     rg -q 'SwiftCompile .*PendingTransactionRepository\.swift' "$host_log"
     if [[ "$run_label" == baseline ]]; then
       rg -q 'PendingTransactionRepository\.swift:77|PendingTransactionRepository\.swift:92' "$host_log"
     else
       ! rg -q 'PendingTransactionRepository\.swift:77|PendingTransactionRepository\.swift:92' "$host_log"
     fi
     printf 'run_dir=%s derived_data=%s exit=%s log_sha256=' "$run_dir" "$host_derived_data" "$host_status"
     awk '{print $1}' "$run_dir/xcodebuild.log.sha256"
   }

   run_host_probe baseline \
     "$THR164_BASELINE_HOST_ROOT" "$THR164_BASELINE_SOURCE_PACKAGES" \
     "$THR164_BASELINE_MIRROR_GITCONFIG" \
     922a5badac5a9b80361a02dff5c75711f00da53c 65
   run_host_probe implementation \
     "$THR164_IMPLEMENTATION_HOST_ROOT" "$THR164_IMPLEMENTATION_SOURCE_PACKAGES" \
     "$THR164_IMPLEMENTATION_MIRROR_GITCONFIG" \
     "$IMPLEMENTATION_THORCHAIN_SHA" 0
   ```

   Each invocation receives a separately prepared host root, SourcePackages
   directory, and mirror configuration. It checks each of the four pin files
   independently against its run-specific `expected_thorchain_sha`, rejects
   both known stale SHAs in each file, and checks the resolved SourcePackages
   checkout against the same value. `workspace-state.json` is copied and
   hashed as the resolved host package graph. `host_derived_data`, checkout
   status, toolchain files, captured exit, and log hash are all per-run local
   artifacts. Do not claim success if compilation never reached the kit
   target.

5. Retain the exact function invocations/command text, expected and resolved
   heads, all four individual pin-match outputs, toolchain and Xcode versions,
   resolved graph hash, captured exit statuses, log SHA-256 values, and
   selected positive `SwiftCompile`/diagnostic lines in local run artifacts.
   The committed
   `docs/reports/gimle/THR-164-canonical-baseline-20260727.md` (or its
   revisioned successor) must contain only sanitized run labels, exact SHAs,
   toolchain identifiers/versions, graph and log hashes, statuses, and
   selected output. Keep absolute checkout, SourcePackages, DerivedData,
   mirror-config, and other operator paths local-only. Audit `git diff --stat`,
   exact changed lines, and all residual diagnostics; do not expand scope for
   unrelated failures.

## Non-goals

No live transaction, simulator, Maestro, mutation, dependency, or hosted CI
verification is part of this slice.
