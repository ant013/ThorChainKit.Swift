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

Out of scope: network preflight implementation, protobuf, cryptographic verification, journal, transport, Example UI, and host integration. Later slices implement these behind the API without changing its ownership.

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

`quote`, `send`, and `retryBroadcast` require this `Kit` instance's Sprint 1 lifecycle client to be active. A never-started or stopped instance throws `SendError.kitNotStarted` before QuoteStore/journal access, quote-token consumption, signer work, or endpoint I/O. The runtime actor gives every successful `start()` activation a monotonic client lifecycle generation. Quote admission captures that exact generation; every H0 callback, next-request decision, and final QuoteStore insertion must still match it. `stop()` deactivates and advances the generation, resolves any suspended quote-operation waiters with `kitNotStarted`, and invalidates that Kit's already stored unconsumed quotes. A late H0 callback from the old generation is discarded, cannot store/return a quote after a rapid `start()`, and cannot begin another request. `stop()` does not revoke an already admitted financial operation: S2-05 gives each admitted send/retry an operation activity hold which survives client stop until clean finalization or repair.

`SendAmount.exact(_:)` immediately copies the caller's `BigUInt` into canonical big-endian magnitude `Data`; `.maximum` stores no magnitude. The public call spelling remains `SendAmount.exact(value)`/`.maximum`, but the value that enters `QuoteStore`, an endpoint task, or an actor is checked `Sendable`. Likewise, `Kit.retryBroadcast(...acceptingNativeFee:)` canonicalizes its optional ergonomic `BigUInt` argument into an internal `Data?` snapshot at the facade boundary before invoking the runtime actor. Neither caller-owned BigInt storage crosses a task or actor boundary.

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

Internal state contains one cryptographically random opaque quote token. `QuoteStore` maps that token to the authoritative wallet/network namespace, lifecycle client ID/generation, sender, requested amount intent, account number, sequence, provider-family lease identity, policy snapshot, and every review field. The insertion occurs only after the runtime actor revalidates the still-active captured generation. A second undefined tamper signature is intentionally not added. The quote:

- is valid only for the originating `Kit` instance/wallet namespace;
- expires exactly ten seconds after the final coherent quote snapshot has been accepted and stored;
- can start at most one send attempt;
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

`SigningRequestFactory` independently decodes its own `serializedSignDoc` before releasing the request and proves that sender, recipient, memo, account number, sequence, literal denom `rune`, and base-unit amount agree with `summary`; it also proves that the quote's pinned native fee and checked total convert exactly to the fixed-eight strings. A mismatch is an internal invariant failure and makes zero signer calls. The SignDoc `Fee.amount` remains empty by THORChain protocol, so `nativeFee` is authorized quote policy rather than a serialized fee coin.

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

Initialization must successfully migrate/recover the send store and load the first committed snapshot before the send runtime becomes ready; a storage failure at that boundary prevents the runtime from starting. The publisher then replays the current shared-runtime snapshot on subscription. `pendingTransactions` reads the runtime's last successfully committed snapshot synchronously, while one GRDB `ValueObservation` on the runtime's shared writer serializes post-commit emissions on a documented dedicated state queue. Internal `broadcasting` rows remain public as `.unknown` with `.inFlight`; they never disappear while I/O is active. Pending ordering is deterministic: newest `createdAt` first, then hash. Rejected journal rows are not public pending items.

The nonfailing API does not hide storage health. `pendingTransactionsStatus` starts at `.ready`; an observation/read failure keeps the last valid snapshot, changes status to `.degraded`, emits no empty/fabricated list, and starts the generation-scoped observation replacement specified in S2-05. The raw database error is restricted to sanitized internal diagnostics. `.ready` returns only after the first successful initial snapshot from the replacement observation has been published; an isolated reread without an active replacement subscription is insufficient. Sprint 3 may reconcile pending rows with confirmed history without changing the Sprint 2 transaction identity.

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

`LocalizedError`/debug rendering is deterministic and bounded: `quoteChanged` sorts `QuoteChanges.values` by `QuoteChange.rawValue`, monetary values render canonical base-unit decimal strings, and no description relies on `Set` iteration, upstream error text, or locale. WalletCore maps cases to localized copy; the package error itself does not own UI localization.

`SendError` is explicitly checked `Sendable`. Because `Error` values cross concurrency boundaries, no case stores `BigUInt`; computed monetary accessors reconstruct new values. A strict compiler probe for a control `Error` case containing `BigUInt` must fail, while a probe containing this exact graph must compile without suppression.

Once exact signed bytes and a local transaction ID are durable, any uncommitted transition or ambiguous network outcome is always returned as `SendSubmission.state == .unknown`; it is never thrown as an ambiguous `SendError`. A storage error may be thrown only when the initial durable identity was not created. A definitive CheckTx rejection is thrown only after its terminal journal transaction commits; failure to persist a terminal response remains `.unknown`.

Raw URLs, credentials, wallet identifiers, public-key bytes, signatures, SignDoc/TxRaw bytes, and upstream response bodies are excluded from error/debug descriptions.

## Local Validation Order

After the facade has snapshotted ergonomic values, the first behavioral step is runtime-actor active-client admission and lifecycle-generation capture. A stopped/never-started Kit therefore returns `kitNotStarted` even when the supplied amount/recipient is also invalid. Only an admitted quote operation applies this local order before any endpoint call:

1. `.exact` amount is greater than zero; `.maximum` has no fabricated numeric amount before preflight;
2. recipient is a canonical address for the kit network;
3. recipient differs from sender;
4. memo is valid Swift UTF-8 text;
5. quote request is not already cancelled.

Network-dependent module/memo/fee/balance/halt validation is S2-02.

## Analog Delta

The UW EVM/TRON handler split supplies the review→send lifecycle. Unlike those handlers, the host does not build chain-specific fee/transaction data. EvmKit's seed/private-key signer construction is an explicit counterexample: ThorChainKit accepts only a narrow async signer capability after user confirmation.

## Tests Before Implementation

- API compile test from a temporary public-only consumer;
- `SendAmount`, `SendQuote`, `SendSubmission`, `TransactionID`, `PendingTransaction`, all nested states/status, `QuoteChanges`, `NativeFeeChange`, and `SendError` compile as checked `Sendable` under pinned Swift 5 complete mode with BigInt 5.3.0; a source guard proves no cross-boundary value stores `BigUInt` or uses unchecked/preconcurrency suppression;
- every exact `SendError` case and supporting payload above is constructed by tests; internal `QuoteChanges(validating:)` rejects an empty set, a public-only consumer cannot initialize `QuoteChanges` or compile `.quoteChanged([])`, `NativeFeeChange` round-trips zero and values above `UInt64`, retry-blocked cases project to matching pending availability, and broadcast diagnostic bounds/redaction are enforced;
- never-started and after-stop quote/send/retry fail with `kitNotStarted` before behavioral input/quote/row validation, QuoteStore/journal access, consumption, signer, or endpoint work; stopped quote with invalid input, stopped send with a foreign/expired quote, and stopped retry with a missing/terminal ID prove lifecycle error precedence and zero storage-spy calls;
- suspended H0 → `stop()` → late success, including `start()` again before quote expiry, returns `kitNotStarted`, leaves QuoteStore empty, starts no next request, and cannot return/use an old-generation quote; stop invalidates stored unconsumed quotes while an already admitted send/retry retains its operation activity hold;
- exact amount and optional retry-fee inputs are copied into canonical `Data` before the first actor/task call; actor-crossing probes and values above `UInt64` prove the original BigUInt object is never retained;
- quote amount/fee/total round-trip boundaries through canonical magnitude Data, including zero fee, one base unit, values above UInt64, and repeated cross-task reads producing equal independent BigUInt values;
- the public-only signer reads every `SigningRequest` accessor, while external memberwise construction remains unavailable;
- fixed-eight native-RUNE summary boundaries, including `1` base unit → `0.00000001`, `100_000_000` → `1.00000000`, zero fee, checked total, and rejection of sign/grouping/exponent/incorrect precision;
- independent SignDoc decode proves amount/sender/recipient/memo/account/sequence match the summary and pinned fee plus amount equals total before the signer is called;
- memberwise construction unavailable for quote/request/transaction ID;
- zero amount/self/wrong-network recipient performs zero transport calls;
- empty memo canonicalizes to nil while nonempty whitespace/multibyte text remains exact through quote, summary, SignDoc and pending projection;
- exact versus maximum intent, including maximum balance greater than/equal to/below native fee;
- quote expiration boundary at 9.999s/10.000s using an injected clock;
- one-use state under sequential and concurrent attempts;
- quote from another kit/wallet rejected;
- module-level `QuoteStore` can consume `internalQuoteToken`, while a public-only consumer cannot construct a quote or read either token accessor;
- publisher initial empty replay and deterministic ordering;
- concurrent snapshot/subscription/update ordering through the GRDB observation queue;
- internal broadcasting projects continuously as public unknown/in-flight;
- observation failure retains the last snapshot and publishes degraded status; only a replacement observation's first snapshot returns to ready, and a later independent commit is still observed;
- every public error description passes a canary redaction test;
- strict-concurrency compile gate for `Signer` and actor crossings.

## Verification

```text
swift package dump-package
swift test --filter SendQuoteTests
swift test --filter QuoteStoreTests
swift test --filter SendPublicApiTests
swift test
temporary iOS consumer xcodebuild with import ThorChainKit only
```

## Acceptance Criteria

- The complete public send graph compiles without host imports or public protobuf types.
- A consumer can request/review a quote and authorize send, but cannot supply account, sequence, fee, gas, or raw sign bytes.
- No public initializer can forge an authoritative quote or SigningRequest.
- No public construction path can create an empty `QuoteChanges` payload.
- Quote expiry, identity, and one-use semantics are deterministic and tested.
- Stop invalidates both stored and in-flight old-generation quotes before they can be returned or consumed.
- No secret-bearing value has a default debug representation.

## Pinned Decisions

The facade names and ownership above are fixed for Sprint 2. Rich inclusion status is intentionally absent; `checkTxAccepted` means CheckTx only and `unknown` means the exact signed transaction may already have been accepted.
