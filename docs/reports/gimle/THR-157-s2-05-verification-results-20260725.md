# THR-157 S2-05 verification results

## Passed

- All ThorChainKit sources typecheck locally with Swift warnings treated as errors against the iOS simulator SDK and the existing dependency modules.
- All changed and added Swift sources pass frontend parsing.
- `git diff --check` passes.

## Not run

- `swift test --skip-update --filter StrictJSONEnvelopeDecoderTests` could not reach product compilation because SwiftPM stalled while creating the nested `swift-protobuf` checkout (`protobuf`). No test result is claimed.

The unrelated pre-existing THR-104 report files were left untouched.
