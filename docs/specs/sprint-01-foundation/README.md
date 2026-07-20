# Sprint 1 — Foundation Design Package

## Status

**Architecture review:** S1-01 revision 11 awaits fresh adversarial review; implementation remains blocked until explicit revision-bound user approval.

This package divides the first standalone `ThorChainKit` sprint into seven sequential vertical slices. Each slice concludes with an observable result in the evolving `iOS Example`; S1-06 and S1-07 additionally verify the real Unstoppable Wallet integration surface.

## Goal and Success Criterion

At the end of Sprint 1, a mnemonic account manually enables native RUNE in Unstoppable Wallet, obtains a deterministic `thor1…` address, sees the complete live balance, and, after terminate/relaunch, restores the same wallet and cached state followed by fresh synchronization.

Success is demonstrated simultaneously by four independent layers:

1. deterministic Swift package tests;
2. runnable SwiftUI `iOS Example`, retaining only the verified kit workspace topology, and fixture Maestro flows;
3. opt-in mainnet compatibility tests;
4. Unstoppable `AppTests` and a manual create/import/enable/relaunch checklist without Maestro.

## Slices

| ID | Spec | Verifiable outcome |
|---|---|---|
| S1-01 | [`S1-01-package-public-api.md`](S1-01-package-public-api.md) | package, public facade, test target, and Example scaffold build |
| S1-02 | [`S1-02-network-endpoint-policy.md`](S1-02-network-endpoint-policy.md) | endpoint family proves network identity and role freshness fail-closed |
| S1-03 | [`S1-03-derivation-address-codec.md`](S1-03-derivation-address-codec.md) | independent vectors produce the exact THORChain address; invalid inputs are rejected |
| S1-04 | [`S1-04-thornode-read-client.md`](S1-04-thornode-read-client.md) | complete account/balances read pinned to one Cosmos height |
| S1-05 | [`S1-05-rune-account-sync.md`](S1-05-rune-account-sync.md) | lifecycle, cache, and publication are protected by cancellation/generation invariants |
| S1-06 | [`S1-06-unstoppable-lifecycle-composition.md`](S1-06-unstoppable-lifecycle-composition.md) | manually constructed RUNE wallet passes the exact WalletCore adapter contracts |
| S1-07 | [`S1-07-unstoppable-rune-surface.md`](S1-07-unstoppable-rune-surface.md) | MarketKit discovery and the real create/import/enable/relaunch path are completed end to end |

Consolidated verification: [`test-plan.md`](test-plan.md).

## Related Evidence

- [Verified analog family](../../research/sprint-01-analog-family.md)
- [TronKit/EvmKit Example inventory and UI acceptance](../../research/kit-example-apps-and-ui-acceptance.md)
- [Sprint roadmap](../../roadmap/sprint-01-foundation.md)
- [Adversarial review](../../reports/sprint-01-adversarial-review.md)
- [Gimle reliability](../../reports/gimle/sprint-01-gimle-reliability.md)

## Assumptions

- This repository is the product authority for the standalone kit; Unstoppable Wallet is a separate future consumer.
- The repository remains documentation-only until S1-01 receives explicit revision-bound approval.
- `Sources/ThorChainKit` is UI-agnostic: Combine is allowed for state publication, while UIKit and SwiftUI imports are prohibited.
- `iOS Example` retains the verified TronKit project/workspace structure only. Its lifecycle and presentation use SwiftUI + Combine, with no UIKit import/type/representable; it also does not copy TronKit's hardcoded mnemonic, plaintext persistence, or demo lifecycle ownership.
- The library retains iOS 13; the UIKit-free SwiftUI Example targets iOS 14 or later.
- Vultisig is used only as a THORChain-specific supporting reference and a source of missing protocol details.
- Production integration follows the exact current-tree Unstoppable contracts; similar names do not constitute evidence.
- Live-network and Example UI gates are opt-in; fixture success is never labeled as live evidence.
- Maestro applies only to `ThorChainKit/iOS Example`; no `.maestro`, runner, acceptance fixtures, or launch-argument hooks are added to Unstoppable.

## Sprint Scope

In scope: package/API foundation, endpoint policy, address derivation/codec, read client, RUNE balance sync, persistence/lifecycle, and address/balance/deposit integration in Unstoppable.

Out of scope: send/sign/broadcast, transaction history, native swap, THORName, private-key/watch-only accounts, and production custom-node UI.

## Areas Affected by Future Implementation

- this `ThorChainKit.Swift` repository: package sources, tests, Example app, Maestro workspace;
- MarketKit: THORChain blockchain/native RUNE metadata and tests;
- Unstoppable WalletCore: address factory, kit manager/factory, adapter, parser, and Core wiring;
- Unstoppable host: only existing `AppTests` and manual product acceptance; no acceptance-only runtime is added.

Exact files, classes, functions, and APIs are listed in each slice spec. Until S1-06, the reference source repositories remain read-only.

## Acceptance and Verification Order

1. Run unit/controlled/storage/package tests with a non-empty test manifest.
2. Prove the no-UIKit/no-core-SwiftUI platform scan, build the SwiftUI `iOS Example` with the local root package, and run all fixture Maestro flows.
3. Separately run opt-in mainnet compatibility tests and record the chain ID/heights/provider family.
4. Connect the kit to an Unstoppable review branch only after approval of the host spec.
5. Run `AppTests`, then manually verify create/import/enable/terminate/relaunch/App Status in the `Development` app.
6. Verify the absence of acceptance-only hooks in Unstoppable, UIKit in repository-owned production/Example source, and secrets in Example artifacts.

## Pinned Maestro Boundary

The user term `Meteora` means **Maestro**. Its scope is limited to `ThorChainKit/iOS Example`; Unstoppable is not a Maestro target in either Sprint 1 or the current roadmap.

## Integrity Manifest

SHA-256 pins the exact versions of the seven slice specs, the S1-02 recovery spec, both approved S1-02 implementation plans, and the consolidated test plan. Values are updated after any design edit; a plan pin does not imply approval.

<!-- SPEC_HASHES_START -->
| Artifact | SHA-256 |
|---|---|
| `S1-01-package-public-api.md` | `a1dc63ef44b40f2e778bd1c86df0de42846fa9e119c2c12989268a455257dd4d` |
| `S1-02-network-endpoint-policy.md` | `48f88590331c5cfca24c39632a690d69417c3be979ed61a3df355262091909cf` |
| `S1-02-swiftui-integration-recovery.md` | `13382503e6b60fd60839039794da636617a6eddfbb31abd3982a2b8860ed4569` |
| `S1-03-derivation-address-codec.md` | `429e894c2144c6f1b4b65f7fbc48838ee663472e036c4061df444df1f91c609c` |
| `S1-04-thornode-read-client.md` | `c17f04ea8d4343f558af745a58666ce3122757919a6a27600fa54d849e4ff886` |
| `S1-05-rune-account-sync.md` | `5345c4ef169d4c39187bef7371a16cae5a779164ddecbbe97a99ff12b471a0ff` |
| `S1-06-unstoppable-lifecycle-composition.md` | `0a598cdc320e5da99c805bb676241b9c1924eb2a4d9078f68a21896681fa1703` |
| `S1-07-unstoppable-rune-surface.md` | `9da09bfc288bf9e43565f503d2db06b29f57291f0870c1d9729f9d092e2f502c` |
| `docs/superpowers/plans/2026-07-19-THR-13-s1-02-network-endpoint-policy.md` | `b6f98cda1a9e6c04107633a871e63b5c47be7e456150288ca63f716a814fd497` |
| `docs/superpowers/plans/2026-07-20-THR-32-s1-02-swiftui-integration-recovery.md` | `02078fd98f9bdea0c064e91d1449524eb8ca943e0b10458f323cfaadf886635a` |
| `test-plan.md` | `e504823b0b22ae202fd453d0bec7283e79e04ee0b39b985c86535a0fccbc8ce8` |
<!-- SPEC_HASHES_END -->
