# S2-04 — External Signer and Per-Account Coordinator

**Risk:** critical
**Depends on:** S2-01 API, S2-02 revalidation, S2-03 codec
**Produces:** verified signed transaction and serialized send lifecycle; no network broadcast yet

## Goal

Let a host-controlled asynchronous signer authorize one reviewed transaction while the kit retains control of bytes, validates signer identity/signature, and prevents sequence races.

## Scope

- public `Signer` execution contract and internal `SigningRequest` construction;
- address/public-key binding and compact signature verification;
- `SendCoordinator` actor, quote consumption, cancellation, and revalidation order;
- one sign/send attempt per account namespace;
- handoff of a verified `SignedTransaction` to S2-05.

Out of scope: seed/private-key derivation, hardware/MPC implementation, journal/broadcast, UI confirmation, and host localization.

## Proposed Areas and Types

```text
Sources/ThorChainKit/Send/Signing/
  SendCoordinatorRegistry.swift
  SendCoordinator.swift
  SignerVerifier.swift
  CompactSignature.swift
  SigningRequestFactory.swift
Sources/ThorChainKit/Send/Storage/
  SendRuntimeRegistry.swift
  DatabaseLocation.swift
  DatabaseRuntime.swift
  SendRuntime.swift
  SequenceReservationStore.swift
  SequenceReservationMigration.swift
Tests/ThorChainKitTests/Send/Signing/
  SendCoordinatorTests.swift
  SendCoordinatorConcurrencyTests.swift
  SignerVerifierTests.swift
  SigningRequestRedactionTests.swift
```

`SendRuntimeRegistry.shared` is an internal process-wide actor. Its top-level key is the physical SQLite `DatabaseFileIdentity`, not the wallet namespace. One `DatabaseRuntime` owns the sole GRDB `DatabaseWriter` for that file and contains child `SendRuntime`s keyed by the existing stable wallet/network namespace. Repositories, coordinator keys, reservations, rows, and observations remain namespace-scoped, but two namespaces in one file never create external writers that miss each other's GRDB notifications. A second Kit cannot rerun recovery or start another signer for the same sequence. Cross-process/app-extension use is outside Sprint 2.

`DatabaseLocation.resolve()` is executable rather than a string-normalization promise:

1. require a file URL, standardize `.`/`..`, resolve symlinks in the existing parent path, and create the private parent directory if needed;
2. open/create the database file with owner-only permissions, call `fstat`, and define identity as the filesystem `(device, inode)` pair; this converges standardized aliases, symlinks, hard links, and two independently built URLs for the same file;
3. keep the descriptor alive until the registry has installed an `.initializing` entry, then construct exactly one `DatabasePool` at the resolved path and verify the path still resolves to the same identity; mismatch fails initialization rather than opening a second writer;
4. inside the registry actor, atomically return an existing ready/initializing entry or install one database-initialization task before the first suspension. Only that winning task may construct the writer and run file-wide schema migration; it never runs wallet-namespace recovery. Waiters share its result. A failed task removes only its matching entry so a later explicit construction may retry. S2-05's namespace child task is the sole owner of reservation/journal recovery and first observation for that namespace.

The Sprint 1 production `KitFactory` must obtain its sync storage through this same `DatabaseRuntime`; S2 cannot wrap an already-created independent writer. Tests may inject an in-memory runtime directly, but production accepts a `DatabaseLocation`, resolves identity first, and asks the registry to create/return the writer. Namespace derivation remains `uniqueId`; it partitions rows and child runtimes but is never part of physical file identity.

The runtime resolves one `SendCoordinator` per sender payload. Its `SequenceReservationStore` has a unique key `(namespace, sender_payload, sequence)` and an attempt owner token. The reservation is acquired before the signer call. SQL uniqueness is also tested with independent connections, but production publication and recovery always use the shared writer.

An unlinked reservation contains no signed bytes and therefore cannot have been broadcast under this design. On process startup, the database owner removes only reservations that have no linked journal row; live in-process cleanup is owner-token CAS, never age-only eviction. If that delete fails, the runtime releases the in-memory gate, marks the exact owner token cleanup-pending/degraded, blocks a new signer without calling it, and invokes S2-05's bounded shared-writer repair until the inactive unlinked token is deleted. Once S2-05 links a durable transaction, the reservation remains until CheckTx rejection releases it or a later on-chain sequence permits a different sequence reservation.

## Send Sequence

Inside the actor:

1. Before any QuoteStore access, atomically require this Kit's client lease to be active, acquire its S2-05 operation activity hold, and acquire the registry gate for the wallet/network/sender namespace. An earlier/concurrent `stop()` that wins actor ordering returns `kitNotStarted` with zero QuoteStore/storage/signer/endpoint calls; a later stop cannot revoke the admitted operation or cleanup hold.
2. Validate quote origin, binding, lifecycle generation, expiry, and unused state, then mark it consumed for this send. Any validation failure runs the clean exactly-once finalizer, releases gate/hold, and never makes the quote reusable after consumption began.
3. Read `signer.compressedPublicKey` exactly once into an immutable `Data` snapshot; validate it and bind it to the kit sender.
4. Run S2-02 coherent revalidation at `H1 >= H0` on the quote's same provider family. Every lease/read/backoff is a separate `EndpointOperationRunner` operation guarded by this attempt token. If cancellation, the endpoint deadline, or quote expiry wins, invalidate/finalize the token and return without awaiting the provider task. If the H1 BaseAccount public key is non-null, require exact equality with the captured signer key; null remains valid for a first outgoing transaction.
5. Atomically acquire the durable sequence reservation with a random attempt token. A conflict returns `sendInProgress` and makes zero signer calls.
6. Build exact S2-03 SignDoc/digest and internal `Sendable` SigningRequest using the captured key.
7. Start one owned unstructured `Task` (never `Task.detached`) that calls `signer.sign(request)` with the immutable request. The coordinator waits through an actor-owned exactly-once result channel racing signer completion against caller cancellation and the quote's absolute expiry. It never waits for a non-cooperative child task to terminate.
8. If cancellation/expiry wins, atomically invalidate the attempt token, owner-CAS release the still-unlinked reservation and registry gate, resume the caller, and drop the task handle. A signer that ignores cancellation may finish later, but its result callback re-enters the actor, observes the invalid token, and is discarded without journal or broadcast.
9. Revalidate the complete snapshot at `H2 >= H1` through the same per-operation race. A losing deadline/cancellation finalizes the unlinked reservation/gate immediately; a late provider result is discarded and cannot start another read. Repeat the non-null account-key equality check, then run another cancellation/token check.
10. Verify the compact signature against the digest and the same captured key.
11. Build exact TxRaw/local hash, run a final cancellation/token check, and pass the still-owned attempt to S2-05. The shared runtime changes its in-memory phase to `committing` before the database transaction, retains the same gate/token through the commit, and follows S2-05's explicit success/failure/crash ordering; it never claims an atomic SQLite/actor-memory transfer.
12. On any pre-link failure, release only the matching owner reservation and registry gate through an exactly-once attempt finalizer. A clean finalizer releases the operation hold; a failed reservation cleanup atomically transfers it to S2-05 repair intent before returning. The finalizer is invoked by validation, signer result, cancellation, or expiry; it is not dependent on the signer task returning or the Kit client remaining started.

The signature may be cryptographically verified before or after the second network revalidation for CPU efficiency, but no invalid/stale result may reach storage/broadcast. A change during signer suspension discards the signature and requires a new quote/user confirmation.

## Address/Public-Key Binding

- Require exactly one valid compressed secp256k1 public key (33 bytes, prefix 02/03).
- Compute `RIPEMD160(SHA256(compressedPublicKey))`.
- Compare in constant-time with the sender Address 20-byte payload.
- Reject before creating a SigningRequest when it differs.

The kit does not derive a path/key or accept an expected address supplied by the signer.

## Signature Validation

Treat signer output as untrusted:

- exactly 64 bytes `r || s`;
- `r` and `s` non-zero and strictly below curve order;
- `s` no greater than half order (low-S);
- verify ECDSA over the exact 32-byte S2-03 digest and compressed public key;
- no DER, recoverable header, Ethereum `v`, or silent normalization on receipt.

HsCryptoKit's compact normalized signing is a host implementation analog. ThorChainKit verifies with the package's direct secp256k1 dependency; producer success is not proof.

## Cancellation and Errors

- Cancellation observed before lifecycle-first actor admission leaves the quote unconsumed. After admission, valid quote validation and consumption occur without suspension; there is no cancellable gap between them.
- Once the valid quote is consumed, it remains consumed even if signer cancels/fails.
- Cancellation or absolute quote expiry while awaiting signer invalidates the attempt and releases the gate/unlinked reservation immediately. The owned signer task is cancelled as a hint but is not awaited; a non-cooperative or never-returning signer cannot keep the account gate locked.
- The same rule applies while acquiring the H1/H2 lease and awaiting every revalidation request/backoff. Each request is one owned operation, token validity is checked on actor re-entry before another request begins, and a non-cooperative provider cannot retain the gate or reservation.
- Cancellation after a durable broadcast state begins is governed by S2-05 and becomes unknown as necessary.
- Signer errors cross as a bounded typed category; error text is not trusted/logged verbatim.

## Concurrency Contract

- At most one active sign/submission per wallet/network/sender/sequence across all Kit instances sharing the process-wide runtime. Cross-process/app-extension signing is outside Sprint 2.
- Quotes may be prepared concurrently.
- Distinct account namespaces can send concurrently.
- The actor never performs blocking work.
- The `Signer` protocol is `Sendable`; mutable implementations must provide their own synchronization.
- `SigningRequest` is explicitly `Sendable`. A host actor implements the synchronous key requirement as immutable `nonisolated let compressedPublicKey`; the kit captures it once.
- No `@unchecked Sendable` is introduced for kit-owned mutable state.

## Analog Delta

Unstoppable wrappers establish that the host owns signing capability; HsCryptoKit provides compact low-S output. EvmKit's synchronous concrete private-key signer is rejected. Vultisig verification/vectors support the cryptographic shape but its MPC/TSS request model is not imported.

## Tests Before Implementation

- correct key/address and signature success vector;
- invalid key length/prefix/curve point and wrong address, with zero signer calls where applicable;
- signature length, zero/out-of-range scalars, high-S, wrong digest/key;
- exact SigningRequest fields and redacted description;
- sequence/fee/halt/balance/module/memo changes before first revalidation;
- each change while signer continuation is suspended: signature discarded, zero submission calls;
- simultaneous same-account sends: one signer call/one `sendInProgress`;
- never-started and after-stop send, including a foreign/expired quote, fail with `kitNotStarted` before QuoteStore access/consumption/reservation/signer; a QuoteStore spy stays at zero, stop racing first-step admission has an actor-ordered winner, and stop after admission leaves the operation hold until clean finalization or repair transfer;
- two independently constructed Kit instances from standardized, relative-alias, symlink, hard-link, and duplicate URLs for one SQLite file converge on one `DatabaseFileIdentity`, one writer/runtime initialization, one reservation, and at most one signer call; a separate SQL test proves the unique constraint across intentionally independent test connections;
- two wallet/network namespaces in the same physical database receive distinct child runtimes/rows while sharing the exact writer and observation connection;
- restart clears only unlinked reservation, while a journal-linked check-tx-accepted/unknown reservation blocks a different transaction at the same sequence;
- distinct accounts can overlap;
- signer throw/cancel/late completion that ignores cancellation, plus a signer that never resumes: cancellation/expiry returns promptly, releases the gate, and no late result can create a journal/broadcast;
- H1 and H2 lease/read/backoff continuations that ignore cancellation, never resume, or return late: cancellation/deadline returns promptly, exact ownership is finalized, no subsequent endpoint request starts, and no signer/journal/broadcast is reached from the stale callback;
- fail the unlinked owner-token deletion after cancellation: no signer is called while cleanup is pending, live repair deletes only that inactive token without restart, and a fresh quote then sends in the same process;
- computed/mutating key getter is read once; captured key drives address, AuthInfo, and verification;
- quote cannot be reused after any started attempt;
- strict concurrency build with a test actor signer.

## Verification

```text
swift test --filter SignerVerifierTests
swift test --filter SendCoordinatorTests
swift test --filter SendCoordinatorConcurrencyTests
swift test --filter SigningRequestRedactionTests
swift test
strict-concurrency diagnostics gate
```

## Acceptance Criteria

- Kit requests a signature only after signer/address binding and fresh coherent preflight.
- Every returned signature is structurally and cryptographically verified.
- Relevant state change during asynchronous signing prevents submission.
- Active-client admission and operation-hold acquisition precede every QuoteStore access; stop has deterministic actor-ordered precedence.
- One account cannot race sequences or request two simultaneous signatures.
- The kit never observes or retains a mnemonic/private key.

## Pinned Decision

There is no concrete production signer in ThorChainKit. The Example may provide a fixture/test signer; Unstoppable supplies the real host signer in S2-07 through the same protocol.
