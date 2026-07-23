# THR-135 S2-01 implementation verification

## Scope

This report covers only the approved S2-01 immutable send/quote domain,
stable public errors, fail-closed quote/send/retry/pending facade, quote
identity store, and lifecycle generation invalidation. It does not add
preflight, protobuf, signing verification, journal, transport, Example UI,
host integration, or S2-02 behavior.

## Implementation evidence

- Send values snapshot `BigUInt` magnitudes before async/runtime hops.
- Quote authority is one-use, store-owned, generation-bound, and expires at
  the exclusive ten-second monotonic deadline.
- Consumed and invalidated records remain terminal tombstones through their
  originating deadline, then are cleaned; an own unexpired missing record is
  `operationUnavailable`, while an expired quote remains `quoteExpired`.
- Lifecycle stop invalidates the taken generation before either syncer close
  branch, including control-failure close; rapid restart rejects late prior
  generation callbacks.
- The public-surface guard includes a successful external consumer control,
  seven negative access/name-resolution controls, and explicit tracking checks
  for every Send source plus `Core/Kit+Send.swift` despite the case-insensitive
  `sources/` ignore rule.
- Temporary roots in all three S2-01 harnesses are reclaimed with EXIT traps.

## Local verification

All simulator commands used the approved booted iPhone 17 Pro, iOS 26.2,
UDID `0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`. Commands preserved their actual
exit codes.

- Named S2-01 selectors: 31 tests, 0 failures, `TEST SUCCEEDED`.
  This includes `SendValueTests`, `KitCompositionTests`,
  `LifecycleCommandBridgeTests`, `SendFacadeAdmissionTests`,
  `QuoteStoreTests`, `SendErrorTests`, `SendReflectionTests`,
  `PendingTransactionTests`, `SendPublicApiTests`, and `SendQuoteTests`.
- Full local non-live `ThorChainKitTests`: 118 tests, 0 failures, with only
  the pre-existing `LifecycleInvariantProbeTests` excluded because it
  repeatedly restarts/timeouts; no live network tests were enabled.
- `Scripts/verify-s2-01-public-surface.sh`: pass, including positive import
  control and diagnostic-specific negative cases.
- `Scripts/verify-s2-01-concurrency.sh --dependency 5.0.0`: pass. The stored
  `BigUInt: Sendable` control fails with the expected non-Sendable diagnostic.
- `Scripts/verify-s2-01-concurrency.sh --dependency 5.7.0`: pass. The stored
  `BigUInt: Sendable` control compiles and a separate bad-reference capture
  fails with the expected strict-concurrency diagnostic.
- `Scripts/verify-s2-01-deployment-floor.sh`: pass for device triple
  `arm64-apple-ios13.0`; no simulator triple was used for this proof.
- `Scripts/verify-bigint-floor.sh`: pass at BigInt 5.0.0, 83 existing floor
  tests, on the approved simulator.
- `swift package dump-package`: pass; the package retains the iOS 13 floor.
- Host `swift test` remains an invalid route on this Mac because the package's
  macOS 10.13 declaration conflicts with the HsCryptoKit dependency's macOS
  10.15 requirement. No package-floor change was made.

## Verification commands

```text
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 \
  bash Scripts/verify-s2-01-public-surface.sh
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 \
  bash Scripts/verify-s2-01-deployment-floor.sh
bash Scripts/verify-s2-01-concurrency.sh --dependency 5.0.0
bash Scripts/verify-s2-01-concurrency.sh --dependency 5.7.0
THORCHAIN_SIMULATOR_UDID=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17 \
  bash Scripts/verify-bigint-floor.sh
```
