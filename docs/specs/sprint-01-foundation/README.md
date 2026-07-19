# Sprint 1 — Foundation Design Package

## Status

**Architecture review:** S1-01 revision 11 awaits fresh adversarial review; implementation remains blocked until explicit revision-bound user approval.

This package divides the first standalone `ThorChainKit` sprint into seven sequential vertical slices. Each slice concludes with an observable result in the evolving `iOS Example`; S1-06 and S1-07 additionally verify the real Unstoppable Wallet integration surface.

## Goal and Success Criterion

At the end of Sprint 1, a mnemonic account manually enables native RUNE in Unstoppable Wallet, obtains a deterministic `thor1…` address, sees the complete live balance, and, after terminate/relaunch, restores the same wallet and cached state followed by fresh synchronization.

Success is demonstrated simultaneously by four independent layers:

1. deterministic Swift package tests;
2. runnable TronKit-derived `iOS Example` and fixture Maestro flows;
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
- `iOS Example` uses the verified TronKit project/workspace structure, but does not copy its hardcoded mnemonic, plaintext persistence, or demo lifecycle ownership.
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
2. Build `iOS Example` with the local root package and run all fixture Maestro flows.
3. Separately run opt-in mainnet compatibility tests and record the chain ID/heights/provider family.
4. Connect the kit to an Unstoppable review branch only after approval of the host spec.
5. Run `AppTests`, then manually verify create/import/enable/terminate/relaunch/App Status in the `Development` app.
6. Verify the absence of acceptance-only hooks in Unstoppable and secrets in Example artifacts.

## Pinned Maestro Boundary

The user term `Meteora` means **Maestro**. Its scope is limited to `ThorChainKit/iOS Example`; Unstoppable is not a Maestro target in either Sprint 1 or the current roadmap.

## Integrity Manifest

SHA-256 pins the exact versions of the seven slice specs, the active S1-02 implementation plan, and the consolidated test plan. Values are updated after any design edit; a plan pin does not imply approval.

<!-- SPEC_HASHES_START -->
| Artifact | SHA-256 |
|---|---|
| `S1-01-package-public-api.md` | `3c42cf77364c6ca27388ec56a1573395ca7fba9b48ddb89f4ae371af79bbd53a` |
| `S1-02-network-endpoint-policy.md` | `ffbacae285f7ec8dbdca818bf850062b62222d4bb65a479b7ce4f9929c0d5194` |
| `S1-03-derivation-address-codec.md` | `bb06bdfeae3f6b5dfa54b7b49c689ade3fc6454b7666f158e1c59b5e2554d58a` |
| `S1-04-thornode-read-client.md` | `c2d51c8be3a19fdd96ea21e6501aed3d27489a675ef455defa444118a0db9595` |
| `S1-05-rune-account-sync.md` | `9ce0432cc1bb75f47dd803d9db8c57f5cd24c87d86a9d7bc61ffe33a215ce305` |
| `S1-06-unstoppable-lifecycle-composition.md` | `fc6bc88fa09aa18223e52edf22a35f129f871b5c4a9d9c59a370c91604854827` |
| `S1-07-unstoppable-rune-surface.md` | `9da09bfc288bf9e43565f503d2db06b29f57291f0870c1d9729f9d092e2f502c` |
| `docs/superpowers/plans/2026-07-19-THR-13-s1-02-network-endpoint-policy.md` | `2e70a48d94eace36c5589f53fe2ea0db5c53df68252e73c01d0bfe2a04fa9f9a` |
| `test-plan.md` | `eaf96c2c26dae79ae0f90fdfd3dcd9f12f75878db7699f6597040e4f24a815c0` |
<!-- SPEC_HASHES_END -->
