# THR-157 S2-05 verification results

## Passed

- All ThorChainKit sources typecheck locally with Swift warnings treated as errors against the iOS simulator SDK and the existing dependency modules.
- All changed and added Swift sources pass frontend parsing.
- `git diff --check` passes.

## Focused test result

- The protobuf checkout was recovered from the verified local cache; both nested
  submodules match the required gitlinks and are clean.
- `xcrun swift test --list-tests` discovers the named journal tests.
- The required retry, lookup, pending-publication, restart, ownership, and
  redaction test sources plus both S2-05 harness scripts are force-added and
  present in the staged diff; no XCTest acceptance is inferred from source
  presence.
- `xcrun swift test --filter SendJournalOrderingTests` reaches compilation but
  exits before XCTest discovery because the existing `HsExtensions` dependency
  is compiled below macOS 10.15 and rejects `Task` and Combine availability.
- `MACOSX_DEPLOYMENT_TARGET=10.15 xcrun swift test --filter
  SendJournalOrderingTests` reproduces the same dependency failure.
- An explicit `arm64-apple-macosx10.15` target advances beyond that failure but
  exits on the host Xcode 26 SDK conflict with `/usr/local/include/IOKit`;
  this is an environment failure, not a passing test result.
- `xcrun swift test --skip-update -Xswiftc -Xfrontend -Xswiftc
  -disable-availability-checking --list-tests` advances beyond the dependency
  availability diagnostics but exits on the same host Xcode 26 SDK `IOKit`
  conflict before XCTest discovery.

## Closure 4 correction

- Commit `57612a8` removes the nested GRDB transaction and keeps the insert,
  reservation-link update, and rollback guard in the single `DatabasePool.write`
  transaction.
- Retry tests now observe operation-hold release, journal read, CAS,
  publication acknowledgement, lookup, and broadcast ordering; the persisted
  `sequence_advanced` path asserts no CAS/publication/endpoint activity across
  a second runtime.
- `PendingTransactionRepository` uses generation-scoped GRDB
  `ValueObservation`; observation errors retain the last snapshot and a later
  successful refresh installs a replacement observation.
- `xcrun swiftc -parse` over all changed Swift files, both S2-05 `zsh -n`
  harness checks, and `git diff --check` pass on `57612a8`.
- Focused `swift test`, `xcodebuild test`, and strict `swift build` remain
  unavailable because SwiftPM stalls creating the cached `swift-protobuf`
  checkout before product compilation; no XCTest acceptance is claimed.

## Closure 5 correction

- Commit `8664b06` fixes the remaining direct call-site and XCTest compile
  diagnostics at the exact engineer head.
- The full named S2-05 selector set was run locally with the pinned iOS 26.2
  simulator, `SWIFT_SUPPRESS_WARNINGS=NO`,
  `-clonedSourcePackagesDirPath` bound to the verified `s2-03-review` cache,
  `-disableAutomaticPackageResolution`, and
  `-onlyUsePackageVersionsFromResolvedFile`.
- Result: `TEST SUCCEEDED`; 31 selected tests executed with 0 failures.
- The earlier SwiftPM-stall limitation is superseded for this route. The
  simulator emitted only the known test-cleanup vnode-unlink diagnostics; all
  selected tests passed.

The full named S2-05 selector acceptance is green; the broader package suite
was not run in this bounded closure.

The unrelated pre-existing THR-104 report files were left untouched.
