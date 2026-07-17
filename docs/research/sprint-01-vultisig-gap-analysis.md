# Sprint 1 — Vultisig gap analysis

The full app-wide report is available at [`../reports/vultisig-ios-deep-analysis.md`](../reports/vultisig-ios-deep-analysis.md). This document records only what affects the seven Sprint 1 slices.

## What can be used as a requirement/fixture

- Environment HRP: `thor`, `cthor`, `sthor`.
- Default derivation path `m/44'/931'/0'/0/0` and the existing compressed-public-key vector.
- Specific read paths: `/status`, `/thorchain/network`, `/cosmos/bank/v1beta1/balances/{address}`, auth account endpoint.
- Decimal numbers arrive as strings; the native denom is exactly `rune`.
- A denom may contain `/` and must be percent-encoded correctly.
- Freshness must be explicit: cached versus network-only/fail-closed.
- Bank pagination must terminate only when `next_key` is empty.

## What must not be carried over

- `Vault`, `ChainPublicKey`, `isDerived`, `TssGetDerivedPubKey`, and WalletCore signing protobuf.
- A single app service protocol combining account, swap, staking, yield, TNS, and broadcast.
- Three nearly duplicate environment API classes instead of a parameterized client.
- `DispatchGroup.wait()` around an async chain-ID request.
- Invalid numeric string → zero.
- HTTP 2xx → `networkVerified: true` without checking the response body.
- Sequence growth as evidence that a specific transaction has been confirmed.
- Memory-only pending state with unconditional deletion after 10 minutes.

## Critical counterexample: mixed identity

Vultisig permits a configuration in which:

1. the mainnet chain is selected as `.thorChain`;
2. a custom endpoint returns any 2xx and is considered verified;
3. the chain ID obtained from the endpoint is cached indefinitely;
4. the validator continues to require `thor1…`;
5. signing uses the chain ID of a different network.

`ThorChainKit` must make such a configuration unrepresentable: `Network` atomically carries the expected chain ID + HRP, and an endpoint becomes active only after an exact identity check.

## Account-sync gap

In Vultisig, balance sync is performed per coin even though every call obtains the full bank balance list. For N denoms, this creates N identical requests, while token discovery may receive a different snapshot. In the kit, one refresh must:

1. obtain all balance pages exactly once;
2. obtain the auth account on the same endpoint lease;
3. bind the data to the accepted height/endpoint identity;
4. atomically publish one `AccountSnapshot`;
5. only then project native RUNE and future token denoms.

## State-model gap

Persisted `Coin.rawBalance` in Vultisig does not distinguish fresh/stale/failed/loading. The following are required:

- `SyncState.idle(cached:)`;
- `SyncState.syncing(previous:)`;
- `SyncState.synced(snapshot:)`;
- `SyncState.notSynced(error:cached:)`;
- timestamp, accepted height, endpoint identity, and generation.

Account absence must be a distinct valid result; it is not equivalent to a transport/decode failure and must not be synthesized from one as balance `0`.
