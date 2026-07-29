# THR-104 S1-06 local verification results

Date: 2026-07-22

## Frozen implementation identity

- Unstoppable base and current HEAD: `8a63bfda028dd8543115b26dd777235a53304311` (`version/0.50`).
- Local branch: `local/THR-104-thorchain-lifecycle-v0.50`.
- Complete tracked-plus-untracked binary diff SHA-256: `eafc62acc3dd67ededa4666540314fb51a19fa33f348cf616d793f6938b05fe4`.
- Local sibling packages: ThorChainKit and MarketKit; no Unstoppable commit, push, PR, or merge was made.

## Passed acceptance evidence

- Targeted Unstoppable AppTests: 25 passed, 0 failed, 0 skipped in the three THORChain suites. The xcresult identifies iPhone 17 Pro, iOS 26.2 build 23C52, arm64.
- Unstoppable `Development` simulator build: passed after the final endpoint correction.
- Real ThorChainKit mainnet read on the same simulator passed against the Liquify API/RPC pair: chain ID `thorchain-1`; Cosmos, CometBFT, and accepted heights all `27111362`; the implementation RUNE amount exactly matched the raw response; the absent-account case returned no account or balances.
- ThorChainKit ordinary tests: 83 passed when the intentional fatal-invariant harness is excluded.
- ThorChainKit fatal-invariant harness: all 3 expected fatal probes passed.
- MarketKit iOS tests: 2 passed, 0 failed.
- Full Unstoppable AppTests baseline run: 135 passed of 136. The only failure is the pre-existing, unchanged `SwapRequestRefundTests/actionRequiredStatusIsPending()` expectation against the version/0.50 `Swap.pendingStatuses` definition.

## Passed verification evidence

- `git diff --check` passed.
- The Xcode project plist and workspace XML parsed successfully.
- `swift package dump-package` passed for local WalletCore.
- `project.pbxproj` and `AdapterManager.swift` are unchanged from the version/0.50 base.
- Changed-path scans found no `@_spi(Testing)`, host-local absolute paths, or credential-shaped string assignments.
- Final manual diff audit found and corrected an idle-state publication race; the 25 targeted tests and app build were repeated afterward and passed.
- Public DNS proved the previously configured NineRealms host had no address record. The approved production provider now uses the working official Liquify split endpoints, and no NineRealms reference remains in the changed host paths.

## Explicit limitations and acceptance conflicts

- A direct ThorChainKit product dependency on the version/0.50 AppTests target was attempted. Xcode 26.2 then failed while linking the existing static package graph because the transitive HsCryptoKit `Crypto` package framework wrapper was unavailable. The project-file experiment was removed completely. AppTests compile ThorChainKit transitively through the locally linked WalletCore package.
- `ThorChainAdapterTests` uses `@testable import ThorChainKit` because the public `AccountState` type exposes no public initializer. Production code uses the normal import and production diagnostics are clean.
- codebase-memory was attempted first but its transport closed. Load-bearing evidence was independently verified with Serena and targeted Git/`rg`; Serena production diagnostics were clean. SourceKit diagnostics for Swift Testing macro files were treated as non-authoritative and xcodebuild was used as the test authority.
- `swift test` for MarketKit is not valid evidence on this host because the package's macOS 10.13 declaration conflicts with the current ObjectMapper macOS 12 floor; the iOS xcodebuild test is the relevant passing result.

## Readiness

The local version/0.50 implementation, targeted tests, real mainnet read, and application build are ready for review by the frozen diff digest. Formal slice closure remains conditional only on accepting the AppTests dependency deviation.
