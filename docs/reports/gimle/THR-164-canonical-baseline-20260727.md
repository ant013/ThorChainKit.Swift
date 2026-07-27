# THR-164 canonical baseline evidence

**Purpose:** durable record of the pre-fix host reproduction and the exact
evidence that must be refreshed after implementation.

## Baseline identity

- ThorChainKit canonical SHA: `922a5badac5a9b80361a02dff5c75711f00da53c`
- Xcode: `Xcode 26.6 (Build version 17F113)`
- Host configuration: `Wallet.xcworkspace`, scheme `Development`,
  configuration `Debug-Dev`, generic iOS Simulator, `build-for-testing`
- Strict settings: `SWIFT_SUPPRESS_WARNINGS=NO`,
  `SWIFT_STRICT_CONCURRENCY=complete`, `OTHER_SWIFT_FLAGS=$(inherited)
  -warn-concurrency`, existing warnings-as-errors policy
- Source log captured by the canonical THR-160 board run; the host-local path
  is intentionally omitted from the repository:
- Source log SHA-256:
  `6fa13e6db964e9d67546f86a688d31ea4b19693633bf21fb8f425eee51c382ef`

## Observed baseline

The log contains a `SwiftCompile` command for the ThorChainKit target that
lists `PendingTransactionRepository.swift`, followed by the two expected
complete-concurrency diagnostics at `PendingTransactionRepository.swift:77`
and `:92`. The build terminates with `** TEST BUILD FAILED **` after reaching
that kit compile job. This is the baseline acceptance fact; the source log is
retained as a local verification-host artifact and its digest makes any
replacement artifact detectable.

## Required refresh after implementation

The implementer/QA engineer must append or replace this manifest with
sanitized run labels, exact command text, four host-pin checks, exact resolved
SHAs, Xcode/Swift version identifiers, graph and log hashes, exit statuses, and
selected positive `SwiftCompile` and diagnostic lines. Absolute checkout,
SourcePackages, DerivedData, mirror-config, and other operator paths remain
local-only run artifacts. The post-fix host log must contain no diagnostic at
the two named lines. A build that exits before the ThorChainKit compile job is
not a passing proof.

Gimle/Palace trust remains RED because the ThorChainKit project mapping and
Serena navigation are unavailable; current-tree `rg`, Git, and
codebase-memory evidence are the authority for this slice.
