# Sprint 2 — Safe Native RUNE Send

## Sprint Outcome

At the end of Sprint 2 a user can enter a native RUNE recipient and amount, review a height-coherent quote, authorize signing through the host-owned signer, submit the exact locally constructed transaction, and receive a deterministic local transaction hash. If the network result is ambiguous, the same signed bytes remain recoverable and can be rebroadcast without rebuilding or signing a second transaction.

The outcome is demonstrated in both products:

- `ThorChainKit/iOS Example`: deterministic fixture flows and an opt-in controlled mainnet transfer, including restart and retry;
- Unstoppable Wallet: the standard `SendNew` route produces the same quote/send behavior through a WalletCore adapter. Maestro is never added to or run against Unstoppable.

## Slice Sequence

| Slice | Capability | Observable exit |
|---|---|---|
| S2-01 | immutable send/quote domain | Example can validate input and render stable review data; signer summary uses unambiguous fixed-eight RUNE values |
| S2-02 | one-family, one-height preflight | Example displays account sequence, native fee, total debit, and halt state from one coherent snapshot |
| S2-03 | local direct-sign codec | official and independent fixtures produce exact SignDoc, TxRaw, and transaction hashes |
| S2-04 | external signer + per-account coordinator | a host signer authorizes one request; wrong key, bad signature, stale quote, and concurrent send fail closed |
| S2-05 | durable broadcast + pending lifecycle | exact signed bytes survive timeout/restart and can be rebroadcast idempotently |
| S2-06 | Example acceptance | Maestro proves review, CheckTx acceptance, ambiguous result, retry, and restart/pending projections in an isolated fixture target |
| S2-07 | Unstoppable integration | the real `SendNew` flow sends a controlled mainnet transfer and records the local hash and node result |

Each slice is independently reviewable and must leave the package buildable. S2-07 starts only after the standalone package behavior is accepted.

## Architectural Flow

```text
UI input
  │
  ▼
Kit.quote(to:amount:memo:)
  │ one EndpointLease + one Cosmos height proven per route
  │ (REST echo / Comet ABCI response height / authoritative body height)
  ├─ account number / sequence
  ├─ balances
  ├─ /thorchain/network native_tx_fee_rune
  ├─ exact halt Mimir keys
  ├─ auth memo limit
  └─ node version + recipient Account/reserved-module policy
  │
  ▼
immutable SendQuote ── user review ── Kit.send(quote:signer:)
                                           │
                                           ├─ revalidate same provider family through bounded owned operations
                                           ├─ build local SIGN_MODE_DIRECT SignDoc
                                           ├─ request 64-byte compact signature
                                           ├─ verify key/address + low-S signature
                                           ├─ build TxRaw + local SHA-256 hash
                                           ├─ persist exact bytes + acknowledge every broadcast generation before I/O
                                           └─ BROADCAST_MODE_SYNC
                                                     │
                      ┌──────────────────────────────┼──────────────────────────────┐
                      ▼                              ▼                              ▼
            code 0 / sdk code 19             definitive CheckTx error        no valid response
                      │                              │                              │
           checkTxAccepted                     rejected                        unknown
                      └──────────────────────────────┴──────────────────────────────┘
                                                     │
                                                     ▼
                                   pending projection + exact-byte retry
```

## Sprint-Wide Invariants

1. `ThorChainKit` never accepts, derives, stores, logs, or returns a mnemonic or private key.
2. Quote authority comes from one provider family at coherent height H0; pre/post-sign snapshots use the same family at monotonic H1/H2. No field is merged from another provider or frozen old height.
3. Exact amount is positive native RUNE in base units. Explicit Max is computed coherently as `spendableRune - native_tx_fee_rune`; native fee zero is valid.
4. Recipient is canonical for the selected network, differs from the sender, and is not any THORChain module account.
5. Halt state follows exact THORNode semantics: proven Mimir `-1`/`0` is inactive, active boundaries are evaluated at H0/H1/H2, and malformed/unproven values fail closed.
6. A quote is immutable, opaque, one-use, and expires after ten seconds, any relevant snapshot change, or its Kit client lifecycle generation stopping; a late H0 callback cannot create a quote after stop/start.
7. Protobuf signing is local. A server never supplies the bytes to sign.
8. Native MsgSend uses `/types.MsgSend`, `SIGN_MODE_DIRECT`, empty `Fee.amount`, and gas limit `3_000_000`.
9. Signatures are 64-byte `r || s`, low-S secp256k1 signatures bound to the compressed public key and the kit address.
10. One process-wide database runtime per physical SQLite `(device,inode)` identity owns the shared writer; wallet/network namespaces are child runtimes. Atomic file-migration ownership, child-owned namespace recovery, per-Kit lifecycle generations/client leases, lifecycle-first send/retry admission, operation/repair holds, version-tokened live inactive-generation/owner-token repair, coordinator, and durable unique `(namespace,sender,sequence)` reservation prevent alias writers, stopped-client storage access, stop-during-send orphaning, invalidated live generations, and missed commits.
11. Signed `TxRaw` bytes, the local hash, active generation, and linked reservation commit atomically before broadcast. The pending publisher acknowledges every exact initial/retry unknown/in-flight generation before its first endpoint call; failed observations are replaced generation-by-generation, so there is no invisible prepared/retry window or reread-only false recovery.
12. Every lease/read/backoff/broadcast operation is an owned task raced against cancellation and an absolute deadline, with token/generation validation before another call starts; H0 also races lifecycle invalidation. Ambiguous outcomes become `unknown`; non-returning signer, revalidation, retry, or transport work cannot retain the public attempt gate, and late invalid generations cannot advance state.
13. `code == 0` and idempotent Cosmos `sdk/19` become terminal `checkTxAccepted` only after the exact bounded Cosmos REST broadcast HTTP/media/JSON manifest succeeds and the returned hash matches the local hash. Duplicate keys, wrong status/media/top-level/type/bounds, redirects, and malformed/mismatched hashes remain unknown and retain the reservation. Foreign-codespace 19 rejects; missing/malformed codespace 19 remains unknown. Terminal truth is never downgraded.
14. A retry binds one family-pinned Cosmos REST lookup, the coherent policy snapshot, and exact-byte broadcast to one identity-proven family lease. Lookup can terminalize only after a bounded HTTP-200 returned/local hash equality; only the exact bounded family HTTP-404/code-5/hash-message envelope means not-found. Every other identity remains unknown and blocks or defers rebroadcast. A changed native fee requires explicit UI acknowledgement; an advanced sequence without an observed transaction keeps the outcome unknown and blocks rebroadcast.
15. Sprint 2 acceptance stops at CheckTx/local pending. Inclusion and historical reconciliation belong to Sprint 3.
16. Kit amount/quote/pending/error authority remains externally unforgeable and crosses tasks only as checked-Sendable Address/Data/string/integer snapshots; BigUInt is reconstructed, never stored. The exact public `SendError` graph includes an internally validated, externally read-only nonempty `QuoteChanges` payload and is compiler-proven, not inferred. WalletCore live handles are bound to one private client owner, CheckTx/unknown render dedicated local-hash outcomes and cannot consume generic SlideButton completion, and `Debug-Dev build-for-testing` adds no concurrency diagnostic in any repository-owned Swift file, including unchanged transitive callers.

## Real Acceptance Script

### Standalone kit

1. Build and run the complete deterministic Swift test suite.
2. Build `iOS Example` on one explicitly selected simulator UDID.
3. Run the guarded Maestro fixture manifest and require non-zero discovered flows/tests.
4. Demonstrate quote → review → CheckTx-accepted send with the expected local hash.
5. Inject a response loss after node acceptance, terminate the Example, relaunch it, and verify the same hash/bytes remain `unknown`.
6. Confirm a fee-change prompt, rebroadcast the exact bytes, and observe CheckTx-accepted/idempotent state without a second signature request.
7. In a separate opt-in run, send a minimal mainnet amount between controlled purpose-created accounts and record endpoint family, quote height, accepted height, local hash, CheckTx code/codespace, and later explorer observation. Internal classifier tests prove a CheckTx-accepted node hash matched the local hash; no second public hash is invented. No secret enters the evidence.

### Unstoppable Wallet

1. Integrate the reviewed package revision through the normal dependency and WalletCore adapter paths.
2. Run narrow WalletCore tests for input conversion, Sendable snapshot round-trips, live/fake/cross-client quote handles, signer ownership, drag/accessibility outcome completion, and factory registration; the fake never constructs kit authority.
3. Build the Development app and manually execute precision-safe exact and 100%/Max RUNE SendNew quote → review → send on a controlled account; excess fractional precision must fail rather than round.
4. Run the `Debug-Dev build-for-testing` baseline-delta strict-concurrency diagnostic/canary script across all repository-owned Swift diagnostics and the literal strict nonparallel serialized global-state test command, then verify internal hash equality, absolute quote expiry/Refresh, active-account/duress authorization, and dedicated CheckTx/ambiguous-outcome behavior in both direct and wrapper presentations without a generic error/sent banner or secret logging.
5. Confirm no `.maestro`, fixture transport, acceptance launch argument, or secret-bearing artifact was added to Unstoppable.

## Sprint Exit Gate

- Every slice spec is approved and implemented in order.
- Deterministic tests contain no ignored/skipped send cases.
- Independent codec controls pass, including the fully signed deterministic official-`3_000_000` vector and the Vultisig compatibility vector.
- Failure tests cover stale quote, fee/sequence/halt changes, wrong signer, high-S/malformed signature, concurrent send, non-cooperative H1/H2/retry calls, repair reentrancy, publication failure, crash before/after broadcast, response loss, hash mismatch, and restart.
- Example Maestro fixture flows are green and artifacts pass secret/canary scans.
- A controlled mainnet transaction is CheckTx-accepted and its hash is independently observable; later inclusion is recorded but does not substitute for Sprint 3 reconciliation.
- The real Unstoppable SendNew flow is exercised without Maestro.
- All high/critical adversarial findings are closed and Gimle evidence has a valid durable report.

## Non-Goals

- transaction history, inclusion monitoring, confirmations, reorg handling, and explorer reconciliation;
- MsgDeposit, swap, bond/LP/saver/THORName operations, or arbitrary THORChain memos;
- RBF, fee bumping, transaction replacement, batch send, or multi-send;
- importing Vultisig MPC/TSS, WalletCore transaction compilation, or global services;
- holding seed/private-key material inside the kit;
- Maestro automation in Unstoppable.
