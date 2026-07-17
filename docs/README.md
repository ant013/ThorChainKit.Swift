# ThorChainKit — Project Documentation

This folder is the documentation entry point for the standalone `ThorChainKit` project, intended for subsequent integration into Unstoppable Wallet iOS. The initial repository seed is documentation-only: research, the roadmap, architecture specs, and evidence reports live here before the first implementation slice.

## Navigation

- [`research/`](research/) — protocol research, the verified analog family, Vultisig gap analysis, and an evidence-based analysis of the Paperclip roadmap walker.
- [`roadmap/`](roadmap/) — the overall project plan and the vertical Sprint 1 plan.
- [`specs/`](specs/) — a separate detailed spec for each slice.
- [`reports/`](reports/) — reports on Vultisig and Gimle reliability.

## Current Status

| Area | Status |
|---|---|
| Overall project architecture | defined |
| Sprint 1 | divided into 7 verifiable slices |
| Analog family | verified against exact local source trees; Gimle limitations are reported separately |
| Vultisig | separate deep analysis completed |
| Example/UI acceptance | TronKit/EvmKit apps verified; evolving `iOS Example` + Maestro strategy added |
| Paperclip roadmap walker | historical mechanics reconstructed; cleaned-up ThorChain contract documented; old data was not deleted |
| ThorChainKit code | not started; the documentation seed precedes S1-01 |
| Unstoppable Wallet changes | not performed |

## Evidence Rules

1. Gimle is used to find candidates.
2. Every architecturally significant claim is cross-checked in the exact local directory mapped by Gimle, using Serena and/or `rg`.
3. Vultisig is treated as a THOR-specific supporting reference and a source of counterexamples, but not as the primary architectural framework.
4. Source repositories are read-only. All project files are created only here.
5. Implementation begins only after the user explicitly approves the corresponding design package.

Key supplementary report: [`research/kit-example-apps-and-ui-acceptance.md`](research/kit-example-apps-and-ui-acceptance.md).

Paperclip orchestration: [`research/paperclip-unstoppable-roadmap-walker-analysis.md`](research/paperclip-unstoppable-roadmap-walker-analysis.md) and [`research/paperclip-thorchain-roadmap-walker-contract.md`](research/paperclip-thorchain-roadmap-walker-contract.md).

Sprint 1 package submitted for approval: [`specs/sprint-01-foundation/README.md`](specs/sprint-01-foundation/README.md). Final independent review: [`reports/sprint-01-adversarial-review.md`](reports/sprint-01-adversarial-review.md).

Vultisig deep analysis: [`reports/vultisig-ios-deep-analysis.md`](reports/vultisig-ios-deep-analysis.md).

## Pinned Source Revisions

| Source | Revision |
|---|---|
| Unstoppable Wallet iOS | `5b06860e6e0068f05411cacc568bbb50bca1c588` |
| TronKit.Swift | `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` |
| EvmKit.Swift | `be0286317c202084784c5a695928cdc985c4ff7b` |
| HsCryptoKit.Swift | `7c11ad0e690cbb178a70f3b9d1116d0a37a51a41` |
| HdWalletKit.Swift | `163b4e253aa763babeb6d14f246e1d81cfa0473e` |
| MarketKit.Swift | `95c92c876c3f40c28816e8e9891d6ffaf6eb0828` |
| BitcoinCore.Swift | `5b49f424f495904cf06519b1a7b861ef37b45b50` |
| Vultisig iOS pinned clone | `d3123dbe6ef1103937c272a8b1cd81f613af0acc` |
