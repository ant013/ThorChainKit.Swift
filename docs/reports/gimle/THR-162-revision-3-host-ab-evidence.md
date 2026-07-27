# THR-162 revision-3 exact-host A/B evidence

This compact bundle preserves the accepted causal result and binds it to the
raw logs, which remain available in `/tmp` at the recorded paths.

## Identity and provenance

- Repository: ThorChainKit.Swift
- Approved base: `origin/main` / `162cc3165cfbf1023bcb9c7111cc1d059a2fcded`
- Product head reviewed for revision 3: `6e1d7f9`
- Exact disposable host checkout: Unstoppable head
  `bdaac19866dcda878eb1b8a774f5c17baf759c04`
- Toolchain: Xcode 26.6, Apple Swift 6.3.3
- Build: `Development`, `build-for-testing`, generic iOS Simulator destination
- Language/concurrency: Swift 5, complete strict concurrency,
  `-warn-concurrency`, warnings-as-errors; warning suppression disabled
- Load-bearing host lockfile: `Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved`,
  21,833 bytes, SHA-256
  `556fcb632348d1962b888feed65b25400acee71bcd9c3ce7e04901473a0f33ab`.
  This is the resolved graph consumed by the exact `Wallet.xcworkspace`
  `Development` build and therefore the authoritative host-build digest. It is
  generated/ignored in the exact host checkout; this evidence does not claim
  that it was committed at `bdaac198`.
- Nested kit lockfile: `SourcePackages/checkouts/ThorChainKit.Swift/Package.resolved`,
  2,320 bytes, SHA-256
  `d4f311c9e43a1e20be3288564e5cc87b8d7cbc8ad8eb61d37e7a33e4bfd4730d`; it is
  byte-identical to this repository's `Package.resolved`. This records the
  checked-out kit package identity, but does not replace the host lockfile as
  the load-bearing resolved-graph evidence.
- Normalized resolved-graph proof: extracting the first `Resolved source
  packages` block from each retained raw log, sorting with `LC_ALL=C`, produces
  exactly 79 lines on both sides. The baseline and after blocks have the
  identical SHA-256
  `dcf011b12be89c36b16c962a644e02cb2850e963d3045600f0fa344d8518cde3`, and the
  normalized diff is empty. This log-derived digest is the load-bearing A/B
  graph identity; the two lockfile identities above are supporting evidence
  with their stated generated/ignored and checked-out-package roles.
- Provenance comments: Board unblock `9f4a86e4-cd3a-4c7b-9733-0d446c755910`,
  Board acceptance `5e906e07-77f5-4884-8e8f-b50a9f82c22f`, reviewer recheck
  `349646d5-a103-4d3a-833f-b816ef33343e`

## Command identity

The two builds used the same resolved package graph, destination, build
settings, and fresh DerivedData. The disposable checkout differed from the
baseline by exactly one source-line substitution:

```text
func finish(_ result: Result<T, Error>) -> Bool
->
func finish(_ result: sending Result<T, Error>) -> Bool
```

The bounded host command was:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development \
  -configuration Debug-Dev \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath <fresh-derived-data> \
  -clonedSourcePackagesDirPath <fresh-package-cache> \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  SWIFT_SUPPRESS_WARNINGS=NO SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' build-for-testing
```

## Normalized result

| Side | Exit | Stable diagnostic result |
|---|---:|---|
| Baseline, unchanged checkout | 65 | `EndpointOperationRunner.swift:231` CompletionGate diagnostic present; no `PendingTransactionRepository` diagnostic in the baseline excerpt. |
| After, disposable one-line variant | 65 | No `EndpointOperationRunner` diagnostic; only unrelated `PendingTransactionRepository.swift:77:31` and `:92:31` captured-`self` errors remain. |

The accepted criterion is scoped to removal of the CompletionGate diagnostic;
the two unrelated after-side errors are named latent failures and remain
outside THR-162. The isolated `swiftc` probe and reduced canaries exited zero
before and after and are retained as non-causal historical limitations.

## Durability and hashes

- Raw baseline log: `/tmp/thr160-s207-mirror.WhUGem/xcodebuild.log`, line
  83411, 20,249,234 bytes, SHA-256
  `1f631d275963f822b3551b3be195d722bb9b2bfbd91feac4b45789127c148b14`.
- Raw after log: `/tmp/thr162-after.xpsoPu/xcodebuild-after.log`, line 83552,
  18,389,412 bytes, SHA-256
  `48a9ffd818b057961a3da902776a50e8485d580299b8e104a53c0c1767380a4c`.
- Host lockfile: `Wallet.xcworkspace/xcshareddata/swiftpm/Package.resolved`,
  21,833 bytes, SHA-256
  `556fcb632348d1962b888feed65b25400acee71bcd9c3ce7e04901473a0f33ab`.
- Nested kit lockfile: `SourcePackages/checkouts/ThorChainKit.Swift/Package.resolved`,
  2,320 bytes, SHA-256
  `d4f311c9e43a1e20be3288564e5cc87b8d7cbc8ad8eb61d37e7a33e4bfd4730d`.
- The durable artifact hash is recorded by `run_state.py` for this file and
  binds the normalized result, raw-log hashes, both lockfile roles and hashes,
  provenance, and command above.
