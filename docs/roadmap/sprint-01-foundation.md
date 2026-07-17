# Sprint 1 — Foundation and the First Read-Only RUNE Wallet

## Sprint Outcome

At the end of Sprint 1, a user with a mnemonic account can manually enable native RUNE in Unstoppable Wallet, obtain a deterministic mainnet `thor1…` address, see the live balance, and receive the same address and synchronized balance again after fully restarting the app.

Send, history, and swap are intentionally outside Sprint 1.

## Slice Sequence

| ID | Slice | Verifiable outcome | Depends on | Status |
|---|---|---|---|---|
| S1-01 | Package and public API | standalone package builds; local-package `iOS Example` and the first Maestro fixture flow run | — | Pending |
| S1-02 | Network and endpoint policy | an endpoint with the wrong chain ID/role or a stale endpoint is rejected fail-closed | S1-01 | Pending |
| S1-03 | Derivation and address codec | an official/independent vector produces the expected `thor1…`; wrong HRP/checksum is rejected | S1-01 | Pending |
| S1-04 | THORNode read client | fixtures and opt-in mainnet requests return typed status/account/balances | S1-02, S1-03 | Pending |
| S1-05 | RUNE account sync | start/refresh/stop/restart produce an atomic account snapshot without stale publication | S1-04 | Pending |
| S1-06 | UW lifecycle composition | the adapter creates the kit, owns its lifecycle, and displays a manually constructed RUNE wallet | S1-05 | Pending |
| S1-07 | UW discovery/address/balance/restart | MarketKit metadata + real create/import/enable/relaunch flows | S1-06 | Pending |

The status cell is the canonical repository marker. A completed row contains `✅ Implemented — PR #<real> — <YYYY-MM-DD>` and no commit SHA. Exact reviewed `headRefOid` and post-merge `mergeCommit.oid` remain external review/merge evidence.

## End-to-End Verification Surface

S1-01 creates an `iOS Example` based on the verified TronKit structure (`.xcodeproj` + shared scheme + workspace connected to the package root). Each subsequent slice extends the same app and a separate Maestro flow:

```text
S1-01 launch/public API
  → S1-02 endpoint identity/fail-closed
    → S1-03 address codec
      → S1-04 complete account read
        → S1-05 lifecycle/cache/restart
          → S1-06 host adapter AppTests
            → S1-07 Unstoppable AppTests + manual create/import/relaunch/App Status
```

The Example app is a manual/live harness and UI acceptance target, not production architecture. XCTest remains the source of deterministic low-level correctness; the real Unstoppable app remains the final host gate.

## Architectural Flow

```text
Public key / mnemonic adapter
        │
        ▼
ThorChainKit.Address + Network
        │
        ▼
EndpointPool actor ── validates chain-id / role / freshness
        │
        ▼
LiveThorNodeClient ── status + auth account + paginated bank balances
        │
        ▼
AccountSyncer actor ── one generation / atomic snapshot / cancellation
        │
        ▼
ThorChainKit.Kit ── synchronous state + Combine publishers
        │
        ▼
ThorChainAdapter ── Rx bridge + IBalanceAdapter + IDepositAdapter
        │
        ▼
Wallet list / Receive / restart reconstruction
```

## Sprint-Wide Invariants

- `Network` atomically binds the expected chain ID and account HRP.
- Mainnet: chain ID `thorchain-1`, HRP `thor`.
- Stagenet/chainnet do not receive permanently hardcoded public endpoints; configuration requires an explicitly confirmed chain ID because official stagenet endpoints and IDs change.
- A Cosmos account address is 20 bytes: `RIPEMD160(SHA256(compressed secp256k1 publicKey))`, followed by Bech32 encoding.
- The default path is `m/44'/931'/0'/0/0`; the kit does not store the seed/private key.
- `rune` is the exact native denom; raw amounts are stored as unsigned integers, not `Decimal`/`Double`.
- One account refresh performs one complete paginated bank fetch and one auth fetch on one validated endpoint lease.
- The account and all bank pages are pinned to one Cosmos REST height and confirm it through the response header; Comet height does not substitute for the account observation height.
- Account-not-found, zero balance, stale cache, decode failure, and transport failure are distinct states.
- `CancellationError` is not converted into a user-facing sync error and does not trigger failover.
- After `stop()`, completion from an old generation cannot change state.
- The manager does not start the kit. The lifecycle belongs to `ThorChainAdapter` and runs through the shared `AdapterManager`.

## Real Acceptance Script

1. Build the standalone `ThorChainKit` and run the deterministic suite.
2. Build `iOS Example` through the workspace and run all fixture Maestro flows.
3. Run the opt-in live read for a known public mainnet address; save the endpoint, chain ID, height, and RUNE amount.
4. Connect the local package to an Unstoppable test branch only during S1-06 implementation.
5. Create a new mnemonic account.
6. Open Manage Wallets, find and enable RUNE/THORChain.
7. Verify that Receive displays a valid `thor1…` address and reopening it returns the same address.
8. Verify the live balance and its raw/decimal representation with metadata decimals `8`.
9. Terminate the app process and launch it again.
10. Confirm that the wallet is restored from storage, the adapter is re-created, cached state is shown as stale until the network refresh, and then becomes fresh.
11. Repeat the import flow and verify App Status manually in the `Development` app; do not use Maestro with Unstoppable.
12. After state becomes fresh, terminate the app, disable the network, relaunch without clearing data, and confirm the same wallet/address/cached balance together with an explicit stale/error state.
13. Restore the network and confirm fresh recovery without changing the address or creating a second adapter.
14. Remove the RUNE wallet during active synchronization; `AppTests` proves one `stop`/cancellation, and the manual run proves there are no subsequent UI updates.
15. On a dedicated test device/simulator, clear app data, perform a clean install, and prove RUNE discovery without an old MarketKit cache.

## Sprint-Wide Non-Goals

- private-key/watch-only account types;
- send/sign/broadcast, fee, and sequence reservation;
- history/transaction adapter;
- native swap and Midgard action tracking;
- THORName/TNS resolution;
- automatic addition of RUNE to every new account;
- TRON-style account activation/deposit warning;
- URI/deep-link scheme without a confirmed standard.
