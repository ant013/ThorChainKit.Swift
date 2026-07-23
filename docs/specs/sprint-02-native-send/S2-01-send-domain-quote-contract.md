# S2-01 — Send Domain and Quote Contract

**Risk:** high
**Depends on:** completed Sprint 1 public/network/address foundation
**Produces:** the complete public send type graph and an input-validating quote facade; no signing or broadcast yet

## Goal

Define one host-neutral API that separates mutable UI input, immutable review data, user authorization, and broadcast outcome. The API cannot expose secret material or allow the host to assemble authoritative fee/sequence/sign bytes.

## Assumptions

- Native amounts use the package's approved arbitrary-precision base-unit representation.
- Existing `Address`, `Network`, `Kit`, endpoint, and publisher conventions from Sprint 1 remain authoritative.
- Pinned BigInt 5.3.0 does not make `BigUInt` `Sendable`. Any public type that crosses an actor/task boundary stores validated `Data`/string/integer snapshots only and may expose a newly reconstructed `BigUInt` through a read-only computed accessor; no `@unchecked Sendable` or `@preconcurrency` suppression is permitted.

## Scope

- public `Signer`, `SigningRequest`, `SendQuote`, `SendSubmission`, `TransactionID`, `PendingTransaction`, `SendError`, and supporting value types/enums;
- public `Kit.quote`, `Kit.send`, `Kit.retryBroadcast`, pending snapshot/publisher;
- immutable quote identity/binding, ten-second expiry, and one-use semantics;
- cheap local validation before any network work;
- deterministic public error descriptions without secrets.

Out of scope: network preflight implementation, protobuf, cryptographic verification, journal, transport, Example UI, and host integration. S2-01 defines the public pending/retry contracts and an in-memory contract test seam only; S2-05 owns durable journal/runtime/recovery, observation replacement, operation holds, and concrete retry behavior. Later slices implement these behind the API without changing its ownership.

## Proposed Package Areas

```text
Sources/ThorChainKit/
  Core/Kit+Send.swift
  Send/Domain/SendQuote.swift
  Send/Domain/SendSubmission.swift
  Send/Domain/PendingTransaction.swift
  Send/Domain/SigningRequest.swift
  Send/Domain/TransactionID.swift
  Send/Errors/SendError.swift
  Send/Signer.swift
  Send/Internal/QuoteStore.swift
Tests/ThorChainKitTests/Send/Domain/
  SendQuoteTests.swift
  QuoteStoreTests.swift
  SendErrorTests.swift
  SendPublicApiTests.swift
```

Exact placement may follow the package layout created in Sprint 1; type names and dependency direction are fixed.

## Public API

```swift
public protocol Signer: Sendable {
    var compressedPublicKey: Data { get }
    func sign(_ request: SigningRequest) async throws -> Data
}

public struct SendAmount: Sendable {
    private enum Kind: Sendable { case exact, maximum }

    public static func exact(_ amount: BigUInt) -> SendAmount
    public static var maximum: SendAmount { get }

    public var exactAmount: BigUInt? { get }

    private let kind: Kind
    private let exactMagnitude: Data?
}

extension Kit {
    public func quote(
        to: Address,
        amount: SendAmount,
        memo: String? = nil
    ) async throws -> SendQuote

    public func send(
        quote: SendQuote,
        signer: any Signer
    ) async throws -> SendSubmission

    public func retryBroadcast(
        transactionId: TransactionID,
        acceptingNativeFee: BigUInt? = nil
    ) async throws -> SendSubmission

    public var pendingTransactions: [PendingTransaction] { get }
    public var pendingTransactionsPublisher: AnyPublisher<[PendingTransaction], Never> { get }
    public var pendingTransactionsStatus: PendingTransactionsStatus { get }
    public var pendingTransactionsStatusPublisher: AnyPublisher<PendingTransactionsStatus, Never> { get }
}
```

`Kit` remains the only public behavior facade. No public transaction builder, raw account/sequence override, fee override, gas override, private-key constructor, or arbitrary broadcast method exists.

`quote`, `send`, and `retryBroadcast` require this `Kit` instance's Sprint 1 lifecycle client to be active. A never-started or stopped instance throws `SendError.kitNotStarted` before QuoteStore/journal access, quote-token consumption, signer work, or endpoint I/O. The runtime actor gives every successful `start()` activation a monotonic client lifecycle generation. Quote admission captures that exact generation; every H0 callback, next-request decision, and final QuoteStore insertion must still match it. `stop()` deactivates and advances the generation, resolves any suspended quote-operation waiters with `kitNotStarted`, and invalidates in-flight quote construction and stored unconsumed quotes. A late H0 callback from the old generation is discarded, cannot store/return a quote after a rapid `start()`, and cannot begin another request. Once QuoteStore atomically admits a send/retry by consuming a quote or retry record, that operation is no longer an unconsumed quote; S2-05 supplies the later operation hold so it can finish or repair after client stop. The S2-01 state contract therefore distinguishes construction, unconsumed, admitted, and terminal states explicitly.

`SendAmount.exact(_:)` immediately copies the caller's `BigUInt` into canonical big-endian magnitude `Data`; `.maximum` stores no magnitude. The public call spelling remains `SendAmount.exact(value)`/`.maximum`, but the value that enters `QuoteStore`, an endpoint task, or an actor is checked `Sendable`. Likewise, `Kit.retryBroadcast(...acceptingNativeFee:)` is a non-actor-isolated facade entry point whose first operation canonicalizes its optional ergonomic `BigUInt` argument into an internal `Data?` snapshot before any runtime-actor call; the public argument is never captured by an escaping task. Neither caller-owned BigInt storage crosses a task or actor boundary. The strict-concurrency test invokes the facade from a caller task and proves the snapshot occurs before the first actor hop.

`SendAmount.maximum` is an explicit user intent, not a magic numeric sentinel. S2-02 resolves it inside the same coherent snapshot as the native fee by calculating checked `spendableRune - nativeFee`; the returned quote always contains the actual positive amount the user will sign. `exact` is never silently reduced.

## `SendQuote`

Public immutable review fields:

```swift
public struct SendQuote: Sendable {
    public let recipient: Address
    public var amount: BigUInt { BigUInt(amountMagnitude) }
    public let isMaximum: Bool
    public var nativeFee: BigUInt { BigUInt(nativeFeeMagnitude) }
    public var totalDebit: BigUInt { BigUInt(totalDebitMagnitude) }
    public let memo: String?
    public let acceptedHeight: Int64
    public let expiresAt: Date

    private let amountMagnitude: Data
    private let nativeFeeMagnitude: Data
    private let totalDebitMagnitude: Data
    private let quoteToken: Data

    internal var internalQuoteToken: Data { quoteToken }
}
```

The custom authoritative initializer is internal; private magnitude fields make the synthesized memberwise initializer unavailable outside the type. The three amount accessors reconstruct a fresh `BigUInt` from canonical big-endian `Data` magnitudes using BigInt's nonfailing `BigUInt(Data)` initializer; no `BigUInt` is stored. Zero fee uses empty canonical magnitude, while amount/total remain positive. Strict Swift 5 complete-mode compilation proves every stored field—including Sprint 1's `Address`, the random quote token, `Data`, strings, integers, Bool and Date—is `Sendable`. `internalQuoteToken` is implemented in `SendQuote.swift`, returns the value snapshot, and is the only cross-file access used by `QuoteStore`; it and the initializer remain invisible to an external consumer.

Internal state contains one 32-byte opaque quote token generated with the platform secure-random source; a token collision is retried inside the same atomic store operation. `QuoteStore` maps that token to the authoritative wallet/network namespace, lifecycle client ID/generation, sender, requested amount intent, account number, sequence, provider-family lease identity, policy snapshot, and every review field. The insertion occurs only after the runtime actor revalidates the still-active captured generation. A second undefined tamper signature is intentionally not added. The quote:

- is valid only for the originating `Kit` instance/wallet namespace;
- expires exactly ten seconds after the final coherent quote snapshot has been accepted and stored, measured by an injected monotonic clock; `expiresAt` is a wall-clock display projection only;
- can start at most one send attempt; `QuoteStore.consume` is the atomic linearization point and removes/reserves the token before signer work;
- cannot be reconstructed from public review values;
- does not expose endpoint credentials, module addresses, or account metadata.

`totalDebit` is checked addition of `amount + nativeFee`; overflow is an error, never wrapping arithmetic.

Local input canonicalizes `memo == ""` to `nil` before quote creation; nonempty whitespace is not silently removed. Quote, summary, SignDoc and pending models all carry that one canonical optional value, avoiding an authorization distinction protobuf cannot encode.

## `SigningRequest`

`SigningRequest` has this exact public immutable API. Both memberwise initializers remain internal:

```swift
public struct SigningRequest: Sendable {
    public struct Summary: Sendable {
        public let sender: String
        public let recipient: String
        public let amount: String
        public let nativeFee: String
        public let totalDebit: String
        public let memo: String?
        public let accountNumber: String
        public let sequence: String
    }

    public let digest: Data                 // exactly 32 bytes
    public let serializedSignDoc: Data
    public let chainId: String
    public let requestId: String
    public let summary: Summary
}
```

The cross-actor representation contains only immutable `Data` and `String` fields. The three monetary summary strings are canonical native-RUNE display values with exactly eight fractional digits, ASCII digits only, one decimal point, no sign/grouping/exponent, and no ticker suffix: for example, `100_000_000` base units is `"1.00000000"`. `amount`, `nativeFee`, and `totalDebit` always mean RUNE at eight decimals; `totalDebit` must be the checked exact sum of the first two both in base units and in this representation. `accountNumber` and `sequence` are canonical unsigned base-10 integers with no leading zero except `"0"`. Sender/recipient are canonical network Bech32 strings and memo is the exact reviewed UTF-8 value. `requestId` is an opaque random public correlation value bound to the quote attempt and contains no wallet identifier or secret.

S2-01's internal `SigningRequest` constructor validates only the immutable
field shape, fixed-size digest, canonical summary strings, and request-id
requirements; it does not decode protobuf or release signer bytes. S2-03 owns
SignDoc construction/decoding and exact byte consistency. S2-04 owns signer
binding and signature verification. Both later slices must preserve this public
request shape. The SignDoc `Fee.amount` remains empty by THORChain protocol, so
`nativeFee` is authorized quote policy rather than a serialized fee coin.

The signer returns only a 64-byte compact signature. It cannot replace body/auth/sign bytes or mutate the quote. `description`, debug output, and errors redact SignDoc bytes and signature.

## Submission and Pending Models

```swift
public struct TransactionID: Hashable, Sendable {
    public let hash: String       // canonical uppercase 64-char hex
}

public struct SendSubmission: Sendable {
    public enum State: Sendable { case checkTxAccepted, unknown }
    public let transactionId: TransactionID
    public let state: State
}

public struct PendingTransaction: Sendable {
    public enum State: Sendable { case checkTxAccepted, unknown }
    public enum RetryAvailability: Sendable { case available, inFlight, sequenceAdvanced, providerInconsistent, notApplicable }
    public let transactionId: TransactionID
    public let recipient: Address
    public var amount: BigUInt { BigUInt(amountMagnitude) }
    public var nativeFee: BigUInt { BigUInt(nativeFeeMagnitude) }
    public let memo: String?
    public let state: State
    public let retryAvailability: RetryAvailability
    public let createdAt: Date

    private let amountMagnitude: Data
    private let nativeFeeMagnitude: Data
}

public enum PendingTransactionsStatus: Sendable {
    case ready
    case degraded
}
```

`PendingTransaction` is created only by the kit through an internal invariant-checking initializer. Amount and fee use the same canonical magnitude rules as `SendQuote`; no public pending value stores `BigUInt`, even though ergonomic computed accessors return newly reconstructed values. The complete pending graph is therefore safe to publish from the dedicated state queue and replay across Combine subscribers without unchecked conformance.

S2-01 defines only the immutable pending value graph, deterministic ordering contract, and nonfailing facade signatures. A local in-memory publisher fixture may replay a supplied snapshot for contract tests; it does not create a journal or claim durable readiness. S2-05 owns migration/recovery, the shared writer, GRDB observation replacement, operation holds, broadcasting-row persistence, degraded health transitions, and concrete retry behavior. No S2-01 test may require GRDB, protobuf, transport, or a durable store.

`checkTxAccepted` is deliberately literal: it means the node accepted CheckTx, not that the transaction was included or confirmed. UI text and tests must use that meaning.

## Stable Error Surface

The complete Sprint 2 public error graph is fixed rather than left to implementation inference:

```swift
public enum QuoteChange: String, Hashable, Sendable {
    case providerIdentity
    case heightRollback
    case accountNumber
    case sequence
    case accountPublicKey
    case balance
    case nativeFee
    case haltStatus
    case memoPolicy
    case recipientPolicy
}

public struct QuoteChanges: Equatable, Sendable {
    public let values: Set<QuoteChange>

    internal init?(validating values: Set<QuoteChange>) {
        guard !values.isEmpty else { return nil }
        self.values = values
    }
}

public enum RetryBlockedReason: String, Hashable, Sendable {
    case sequenceAdvanced
    case providerInconsistent
}

public struct NativeFeeChange: Equatable, Sendable {
    public var previous: BigUInt { BigUInt(previousMagnitude) }
    public var current: BigUInt { BigUInt(currentMagnitude) }

    private let previousMagnitude: Data
    private let currentMagnitude: Data
}

public struct BroadcastRejection: Equatable, Sendable {
    public let code: UInt32
    public let codespace: String?
    public let sanitizedLog: String?
}

public enum SendError: Error, Equatable, Sendable {
    case invalidAmount
    case invalidRecipient
    case selfRecipient
    case recipientIsModule
    case memoTooLong(maxUTF8Bytes: Int)
    case chainHalted
    case accountUnavailable
    case insufficientBalance
    case providerUnavailable
    case heightUnproven
    case policyUnavailable
    case kitNotStarted
    case quoteExpired
    case quoteChanged(QuoteChanges)
    case quoteAlreadyConsumed
    case quoteOwnershipMismatch
    case signerAddressMismatch
    case invalidPublicKey
    case signerCancelled
    case signerFailed
    case invalidSignature
    case sendInProgress
    case storageUnavailable
    case broadcastRejected(BroadcastRejection)
    case retryRecordMissing
    case retryTerminal
    case retryFeeChanged(NativeFeeChange)
    case retryBlocked(RetryBlockedReason)
}
```

All custom initializers for `QuoteChanges`, `NativeFeeChange`, and `BroadcastRejection` are internal and invariant-checking. `QuoteChanges` rejects an empty set and exposes its read-only nonempty `values`; the public enum case cannot be constructed from a raw or empty set. Fee magnitudes use the same canonical big-endian representation as `SendQuote`; they may be zero but never noncanonical. `BroadcastRejection.code` is nonzero; `codespace` is nil or at most 64 printable ASCII bytes; `sanitizedLog` is nil or valid UTF-8 capped at 256 bytes after control-character replacement. No public case carries an upstream `Error`, URL, response body, arbitrary log, or secret.

`LocalizedError`/debug rendering is deterministic and bounded: `quoteChanged` sorts `QuoteChanges.values` by `QuoteChange.rawValue`, monetary values render canonical base-unit decimal strings, and no description relies on `Set` iteration, upstream error text, or locale. WalletCore maps cases to localized copy; the package error itself does not own UI localization. `SendQuote`, `SigningRequest`, `PendingTransaction`, and `SendError` provide explicit `CustomDebugStringConvertible` projections that omit quote tokens, digest/sign-doc/signature bytes, public-key bytes, URLs, credentials, wallet identifiers, and upstream response text. The projections use fixed labels and bounded reviewed fields only; synthesized debug output is not permitted for these types.

`SendError` is explicitly checked `Sendable`. Because `Error` values cross concurrency boundaries, no case stores `BigUInt`; computed monetary accessors reconstruct new values. A strict compiler probe for a control `Error` case containing `BigUInt` must fail, while a probe containing this exact graph must compile without suppression.

Once exact signed bytes and a local transaction ID are durable, any uncommitted transition or ambiguous network outcome is always returned as `SendSubmission.state == .unknown`; it is never thrown as an ambiguous `SendError`. A storage error may be thrown only when the initial durable identity was not created. A definitive CheckTx rejection is thrown only after its terminal journal transaction commits; failure to persist a terminal response remains `.unknown`.

Raw URLs, credentials, wallet identifiers, public-key bytes, signatures, SignDoc/TxRaw bytes, and upstream response bodies are excluded from error/debug descriptions. `BroadcastRejection.sanitizedLog` is not a copied upstream log: its internal initializer accepts only a package-owned allowlisted diagnostic category and renders a fixed bounded string; arbitrary node text is discarded. Tests must prove a credential, URL, hash, key-like value, signature, SignDoc/TxRaw marker, and response body never appear in any public error or debug projection.

## Local Validation Order

After the facade has snapshotted ergonomic values, the first behavioral step is runtime-actor active-client admission and lifecycle-generation capture. A stopped/never-started Kit therefore returns `kitNotStarted` even when the supplied amount/recipient is also invalid. Only an admitted quote operation applies this local order before any endpoint call:

1. `.exact` amount is greater than zero; `.maximum` has no fabricated numeric amount before preflight;
2. recipient is a canonical address for the kit network;
3. recipient differs from sender;
4. memo is valid Swift UTF-8 text;
5. quote request is not already cancelled.

Network-dependent module/memo/fee/balance/halt validation is S2-02.

## Ownership and analog delta

The primary ownership spine is current TronKit's Kit-owned send/pending composition. Its raw chain-specific transaction construction is explicitly rejected. The Unstoppable EVM/TRON handler split is a supporting role-specific analog for review→send separation and expiration, not the kit lifecycle or authority owner. The immutable domain and opaque quote capability are a greenfield S2-01 delta informed by both roles. EvmKit's seed/private-key signer construction is an explicit counterexample: ThorChainKit accepts only a narrow async signer capability after user confirmation.

## Repository and evidence binding

This revision is based on the rebased branch `docs/THR-135-s2-01-formalization` at current `origin/main` `937332b2e7020868abcac8681ddd664b6e4bad72`, while preserving the canonical Sprint 2 architecture content from `518835315a65996b9321665213adb0516503df65`. This document is the S2-01 authority for implementation planning; it does not authorize production source changes.

The authorized Unstoppable supporting checkout is the operator-local checkout `$UW_ROOT`, branch `local/THR-104-thorchain-lifecycle-v0.50`, at HEAD `8a63bfda028dd8543115b26dd777235a53304311`, remote `horizontalsystems/unstoppable-wallet-ios`. Its working tree is intentionally dirty with local THR-104/THR-139 integration changes and one unrelated pre-existing `Unstoppable/Tests/Modules/MultiSwap/SwapExecutableTests.swift` change. It is read-only supporting evidence; its dirty state is not delivery evidence. The earlier `0e52f5908` identity is invalid and is not used.

Gimle indexed the UW project under a different checkout and commit. That mapping defect is quarantined as evidence metadata, with Serena and targeted `rg` on the authorized checkout as the fallback. Current TronKit and EvmKit indexed commits match their verified local trees. Vultisig raw transaction, raw key-shaped, and raw error-presentation examples are rejected counterevidence and are not copied into ThorChainKit.

## Affected areas

| Area | S2-01 change | Excluded owner |
| --- | --- | --- |
| Public send domain | Define immutable `SendAmount`, `SendQuote`, `SigningRequest`, `SendSubmission`, `TransactionID`, and `PendingTransaction` values. | None; later slices must preserve this graph. |
| Kit facade | Define quote, send, retry, pending snapshot, and publisher contracts with lifecycle admission. | S2-05 owns durable runtime and concrete retry behavior. |
| Quote capability | Define opaque identity, exact ten-second expiry, one-use consume, generation binding, and local validation. | S2-02 owns network preflight and coherent fee/account snapshot. |
| Stable errors | Define finite `SendError`, value wrappers, deterministic descriptions, and redacted debug projections. | WalletCore owns localized UI copy; transport owns private provider details. |
| Package tests | Add contract, strict-concurrency, expiry/consume, validation, and redaction test seams. | No GRDB, protobuf, transport, simulator, or Maestro tests in this slice. |

## Acceptance criteria

1. The public graph compiles on the iOS 13 floor and imports no UIKit or SwiftUI.
2. Public review, signing-request, submission, pending, and error values are immutable and `Sendable`; no public initializer permits forged quote identity, raw transaction bytes, secret material, or caller-owned `BigUInt` storage across an actor/task boundary.
3. `SendAmount` and optional retry fee values snapshot canonical magnitudes before the first actor hop; `.maximum` is explicit intent and is not represented by a numeric sentinel.
4. Quote expiry is exactly ten seconds from the accepted coherent snapshot, uses an injected monotonic clock, and is one-use with atomic consume; stale, consumed, foreign, and generation-invalid quotes fail deterministically.
5. A never-started or stopped Kit returns `kitNotStarted` before quote storage, token consumption, signer work, or endpoint work.
6. Local validation order is deterministic, and every public `SendError` case is finite, `Sendable`, equality-testable, sanitized, and bounded without upstream text or sensitive values.
7. Pending/retry contracts are immutable and honest about `checkTxAccepted` versus `unknown`; durable journal, transport, protobuf, cryptographic verification, and concrete retry behavior remain excluded.

## Verification

Verification is local to the MacBook and applies to the future implementation head, not this documentation-only revision:

1. Run `swift test` for the package after the implementation slice exists; the focused test target must cover each acceptance criterion.
2. Run a strict Swift 5 complete-concurrency compile probe proving the public graph is `Sendable` without `@unchecked Sendable` or `@preconcurrency` suppression.
3. Run focused tests for canonical `BigUInt` snapshots, lifecycle admission precedence, quote expiry boundaries, atomic one-use consume, generation invalidation, local validation order, deterministic error/debug projections, and redaction.
4. Inspect the public symbol surface to prove no transaction builder, raw account/sequence override, fee/gas override, private-key constructor, arbitrary broadcast API, URL, credential, key, signature, SignDoc, TxRaw, or response-body field is exposed.
5. Confirm the diff contains only S2-01 documentation in this phase. GitHub Actions remain build-only; no CI tests, mutants, simulators, or Maestro are part of S2-01, and no Maestro suite is applied to Unstoppable Wallet.

## Open questions

- S2-02 must define the exact provider-family lease and fee-policy snapshot fields that populate the internal quote record without changing this public graph.
- S2-03 must define the exact SignDoc encoding and digest construction behind the fixed `SigningRequest` fields.
- S2-04 must define the host signer binding and compact-signature verification policy behind the `Signer` capability.
- S2-05 must define durable pending/retry storage, recovery, observation replacement, and operation holds behind the nonfailing facade contracts.
- The package's Sprint 1 implementation will determine exact source placement; type names, ownership, and dependency direction in this document are fixed.

## Full analog delta matrix

| S2-01 slice | Verified analog evidence | Kept delta | Rejected or deferred behavior | Safety/verification consequence |
| --- | --- | --- | --- | --- |
| Immutable send domain | TronKit `TransactionSender`/`Kit` boundary; EvmKit signer boundary; UW handler registration as consumer evidence | Kit-owned immutable values, host-signer capability, opaque quote identity, explicit pending/submission states | Tron/EVM raw transaction construction, UW application lifecycle ownership, durable pending runtime | Public API inspection and strict-concurrency probes must show no raw bytes, secret material, or mutable review state. |
| One-use quote and expiry | TronKit send sequencing; UW `TronSendHandler` ten-second expiration; EvmKit signer composition | Exact ten-second monotonic expiry, atomic token consume, lifecycle-generation binding, injected-clock tests | Duration-like consumer behavior without identity proof; raw signer/transaction APIs | Boundary, `now == expiresAt`, duplicate consume, foreign Kit, stop/start race, and cancellation tests are mandatory. |
| Local validation and facade admission | UW `TronSendHandler` validation cases; TronKit Kit composition | `kitNotStarted` precedence, canonical memo, recipient/amount checks before endpoint work, explicit maximum intent | Network-dependent preflight, fee/balance/halt checks, transport | Call-order tests must prove no QuoteStore, signer, or endpoint work occurs before admission and local validation. |
| Stable sanitized errors | EvmKit typed error boundary; TronKit `SendError`; UW consumer errors | Finite `SendError`, typed value wrappers, deterministic sorted projections, allowlisted bounded diagnostics | Provider error text, URL/credential/response-body propagation, UI localization in the kit | Equality, `Sendable`, deterministic rendering, and sensitive-token redaction tests are mandatory. |
| Unsafe counterexample | Vultisig raw transaction/key-shaped fixtures and raw error presentation | Explicit rejection recorded in Gimle evidence | No raw key, raw transaction, or unbounded error string in public S2-01 types | Adversarial review must treat any such field or projection as a blocking finding. |

## Test-first implementation plan

1. Write public-surface and strict-concurrency tests first; check that immutable values compile, reject forged construction, snapshot `BigUInt`, and expose no sensitive fields.
2. Write quote-store contract tests first; check exact ten-second expiry, injected-clock boundaries, atomic one-use consume, quote ownership, lifecycle generation, cancellation, and stop/start invalidation.
3. Write facade admission and validation tests first; check `kitNotStarted` precedence and the specified amount, recipient, memo, and cancellation order without endpoint calls.
4. Write error contract tests first; check every `SendError` case, value-wrapper invariants, deterministic descriptions/debug projections, `Sendable`, and redaction of URL, credential, hash, key-like, signature, SignDoc/TxRaw, and response-body markers.
5. Write pending/submission contract tests first; check deterministic ordering, honest `checkTxAccepted`/`unknown` semantics, publisher snapshot replay, and the non-durable in-memory seam.
6. Implement only the smallest production code needed to make those tests pass. Stop before preflight, protobuf, signing verification, journal, transport, Example UI, host integration, or S2-02 work.

Kit owns quote/send authority, immutable value invariants, QuoteStore admission, and public error projections. A host adapter owns lifecycle invocation, user confirmation, and secret material; it may call Kit.start/stop but cannot construct quote authority or retain private keys in the kit.

`SigningRequestFactory` is not implemented in S2-01. This slice defines the immutable `SigningRequest` public shape and an internal construction precondition only. Independent SignDoc decoding and byte-level consistency proofs belong to S2-03/S2-04; S2-01 tests verify that an invalid internal construction makes zero signer calls without requiring protobuf.

## Tests Before Implementation

- API compile test from a temporary public-only consumer;
- `SendAmount`, `SendQuote`, `SendSubmission`, `TransactionID`, `PendingTransaction`, all nested states/status, `QuoteChanges`, `NativeFeeChange`, and `SendError` compile as checked `Sendable` under pinned Swift 5 complete mode with BigInt 5.3.0; a source guard proves no cross-boundary value stores `BigUInt` or uses unchecked/preconcurrency suppression;
- every exact `SendError` case and supporting payload above is constructed by tests; internal `QuoteChanges(validating:)` rejects an empty set, a public-only consumer cannot initialize `QuoteChanges` or compile `.quoteChanged([])`, `NativeFeeChange` round-trips zero and values above `UInt64`, retry-blocked cases project to matching pending availability, and broadcast diagnostic bounds/redaction are enforced;
- never-started and after-stop quote/send/retry fail with `kitNotStarted` before behavioral input/quote/row validation, QuoteStore/journal access, consumption, signer, or endpoint work; stopped quote with invalid input, stopped send with a foreign/expired quote, and stopped retry with a missing/terminal ID prove lifecycle error precedence and zero storage-spy calls;
- suspended H0 → `stop()` → late success, including `start()` again before quote expiry, returns `kitNotStarted`, leaves QuoteStore empty, starts no next request, and cannot return/use an old-generation quote; S2-01 proves only the admission boundary, while S2-05 proves the admitted-operation hold and finalization/repair behavior;
- exact amount and optional retry-fee inputs are copied into canonical `Data` before the first actor/task call; actor-crossing probes and values above `UInt64` prove the original BigUInt object is never retained;
- quote amount/fee/total round-trip boundaries through canonical magnitude Data, including zero fee, one base unit, values above UInt64, and repeated cross-task reads producing equal independent BigUInt values;
- the public-only signer reads every `SigningRequest` accessor, while external memberwise construction remains unavailable;
- fixed-eight native-RUNE summary boundaries, including `1` base unit → `0.00000001`, `100_000_000` → `1.00000000`, zero fee, checked total, and rejection of sign/grouping/exponent/incorrect precision;
- invalid internal SigningRequest construction makes zero signer calls; independent SignDoc decode and byte-level consistency proofs are S2-03/S2-04 tests;
- memberwise construction unavailable for quote/request/transaction ID;
- zero amount/self/wrong-network recipient performs zero transport calls;
- empty memo canonicalizes to nil while nonempty whitespace/multibyte text remains exact through quote, summary, SignDoc and pending projection;
- exact versus maximum intent, including maximum balance greater than/equal to/below native fee;
- quote expiration boundary at 9.999s/10.000s using an injected clock;
- one-use state under sequential and concurrent attempts;
- quote from another kit/wallet rejected;
- module-level `QuoteStore` can consume `internalQuoteToken`, while a public-only consumer cannot construct a quote or read either token accessor;
- publisher initial snapshot replay and deterministic ordering through the in-memory contract fixture;
- durable publisher, broadcasting-row, observation failure, degraded status, and retry tests are S2-05 tests;
- every public error and explicit debug projection passes credential/URL/key/signature/bytes redaction canaries;
- strict-concurrency compile gate for `Signer` and actor crossings.

## Verification

Verification commands apply to the post-implementation PR head, not the
documentation-only architecture head. The implementation PR must provide an
executable package/consumer target before running:

```text
swift package dump-package
swift test --filter SendQuoteTests
swift test --filter QuoteStoreTests
swift test --filter SendErrorTests
swift test --filter SendPublicApiTests
swift test
xcodebuild -project <temporary-consumer-project> -scheme <consumer-scheme> -destination 'platform=iOS Simulator,id=<approved-udid>' build
```

Each focused command must report a nonzero discovered test count. The PR/QA
evidence must cite one exact head SHA, `git diff --name-only` against the base,
local test logs, build-only GitHub Actions conclusions, the public import and
secret/redaction audits, and an explicit QA PASS on that same SHA. Before
implementation, only documentation/spec hash and current-tree evidence checks
are expected; package commands are intentionally unrun because the pinned
architecture head has no `Package.swift`.

## Acceptance Criteria

- The complete public send graph compiles without host imports or public protobuf types.
- A consumer can request/review a quote and authorize send, but cannot supply account, sequence, fee, gas, or raw sign bytes.
- No public initializer can forge an authoritative quote or SigningRequest.
- No public construction path can create an empty `QuoteChanges` payload.
- Quote expiry, identity, and one-use semantics are deterministic and tested.
- Stop invalidates both stored and in-flight unconsumed old-generation quotes before they can be returned or consumed; an admitted operation is not an unconsumed quote and follows S2-05 finalization/repair rules.
- No secret-bearing value has synthesized or default debug output; explicit bounded projections are tested.

## Pinned Decisions

The facade names and ownership above are fixed for Sprint 2. Rich inclusion status is intentionally absent; `checkTxAccepted` means CheckTx only and `unknown` means the exact signed transaction may already have been accepted.
