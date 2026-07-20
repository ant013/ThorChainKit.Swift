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
