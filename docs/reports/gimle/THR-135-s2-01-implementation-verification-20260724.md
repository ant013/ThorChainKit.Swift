# THR-135 S2-01 implementation verification

## Scope

This report covers only the approved S2-01 immutable send/quote domain,
stable public errors, fail-closed quote/send/retry/pending facade, quote
identity store, and lifecycle generation invalidation. It does not add
preflight, protobuf, signing verification, journal, transport, Example UI,
host integration, or S2-02 behavior.

## Implementation evidence

- The corrected implementation code is committed at
  `06714fa4feb8fc9706b3dea8dcdebab84052558c`.
- Send values snapshot `BigUInt` magnitudes before async/runtime hops.
- Quote authority is one-use, store-owned, generation-bound, and expires at
  the exclusive ten-second monotonic deadline.
- Quote creation and public projection both reject noncanonical magnitude
  encodings, zero amount/total, non-empty zero-fee encoding, unchecked totals,
  and missing provider-family identity.
- Signing summaries require canonical lowercase THOR/STHOR/CTHOR addresses,
  fixed-eight ASCII RUNE amounts with checked totals, and canonical unsigned
  account/sequence values. Repeated and trailing decimal separators are
  rejected by preserving empty split subsequences.
- Consumed and invalidated records remain terminal tombstones through their
  originating deadline, then are cleaned; an own unexpired missing record is
  `operationUnavailable`, while an expired quote remains `quoteExpired`.
- Lifecycle stop invalidates the taken generation before either syncer close
  branch, including control-failure close; rapid restart rejects late prior
  generation callbacks.
- Quote-store and synchronous admission state use checked `Sendable`
  queue-backed storage. The S2 Send concurrency gate rejects any
  `@unchecked Sendable` or `@preconcurrency` suppression in the module.
- The public-surface guard includes a successful external consumer control,
  seven negative access/name-resolution controls, and explicit tracking checks
  for every Send source plus `Core/Kit+Send.swift` despite the case-insensitive
  `sources/` ignore rule.
- Temporary roots in all three S2-01 harnesses are reclaimed with EXIT traps.

## Local verification

All simulator commands used the approved booted iPhone 17 Pro, iOS 26.2,
UDID `0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`. Commands preserved their actual
exit codes.

- The repeated/trailing-separator regression first failed twice on the old
  parser, then passed after the two parsing paths preserved empty subsequences.
- Before the checked-concurrency correction, named S2-01 selectors passed
  43/43 and the full non-live `ThorChainKitTests` gate passed 130/130.
  On exact corrected head `06714fa`, the engineer reran 35 focused tests and
  the reviewer independently reran 37 focused tests covering quote-store
  atomicity, lifecycle admission, errors, quote/public projection, reflection,
  and facade admission; both runs had zero failures.
  The named selector set includes `SendValueTests`, `KitCompositionTests`,
  `LifecycleCommandBridgeTests`, `SendFacadeAdmissionTests`,
  `QuoteStoreTests`, `SendErrorTests`, `SendReflectionTests`,
  `PendingTransactionTests`, `SendPublicApiTests`, and `SendQuoteTests`.
- The 130-test non-live run had zero failures, with only
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

## Independent review

- `ThorChainCodeReviewer` approved exact implementation head `06714fa` after
  independently reviewing the three-file checked-concurrency correction.
- The reviewer independently passed both BigInt concurrency probes, 37 focused
  simulator tests, public-surface, deployment-floor, package-manifest, and
  diff-hygiene checks.
- Serena had no active Swift language server for this checkout. Exact-tree
  Git/`rg` inspection and executable local gates supplied the documented
  fallback; Gimle trust remains RED because of the already quarantined
  Unstoppable mapping defect.

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
