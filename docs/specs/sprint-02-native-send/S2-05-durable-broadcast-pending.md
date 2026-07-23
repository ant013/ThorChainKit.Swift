# S2-05 — Durable Broadcast and Pending Lifecycle

**Risk:** critical
**Depends on:** verified `SignedTransaction` from S2-04
**Produces:** pre-broadcast durability, CheckTx classification, exact-byte retry, and pending projection

## Goal

Make network uncertainty recoverable. Once signing succeeds, exact `TxRaw` bytes and their local hash must survive every timeout, cancellation, crash, and process restart before or during broadcast.

## Scope

- GRDB send-journal migration and wallet/network namespace;
- journal state machine and atomic ordering;
- Cosmos sync broadcaster and response classifier;
- local/remote hash equality;
- exact-byte retry with fee acknowledgement and sequence safety;
- public pending snapshot/replaying publisher;
- restart recovery.

Out of scope: inclusion polling, history merge, confirmations/finality, replacement/resigning, and explorer logic. Sprint 3 consumes the pending journal.

## Proposed Areas

```text
Sources/ThorChainKit/Send/Broadcast/
  TransactionBroadcaster.swift
  BroadcastResponse.swift
  BroadcastClassifier.swift
  CosmosTransactionLookupClient.swift
  StrictJSONEnvelopeDecoder.swift
  RetryLookupResponse.swift
  BroadcastRetryCoordinator.swift
Sources/ThorChainKit/Send/Storage/
  SendRuntime.swift
  RuntimeActivityLease.swift
  OperationActivityHold.swift
  SendRuntimeRecovery.swift
  SendJournal.swift
  SendJournalRecord.swift
  SendJournalMigration.swift
  PendingTransactionRepository.swift
  PendingPublicationBarrier.swift
Tests/ThorChainKitTests/Send/Broadcast/
  BroadcastClassifierTests.swift
  CosmosTransactionLookupClientTests.swift
  StrictJSONEnvelopeDecoderTests.swift
  BroadcastRetryTests.swift
  SendJournalOrderingTests.swift
  SendJournalRestartTests.swift
  PendingTransactionRepositoryTests.swift
  PendingPublicationBarrierTests.swift
```

## Journal Schema

One row per local transaction hash:

| Column | Contract |
|---|---|
| `namespace` | existing stable wallet + network persistence namespace; never logged |
| `local_hash` | canonical uppercase SHA-256 TxRaw, primary identity within namespace |
| `signed_tx_raw` | exact immutable bytes, non-null |
| `sender_payload` / `recipient_payload` | canonical address payloads |
| `amount` / `quoted_native_fee` | canonical decimal base-unit strings |
| `memo` | nullable validated text |
| `account_number` / `sequence` | canonical decimal strings |
| `provider_family_id` / `quote_height` | non-secret coherence metadata |
| `state` | unknown, broadcasting, check_tx_accepted, rejected |
| `broadcast_generation` | monotonic CAS token for one in-flight broadcast attempt |
| `retry_blocked_reason` | nullable bounded enum, including sequence_advanced/provider_inconsistent |
| `check_tx_code` / `codespace` / `sanitized_log` | nullable bounded result; codespace is required to interpret duplicate code 19 |
| `created_at` / `updated_at` | injected-clock timestamps |

Migration runs in the same database/namespace transaction model approved in Sprint 1. It also links the S2-04 unique sequence reservation to `local_hash` in the same transaction that inserts a journal row. Existing read-only state is preserved. The raw bytes/signature are never emitted by public models, telemetry, errors, or logs.

The shared runtime performs the cross-domain handoff in a fixed recoverable order rather than claiming SQLite and actor memory are atomic: while retaining the signer gate it allocates/registers a broadcast generation and changes the attempt phase to `committing`; it then commits the journal/link transaction on the shared writer. A failed commit removes that generation and runs the pre-link finalizer. A successful commit makes the database authoritative; the actor advances the same token to `broadcasting`, observes any cancellation queued during the bounded local commit, and waits for the publication acknowledgement below before starting transport. A process crash after the commit but before either actor step is handled by startup normalization. No other attempt can enter while phase is `committing`.

Every S2-05 public return/throw finalizes in-memory ownership exactly once. The durable linked reservation follows the journal rules independently; releasing an actor gate never deletes it.

## Shared Runtime and Initialization

S2-04's process-wide `SendRuntimeRegistry` is the production ownership boundary. One `DatabaseRuntime` per physical `(device,inode)` identity owns the GRDB `DatabaseWriter` and a one-time writer/migration barrier. Namespace-keyed child `SendRuntime`s own journal/reservation facades, coordinator/attempt registries, activity leases, last committed pending snapshots, and their own one-time namespace-recovery task over that writer. Before publishing a ready child, its task removes only that namespace's unlinked reservations, normalizes its crash-residue `broadcasting` rows to `unknown`, and installs the first pending observation in one serialized startup sequence. Concurrent constructors for the same namespace await the same child task; failure removes only that failed child entry and never fabricates an empty ready state.

Recovery is once per database/namespace runtime/process lifetime, not once per `Kit`. A second Kit created during a live broadcast joins the existing ready runtime and cannot invalidate that broadcast generation. A true process restart recreates the registry and performs recovery before any send/retry or public pending publication. Production Kit instances resolve file identity before writer construction and never create an independent writer for the same file, because GRDB observation does not see writes made through an external database connection.

Each Kit receives a unique client `RuntimeActivityLease` from its namespace runtime. The inactive→active `start()` transition assigns the next monotonic lifecycle generation; calling `start()` again while active is idempotent and keeps that generation. `stop()` deactivates only that ID, advances and invalidates its generation, prevents new quote/send/retry admission, resolves its suspended H0 waiters, and invalidates that Kit's unconsumed quotes. A never-started or stopped client fails with `kitNotStarted` before QuoteStore/journal access, quote consumption, row mutation, signer/storage work, or endpoint I/O.

Every admitted send/retry first acquires a distinct runtime-actor `OperationActivityHold` before quote consumption or retry-row admission. Client `stop()` does not revoke an already authorized financial operation; its hold remains active through the exactly-once finalizer. Clean finalization releases it. If any finalizer/publication/terminal write fails, the same hold is transferred atomically to the fresh `repairIntentToken` and is released only when the matching repair plus replacement-observation acknowledgement succeeds. Thus a stop during send, or the last client stopping before a failed normalization, cannot orphan repair. The shared scheduler runs while any client lease, operation hold, or repair hold exists. It pauses only when all three sets are empty; a new client start resumes any durable startup intent before admission.

One Kit stopping or deinitializing cannot suspend another client's or operation's work. Explicit `stop()` is the deterministic client-lifecycle contract; the client lease object also schedules a best-effort exact-ID release from `deinit`, and duplicate release is harmless. Operation/repair holds are actor-owned tokens and never depend on Kit deinitialization.

## Ordering and State Machine

```text
verified SignedTransaction
  └─ atomic INSERT broadcasting(generation) + link reservation
       │  public projection: unknown/inFlight before network I/O
       ├─ code 0/hash match ─────────────────────► check_tx_accepted (terminal)
       ├─ sdk code 19/hash match ────────────────► check_tx_accepted (terminal)
       ├─ definitive other CheckTx ──────────────► rejected
       └─ no valid authoritative result ─────────► unknown

process restart: broadcasting ─► unknown
retry admission before endpoint I/O: unknown ─► broadcasting(new generation)
retry outcome: broadcasting ─► check_tx_accepted/rejected/unknown
sequence advanced, tx absent ─► unknown + retry_blocked(sequence_advanced)
```

The initial transaction persists exact bytes/local hash directly as an active `broadcasting(generation)` row and links the sequence reservation before any network call. Publicly that row is `.unknown/.inFlight`: `broadcasting` means an attempt owns the bytes and may still be immediately before transport, not that bytes definitely left the process. There is no durable `prepared` or publicly available pre-CAS window. If this transaction fails, no local transaction identity is durable, broadcast is not attempted, and the storage error is thrown. The journal rejects any attempt to replace `signed_tx_raw` or `local_hash` for an existing record.

Before the first endpoint call for every initial or retry broadcast generation, `PendingPublicationBarrier` requires the shared-writer `ValueObservation` callback to publish a snapshot containing this exact `(local_hash, generation)` as unknown/in-flight on the dedicated state queue and then acknowledge it to the runtime actor. The barrier first checks the last published snapshot so an observation that arrived before waiter registration cannot be lost. It races acknowledgement against cancellation and a bounded injected local-publication deadline. Failure/observation degradation makes zero endpoint calls, invalidates the active generation, attempts `broadcasting → unknown`, and returns the already durable ID as unknown; failed normalization is owned by live repair. The guarantee is package publication, not that a consumer which adds its own asynchronous scheduler has rendered the value.

During the runtime's one-time startup barrier, an interrupted `broadcasting` row is atomically changed to `unknown` and its generation is invalidated; it is never assumed rejected. Completion from an older generation cannot overwrite a newer result. `check_tx_accepted` and `rejected` are terminal and cannot transition back to broadcasting/unknown. Only `unknown` can acquire a retry broadcast CAS, so concurrent retries have one winner.

A definitive rejection is one GRDB transaction: compare-and-swap `broadcasting(expectedGeneration) → rejected` and delete only the linked reservation whose `(namespace, sender_payload, sequence, local_hash)` matches that row. If any part fails, neither part commits; the public result is `unknown`, the reservation remains conservative, the generation is removed from the active registry, and live repair normalizes the inactive row. A CheckTx-accepted reservation remains linked. Tests inject failures before and after each statement and prove no intermediate release is visible.

## Live Inactive-Work Repair

`SendRuntime` owns one injected `RuntimeRepairScheduler` and an optional actor-owned `repairIntentToken` with an attached repair hold. Every owner-token cleanup, broadcasting normalization, terminal write, publication, or observation failure replaces that token with a fresh random value, transfers or creates its hold before releasing the failed operation hold, removes the failed attempt from its active-token registry when applicable, marks pending status degraded, and requests repair immediately, then at 1s, 2s, 4s, and 8s capped backoff. Removing a client lease cancels the timer only when the client, operation, and repair-hold sets are all empty; it never clears the token. A matching successful repair/replacement-snapshot acknowledgement clears both token and hold atomically.

Each repair first enters a runtime-actor `repairing` admission barrier: new send/retry generations cannot register until the repair transaction finishes. It captures the current repair-intent token, snapshots active tokens/generations, and uses the shared writer. Existing active attempts present in the snapshot remain protected even if they complete concurrently; they are eligible only on the next repair pass. In one transaction repair:

- deletes only unlinked reservations whose exact owner token is no longer active;
- changes only `broadcasting` rows whose exact `(local_hash, generation)` is no longer active to `unknown`, invalidating that generation;
- never uses age and never touches an active attempt;
- rereads/publishes the complete pending snapshot only after the repair commit.

After normalization succeeds, observation recovery installs a replacement observation as described below. The actor clears repair intent only after the replacement's first successful snapshot and only when the current token still equals the captured token. Any failure or new repair request while the actor was reentrant replaces the token; mismatch keeps the admission barrier/intent and schedules the next pass immediately rather than waiting for backoff. Thus an attempt which was active in the old snapshot but becomes inactive with a failed write during that pass is guaranteed a later pass. A late signer/broadcaster callback is rejected by the in-memory token even before repair; after repair its durable generation also cannot match.

## Broadcast Wire Manifest

Every send-capable `EndpointFamilyCapabilityManifest` contains one versioned `CosmosTxRESTBroadcast` entry bound to that family's Cosmos REST role. It uses exactly:

```text
request
  POST /cosmos/tx/v1beta1/txs; no query parameters; redirects disabled
  Content-Type: application/json; charset=utf-8
  Accept: application/json
  body <= 1 MiB and contains exactly tx_bytes plus mode

authoritative response
  HTTP 200 only; normalized media type application/json with no non-UTF-8 charset
  body <= 64 KiB; no BOM, trailing token, or duplicate JSON key at any depth
  top level is one object with exactly the single key tx_response, whose value is an object
  tx_response contains one txhash JSON string and one code JSON integer in UInt32 range
  tx_response contains at most one codespace JSON string and at most one raw_log JSON string
  other bounded documented TxResponse fields are ignored only after strict duplicate-key parsing
```

The request body is constructed locally from the journal's exact bytes and has this complete schema:

```json
{
  "tx_bytes": "<base64 exact journal bytes>",
  "mode": "BROADCAST_MODE_SYNC"
}
```

`tx_bytes` is the canonical base64 of the exact journal bytes and `mode` is the literal string above; missing, extra, duplicated, differently typed, or oversized request fields are an internal invariant failure and make zero transport calls. A send-capable family must prove that its supported auth memo limit plus the fixed MsgSend/AuthInfo/SignDoc/TxRaw/base64/JSON overhead remains within this request ceiling; otherwise the family is policy-unavailable rather than silently truncating the memo. This route/schema is pinned to Cosmos SDK `v0.53.0` `Service.BroadcastTx` and `BroadcastTxResponse { tx_response }`.

The broadcaster does not serialize protobuf, accept a signer, or compute another hash. `StrictJSONEnvelopeDecoder` parses the response into only numeric code, codespace, returned hash, and sanitized log. `txhash` must parse as exactly 32 bytes. `codespace` is absent or at most 64 printable ASCII bytes. `raw_log` is valid JSON UTF-8 text, has control characters replaced, and is capped to 256 UTF-8 bytes before it can enter `BroadcastRejection`; the raw value/body is never logged or persisted. Invalid encoding, type, cardinality, bounds, or top-level shape makes the whole response non-authoritative.

## Classification

Classification order is normative:

1. Require the exact `CosmosTxRESTBroadcast` HTTP/media/size/redirect contract and parse the strict envelope. Every wrong status, content type/charset, redirect, oversized body, BOM, trailing token, duplicate key, top-level/nesting/cardinality/type error, malformed numeric field, invalid text/codespace, or invalid hash representation is `unknown`.
2. Require the returned hash to equal the local hash **before inspecting code or codespace**. Missing/mismatched hash is `unknown` for code 0, `sdk/19`, foreign-codespace 19, and every other nonzero code; it can never release a reservation for another transaction.
3. With a matching hash: `code == 0` is `checkTxAccepted`; exact `sdk/19` is idempotent `checkTxAccepted`; code 19 with a valid nonempty non-`sdk` codespace is `rejected`; code 19 with missing/empty codespace is `unknown`; any other valid nonzero CheckTx is `rejected` with bounded diagnostic fields.

- Timeout, connection loss, every non-200 HTTP response, malformed/non-authoritative body, or cancellation after `broadcasting`: `unknown`; none may terminalize the row or release its linked reservation.

`send` returns `SendSubmission(checkTxAccepted|unknown)`. A definitive rejection is thrown only after the terminal journal/release transaction commits. Failure to commit any post-initial response/cancellation transition invalidates the active generation, schedules live repair, and returns the already durable transaction ID as `.unknown`. No outcome claims inclusion.

Broadcast transport uses the same liveness pattern as the signer. After the durable initial commit, an owned unstructured task performs the bounded endpoint request while the runtime races result against caller cancellation and the endpoint-policy deadline. Cancellation/deadline invalidates the in-memory attempt token and attempts `broadcasting(expectedGeneration) → unknown` without awaiting a non-cooperative transport. The caller promptly receives `.unknown`; any late result from the invalid token is discarded. If the fallback state write itself fails, the row remains conservatively public as unknown/in-flight and live inactive-work repair normalizes it without a process restart; it is never reported accepted/rejected from memory alone.

## Retry Transaction Lookup Manifest

Every retry-capable `EndpointFamilyCapabilityManifest` contains one `CosmosTxRESTLookup` entry bound to that family's Cosmos REST role. Sprint 2 supports no guessed JSON-RPC/gRPC fallback:

```text
request
  GET /cosmos/tx/v1beta1/txs/{HASH}
  HASH is the journal's canonical uppercase 64-hex local hash
  Accept: application/json; redirects disabled; no query parameters

found
  HTTP 200; normalized media type application/json with no non-UTF-8 charset; body <= 64 KiB; duplicate JSON keys rejected
  top level is one object with exactly one tx_response object; other bounded documented GetTxResponse fields are ignored
  tx_response.txhash is one JSON string that parses as 32 bytes and equals HASH byte-for-byte
  tx_response.height is one JSON string containing a positive canonical base-10 Int64

notFound
  HTTP 404; normalized media type application/json with no non-UTF-8 charset; body <= 4 KiB; duplicate JSON keys rejected
  top level is one object with exactly the keys code, message, and details
  code is the JSON integer 5; details is exactly []
  bounded printable-ASCII message equals the family-pinned template containing HASH exactly once
```

For the current Liquify mainnet manifest, the exact not-found template is `rpc error: code = NotFound desc = tx not found: {HASH}: key not found`. This route and gRPC code 5 are backed by Cosmos SDK `v0.53.0` `Service.GetTx`; the live 2026-07-17 negative probe returned HTTP 404 with that exact envelope. A live positive probe returned HTTP 200, `tx_response.txhash` equal to the requested hash, and positive body height. The response's gateway metadata height is not used as transaction identity or H0/H1/H2 proof.

`RetryLookupResponse` has exactly four internal outcomes:

- `.found` only for the matching bounded positive envelope; it proves this exact transaction was indexed/included and therefore had passed CheckTx, regardless of DeliverTx code;
- `.notFound` only for the exact family-pinned 404 envelope above; it permits coherent retry policy reads but is never proof that the transaction was absent from mempool/network;
- `.providerInconsistent` for any bounded HTTP 200 or 404 response with the approved media type whose UTF-8/JSON/schema fails—including duplicate keys, trailing tokens, missing/malformed/different hash, or a deviating code/details/message—or for any other bounded non-retriable 4xx logical envelope;
- `.transportFailure` for timeout/cancellation, TLS/read failure, redirect, wrong content type, oversized body, 429, or 5xx.

No other HTTP, JSON-RPC, gRPC, proxy, or decoded shape can become `.notFound`. Each supported family must pin and opt-in live-test both a known positive hash and a purpose-generated absent hash before it is retry-capable; otherwise retry makes no broadcast call. Positive matching identity can terminalize without a height-pinned policy round, while only exact not-found proceeds to the round below.

`StrictJSONEnvelopeDecoder` is the single bounded parser for the broadcast response and both lookup envelopes. Its caller must select the non-public schema mode `.broadcast`, `.lookupFound`, or `.lookupNotFound` before parsing; it never auto-detects or reinterprets one route's body as another route's authority. It counts bytes before parsing, rejects a byte-order mark, non-UTF-8 input, trailing tokens, duplicate keys at any nesting depth, non-integer/out-of-range `code`, non-string/canonical `height`, and every top-level shape forbidden above. It returns only the typed fields above; raw bodies and arbitrary upstream messages never enter errors, logs, or the journal.

## Retry Algorithm

`retryBroadcast(transactionId:acceptingNativeFee:)`:

1. Before any journal access, atomically require this Kit's client lease active and acquire its operation activity hold. A stopped/never-started client returns `kitNotStarted`; a missing/terminal transaction ID is not inspected and the journal spy remains at zero. Every later early return runs the clean finalizer or transfers the hold to repair on cleanup failure.
2. Load the immutable journal record in the current namespace and reject terminal `check_tx_accepted`/`rejected`; accepted transactions are never downgraded or rebroadcast by Sprint 2.
3. Before any lease/lookup/network call, acquire the shared runtime gate and CAS this exact `unknown` row to `broadcasting(newGeneration)`, registering the same generation as active. Wait for `PendingPublicationBarrier` to acknowledge that exact retry generation as public unknown/in-flight. A `broadcasting` row, active gate, repair-pending inactive row, CAS loser, or publication failure makes zero endpoint calls; failure normalizes/repairs the row to unknown.
4. Acquire one complete identity-proven retry `EndpointLease` through S2-02's `EndpointOperationRunner`. That family/lease and generation bind the exact lookup manifest above, complete current policy snapshot, and broadcast for the entire attempt. No mid-attempt family switch is allowed. A later explicit retry may choose another complete family only as a new attempt.
5. Query the transaction by local hash through one owned operation and the lease's exact `CosmosTxRESTLookup` manifest. Accept the callback only after actor re-entry proves the same active generation. Only `.found` with a byte-equal returned hash terminalizes to `checkTxAccepted` without rebroadcast. Only the exact `.notFound` envelope permits policy preflight. `.providerInconsistent` first normalizes to `unknown + retryBlocked(providerInconsistent)`, makes zero broadcast calls, and throws `retryBlocked(.providerInconsistent)`; `.transportFailure` normalizes to unknown and returns `.unknown`. No other response can mean not found or replace local identity.
6. Read current account sequence, balance, native fee, halt, and module/memo policy coherently through the same lease. Each request/backoff is a separate owned operation, and the generation is rechecked before the next call begins.
7. If current sequence is lower than the record sequence, transition back to `unknown`, set `provider_inconsistent`, and throw `retryBlocked(.providerInconsistent)`.
8. If current sequence is greater after exact `.notFound`, transition back to `unknown`, set `sequence_advanced`, and prohibit rebroadcast. An index not-found is not proof that this transaction was absent, so the record remains public pending.
9. If current native fee differs from `quoted_native_fee`, transition back to `unknown` and throw `retryFeeChanged(NativeFeeChange)` unless the facade-snapshotted `acceptingNativeFee` equals current; stale/other acknowledgement is rejected.
10. Require balance for amount plus current fee and current policy safety; any failure returns the active generation to `unknown` before the typed error.
11. Broadcast the exact stored bytes through that lease and current generation. There is no signer call, rebuild, memo change, gas change, hash change, or failover.

Only an `unknown` row can retry. CheckTx-accepted and rejected rows are terminal. Exact `sdk/19` with a matching hash remains an idempotent acceptance result for an unknown exact-byte retry.

Any lease/lookup transport failure before rebroadcast returns the active generation to `unknown` and returns `.unknown`; it does not strand `.inFlight` or switch families. Definitive safety/policy/fee errors first commit `unknown` plus the bounded blocked reason, then throw their typed error. If that normalization write fails, the generation is invalidated in memory, public outcome remains unknown/in-flight, and live repair owns normalization.

Cancellation or an endpoint-policy deadline at any retry lease/lookup/policy operation invalidates the generation, attempts `broadcasting(expectedGeneration) → unknown`, releases the in-memory gate, and returns promptly without awaiting the child task. A late callback cannot start a subsequent request or commit. If normalization fails, the fresh repair-intent token guarantees live cleanup. Broadcast step 11 uses the same operation runner and classification contract already defined above.

## Pending Projection

Public pending contains check-tx-accepted, unknown, and in-flight broadcasting rows, newest first. Projection is exact:

- internal `unknown` → public `.unknown` plus `.available`, `.sequenceAdvanced`, or `.providerInconsistent` from its persisted blocked reason;
- internal `broadcasting` → public `.unknown` plus `.inFlight`;
- internal `check_tx_accepted` → public `.checkTxAccepted` plus `.notApplicable`;
- internal `rejected` → omitted.

The repository:

- uses one GRDB `ValueObservation` on the shared runtime writer for one atomic initial snapshot and serialized post-commit emissions on the dedicated state queue;
- updates after each committed state change;
- reconstructs deterministically after restart;
- never exposes raw bytes, signature, account number, sequence, namespace, or provider ID;
- exposes retry availability, including `sequenceAdvanced`, without hiding an unknown record;
- never overwrites a confirmed Sprint 3 transaction; reconciliation uses the same local hash.

The runtime keeps the last successfully committed snapshot. An observation/read error never uses `try!`, clears the list, crashes, or completes the public `Never` publisher. GRDB 6.29.3 completes a `ValueObservation` after error, so the runtime cannot recover with a standalone reread:

- every installed observation receives a monotonic `observationGeneration`; callbacks carry it and old-generation callbacks are ignored;
- current-generation error cancels/clears that observation, sets status `.degraded`, records only a sanitized diagnostic, creates fresh repair intent, and keeps the last valid snapshot;
- after repair normalization, the state queue installs a new generation on the same shared writer. Its atomic initial fetch is the recovery full reread and closes the commit/subscription gap;
- only the first successful snapshot from that new generation atomically publishes the list and `.ready`, acknowledges recovery to the runtime actor, and permits matching repair intent to clear. A second error repeats replacement rather than completing the public publisher.

Journal send/retry calls still use fresh database transactions and surface their own storage contract rather than trusting the cache.

Sprint 2 does not auto-delete check-tx-accepted/unknown rows. Retention changes require the Sprint 3 reconciliation spec.

## Analog Delta

BitcoinCore is the primary lifecycle analog: `TransactionCreator` processes/persists the created transaction before `TransactionSender.send`, pending listeners are notified from storage, and `TransactionSender` later reloads stored pending transactions. EvmKit remains supporting evidence for local bytes/hash ownership, TronKit for pending projection, and Vultisig for the CheckTx envelope. BitcoinCore is UTXO/P2P and lacks Cosmos sequence/CheckTx, exact-byte response-loss classification, shared-writer identity, publication acknowledgement, and generation repair; those are explicit THORChainKit deltas. Evm/Tron post-success pending and Tron remote-build behavior remain counterexamples.

## Tests Before Implementation

- migration on empty and populated Sprint 1 database; namespace isolation;
- byte/hash mismatch rejected at insert; immutable update guard;
- journal insert/update failure causes zero broadcast calls;
- failure of the atomic initial broadcasting+link transaction leaves no durable transaction ID and performs zero I/O;
- exact observed public ordering unknown/in-flight→outcome with no available window before initial I/O;
- publication barrier observes every exact initial and retry generation before any endpoint call; an observation failure/never-acknowledged callback performs zero endpoint calls, returns unknown promptly, and schedules generation repair;
- crash/reopen immediately after the initial broadcasting commit and during transport exposes the same public hash/bytes as unknown after recovery;
- full classification matrix including code 0, exact `sdk/19`, foreign-codespace/19 rejection, missing/empty/malformed-codespace/19 unknown, and a missing/malformed/mismatched hash cross-product over all of those plus another nonzero code; hash validation always wins;
- exact `CosmosTxRESTBroadcast` POST path, headers, no-query/no-redirect and locally bounded request body; only bounded HTTP-200 normalized JSON with the single top-level `tx_response` key is authoritative;
- broadcast responses with duplicate root/`tx_response`/hash/code/codespace/log keys, conflicting duplicate values, missing/null/wrong nesting or top-level fields, noninteger/negative/overflow code, invalid hash/codespace/log type, BOM, trailing JSON, non-UTF-8, wrong media/charset, redirect, oversize, every non-200 status, and a valid lookup envelope supplied to broadcast schema mode remain unknown and retain the linked reservation;
- cancellation before durable insert, after initial broadcasting commit but before transport, and during transport;
- retry `CosmosTxRESTLookup` fixtures cover exact uppercase path/no redirect, bounded 200 matching hash/positive height with both zero and nonzero DeliverTx code, 200 missing/malformed/duplicated/mismatched hash, exact Liquify 404/code-5/empty-details/message-template not-found, malformed/deviating 404, every other 4xx, 429/5xx, wrong content type, oversize/duplicate-key body, timeout, and redirect; only matching `.found` terminalizes to literal CheckTx-accepted, only exact `.notFound` reaches policy reads, and every inconsistent/transport response makes zero broadcast calls;
- same fee; changed fee without/wrong/correct acknowledgement;
- sequence unchanged/lower/advanced with false-negative hash lookup, balance/halt/module/memo changes;
- assert byte identity and zero signer/codec calls during retry;
- repeated exact `sdk/19` and repeated process restart;
- two concurrent retries and delayed old-generation completion cannot downgrade check-tx-accepted/rejected or overwrite a newer generation;
- a non-returning broadcaster is cancelled/times out promptly to public unknown, releases its in-memory attempt, and a late result cannot commit;
- non-returning/late retry lease, hash lookup, and each policy read/backoff are cancelled/timed out promptly; no later request begins, the generation returns or repairs to unknown, and another attempt is not blocked forever;
- failed broadcasting→unknown persistence is normalized by generation-scoped live repair without restart; active generations are untouched;
- failed pre-link owner-token deletion is retried live and a fresh same-process send eventually acquires the sequence;
- rejected-state CAS and linked reservation release are atomic under crash/write failure;
- Kit B created during Kit A's suspended broadcast joins the same runtime, does not run recovery, sees unknown/in-flight, and receives `sendInProgress` on retry;
- Kit B racing both immediately after initial commit and during retry preflight gets `sendInProgress` before lease acquisition and makes zero lookup/transport calls;
- cancellation/crash at each phase of the committing→database-authoritative→broadcasting handoff leaves either no journal or one recoverable inactive generation, never two owners;
- never-started and after-stop quote/send/retry fail before QuoteStore/journal access, consumption, or I/O; stopped retry with missing/terminal/current IDs always returns `kitNotStarted` and leaves the journal spy at zero; A and B client leases active with repair pending, A stop/deinit leaves B active; stop during an admitted send leaves its operation hold active; a failed cleanup transfers that hold to repair and completes even after the last client stops; only an empty client/operation/repair set pauses the timer;
- repair admission and new-attempt registration are serialized so a newly active generation can never be absent from the repair snapshot;
- a repair pass paused after its active-token snapshot cannot clear a fresh repair-intent token created by a concurrent failed normalization; it immediately runs a second pass which repairs that now-inactive generation without restart;
- duplicate/alias/symlink/hard-link database URLs converge before writer construction; Kit A observes every committed production-path write made by Kit B through the shared writer, while an independent-writer SQL test is limited to uniqueness, not publication;
- observation error → replacement initial snapshot B → later independent commit C emits C; stale callbacks from the failed generation cannot publish or return status to ready;
- pending replay/order/namespace, continuous unknown→in-flight→outcome identity, degraded/recovery status, and confirmed-history non-overwrite contract;
- error/log canary redaction and upstream log length/control-character sanitization.
- opt-in current-family lookup compatibility records one live matching-hash HTTP-200 envelope and one purpose-generated absent-hash exact HTTP-404 envelope; a changed template disables retry for that family rather than being guessed as not-found.

## Verification

```text
swift test --filter SendJournalOrderingTests
swift test --filter SendJournalRestartTests
swift test --filter BroadcastClassifierTests
swift test --filter CosmosTransactionLookupClientTests
swift test --filter StrictJSONEnvelopeDecoderTests
swift test --filter BroadcastRetryTests
swift test --filter PendingTransactionRepositoryTests
swift test
```

## Acceptance Criteria

- Exact signed bytes are durable before network I/O and immutable thereafter.
- Every signed transaction is public/recoverable as `unknown` before any I/O; every ambiguous post-broadcast outcome keeps that hash.
- Retry makes no signer/codec call and emits byte-identical TxRaw.
- Retry treats only the family-pinned bounded Cosmos REST matching-hash response or exact code-5 NotFound envelope as authoritative; no guessed response can enable rebroadcast.
- Hash mismatch can never be reported check-tx-accepted, and terminal truth can never be downgraded.
- A broadcast response can terminalize or release a reservation only after the exact strict Cosmos REST wire manifest succeeds; ambiguous parser input is always unknown.
- Restart deterministically restores pending state without claiming inclusion.

## Pinned Decision

The local transaction hash is the stable identity from signing through Sprint 3 reconciliation. Remote text cannot replace it.
