# THR-62 S1-03 Gimle Reliability Report

## Run identity

- Task: THR-62 — S1-03 Derivation and Address Codec
- Repository: ThorChainKit.Swift
- Integration baseline: `origin/main` at `7fd9663442a0e6dcd9c01c4ab04d35f3abd96fc4`
- Working branch: `docs/THR-62-s1-03-derivation-address-codec`
- Scope: design and evidence only; no implementation files were changed
- Palace runtime: `native-dev@0e9cf57c00ff970f584256126b500166580e7a72`
- Codebase-memory project: `Users-ant013-Data-AI-thorchain`
- Indexed target commit: unavailable

## Trust result

**RED — discovery-only Gimle evidence with explicit local fallback.** Palace
has no registered ThorChainKit project or target freshness mapping, and Serena
returned no symbols for the exact current Swift target. Load-bearing target
claims were therefore verified with the codebase-memory graph followed by
targeted local `rg`, numbered source reads, and Git identity checks. The
external Gimle checkpoint is retained outside this repository and is never
committed.

## Calls and defects

The run recorded eight bounded Palace/codebase-memory events. E-0001 reported
the missing target mapping; E-0002 through E-0004 located the selected
HdWalletKit, HsCryptoKit, and BitcoinCore analog families; E-0005 and E-0006
confirmed Palace runtime and memory health; E-0007 and E-0008 returned broad
THOR/Unstoppable candidate searches requiring local verification.

| ID | Classification | Impact | Workaround |
|---|---|---|---|
| `GIM-THR62-TARGET-MAPPING` | confirmed coverage gap | Freshness and target-tree truth cannot be established by Palace | Use codebase-memory, exact branch identity, targeted `rg`, and Git reads |
| `SERENA-THR62-SWIFT-INDEX` | confirmed environment drift | Symbol navigation is unavailable | Do not claim Serena verification; use exact local reads |
| `GIM-THR62-TRON-SEARCH-WARNING` | probable coverage gap | Broad results can pollute THOR analog selection | Use only pinned local THOR checkout evidence |
| `GIM-THR62-UW-SEARCH-WARNING` | probable coverage gap | Broad results can pollute wallet-consumer selection | Keep Unstoppable evidence supporting-only and locally verified |

The target-mapping defect forces RED. No Gimle result was used as the sole
proof of a cryptographic or public-API invariant.

## Analog evidence disposition

- Derivation: HdWalletKit is the primary lifecycle/path analog; HsCryptoKit
  supplies supporting crypto primitives; the pinned Vultisig THOR assertion is
  a supporting public vector. HsCryptoKit private-key convenience APIs are
  rejected as a kit ownership boundary.
- Address codec: the current S1-01 `Network`/`Address`/`Bech32Codec` family is
  primary; HsCryptoKit HASH160 and BitcoinCore classic Bech32 are supporting
  references. BitcoinCore SegWit handling is a rejected counterexample.
- Vultisig is not treated as the lifecycle or ownership spine.

Three fresh bounded adversarial lanes (architecture, security/protocol safety,
and verification/operability) initially returned `REVISE`. Revision 2 of the
spec and plan addresses their Critical/High findings by removing secret-bearing
fixtures, requiring immutable vector provenance, adding crypto capability and
source-closure gates, defining typed unavailable-context behavior, authenticating
baseline/platform/CI checks, and making the Example Maestro path reachable and
real-call-path dependent. Explicit approval is still required before
implementation.

## Discovery 2/2 frozen allowlist and revision 6 closure

ThorChainCodeReviewer independently re-ran the three bounded read-only lanes
on the pushed revision-2 head and returned `REVISE`. Discovery 2/2 is now
frozen; no new discovery IDs may be opened. The operator accepted the following
allowlist for closure-only rework:

- `S103-ARCH-01..05`: exact analog commit/path/role manifest; path raw-value and
  typed-error consumer contract; direct Address delegation without an
  error-erasing Boolean parser; Example Xcode target/navigation composition;
  cumulative S1-02 CI authority and exact three-flow transition.
- `THR62-SEC-B01..05`: no hidden `.mainnet` default trap; operational BIP44
  path binding; exact vector values/provenance; falsifiable dependency/capability
  closure; deterministic parser-context failure seam.
- `VOP-01..05`: reachable Example call path; authenticated expected base/head
  and clean-worktree identity; fixed resolved dependency SHAs; schema-proven
  independent-source provenance; deterministic fuzz/context-failure replay.

Revision 3 closed the security IDs and the non-allowlisted review items, but
closure 1/5 returned seven frozen High IDs for revision. Revision 4 addressed
the first closure pass. Closure 2/5 retained four frozen High IDs, and closure
3/5 retained one frozen High ID, so revision 6 addresses only that remaining
finding: SplitMix64 state advancement now explicitly uses modulo-2⁶⁴ wrapping
arithmetic (`&+`). The BitcoinCore path is now the reproducible
`Sources/BitcoinCore/Classes/SegWit/Bech32.swift` path; the CI contract now
requires full-history checkout plus an authenticated exact `origin/main`
refspec/equality check; dependency provenance now freezes the inherited
S1-01 baseline and all four direct/transitive S1-03 closure pins; and the fuzz
fixture now specifies the 3072-output SplitMix64 stream, modulo-2⁶⁴ state
advancement, little-endian packing, four-byte truncation, and `count == 1024`.
The revision preserves the accepted protocol choices and remains
documentation-only. The next authorized action is closure review 4/5 on the
exact pushed head; approval and implementation remain prohibited until
CodeReviewer ACCEPT.

## Reproduction and verification record

The evidence sequence was: activate the exact target workspace; query
codebase-memory first; verify the S1-01 seam and public tests locally; verify
pinned analog checkouts and commits; record the external checkpoint; then
review the revised design. The design package is limited to:

- `docs/specs/sprint-01-foundation/S1-03-derivation-address-codec.md`
- `docs/specs/sprint-01-foundation/S1-03-delta-matrix.md`
- `docs/superpowers/plans/2026-07-21-THR-62-s1-03-derivation-address-codec.md`
- this report

The external checkpoint contains the detailed event, bug, analog, decision,
and artifact records. It is not a repository path and must not be added to a
commit.

## Revision 7 — Board-approved platform correction

The Board approved removal of the false macOS package-platform contract while
preserving the iOS 13 library floor and iOS 14+ SwiftUI Example floor. The
operator independently proved the replacement verification substrate on exact
head `f85b1e8eaa054bbf9644c270b355397771d7dae6` with:

```text
xcodebuild -scheme ThorChainKit -destination 'platform=iOS Simulator,id=<exact-udid>' -derivedDataPath <temporary-derived-data> CODE_SIGNING_ALLOWED=NO test
```

The dependency closure resolved and compiled for `arm64-apple-ios13.0-simulator`;
the command failed only because `CosmosAccountAddressDeriver` was declared in
both `AccountAddressFactory.swift:3` and `CosmosAccountAddressDeriver.swift:17`.
This is an implementation defect for the Engineer, not a platform blocker.

Revision-7 design delta: `Package.swift` is iOS-only; S1-01 package topology,
S1-02 CI policy, and S1-03 verification must use the exact iOS Simulator
`xcodebuild` narrow/full package gates. Host `swift build`/`swift test` are no
longer product acceptance commands. The external Gimle checkpoint remains
outside the repository; no repository-local `audit/` checkpoint is permitted.
Gimle trust remains **RED** because the target mapping is still unavailable;
current-tree facts are independently verified with codebase-memory, Serena,
targeted `rg`, and Git.

The corrected design package also binds the real
`docs/specs/sprint-01-foundation/S1-03-delta-matrix.md`, updates the checked-in
`S1-01-package-public-api.md` platform/verifier contract, and replaces the
earlier S1-01 xUnit/transcript and host BigInt obligations in
`test-plan.md` with iOS Simulator/xcresult evidence. These are documentation
changes only; implementation remains unauthorized pending independent review.

### Host-gate census

The bounded current-tree census found package-gate operations in
`.github/workflows/ci.yml`, `Scripts/verify-s1-02-ci-policy.sh`,
`Scripts/verify-s1-03.sh`, `Scripts/verify-s1-01.sh`,
`Scripts/verify-s1-02.sh`, `Scripts/test-s1-01-mutants.sh`, and
`Scripts/verify-bigint-floor.sh`. Revision 7 now requires simulator
Xcode/xcresult or iOS-consumer replacements for every one of those paths,
including symbolgraph extraction, test discovery, PublicApi xUnit execution,
strict-concurrency builds, skip canaries, mutant runs, and copied-package
BigInt-floor checks.

The `xcrun swift` calls in `Scripts/run-maestro.sh`,
`Scripts/test-run-maestro.sh`, `Scripts/verify-s1-01-factory.swift`, and
`Scripts/verify-s1-02-live-evidence.swift` were verified as standalone scanner
or evidence tooling. They do not resolve `Package.swift` or receive product
test credit and are explicitly retained as non-product host tooling.
