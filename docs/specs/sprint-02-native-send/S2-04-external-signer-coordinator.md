# S2-04 — External Signer and Per-Account Coordinator

**Design revision:** 6 (discovery 1/2; closure 0/5)
**Risk:** critical
**Depends on:** S2-01 API, S2-02 revalidation, S2-03 codec at merged
implementation base `3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`. Its tree is
identical to the exact accepted PR head
`d548b9b5b858e6ed96793a8d3e40de6084e96efa`.
**Produces:** a verified signed transaction and an owned handoff to S2-05; no journal or broadcast implementation

## Goal

Let a host-controlled asynchronous signer authorize one reviewed transaction
while the kit retains control of bytes, validates signer identity and
signature, and prevents account-level sequence races.

## Scope and non-goals

In scope are the public `Signer` contract, internal signing-request
construction, signer key/address binding, compact low-S verification, the
`SendCoordinator` lifecycle, quote consumption, cancellation and H1/H2
revalidation ordering, one attempt per account namespace, shared physical-file
database ownership, and the minimum owned handoff seam for S2-05.

Out of scope are seed or private-key derivation, hardware/MPC implementation,
journal persistence, broadcast, UI confirmation, host localization, and
cross-process or app-extension coordination.

## Proposed areas and types

```text
Sources/ThorChainKit/Send/Signing/
  SendCoordinatorRegistry.swift
  SendCoordinator.swift
  SendCoordinatorResult.swift
  SignerVerifier.swift
  CompactSignature.swift
  SigningRequestFactory.swift
  SendAttemptHandoff.swift
Sources/ThorChainKit/Send/Storage/
  SendRuntimeRegistry.swift
  DatabaseLocation.swift
  DatabaseRuntime.swift
  SendRuntime.swift
  SequenceReservationStore.swift
  SequenceReservationMigration.swift
Sources/ThorChainKit/Core/KitFactory.swift
Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift
Tests/ThorChainKitTests/Send/Signing/
  SendCoordinatorTests.swift
  SendCoordinatorConcurrencyTests.swift
  SendCoordinatorPublicBoundaryTests.swift
  SignerVerifierTests.swift
  SigningRequestRedactionTests.swift
Tests/ThorChainKitTests/KitCompositionTests.swift
Tests/ThorChainKitTests/AccountStateStorageTests.swift
```

The implementation may use fewer files, but every changed path must map to an
acceptance criterion below. The existing production factory and Sprint-1 sync
storage are part of the allowlist because unit-only runtime convergence would
not prove production convergence.

## Runtime and ownership topology

`SendRuntimeRegistry.shared` is an internal process-wide actor keyed by the
physical SQLite `DatabaseFileIdentity` `(device, inode)`, not by wallet
namespace. One `DatabaseRuntime` owns the sole GRDB `DatabaseWriter` for that
file. It contains child `SendRuntime`s keyed by the existing stable
wallet/network namespace. Each Kit receives a client lease into its namespace;
the lease owns the lifecycle generation and quote invalidation for that Kit.
Once an attempt is admitted, the attempt owns the operation hold through clean
finalization or typed repair transfer; `stop()` never releases an admitted
attempt's hold. Two namespaces may overlap safely, but never create
independent writers for one physical file.

`DatabaseLocation.resolve()` is executable:

1. require a file URL, standardize path components, resolve symlinks through the
   existing parent, and create the private parent directory when needed;
2. open or create the database with owner-only permissions, call `fstat`, and
   use `(device, inode)` as identity;
3. retain the descriptor until the registry installs an `.initializing` entry,
   construct one `DatabasePool` at the resolved path, and verify that the path
   still resolves to the same identity;
4. within the registry actor, return a ready/initializing entry or install one
   initialization task before its first suspension. Only that task constructs
   the writer and runs file-wide migration. A failed task removes only its
   matching entry so a later construction can retry.

The production `KitFactory` must obtain both sync storage and the send runtime
from this same `DatabaseRuntime`; `GrdbAccountStateStorage(path:)` cannot
create an independent pool in the production path. `DatabaseRuntime.open(...)`
is the sole production construction seam: it resolves the physical identity,
constructs the writer, runs the file-wide migration once, and then passes an
already-migrated `DatabaseWriter` to
`GrdbAccountStateStorage(writer:)` and the send runtime. The writer initializer
does not migrate. In-memory runtimes remain an explicit test-only injection.
Namespace derivation partitions rows and child runtimes but never participates
in physical-file identity.

Each account namespace has an in-memory admission key
`(persistenceNamespace, senderPayload)` with no sequence component. It owns one
`AccountAttemptState` containing the operation hold, account gate, durable
reservation owner token, and an `outstandingSignerFence`. The
`reservationOwnerToken` is generated once for the admitted attempt before
reservation acquisition; it is the attempt token and the reservation's
owner-CAS credential, but is persisted only if acquisition succeeds. Durable
SQL uniqueness remains `(namespace, senderPayload, sequence)` with that owner
token. Thus
different sequences cannot sign concurrently for one account, while distinct
account namespaces can overlap.

The signer fence is deliberately separate from the short-lived durable
reservation. If cancellation or expiry returns while a signer ignores
cancellation, the unlinked reservation and client operation hold are finalized
promptly, but the account's outstanding-signer fence remains occupied until
the signer task reports completion. A second send returns typed
`sendInProgress` without calling a signer. If a signer never returns, the fence
stays fail-closed for the life of that process/runtime; process restart clears
only in-memory fences after startup reconciliation. A late result always
re-enters the coordinator actor, observes the invalid attempt token, and is
discarded.

## Send sequence

Inside the coordinator actor:

1. Require an active client lease, acquire the S2-05 operation hold, and then
   acquire the account admission gate. A prior `stop()` returns
   `kitNotStarted` with zero QuoteStore/storage/signer/endpoint calls. A later
   stop cannot revoke the admitted hold.
2. Validate quote origin, binding, lifecycle generation, expiry, and unused
   state, then consume it. Once valid consumption begins the quote remains
   consumed even if a later step fails.
3. Read `signer.compressedPublicKey` exactly once into immutable `Data`, validate
   it, and bind it to the sender.
4. Run S2-02 coherent H1 revalidation at `H1 >= H0` on the quote's provider
   family. Every lease/read/backoff is a separate cancellable operation with
   the attempt token. Cancellation, deadline, or expiry invalidates the token
   and returns without awaiting a non-cooperative provider. A non-null H1
   account key must equal the captured signer key; null remains valid for a
   first outgoing transaction.
5. Acquire the durable sequence reservation. A conflict returns
   `sendInProgress` and makes zero signer calls.
6. Build the exact S2-03 SignDoc and digest, then an internal `SigningRequest`
   containing the captured key, digest, and reviewed transaction fields.
7. Start one owned, non-detached `Task` that calls `signer.sign(request)`. Race
   its result against caller cancellation and absolute quote expiry through an
   actor-owned exactly-once result channel. The coordinator never waits for a
   non-cooperative child to terminate.
8. If cancellation or expiry wins, invalidate the attempt and route it through
   the exactly-once finalizer. The finalizer owner-CAS releases the still-
   unlinked reservation and account gate; it releases the attempt-owned
   operation hold only after that cleanup succeeds, then returns promptly.
   If owner-CAS cleanup fails, it returns typed
   `SendCoordinatorResult.repairPending(RepairIntent)` with the matching
   reservation, operation hold, and owner token retained until S2-05 repair.
   Keep the account signer fence until the signer task reports completion;
   discard its late result without journal/broadcast.
9. Revalidate the complete snapshot at `H2 >= H1` through the same operation
   race. Repeat the account-key equality check and a final cancellation/token
   check before CPU verification. No late provider callback may begin another
   request.
10. Verify the compact signature over the exact S2-03 digest and captured key,
    construct exact TxRaw/local hash using the same body and auth bytes, and
    run one final token check.
11. Create the internal `SendAttemptHandoff`, which contains the verified
    `SignedTransaction` plus the still-owned account gate, the exact
    `reservationOwnerToken`/attempt token, operation-hold lease, and namespace
    runtime handle. The token in the handoff is the same owner-CAS identity
    retained by `AccountAttemptState` and stored in the durable reservation;
    there is no second or ambiguous handoff token. S2-05 consumes this
    internal handoff and is the only owner allowed to transition it to linked,
    rejected, or repair-pending. S2-04 does not implement journal/broadcast,
    and it does not release the gate before this handoff is consumed. The
    coordinator's internal result is the handoff; S2-04 exposes no public
    bare-`SignedTransaction` return while ownership is retained.
12. Every pre-link failure invokes one exactly-once finalizer. A successful
    finalizer owner-CAS releases the reservation, account gate, signer fence
    when applicable, and operation hold. If owner-token deletion fails, the
    internal `SendCoordinatorResult.repairPending(RepairIntent)` result retains
    the matching reservation/hold and exact owner-CAS token as repair intent;
    it is not mapped to an untyped `SendError`. New signer calls are blocked,
    and only the bounded shared-writer repair path may clear that matching
    intent. S2-04 does not complete repair or admit a fresh-quote retry; only
    the bounded shared-writer repair path owned by S2-05 may clear that matching
    intent. A fresh quote can proceed only after S2-05 reports matching repair
    success.

## Public result boundary

S2-04 does not widen the public `Kit.send` result. Until S2-05 consumes the
internal `SendAttemptHandoff`, the existing public facade remains fail-closed:
it returns `SendError.operationUnavailable` and performs zero QuoteStore,
storage, signer, endpoint, journal, or broadcast work. The internal
`SendCoordinatorResult.handoff(SendAttemptHandoff)` seam is tested directly;
no public bare `SignedTransaction` is exposed while the attempt still owns its
gate, hold, and reservation token.

## Address and public-key binding

- require exactly one valid compressed secp256k1 public key, 33 bytes with
  prefix `02` or `03`;
- compute `RIPEMD160(SHA256(compressedPublicKey))`;
- compare the 20-byte result in constant time with the sender address payload;
- reject before creating a `SigningRequest` when it differs.

The kit never derives a key or accepts an expected address supplied by the
signer.

## Signature validation

Signer output is untrusted and must be exactly 64 bytes `r || s`. Both scalars
are non-zero and below curve order; `s` is at most half the order; ECDSA is
verified over the exact 32-byte S2-03 digest and captured compressed key. DER,
recoverable headers, Ethereum `v`, and silent normalization are rejected.

HsCryptoKit's compact normalized output is supporting evidence only. The kit
verifies with its direct secp256k1 dependency; producer success is not proof.

## Error and cancellation contract

Cancellation before actor admission leaves the quote unconsumed. After
admission, quote validation and consumption are contiguous. Cancellation or
absolute expiry while awaiting a signer/provider returns promptly, invalidates
the attempt, and prevents any subsequent request or handoff from a stale
callback. A signer fence may outlive the caller response as described above.

Signer errors cross as bounded typed categories; untrusted error text is not
logged or exposed. No mnemonic, seed, private-key value, or derivation API is
observed by kit-owned S2-04 paths.

The internal coordinator result is a typed `SendCoordinatorResult` with
`handoff(SendAttemptHandoff)`, bounded `failure(SendError)`, and
`repairPending(RepairIntent)` cases. `RepairIntent` retains the namespace,
sequence, reservation identity, and exact `reservationOwnerToken` needed for
owner-CAS repair; it has no public/localized description and never logs the
token. `SendError.swift` is not changed for this internal-only result. S2-05
owns consumption of the handoff and repair intent; S2-04 owns only creation,
retention, and fail-closed blocking.

## Acceptance criteria

1. A signature request occurs only after admission, quote consumption, key/
   address binding, and coherent H1 preflight.
2. Returned signatures pass structural and cryptographic verification over the
   exact S2-03 digest; cross-wired digest/payload bytes are rejected.
3. H2 rejects changed, stale, cancelled, expired, and late results without
   submission or broadcast.
4. Admission and the operation hold precede QuoteStore access; stop ordering is
   actor-deterministic; failed cleanup is explicit repair-pending.
5. One account cannot race sequences or request simultaneous signatures across
   Kit instances; cancelled non-cooperative signers retain the account fence.
6. Production factory and Sprint-1 sync storage converge on one physical-file
   writer/runtime; registry initialization failures remove only the matching
   entry and permit a later retry.
7. The public signer boundary and S2-04 source contain no seed/private-key
   observation, retention, logging, or derivation.

### Acceptance-to-test matrix

| Criterion | Exact observable and test | Verification command |
|---|---|---|
| AC1 | `SendCoordinatorTests.testSignerStartsAfterAdmissionQuoteConsumptionBindingAndH1` proves ordering and one signer call. | `xcrun swift test --filter SendCoordinatorTests.testSignerStartsAfterAdmissionQuoteConsumptionBindingAndH1` |
| AC2 | `SignerVerifierTests.testCompactSignatureRules` and `SendCoordinatorTests.testExactDigestAndTxRawCrossWireIsRejected` prove key/signature structure, low-S, exact digest, and exact bytes. | `xcrun swift test --filter SignerVerifierTests` and `xcrun swift test --filter SendCoordinatorTests.testExactDigestAndTxRawCrossWireIsRejected` |
| AC3 | `SendCoordinatorTests.testH2RejectsChangedStaleCancelledExpiredAndLateResults` proves each rejection has zero handoff/submission/broadcast; the late-result case also proves no later provider request. | `xcrun swift test --filter SendCoordinatorTests.testH2RejectsChangedStaleCancelledExpiredAndLateResults` |
| AC4 | `SendCoordinatorTests.testAdmissionAndOperationHoldPrecedeQuoteAccess`, `testStopDoesNotReleaseAdmittedAttemptHold`, and `testCleanupFailureReturnsRepairPending` prove ordering, stop behavior, and typed repair. | `xcrun swift test --filter SendCoordinatorTests` |
| AC5 | `SendCoordinatorConcurrencyTests.testSameAccountDifferentSequencesUseOneGate`, `testCancelledSignerRetainsFence`, and `testReleasedSignerFenceAllowsExactlyOneFreshAttempt` prove one attempt, retained fence, and release. | `xcrun swift test --filter SendCoordinatorConcurrencyTests` |
| AC6 | `KitCompositionTests.testTwoKitsShareOnePhysicalWriterAndMigrationBarrier` and `testInitializationFailureRemovesOnlyMatchingEntry` prove alias convergence, one writer, one migration barrier, and retry. | `xcrun swift test --filter KitCompositionTests` |
| AC7 | `SendCoordinatorPublicBoundaryTests.testPublicSendIsUnavailableAndSideEffectFree` plus the fail-on-match source/public-symbol audits prove no public bare transaction and no seed/private-key API observation. | `xcrun swift test --filter SendCoordinatorPublicBoundaryTests`, then the expected-no-match audits in the verification block (each `rg` must exit 1; exit 0 or 2 fails). |

## Tests before implementation

- key/address success and invalid key length/prefix/point/wrong-address vectors,
  with zero signer calls where applicable;
- signature length, zero/out-of-range scalar, high-S, wrong digest/key, and
  exact digest/TxRaw golden cross-wire rejection;
- exact `SigningRequest` fields and redacted description;
- H1/H2 state changes, cancellation, expiry, late callbacks, and no subsequent
  provider request;
- stop/admission ordering and quote-consumption invariants;
- two same-account Kit instances with different sequences: one account gate,
  one signer call, and `sendInProgress` for the loser;
- cancellation followed immediately by a second send while a non-cooperative
  signer is suspended: prompt first return, second `sendInProgress`, zero
  second signer calls, and no late handoff;
- owner-token deletion failure: assert the typed internal
  `SendCoordinatorResult.repairPending(RepairIntent)` contains the exact
  namespace, sequence, reservation identity, owner token, and retained
  operation hold; assert fail-closed admission and zero signer calls while
  pending. S2-05 repair completion and fresh-quote retry are out of scope;
- two independently constructed Kit instances using standardized, relative,
  symlink, hard-link, and duplicate URLs for one SQLite file: one identity,
  one writer/runtime initialization, one reservation; distinct namespaces share
  the writer but may overlap;
- registry initialization failure with concurrent waiters: matching entry is
  removed and exactly one writer/migration occurs after retry;
- production `KitFactory` and `GrdbAccountStateStorage` composition tests prove
  `DatabaseRuntime.open(...)` is the only migration/writer construction path,
  no direct second pool exists, and two Kits share one physical writer;
- a permanently suspended signer with an injected clock and bounded XCTest
  completion oracle: prompt caller return, retained signer fence, no second
  signer call, and no provider fixture mixed into this test;
- a separately releasable suspended signer: release after prompt return, assert
  the late callback has zero side effects, then start a fresh same-account
  attempt and assert exactly one fresh signer invocation succeeds;
- a separately non-cooperative provider fixture: prompt operation-hold/gate
  release on cancellation or expiry, zero signer calls, and no later provider
  request;
- source/public-symbol audit for absence of seed/private-key APIs in all
  kit-owned S2-04 paths;
- strict concurrency diagnostics with a test-actor signer.

## Verification commands

```sh
S2_03_ACCEPTED=d548b9b5b858e6ed96793a8d3e40de6084e96efa
S2_03_MERGED=3e8d103821a5c2388143a0ce8d99d4d7c674d9ed
test "$(git rev-parse "${S2_03_ACCEPTED}^{tree}")" = \
  "$(git rev-parse "${S2_03_MERGED}^{tree}")"
git merge-base --is-ancestor "$S2_03_MERGED" HEAD
git cat-file -e HEAD:Sources/ThorChainKit/Protocol/DirectSignCodec.swift
git cat-file -e HEAD:Tests/ThorChainKitTests/Protocol/DirectSignCodecTests.swift
test "$(xcrun swift test --list-tests | rg -c 'SignerVerifierTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorConcurrencyTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SigningRequestRedactionTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'KitCompositionTests[./]testTwoKitsShareOnePhysicalWriterAndMigrationBarrier')" -eq 1
test "$(xcrun swift test --list-tests | rg -c 'KitCompositionTests[./]testInitializationFailureRemovesOnlyMatchingEntry')" -eq 1
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorPublicBoundaryTests[./]testPublicSendIsUnavailableAndSideEffectFree')" -eq 1
xcrun swift test --filter SignerVerifierTests
xcrun swift test --filter SendCoordinatorTests
xcrun swift test --filter SendCoordinatorConcurrencyTests
xcrun swift test --filter SigningRequestRedactionTests
xcrun swift test --filter KitCompositionTests
xcrun swift test --filter SendCoordinatorPublicBoundaryTests
xcrun swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
xcrun swift test
# Expected-no-match audits: each rg must exit 1; exit 0 or 2 fails.
secret_audit_status=0
rg -n -i '(seed|mnemonic|private[ -]?key|derive)' Sources/ThorChainKit/Send Sources/ThorChainKit/Core/Kit+Send.swift || secret_audit_status=$?
test "$secret_audit_status" -eq 1
public_symbol_audit_status=0
rg -n 'public[[:space:]]+.*(SignedTransaction|SendAttemptHandoff)' Sources/ThorChainKit/Send Sources/ThorChainKit/Core/Kit+Send.swift || public_symbol_audit_status=$?
test "$public_symbol_audit_status" -eq 1
git diff --check
```

GitHub Actions is not an acceptance gate for ThorChainKit. No hosted test,
simulator, mutant, or Maestro run is authorized by this slice.

The exact accepted S2-03 head
`d548b9b5b858e6ed96793a8d3e40de6084e96efa` was squash-merged as
`3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`; both commits have tree
`bc3383aa310989f51261b48e42d9669ff24b85d9`. The S2-04 implementation and
verification worktree must descend from the merged commit and contain both
`Sources/ThorChainKit/Protocol/DirectSignCodec.swift` and
`Tests/ThorChainKitTests/Protocol/DirectSignCodecTests.swift`. The earlier
docs-only base `ef064ba` is insufficient.

## Analog delta matrix and approval gate

Unstoppable wrappers establish host-owned signer capability; HsCryptoKit
supports compact low-S output; Vultisig supplies verification/vectors; EvmKit's
concrete private-key signer is a rejected counterexample. None supplies the
full coordinator spine. The account gate, signer fence, shared writer, repair
state, and owned S2-05 handoff are explicit greenfield deltas.

| Slice | Primary invariant and verified analog role | Required S2-04 delta | Rejected difference | Failure mode and test | Verification |
|---|---|---|---|---|---|
| Host-owned signing/coordinator | Existing kit lifecycle/quote ownership remains the boundary; host signer capability is supporting contract evidence; S2-03 exact bytes remain the codec contract. | Add one actor-owned account gate, signer fence, exact key/address and low-S verification, H1/H2 ordering, shared writer/runtime, typed repair-pending state, and internal owned handoff. | No seed/private-key derivation, journal, broadcast, public bare transaction, S2-05 repair completion/retry, UI, or cross-process runtime. | Cancellation, stale/late result, signer suspension, writer initialization failure, and cleanup deletion failure fail closed; covered by the named coordinator, concurrency, composition, and public-boundary tests above. | Exact-base preflight, focused `xcrun swift test` filters, strict-concurrency test, full local `xcrun swift test`, source audit, and `git diff --check`. |

Discovery remains frozen at `1/2`; the next bounded review is a targeted
recheck of D-155-01 through D-155-11 plus direct regressions only. Product
implementation remains prohibited until this revision and its linked plan are
explicitly approved by the operator.
