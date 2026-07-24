# THR-157 S2-05 verification results

## Passed

- All ThorChainKit sources typecheck locally with Swift warnings treated as errors against the iOS simulator SDK and the existing dependency modules.
- All changed and added Swift sources pass frontend parsing.
- `git diff --check` passes.

## Focused test result

- The protobuf checkout was recovered from the verified local cache; both nested
  submodules match the required gitlinks and are clean.
- `xcrun swift test --list-tests` discovers the named journal tests.
- `xcrun swift test --filter SendJournalOrderingTests` reaches compilation but
  exits before XCTest discovery because the existing `HsExtensions` dependency
  is compiled below macOS 10.15 and rejects `Task` and Combine availability.
- `MACOSX_DEPLOYMENT_TARGET=10.15 xcrun swift test --filter
  SendJournalOrderingTests` reproduces the same dependency failure.
- An explicit `arm64-apple-macosx10.15` target advances beyond that failure but
  exits on the host Xcode 26 SDK conflict with `/usr/local/include/IOKit`;
  this is an environment failure, not a passing test result.

No XCTest acceptance is claimed.

The unrelated pre-existing THR-104 report files were left untouched.
