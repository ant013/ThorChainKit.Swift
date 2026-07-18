# Sprint 2 — Native RUNE Send Protocol Notes

## Authoritative Wire Contract

Sprint 2 implements one operation: a native L1 RUNE transfer to a non-module THOR address.

| Field | Required value |
|---|---|
| message type URL | `/types.MsgSend` |
| `MsgSend.from_address` | raw 20-byte sender payload, protobuf field 1 |
| `MsgSend.to_address` | raw 20-byte recipient payload, protobuf field 2 |
| `MsgSend.amount` | repeated Cosmos `Coin`, field 3; literal denom `rune`, positive base units |
| sign mode | Cosmos `SIGN_MODE_DIRECT` (`1`) |
| public-key Any | `/cosmos.crypto.secp256k1.PubKey` |
| `Fee.amount` | empty |
| gas limit | `3_000_000` |
| signature | 64-byte compact secp256k1 `r || s`, normalized low-S |
| transaction hash | uppercase hex SHA-256 of exact serialized `TxRaw` |
| broadcast | Cosmos tx service JSON with base64 `tx_bytes` and `BROADCAST_MODE_SYNC` |

The displayed native network fee is not encoded as a Cosmos `Fee.amount`. THORNode deducts `native_tx_fee_rune` separately. Review data and balance validation must therefore show and require `amount + native fee` while preserving an empty protobuf fee coin list.

## Direct-Sign Construction

The local codec builds these internal protobuf values in order:

1. `types.MsgSend` and its Any wrapper;
2. `TxBody(messages:[msgAny], memo:memo)`;
3. compressed secp256k1 `PubKey` and Any wrapper;
4. `ModeInfo.Single(mode: SIGN_MODE_DIRECT)`;
5. `SignerInfo(publicKey, modeInfo, sequence)`;
6. `Fee(amount: [], gasLimit: 3_000_000)`;
7. `AuthInfo(signerInfos:[...], fee:...)`;
8. `SignDoc(bodyBytes, authInfoBytes, chainId, accountNumber)`;
9. SHA-256 digest of serialized SignDoc;
10. `TxRaw(bodyBytes, authInfoBytes, signatures:[compactSignature])`.

Generated protobuf types are internal implementation details. `SwiftProtobuf` may be a package dependency, but it cannot leak into public signatures.

## Independent Golden Control

The Vultisig fixture provides:

- amount `100_000_000` base units;
- account number `123456`;
- sequence `1`;
- compressed public key `023e4b…a452b`;
- sender `thor18alt…` and recipient `thor1tgxm…`.

Independent reconstruction reproduces Vultisig's signing digest `7e513b…1ebf` only with its 20M gas choice. The approved official-gas vector uses the same semantic inputs with gas `3_000_000` and yields SignDoc SHA-256:

`83a508ff301fc5cf7ab5126d861e7bac8dd1ebc5691df4842d6b2ac84dd3668f`

The serialized SignDoc length is 193 bytes. Tests must pin complete fixture inputs and full expected byte/hash values; ellipses above are documentation abbreviations only.

The native gas/wire authority is the official THORNode multisig example at commit `a759cb4f99b1a13d5d94ace1dddcaf25c165641f`, `docs/cli/multisig.md:27-56` (blob `537cac65592828fb0f10dbf2d75edf51eaa4be67`, file SHA-256 `27e39d943dee5744df87d87ef29828c8b34f51ae8bb4a7504fe4c98716d2649c`). It uses `/types.MsgSend`, denom `rune`, empty fee coins, and gas `3_000_000`.

A second, fully signed deterministic control uses the public scalar-one secp256k1 fixture. Its compressed public key is `0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798`, official-gas SignDoc digest is `1ff56dd4c3627af0cee040965178f50c8d7c854e909d7b54aedbd1b7bf110b68`, low-S compact signature begins `23103daa…` and ends `…478dae45`, and the complete TxRaw hash is `3685BF7AD0C65889B763D4B6D1F1EDEEC96E9B63B63F8DB992D00757EB5F136E`. The full signature and TxRaw bytes are pinned in S2-03 rather than abbreviated.

## Height-Coherent Preflight

One `EndpointLease` selects one provider family. Quote reads form snapshot H0; pre/post-sign revalidation forms complete snapshots H1/H2 from that same family with `H1 >= H0` and `H2 >= H1`. Each route is pinned to one executable proof mode: request/response `x-cosmos-block-height`, a Comet `abci_query` whose decoded business value and `response.height` come from the same response, or an authoritative schema body that explicitly carries the evaluated height. Query-only REST is never proof. Current official Liquify REST strips the height response header on required routes, so that family must use its paired Comet proof for those values or remain ineligible for send. The complete pinned round includes:

- account number and sequence;
- exact spendable balance whose returned `Coin.denom` is literally `rune`;
- `/thorchain/network?height=…` for `native_tx_fee_rune`;
- halt-related Mimir values at the same height;
- Cosmos auth params for memo byte limit;
- THORNode semantic version, the recipient's exact Account response, and the matching source-derived forbidden-module policy revision.

The quote is rejected if any value's own response cannot prove the requested height. A REST value cannot borrow an ABCI height from another call. No maximum sequence, median, fallback merge, frozen H0 re-read, or cached value from a different family can authorize signing. Explicit Send Max is resolved at H0 as spendable RUNE minus the current native fee.

## Halt Evaluation

Read the four exact Mimir keys. A proven `-1` sentinel or `0` is inactive; values below `-1`, malformed data, or unproven height fail closed. Halt when any condition is active at the round height:

```text
HaltChainGlobal > 0          && HaltChainGlobal <= height
NodePauseChainGlobal >= height
HaltTHORChain > 0            && HaltTHORChain <= height
SolvencyHaltTHORChain > 0    && SolvencyHaltTHORChain <= height
```

Missing/malformed required values, identity mismatch, or inability to prove the height makes quote construction fail. CheckTx remains authoritative even after successful client preflight.

## Recipient and Memo Safety

- Decode strict Bech32 and require the selected network HRP and a 20-byte payload.
- Reject self-send in Sprint 2.
- Do not use the current bulk ModuleAccounts route: Liquify REST/Comet independently reproduced an HTTP 500/ABCI panic at height `27049190`. Query the specific recipient at the exact round height instead. Exact `sdk/22` with matching height and zero response bytes proves account absence; the pinned Comet decoder normalizes absent, JSON `null`, or base64 `""` value to zero bytes and rejects nonempty/invalid/duplicate encodings. A successful response must contain the same address and a supported Any, and `ModuleAccount` is rejected.
- Concrete account type is supplemented by the source-identical `IsModuleAccAddress` name set from the exact official `v3.19.0`–`v3.19.3` tags, converted with Cosmos module-address derivation. Both proven `Query/Version.current` and `.querier` must belong to that explicit set; live H=`27049190` returned `3.19.3`/`3.19.0`. A reserved payload is rejected even if the account response is BaseAccount or NotFound; any unreviewed version fails closed. THORNode converts native sends to its own module into MsgDeposit, while other module recipients are invalid; silently changing operation type is prohibited.
- Memo is optional UTF-8 text. Enforce the Cosmos auth parameter as UTF-8 byte count, not Swift character count. The usual SDK default is 256 bytes, but the pinned response is authoritative.
- Sprint 2 does not interpret arbitrary THOR memos. Native-action memos belong to Sprint 4.

## Signer Trust Boundary

`Signer` exposes only a compressed public key and one asynchronous signing function. Before asking for a signature the kit derives `RIPEMD160(SHA256(compressedPublicKey))` and requires equality with the sender address payload.

After signature return the kit requires:

- exactly 64 bytes;
- scalar `r` and `s` in valid secp256k1 range;
- low-S form;
- successful verification of the 32-byte SignDoc digest against the supplied public key.

HsCryptoKit can produce normalized compact signatures, but ThorChainKit must use the underlying secp256k1 verification API for compact verification rather than assuming the producer is correct.

## Broadcast Classification

| Observation | Journal result |
|---|---|
| valid CheckTx `code == 0`, remote hash equals local | `checkTxAccepted` |
| valid `code == 19`, codespace exactly `sdk`, hash equals local | `checkTxAccepted` idempotently |
| valid `code == 19`, nonempty non-`sdk` codespace | `rejected` with sanitized code/codespace/log |
| `code == 19`, codespace missing/empty/malformed | `unknown` |
| valid other non-zero CheckTx | `rejected` with sanitized code/codespace/log |
| hash missing, malformed, or differs for any code/codespace | `unknown` before code classification |
| timeout, cancellation after I/O begins, malformed response, HTTP loss | `unknown` |

`checkTxAccepted` means only CheckTx acceptance. Inclusion/finality is not claimed. The journal's exact `TxRaw` is the only retry payload; only `unknown` may retry. One retry attempt binds hash lookup, current sequence/balance/fee/halt/memo/recipient-policy snapshot, and broadcast to one identity-proven provider-family lease; failover is allowed only by starting a new complete retry attempt. A lookup can terminalize the row only when its returned transaction hash is valid and byte-equal to the local hash; inconsistent lookup identity blocks rebroadcast and remains unknown.

Broadcast uses exactly Cosmos SDK `v0.53.0` `POST /cosmos/tx/v1beta1/txs` with no query/redirect, JSON request/accept headers, locally bounded exact `tx_bytes`/sync-mode body, and only a bounded HTTP-200 normalized JSON `BroadcastTxResponse { tx_response }` as authority. The shared strict decoder rejects BOM, trailing tokens, non-UTF-8, duplicate keys at any depth, wrong top-level/nesting/cardinality/type, out-of-range code, wrong media/charset, redirect, oversize, and every non-200 response. Every such deviation remains `unknown` and retains the linked reservation.

The table is evaluated with strict envelope validity and hash as prerequisites: missing/malformed/mismatched hash returns `unknown` before any code/codespace branch, including foreign code 19 and other nonzero codes. This prevents a response for another transaction—or ambiguous duplicate-key parser behavior—from causing terminal state or reservation release.

Retry lookup uses the same family's Cosmos REST role and exactly `GET /cosmos/tx/v1beta1/txs/{UPPERCASE_LOCAL_HASH}` with redirects disabled. A bounded HTTP-200 `tx_response.txhash` JSON string must byte-match the local hash and its `height` JSON string must be a positive canonical Int64. Only a family-pinned bounded HTTP-404 gRPC-gateway object with the exact key set `code/message/details`, JSON integer code `5`, empty details, and the exact requested-hash message template means not found. The current Liquify template is `rpc error: code = NotFound desc = tx not found: {HASH}: key not found`; every other 404/4xx/body and every JSON-RPC/gRPC guess is inconsistent or transport failure, never not-found. The 200/404 shapes were reproduced live, and the route plus NotFound semantics are pinned to Cosmos SDK `v0.53.0` `Service.GetTx`.

Cosmos error numbers are scoped. Code 19 is the duplicate/mempool-cache result only in the SDK codespace; matching the local hash does not turn another module's code 19 into acceptance.

The process-wide database runtime is keyed by physical SQLite filesystem identity and owns one GRDB writer; wallet/network namespaces are child runtimes/row partitions, not independent writers. Each Kit activation has a lifecycle generation: H0 and final quote insertion must still match it, while send/retry must acquire an operation hold before any QuoteStore/journal access. Initial exact bytes/hash, active generation, and reservation link commit together before I/O and every initial/retry generation is acknowledged in the public unknown/in-flight projection before its first endpoint call. A rejected terminal transition and release of its exactly linked sequence reservation commit in one transaction; acceptance retains the reservation. Inactive generations/unlinked owner tokens receive bounded same-process repair, failed GRDB observations are replaced with generation-scoped subscriptions, and any failure after the initial durable local identity is reported conservatively as unknown rather than inferred from an in-memory response.

## Open Compatibility Checks

Before implementation approval becomes release approval, the live gate must confirm on two current mainnet provider families where available:

- height query/echo behavior for every required endpoint;
- recipient Account success/sdk-22-NotFound/ModuleAccount decoding, exact embedded-address equality, node-version proof, and every source-derived forbidden module vector;
- the known bulk ModuleAccounts panic remains a regression counterexample and is never selected;
- controlled native-send broadcast records the bounded HTTP-200 `BroadcastTxResponse` shape; a changed status/media/top-level/field type disables terminal classification and remains unknown;
- current auth memo parameter shape;
- current broadcast service route and code-19 behavior;
- exact native fee units and chain identity.

An unavailable second provider is recorded as an explicit limitation, never silently replaced with mixed-family reads.
