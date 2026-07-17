# Gimle reliability report — THR-12 S1-01

## Status

- Workflow phase: adversarial review.
- Trust: **RED**.
- ThorChainKit evidence base: `771bad30bb4ff20fa32ed0f4be260a7b934899e9`.
- Canonical machine checkpoint: `audit/runs/thorchainkit-s1-01-THR-12-20260717/state.json` in the Gimle skills audit root.
- Canonical generated report: `audit/runs/thorchainkit-s1-01-THR-12-20260717/gimle-report.md` in the same audit root.

RED describes Gimle trust, not the independent current-tree evidence. Gimle was used for candidate discovery; selected S1-01 decisions use Serena plus targeted `rg`/Git verification of the mandated checkouts.

## Substrate Results

- Codebase-memory project `Users-ant013-Data-AI-thorchain` is ready with 433 nodes and 431 edges; it contains documentation sections and no implementation symbols.
- Serena was activated on the exact ThorChainKit workspace before local verification.
- Gimle runtime identity resolved to `52bb684fdd9492519ed7c87b0cae67c7b978810e`; Neo4j and native code discovery were reachable.
- Twelve Gimle calls were recorded: 11 success, one warning, no protocol errors, and no false-success envelope.
- The warning was a deliberately rejected broad `AdapterManager` query that mixed current and legacy paths.

## Trust Defects

| ID | Severity | Result | Impact | Workaround |
|---|---|---|---|---|
| `GIM-THR12-TRON-MAPPING` | high | Gimle maps TronKit at `f8ce0c00…`; the mandated checkout is `aa691bcd…`. | Indexed package/facade results cannot establish the primary analog. | Use discovery only; verify the mandated checkout with Serena, `rg`, and Git. |
| `GIM-THR12-UW-MAPPING` | high | Gimle maps Unstoppable at `1eeed4e9…`; the mandated checkout is `5b06860e…`. | Indexed consumer/lifecycle results may describe a different revision. | Verify only the pinned WalletCore paths in the mandated checkout. |
| `GIM-THR12-EVM-PATH` | low | Gimle and the mandated EvmKit roots differ, but both resolve to `be028631…`. | Path identity must remain explicit. | Cite the shared commit and independently verify the mandated tree. |
| `GIM-THR12-BROAD-ADAPTER` | low | An unscoped name query returned 102 mixed legacy/current matches. | The result cannot select a lifecycle consumer. | Use the exact WalletCore path; the broad result influenced no decision. |

The two high mapping defects force RED trust. Their accepted fallback claims are separate current-tree facts; contradicted Gimle claims remain rejected in the checkpoint.

## Verified Analog Family

| Slice | Primary | Supporting | Rejected counterexamples | Required delta |
|---|---|---|---|---|
| S1-01A package/test foundation | TronKit `Package.swift` at `aa691bcd…` | TronKit local-package workspace | EvmKit manifest without a test target | Swift 5.10, iOS 13, BigInt only, one library, seven public-API tests |
| S1-01B public facade/lifecycle | TronKit `Kit` and factory at `aa691bcd…` | Unstoppable `TronKitManager` and `AdapterManager` at `5b06860e…` | duplicate demo lifecycle ownership and mnemonic persistence | typed configuration errors, collision-resistant namespace, internal DI, inert factory, idle/zero initial state |
| S1-01C Example/UI gate | TronKit Example workspace at `aa691bcd…` | EvmKit workspace at `be028631…` | demo secrets/duplicate starts and Vultisig zero-case-green fixture discovery | fixture-only diagnostics, stable accessibility IDs, secret-free artifacts, manifest/JUnit-count guards |

All three slices passed the mechanical verified-analog gate. The lifecycle and UI-test roles without matching analog tests carry explicit bounded-search waivers; their missing coverage is a required test-first delta, not an absence claim from Gimle.

## Load-Bearing Current-Tree Anchors

- `TronKit.Swift@aa691bcd:Package.swift:9` and `:40` — one library product and a real test target.
- `TronKit.Swift@aa691bcd:Sources/TronKit/Core/Kit.swift:8`, `:212`, and `:246` — facade, explicit lifecycle, and composition factory.
- `TronKit.Swift@aa691bcd:iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata:4` — project plus local package root.
- `EvmKit.Swift@be028631:Package.swift:10` and `:26` — library/target with no test target.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:58` and `:96` — consumer composition plus manager-owned start.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:74` and `:83` — generic adapter lifecycle ownership.
- `vultisig-ios@d3123dbe:VultisigApp/VultisigAppTests/Chains/ChainHelperTests.swift:53` — prefix filter with no matching committed fixture.

## Review Constraints

- The target repository remains documentation-only; no implementation path exists at the evidence HEAD.
- Maestro CLI is unavailable on the evidence machine, so no fixture flow is claimed green during design review.
- Public `Address` construction versus the deferred S1-03 codec and the pre-merge squash-SHA marker rule remain explicit adversarial-review questions.
- The Unstoppable analog profile was not loaded because S1-01 contains no Unstoppable integration change.
- No reference repository was modified, and no secret, mnemonic, credential, or operator-local absolute path is stored in this repository report.
