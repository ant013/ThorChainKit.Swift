# Sprint 1 — Foundation Design Package

## Status

**Architecture review: ACCEPT after revision of the Maestro boundary. Implementation: blocked until explicit user approval.**

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

- The kit will be created in a separate future repository, not inside Unstoppable Wallet.
- The current folder contains only design/research/report artifacts.
- `iOS Example` uses the verified TronKit project/workspace structure, but does not copy its hardcoded mnemonic, plaintext persistence, or demo lifecycle ownership.
- Vultisig is used only as a THORChain-specific supporting reference and a source of missing protocol details.
- Production integration follows the exact current-tree Unstoppable contracts; similar names do not constitute evidence.
- Live-network and Example UI gates are opt-in; fixture success is never labeled as live evidence.
- Maestro applies only to `ThorChainKit/iOS Example`; no `.maestro`, runner, acceptance fixtures, or launch-argument hooks are added to Unstoppable.

## Sprint Scope

In scope: package/API foundation, endpoint policy, address derivation/codec, read client, RUNE balance sync, persistence/lifecycle, and address/balance/deposit integration in Unstoppable.

Out of scope: send/sign/broadcast, transaction history, native swap, THORName, private-key/watch-only accounts, and production custom-node UI.

## Areas Affected by Future Implementation

- new `ThorChainKit.Swift`: package sources, tests, Example app, Maestro workspace;
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
| `S1-01-package-public-api.md` | `24052b1f561a5e38c10496367710d07285a556e20592530637ce07b79e7c27e9` |
| `S1-02-network-endpoint-policy.md` | `586c88d968c9a21ff072ba42ea44f6b25eca82aff718a7a179a5e200acafda78` |
| `S1-03-derivation-address-codec.md` | `348a9e76565a2bca23353e11f33d71102bcdc0b73d98adff6d2ef19d2e4422f0` |
| `S1-04-thornode-read-client.md` | `6b0db70a01cbe816040461961d839ab12247ab377fba727431f683c5836eebe3` |
| `S1-05-rune-account-sync.md` | `c042b20d9c2264ad7bcfe271c0b221bfaff06b16a6e3ce56bf84c4a7c8950972` |
| `S1-06-unstoppable-lifecycle-composition.md` | `4252d1cdeaf672998e4c733f0da5f875202ff4c9a2fc93d8823a7cdee275e7f6` |
| `S1-07-unstoppable-rune-surface.md` | `4694f0a5b67607dd552a1887b03998b7b182bb7451055f863dff66ffe01940ba` |
| `test-plan.md` | `4c08ea814da8a8ba6a6426dea61a21a21b8bf3bfd4653714503c49c1d0849a45` |
<!-- SPEC_HASHES_END -->
