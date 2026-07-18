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

SHA-256 pins the exact versions of the seven approved specs and the test plan. Values are updated after any design edit.

<!-- SPEC_HASHES_START -->
| Artifact | SHA-256 |
|---|---|
| `S1-01-package-public-api.md` | `9c42bb75fc5f8cbcb8f658db470d09ae500e8871ac60b155d913ad6d429d76de` |
| `S1-02-network-endpoint-policy.md` | `fa459987d8596746ca9068c9bd4be1a687691d89c610f845488710cf814f55c7` |
| `S1-03-derivation-address-codec.md` | `f1301dc6cbab531572585f66bcce3431b7c106c27286fceb2b2035869eb60715` |
| `S1-04-thornode-read-client.md` | `041e1cb8906751a9a287a4eb4e74122f6dea6422a0230395d364a223b0f89361` |
| `S1-05-rune-account-sync.md` | `d1b255b568e0d8662f80a50dd50d0596ddf7c61880e023d03f0474c103fe3842` |
| `S1-06-unstoppable-lifecycle-composition.md` | `012b20e9bb4cc3cca9f6d7261dce1d665d59bc995ad422d458543cd9de44d3e2` |
| `S1-07-unstoppable-rune-surface.md` | `9da09bfc288bf9e43565f503d2db06b29f57291f0870c1d9729f9d092e2f502c` |
| `test-plan.md` | `5a4f8c4587119c3530885a1a4f8db1f300ad4074c1a2b6caa82ef9104fdca898` |
<!-- SPEC_HASHES_END -->
