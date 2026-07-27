# S2-07 — Unstoppable Native RUNE Send Integration

**Formalization revision:** 7 — discovery 2/2; closure 4/5; supersedes
revision 6 after closure `REVISE`.

This document is the implementation contract for THR-160. The design is
approval-gated: no Unstoppable source, test, project, script, or acceptance
artifact may change until this revision is explicitly approved. The reviewed
architecture base remains commit `518835315a65996b9321665213adb0516503df65`.

**Risk:** critical
**Depends on:** completed S2-06 merge/status on `main` at
`65c8e370db983c6bd500448266a4f8f51561ca5f` (PR #17), the required
ThorChainKit package state at that S2-06 `main` head, and completed S1-07
MarketKit/WalletCore host release
**Produces:** standard WalletCore SendNew integration and controlled real mainnet send

## Goal

Connect native RUNE send to the exact current Unstoppable Wallet architecture without moving protocol logic or secret ownership into the wrong layer. The user sees a normal SendNew quote/review/send flow and the host receives the kit's local transaction hash/outcome.

## Repository Boundary

This spec authorizes future changes only on a fresh Unstoppable review branch after the standalone package revision is approved. No host edit belongs in the ThorChainKit spec commit. Maestro remains absent from Unstoppable.

All paths are relative to the current repository root and intentionally use `packages/WalletCore/Sources/WalletCore`; older root `Unstoppable/Core/...` paths are stale.

## Exact Host Files

Existing Sprint 1 files to extend:

- `packages/WalletCore/Sources/WalletCore/Core/Protocols.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/ThorChainKitManager.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Factories/ThorChainKitFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainAdapter.swift`

New files:

- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainSigner.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainSignerProvider.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainSigningKeySource.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Adapters/ThorChain/ThorChainSendClient.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ThorChainPreSendHandler.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ThorChainSendHandler.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ThorChainSendData.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ThorChainSubmissionView.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/IOutcomeSendHandler.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ThorChainSendHelper.swift` for typed error/field mapping.
- `Scripts/CI/check-thorchain-send-concurrency.sh` and its non-target fixture `Scripts/CI/Fixtures/ThorChainActorBoundaryViolation.swift`.

Modify:

- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendData.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendHandlerFactory.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/ISendData.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/SendViewModel.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/PreSendView.swift`
- `packages/WalletCore/Sources/WalletCore/Modules/SendNew/RegularSendView.swift`
- `packages/WalletCore/Sources/WalletCore/UserInterface/SwiftUI/SlideButton/SlideButton.swift`
- `packages/WalletCore/Sources/WalletCore/Resources/Localizable.xcstrings`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/AppManager.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/LockManager.swift`
- `packages/WalletCore/Sources/WalletCore/Core/Managers/AccountManager.swift`
- future host tests in `Unstoppable/Tests/ThorChain/` created by S1 and extended here.
- `packages/WalletCore/Package.swift` and its tracked `Package.resolved`
- the root `.gitignore` exception that keeps this host resolution checked in
- `Unstoppable/Unstoppable/Configuration/Config.template.xcconfig` only when
  the existing template needs a non-secret build key for this slice

`Core/Core.swift` requires no edit or THOR-specific branch: its existing
registration loops consume the updated handler arrays. `SendHandlerFactory`,
`ISendData`, and the existing `SendViewModel.send()` remain nonisolated legacy
contracts. `ISendHandler` is split only at its existing async quote boundary:
`sendData(transactionSettings:)` becomes an `@MainActor` requirement, while
`send(data:)` remains nonisolated. Existing handler implementations keep their
source declarations and are not migrated as a family; only typed callers of
`sendData` use the MainActor requirement. `SendViewModel.init` and `sync()` are
also `@MainActor` entry points. The new outcome path is a separate declaration,
`@MainActor func sendOutcome() async`, called only by the MainActor-owned
SendNew UI action. It reads the current `ISendData` and outcome handler inside
that MainActor method, creates the outcome closure, and invokes it there;
neither `ISendData` nor an existential handler is captured by a non-MainActor
`Task` or passed across an actor. UI result-consumption methods are also
MainActor-isolated. The strict probe must compile this exact declaration and
call sequence; any extra transitive diagnostic requires a spec revision rather
than an opportunistic annotation.

## Adapter and Wrapper Contract

Add internal `ISendThorChainAdapter` in `Core/Protocols.swift` following
`ISendTronAdapter` ownership. It is intentionally not public because it
returns the internal send-client seam and has no external consumer. The
send-client factory is an explicit MainActor requirement: background adapter
construction never constructs or touches a global-actor client.

```swift
protocol ISendThorChainAdapter {
    var thorChainAccountID: String { get }
    var thorChainReceiveAddress: String { get }
    @MainActor
    func makeThorChainSendClient() -> any IThorChainSendClient
}
```

The existing resolver still requires `ISendThorChainAdapter & IBalanceAdapter`;
`balanceData` is not duplicated in the THOR protocol. The pre-send resolver
also requires `IDepositAdapter` and compares the input to
`thorChainReceiveAddress`, which is the adapter's exact S1 receive-address
projection; it never rederives a second address from a wallet. Extend the S1
internal `IThorChainKit`/wrapper seam rather than exposing codec/account/fee
internals. The adapter strongly owns the wrapper and stores no signer—optional
or otherwise.

Kit authority remains unforgeable outside ThorChainKit, so WalletCore does not require a fake to construct `ThorChainKit.SendQuote` or `SendSubmission`. Add this internal host-owned boundary:

```swift
protocol IThorChainQuoteHandle: Sendable {
    var review: ThorChainQuoteReview { get }
}

protocol IThorChainSendClient: AnyObject, Sendable {
    @MainActor
    func quote(to: ThorChainKit.Address, amount: ThorChainKit.SendAmount, memo: String?) async throws -> any IThorChainQuoteHandle
    @MainActor
    func validate(quote: any IThorChainQuoteHandle) throws
    @MainActor
    func send(quote: any IThorChainQuoteHandle, signer: any ThorChainKit.Signer) async throws -> ThorChainClientSubmission
}

enum ThorChainClientSubmission: Equatable, Sendable {
    case checkTxAccepted(transactionHash: String)
    case unknown(transactionHash: String)
}
```

`ThorChainQuoteReview` is an immutable `Sendable` WalletCore DTO with exact fields `recipient: String`, `amountBaseUnits: String`, `isMaximum: Bool`, `nativeFeeBaseUnits: String`, `totalDebitBaseUnits: String`, `memo: String?`, `height: Int64`, and `expiresAt: Date`. The address is canonical Bech32; each amount is canonical unsigned base-10 with no leading zero except `"0"`. The host's existing display converter parses these checked strings locally; no `BigUInt` is stored in the DTO.

`ThorChainQuoteBinding` is an immutable `Equatable, Sendable` value containing
the complete `ThorChainQuoteReview` plus the original recipient, amount intent,
and memo passed to `quote`. A handle is usable only when its binding equals
the binding captured in `ThorChainSendData`; comparing only client identity is
insufficient. This is the same binding used by review rendering and send
validation, so a same-client handle swap cannot pair recipient/memo A with
quote B.

Production `ThorChainSendClient` is a `@MainActor final class` created only by
`ThorChainAdapter.makeThorChainSendClient()`. The adapter remains the strong
owner of the S1 wrapper; the client stores a weak adapter/lease reference and
never stores the wrapper. The lease is a shared atomic state with a monotonic
generation, a revoked bit, and an active-use count. Client use performs one
compare-and-acquire operation: it rejects a revoked/stale generation and
increments the active-use count while holding the permit through the complete
wrapper/kit call; release decrements the count before the client operation
returns. `ThorChainAdapter.stop()` performs the matching compare-and-revoke
operation before releasing the wrapper, so no new permit can be acquired after
revocation, then waits for the active-use count to reach zero before wrapper
release. The same synchronization primitive orders stop, lease validation,
wrapper use, and release; a check followed by an unsynchronized wrapper call
is forbidden. A `ThorChainSendData` retained after removal therefore fails
closed with `adapterUnavailable`, while a later send on a reconstructed adapter
creates a fresh client and namespace; it cannot reuse a stopped client's handle.
The lease state and immutable generation token are Sendable but never contain a
wrapper or secret, and the implementation may not use `@unchecked Sendable`.

The client owns one private immutable `LiveQuoteOwner: Sendable` reference per
client. `LiveThorChainQuoteHandle` stores only that owner reference, the now
checked-`Sendable` real `ThorChainKit.SendQuote` from S2-01, and its immutable
review snapshot. Its type, initializer, quote, and owner are file-private.
`validate(quote:)` requires the live type, `handle.owner === self.owner`, and
the complete `ThorChainQuoteBinding` (recipient, amount, maximum intent, memo,
fee, total, height, and expiry) captured at quote time. `send` repeats every
guard before calling the wrapper/kit. Fake, same-client swapped, and
cross-client live handles therefore fail with zero signer/kit calls. The
client maps the public kit submission to `ThorChainClientSubmission`.

AppTests implement `@MainActor FakeThorChainSendClient` plus their own Sendable fake handle and can deterministically return accepted/unknown without `@testable import ThorChainKit`, test SPI, network, or production-only branches. `ThorChainSendData` stores the client and handle received together. Public compile tests still prove external code cannot construct quote/request/transaction-ID authority. `@unchecked Sendable` and `@preconcurrency` are forbidden in this seam.

Sprint 2 remains mnemonic-only exactly as S1-06/S1-07: unsupported/watch-only account types do not produce a ThorChain wrapper/adapter. Future watch-only read support requires its own account/address/manager design and is not implied here.

## `ThorChainSigner`

`ThorChainSigner` is an ephemeral host actor conforming to
`ThorChainKit.Signer`. It stores only immutable
`nonisolated let compressedPublicKey: Data` and a `Sendable`
`ThorChainSigningKeySource` capability for the duration of one `send` call.
The source contains only the bound account ID and MainActor-isolated
`@Sendable` operations; it does not retain `AccountManager`, `Account`, or
key material. The wrapper, adapter, manager, and factory store no signer,
`Account`, `AccountType`, mnemonic, seed, HD wallet, or private key.

Signer construction is deliberately removed from synchronous
`ThorChainKitManager.thorChainKitWrapper(account:)` and background
`AdapterFactory`/`initAdaptersQueue`. `ThorChainSendHandler.submit(data:)`,
reached only through the MainActor outcome path, calls an injected
`@MainActor @Sendable (String) throws -> any ThorChainKit.Signer` provider.
Production delegates to `ThorChainSignerProvider.signer(accountID:)`; tests
inject a provider without `Core.shared`. The provider is never called by
adapter construction, quote creation, background refresh, or a cancelled
send.

The internal ownership contract is fixed:

```swift
struct ThorChainSigningKeySource: Sendable {
    let accountID: String
    let compressedPublicKey: @MainActor @Sendable () throws -> Data
    let sign: @MainActor @Sendable (_ digest: Data, _ expectedPublicKey: Data) throws -> Data
}

@MainActor
enum ThorChainSignerProvider {
    static func signer(accountID: String) throws -> ThorChainSigner
}

actor ThorChainSigner: ThorChainKit.Signer {
    nonisolated let compressedPublicKey: Data

    init(compressedPublicKey: Data, keySource: ThorChainSigningKeySource)
    func sign(_ request: ThorChainKit.SigningRequest) async throws -> Data
}
```

`ThorChainSignerProvider.signer` is the only construction path. It runs on the
MainActor from the MainActor send submission path, so no synchronous MainActor
hop occurs on `AdapterManager.initAdaptersQueue`; a strict probe also compiles
a non-MainActor caller that awaits the adapter client factory before entering
that path. The provider creates the source from injected MainActor
authorization/key operations, obtains the public key, captures the current
monotonic authorization generation, and returns the actor in one MainActor-
isolated operation. `ThorChainSigner.sign` awaits the source closures and
passes only `request.digest` plus the expected public key. No
`Account`/`AccountType` or raw key crosses into the signer actor.

On both public-key creation and every `sign`, the MainActor authorization
closure requires `LockManager.isLocked == false`, a foreground app, a
non-nil mnemonic active account with the bound ID, and identity equality with
the current visible `AccountManager.accounts` entry. The identity check catches
same-ID replacement because `AccountManager.save(account:)` updates the
visible map without replacing its cached active object. The closure then
rederives the compressed key and requires it to equal the immutable signer key.
`LockManager` and the injected foreground/account authorization source expose a
monotonic `authorizationGeneration` and increment it on both lock and unlock,
background/foreground, passcode/duress-level, active-account, and account
replacement transitions. The signer captures the generation at provider
creation. Immediately before the crypto primitive is called, one synchronous
MainActor authorization section atomically checks the captured generation,
current unlocked/foreground/account identity, and key equality, then invokes
the synchronous key-source operation without an await; the transition cannot
interleave between the check and that operation. A lock followed by unlock
therefore cannot revive an old signer. Any generation mismatch, lock,
background transition, passcode/duress-level change, active-account switch,
removal/replacement, non-mnemonic type, or key mismatch fails before a
signature or broadcast is returned.

`AppManager.didEnterBackground()` increments the same authorization generation
and cancels the ViewModel's outstanding submission task before the existing
background publication. The signer source compares the captured generation at
actual sign time; tests lock, unlock, or background between quote, provider,
and sign and require zero crypto/kit/broadcast calls. A transition ordered after
the synchronous authorization section may complete that already-authorized
operation; one ordered first fails closed.

The scoped key operation uses the exact S1 account contract:

```swift
let wallet = HDWallet(
    seed: seed,
    coinType: 931,
    xPrivKey: HDExtendedKeyVersion.xprv.rawValue,
    purpose: .bip44,
    curve: .secp256k1
)
let key = try wallet.privateKey(account: 0, index: 0, chain: .external)
```

This is exactly `m/44'/931'/0'/0/0`. At ephemeral signer construction the
source performs one scoped derivation from the currently authorized active
account and returns only the compressed public key, which must equal the key
used by S1 address creation. For `sign(_:)`, it repeats the authorization/
generation check, obtains `AccountType.mnemonicSeed`, rederives the temporary private key,
checks the compressed public key, calls
`HsCryptoKit.Crypto.sign(data:request.digest, privateKey:key.raw, compact:true)`,
and returns only the compact signature. Each invocation consumes one scoped
key operation; no seed/private-key value escapes or survives as a signer/key-
source property.

It additionally:

- is constructed only at send time by the MainActor provider from the current authorized active mnemonic account; manager/factory remain secret-free;
- exposes only the immutable compressed public key and actor-isolated `sign(_:)` capability;
- never logs/caches the mnemonic, private key, request bytes, digest, or signature;
- best-effort overwrites only mutable temporary buffers that this code exclusively owns in `defer`. It does not claim to erase COW copies or opaque storage inside `HDWallet`, `HDPrivateKey`, `Data`, or `Crypto.sign`; the enforceable guarantees are scoped lifetime, no secret property/cache/persistence, and no logging.

ThorChainKit independently rebinds the public key to its address and verifies the signature. The signer does not build protobuf or broadcast.

## Pre-Send Handler

`ThorChainPreSendHandler: PreSendHandler, IPreSendHandler` mirrors current `TronPreSendHandler` for host conventions:

- `instance(wallet:address:)` resolves `ISendThorChainAdapter & IBalanceAdapter & IDepositAdapter`;
- republishes adapter state/balance;
- `hasMemo(address:) == true` for optional plain memo;
- `sendData(amount:address:memo:)` uses a THOR-specific fail-closed exact converter; it must not call Tron's `roundedString`, `coinAmount`, or any rounding API. The converter requires a finite positive value, renders it locale-independently, removes only trailing fractional zeros, rejects more than eight significant fractional digits, pads to eight places, parses checked `BigUInt`, and round-trips back to the original `Decimal`. Thus `0.000000001`, half-base-unit and overflow fail rather than round. Fiat-derived input with extra precision must be normalized visibly by the existing amount UI before this boundary or receives the typed precision caution; the handler never changes it silently;
- constructs strict `ThorChainKit.Address`, compares its canonical string to the
  adapter's `thorChainReceiveAddress` (the S1 `IDepositAdapter.receiveAddress`
  projection), rejects own address, canonicalizes both input and available
  balance through the same exact base-unit converter, and returns `.maximum`
  only for exact base-unit equality or `.exact(amount)` otherwise;
- module/halt/fee/balance policy is not duplicated synchronously here; it is rendered by the async quote.

Add to `SendHandlerFactory.unstoppablePreSendHandlers` adjacent to the chain's product ordering.

## Send Data and Handler

Add to `SendData`:

```swift
case thorChain(token: Token, amount: ThorChainKit.SendAmount, recipient: ThorChainKit.Address, memo: String?)
```

`ISendData` gains `var expiresAt: Date? { get }` with a default `nil`. `SendViewModel` schedules the expiration timer from this absolute date when present (not from request completion), refuses `send()` when `Date() >= expiresAt`, and preserves existing duration behavior for other handlers. `RegularSendView` checks `expired` before rendering SlideButton and shows only the existing Refresh action. This closes the currently unused-expired-state defect generically.

The existing `ISendHandler.send(data:) -> Void` cannot distinguish CheckTx acceptance from final success. Do not migrate every existing handler/conformance. Add a narrow secondary protocol:

```swift
public enum SendOutcome: Equatable, Sendable {
    case sent
    case checkTxAccepted(transactionHash: String)
    case unknown(transactionHash: String)
}

protocol IOutcomeSendHandler: AnyObject {
    @MainActor
    func outcomeAction(for data: any ISendData) -> @MainActor () async throws -> SendOutcome
}
```

`SendViewModel.send()` remains the nonisolated legacy transport boundary and is
unchanged for legacy handlers; it never receives an outcome handler or passes
`ISendData` to the MainActor outcome path. The new entry is exactly:

```swift
@MainActor
func sendOutcome() async throws -> SendOutcome {
    guard let handler else {
        throw SendError.noHandler
    }
    if let outcomeHandler = handler as? any IOutcomeSendHandler {
        guard let data = sendData else { throw SendError.noSendData }
        let action = outcomeHandler.outcomeAction(for: data)
        let outcome = try await action()
        record(outcome: outcome)
        return outcome
    }

    // This branch never reads or passes ISendData on MainActor. `send()` keeps
    // the existing nonisolated handler.send(data:) call boundary.
    try await send()
    let outcome = SendOutcome.sent
    record(outcome: outcome)
    return outcome
}
```

`RegularSendView` calls `try await viewModel.sendOutcome()` unconditionally from
its existing MainActor action closure. In the outcome-aware branch,
`sendData`, `handler`, the non-Sendable `ISendData`, and the returned outcome
closure are accessed and invoked only within this MainActor declaration; no
`Task` created by a non-MainActor caller captures them. In the legacy branch,
the MainActor method passes no `ISendData` and calls the existing no-argument
`send()` route; that route alone reads the stored data and invokes the
nonisolated `ISendHandler.send(data:)` boundary. A successful legacy return is
then recorded as `.sent`; a thrown legacy error records no outcome and follows
the existing error path. `consumeGenericCompletionPermission()` is also
MainActor-isolated. The Swift 5 complete-concurrency probe must compile this
exact two-branch declaration and call sequence with no suppression, including
the `Task` created by `sync()`, and must include one legacy-only handler and one
outcome-aware handler. The ViewModel stores the result and saves the recent
address for every submitted outcome, and resets any prior result before a new
attempt. Background/lock cancellation invalidates the submission task and
prevents a resumed task from reaching signer creation.

`SendViewModel.init`, `sync()`, `autoQuoteIfRequired()`, and `onExpiration()`
are `@MainActor`; the task created by
`sync()` remains `Task { @MainActor ... }`. Because the protocol's
`sendData(transactionSettings:)` requirement is also MainActor-isolated, the
legacy `ISendData` result is produced, assigned, and retained on MainActor; it
never crosses from a nonisolated handler call into the view model. The current
`MainActor.run` transfer is removed. `SendHandlerFactory` retains its existing
synchronous surface so `OpenCryptoPayManager` and
`OpenCryptoPaySendHandlerFactory` are not pulled into an unrelated
global-actor migration. Existing timer and foreground-publisher callbacks are
nonisolated entry points, so they do not call `sync()` or read ViewModel state
directly. The MainActor initializer stores a nonisolated
`@MainActor @Sendable` auto-quote action. Each callback copies that Sendable
action and schedules `Task { @MainActor in action() }`; the action alone calls
`autoQuoteIfRequired()`, which may call `onExpiration()` and `sync()` on the
MainActor. The timer closures and foreground callback use this boundary;
MainActor SwiftUI refresh callers continue to call `sync()` directly. No
nonisolated task captures `SendViewModel` or `ISendData`. The strict
baseline-delta build-for-testing must prove this smaller change introduces no
new actor diagnostics anywhere in repository-owned Swift, including unchanged
transitive callers.

The valid Swift 5 complete-concurrency probe declares the split protocol
literally: `@MainActor func sendData(...) async throws -> ISendData` and
nonisolated `func send(data: ISendData) async throws`. It compiles an
`@MainActor sync()` task, the MainActor `autoQuoteIfRequired()`/
`onExpiration()` path, nonisolated timer and foreground callbacks that schedule
the stored MainActor action, the unconditional `sendOutcome()` two-branch
path, one legacy-only handler, and one outcome-aware handler. The probe fails
if any callback directly calls a MainActor method, if a MainActor task receives
legacy `ISendData` from a nonisolated call, or if the legacy branch bypasses the
no-argument `send()` bridge. No `@preconcurrency`, `@unchecked Sendable`, or
warning suppression is permitted.

`ThorChainSendHandler: SendHandler, ISendHandler, IOutcomeSendHandler`:

- `instance(sendData:)` resolves the native RUNE base token and `ISendThorChainAdapter`;
- `autoRefreshEnabled == false`; `ThorChainSendData.expiresAt` is the authoritative absolute kit deadline, so expiry exposes Refresh and requires a new review;
- `sendData(transactionSettings:) async` obtains the adapter's MainActor
  `makeThorChainSendClient()` exactly once, calls its `quote`, and returns
  `ThorChainSendData` containing that exact client plus the immutable
  handle/review projection; background adapter construction never performs
  this call;
- an internal MainActor `submit(data:)` type-checks `ThorChainSendData`,
  guards its absolute deadline and authorization generation, calls the stored
  client's synchronous `validate(quote:)`, compares the stored
  `ThorChainQuoteBinding` against the handle review, then constructs the
  ephemeral signer and calls that same client with the stored handle. It never
  re-resolves a potentially different client, and invalid, same-client-swapped,
  cross-client, stopped-client, locked, backgrounded, or changed-account
  handles create zero signers;
- `outcomeAction(for:)` is created and invoked on MainActor, captures the
  concrete data without crossing an actor, and calls MainActor `submit(data:)`,
  mapping both `.checkTxAccepted` and `.unknown` to explicit `SendOutcome`
  cases with the full local hash; unknown is not thrown into the generic
  unexpected-error sheet;
- the legacy `send(data:)` never submits and immediately throws bounded `outcomeAwarePresentationRequired`; only the MainActor outcome-aware SendViewModel path can invoke `submit`, so no duplicate send or generic success is possible;
- maps definitive quote validation failures to standard cautions and definitive send rejection to the normal error path;
- never recreates a quote inside `send` and never silently signs after expiry/change.

`ThorChainSendData: ISendData` has exact immutable stored properties `input`,
`sendClient: any IThorChainSendClient`,
`quoteHandle: (any IThorChainQuoteHandle)?`, `quoteBinding`, `transactionError?`,
`token`, and `rateCoins == [token.coin]`. Its initializer and these properties
are internal so a host caller cannot swap a live handle after review. Its
contract is:

- `feeData == nil` and `customSendButtonTitle == nil` because there are no adjustable gas settings;
- `expiresAt == quoteHandle?.review.expiresAt`;
- `canSend == (transactionError == nil && quoteHandle.map { Date() < $0.review.expiresAt } == true)`; the ViewModel also guards the deadline to avoid relying on rendering;
- `sections(...)` preserves the original input only for non-authorizing display
  context; when the handle exists, it renders every signing-relevant field from
  that handle's review (recipient, exact amount/Max, memo, native fee, total
  debit, height, and expiry); fee presentation reuses
  `UtxoSendHelper.feeFields`;
- `cautions(...)` maps typed halted/module/memo/funds/coherence errors through `ThorChainSendHelper`.

`sendData(transactionSettings:)` catches typed quote errors and returns
`ThorChainSendData(quoteHandle:nil, transactionError:error)` with the captured
client so the review retains user input and shows a specific caution/Refresh.
Programmer/invariant errors still throw to the generic failed state. A
client/lease invalidation never reconstructs a quote or silently retries.

Register `ThorChainSendHandler` in `SendHandlerFactory.unstoppableHandlers` in the matching chain order.

## CheckTx and Ambiguous Outcome UX

`SlideButton` currently captures `completion` and invokes it 0.4 seconds after any successful drag action; its accessibility action does not follow the same success/completion path. S2-07 adds one internal MainActor `performAction()` used by both drag and accessibility activation. On callback success it enters `.success` and schedules `completion` exactly once; on throw it returns to `.start`. Existing button behavior is otherwise unchanged. AppTests exercise the two internal entry closures separately against the same action-state seam, and a source/SwiftSyntax wiring test fails if either `.onEnded` or the accessibility `Button(action:)` contains its own callback `Task` or bypasses `performAction()`.

`RegularSendView` makes that completion outcome-aware. `SendViewModel` exposes a MainActor-only `consumeGenericCompletionPermission()` which returns `true` and consumes the result only for `.sent`; it returns `false` for nil, `.checkTxAccepted`, or `.unknown` and retains submitted outcomes for rendering. The SlideButton completion is exactly:

```swift
if sendViewModel.consumeGenericCompletionPermission() {
    onSuccess()
}
```

When `SendViewModel` receives `.checkTxAccepted` or `.unknown`, `RegularSendView` replaces the send action with `ThorChainSubmissionView`. Accepted shows the localized literal meaning `CheckTx accepted — not confirmed`; unknown shows `Submission outcome unknown` and explicitly says it may or may not have reached the network. Both show the full local hash with copy action and an explicit Done button. The scheduled SlideButton completion may still fire after SwiftUI rerenders, but the outcome check makes it a no-op.

`RegularSendView` accepts a separate optional `onSubmittedOutcomeDone` closure which never calls `onSuccess`. Both production presentation routes wire it explicitly:

- current iOS 17 `PreSendView.navigationDestination` removes only its confirmation path element;
- `RegularSendViewWrapper` sets only `isPresented = false`.

The direct `PreSendView` `onSuccess` closure remains the only route to `HudHelper.banner(.sent)`, and only `.sent` can consume generic completion permission. Tests spy on direct navigation and wrapper presentation separately: accepted/unknown each dismiss once through the outcome closure, with zero `onSuccess` and zero `.sent` banners.

The first `send` records the local hash even when the node response is unknown. The handler returns `.unknown(transactionHash:)` as a normal submitted outcome, so it never enters `SendView`'s generic `unexpected_error` sheet (where the hash would otherwise be visible only through Copy Error), never invokes `onSuccess`, and never shows the ordinary sent banner. Pending state remains in the kit.

The current SendNew screen has no honest retry/action-state seam. Sprint 2 therefore does not add host retry UI or perform an automatic retry. Exact-byte retry is fully implemented/tested in the kit and Example; Sprint 3 may expose it together with history/reconciliation. The dedicated submission view tells the user the outcome is unknown, displays the local hash, and explicitly avoids “sent/confirmed” wording.

## Host Tests Before Implementation

- pre-handler amount conversion, invalid address, self address, memo, and `.thorChain` construction; exact boundaries include `1e-8` success, `1e-9`/half-unit/fiat-derived excess precision rejection, overflow, trailing zeros, and locale independence;
- handler factory/pre-handler factory registration and wrong SendData rejection;
- exact versus 100%/maximum intent; balance greater/equal/below fee; quote resolves and renders actual max amount;
- absolute expiry after a delayed quote: RegularSendView shows only Refresh, `send()` makes zero send-client/signer calls, and a new quote is required;
- `ThorChainSendData` fields, fee/total conversion at 8 decimals, cautions, no settings;
- quote review uses canonical Sendable string snapshots; strict compile/source tests reject stored `BigUInt`, non-Sendable `SendQuote`, unchecked/preconcurrency suppression, malformed base-unit strings, and inconsistent total;
- mnemonic account creates the adapter/wrapper but stores no signer; watch-only/unsupported account creates no wrapper/adapter; exactly one ephemeral signer is requested only after the final send guard;
- signer compressed key/address vector and compact signing; no active account, passcode/duress-level switch, active-account switch, removal/replacement, non-mnemonic type, and key mismatch between quote and sign make zero Crypto.sign/broadcast calls; lock→unlock increments authorization generation and cannot revive an old signer; each invocation performs one scoped key operation and no long-lived property contains seed/private-key/account type;
- the exact baseline-delta strict-concurrency gate below constructs the signer only through awaited `ThorChainSignerProvider.signer`, proves SendQuote/live-handle crossing, compiles AppTests, compares every repository-owned diagnostic including unchanged transitive call sites, and uses the real `Debug-Dev` configuration; synchronous AdapterFactory/wrapper/OpenCryptoPay construction contains no newly actor-isolated factory call;
- a public-only negative compile test still cannot construct kit quote/request authority, while `FakeThorChainSendClient` creates its own handle/outcomes and deterministically drives accepted, unknown, and expired host UI with no network;
- public-only external signer compiles against the exact `SigningRequest` accessors and cannot construct or mutate it;
- production client accepts its own live handle but rejects fake and another production client's same-type live handle during pre-signer validation and again at send; rejected cases make zero signer/kit calls;
- concurrent client use versus adapter stop proves the lease's atomic revoke/acquire ordering, drains active-use permits before wrapper release, and leaves stale retained SendData fail-closed;
- a legacy-only handler invoked through the unconditional MainActor `sendOutcome()` path calls its existing nonisolated `send(data:)` boundary exactly once, returns `.sent`, stores that outcome, and grants generic completion exactly once; the exact strict-concurrency probe proves no MainActor declaration, closure, or task receives the legacy `ISendData`; drag and accessibility SlideButton entry closures each call the sole `performAction()` and complete exactly once for generic success; THOR accepted/unknown make the scheduled generic completion a no-op, show their dedicated full-hash result, and dismiss through the direct-navigation or wrapper outcome closure without `onSuccess`/`HudHelper.banner(.sent)`; rejection remains on the typed error path and never completes;
- changing/malicious public-key reads cannot affect the sign request because `nonisolated let` is immutable and kit snapshots it once;
- adapter/manager reconstruction preserves journal namespace and pending hash;
- localization keys, precision caution, and secret/log canaries; cleanup assertions are limited to owned buffers and never claim erasure of third-party copies;
- diff test/audit finds no `.maestro`, fixture transport, or acceptance launch argument in host.

Tests that mutate `Core.shared`, `SendHandlerFactory` registries, active/passcode account state, or global adapter state run with the literal `Debug-Dev` command below and `-parallel-testing-enabled NO`. Their Swift Testing suite is exactly `ThorChainGlobalStateTests`, uses `@Suite(.serialized)`, and has a shared overlap sentinel which fails if two cases enter together. Each test snapshots/restores registries and active-account state in teardown. Pure converter/model tests may remain parallel; a parallelizable Development AppTests plan is not accepted as evidence for the global-state scenarios.

## Reproducible Host Substrate

`packages/WalletCore/Package.swift` adds the public product
`ThorChainKit` from `https://github.com/ant013/ThorChainKit.Swift.git` at exact
S2-06 package-state revision
`65c8e370db983c6bd500448266a4f8f51561ca5f`. This is the required `main` head
whose S2-06 merge includes the package graph/source changes for the
`HdWalletKit` resolution and native-RUNE endpoint capability wiring; the
consumer acceptance and its package prerequisite are therefore one coherent
reproducibility input. The package URL is remote-only; no sibling path, branch,
or floating version is allowed. `packages/WalletCore/Package.resolved` is
committed and must resolve that SHA. The root `.gitignore` removes the blanket
ignore for this file. A clean detached worktree must resolve the same graph
before any test/build command; a mismatch is a hard failure.

The checked-in `Unstoppable/Unstoppable/Configuration/Config.template.xcconfig`
is the only clean-worktree input. The build gate copies it to the ignored
`Config.xcconfig` in a disposable worktree and fills no secret values. No
Fastlane lane, environment file, keychain, or host-local absolute path is
needed for local Development build-for-testing. The gate records
`xcodebuild -version`, `swift --version`, `git rev-parse HEAD`, package
resolution, and the exact `Debug-Dev` configuration before building.

The narrow AppTests commands are literal and each must discover at least one
test before execution:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSendPreflightTests -parallel-testing-enabled NO test
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSignerTests -parallel-testing-enabled NO test
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSendClientTests -parallel-testing-enabled NO test
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSendDataTests -parallel-testing-enabled NO test
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSlideButtonTests -parallel-testing-enabled NO test
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" -only-testing:AppTests/ThorChainSendOutcomeTests -parallel-testing-enabled NO test
```

The global-state suite is run separately by the command below. The clean
simulator/container and complete teardown are acceptance requirements, not
optional test hygiene.

## Executable Strict-Concurrency Gate

`Scripts/CI/check-thorchain-send-concurrency.sh --baseline <approved-base-sha>`
runs from the Unstoppable root. It verifies the baseline is an ancestor,
checks Xcode's version against the recorded implementation toolchain, resolves
the exact public ThorChainKit URL
`https://github.com/ant013/ThorChainKit.Swift.git` at revision
`65c8e370db983c6bd500448266a4f8f51561ca5f` and product `ThorChainKit`, and
fails if `Package.resolved` is missing, ignored, or resolves another SHA. It
creates a disposable detached worktree and performs the same exact
Development build-for-testing for baseline and HEAD in separate DerivedData
directories so `AppTests` is compiled even though the scheme marks it
`buildForRunning="NO"`:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev \
  -destination 'generic/platform=iOS Simulator' \
  SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' build-for-testing
```

The script preserves both real `xcodebuild` exit codes and captures raw
diagnostic records containing repository-relative path, line, column, severity,
diagnostic ID/text, notes/fix-its, and multiplicity. It compares the complete
raw diagnostic multiset for **all repository-owned Swift files**; it never
normalizes away location, severity, or replacement text. Every HEAD diagnostic
absent from the baseline fails, including a warning in an unchanged transitive
caller such as OpenCryptoPay. Package/DerivedData paths outside the repository
are reported separately but do not hide repository failures. A self-test
replaces one baseline diagnostic with the same path/text but a different
line/severity/fix-it and must fail, preventing a false pass. The script still
emits the complete `git diff --name-only <baseline>...HEAD` Swift manifest for
source audits, treats every new file as having no baseline diagnostics, and
fails an empty changed-file set; the manifest is not a compiler-diagnostic
filter.

The script then invokes `xcrun swiftc -typecheck -swift-version 5
-strict-concurrency=complete -warnings-as-errors` on the deliberately invalid
non-target canary and requires a nonzero exit plus the expected global-actor
isolation diagnostic; an unexpectedly compiling canary fails the gate. A valid
compile probe calls the awaited MainActor adapter-client factory from a
non-MainActor async context, crosses a `SendQuote`/live handle, and calls the
MainActor outcome closure without passing `ISendData` across an actor.
`@unchecked Sendable`, `@preconcurrency`, warning suppression, and untracked
or ignored package/configuration inputs fail a full effective-settings/source
audit.

Global-state acceptance uses this literal serialized command with one exact CI simulator:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" \
  -only-testing:AppTests/ThorChainGlobalStateTests \
  SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' \
  -parallel-testing-enabled NO test
```

The runner requires a nonzero discovered test count for every named suite and
the shared overlap sentinel; missing `UNSTOPPABLE_SIMULATOR_UDID`, zero tests,
or a parallel invocation fails. The test command is run on a purpose-created
erased simulator with an isolated application data/keychain container. Every
mutated Core registry, passcode/duress and lock state, active-account cache,
adapter map, factory array, and temporary storage is restored in teardown;
the simulator is erased after the suite. No persistent operator wallet or
production keychain is used.

## Build and Product Acceptance

1. Pin the reviewed ThorChainKit revision/package product and capture the
   exact package graph/toolchain identity.
2. Run each literal narrow AppTests command and the global-state ThorChain
   AppTests with parallel testing explicitly disabled on the erased,
   purpose-created simulator.
3. Build the Development app using the repository's established
   workspace/scheme from the clean detached worktree.
4. Before any irreversible action, record a redacted acceptance preflight:
   exact PR head, ThorChainKit SHA, Xcode/Swift versions, device model/OS and
   UDID suffix, mainnet chain/network endpoint identity, app configuration,
   clean-diff result, and package resolution. Missing or mismatched identity
   aborts acceptance.
5. Use a purpose-created mnemonic account funded with no more than `0.01 RUNE`
   for this acceptance. The recipient must be an operator-controlled,
   pre-verified mainnet address owned outside the test device; the operator
   records ownership and the exact recipient before launch. The amount must
   be positive and no greater than `0.001 RUNE` (and no greater than the
   controlled account's verified spendable balance minus the quoted fee).
   The operator gives a separate final approval immediately before the send;
   design approval never authorizes spending.
6. Enter the pre-verified recipient/amount/memo, verify exact native fee/total,
   run the network/chain/address/balance preflight, confirm the displayed
   quote, and record the local hash plus CheckTx result. The classifier tests
   prove the node response hash must equal this local hash; no separate
   remote-hash UI/API is invented.
7. Exercise one controlled ambiguous response only if the approved
   proxy/test environment is available; otherwise record it as deterministic
   kit evidence, never as a fake host live result. CheckTx acceptance remains
   on the dedicated local-hash/not-confirmed result and never shows the
   generic sent banner. Unknown shows the local hash, does not dismiss/show
   sent, and does not request a second signature.
8. Write only redacted evidence: no mnemonic, seed, private key, provider
   credential, full keychain path, or secret-bearing build artifact. Include
   local hash, result classification, recipient/amount policy result, and
   operator approval timestamp. If any control fails, do not broadcast and
   record `not-run` with the failed preflight.
9. Audit host diff and generated artifacts for secret/acceptance-only code.

## Acceptance Criteria

- Native RUNE is selected through existing generic SendNew factories, with no `Core.swift` special case.
- Host owns signing key material; kit owns quote, bytes, verification, journal, and broadcast.
- Signing is authorized only for the currently active account visible at the current passcode/duress level, rechecked at the actual sign operation.
- Review shows the exact quote used by send and expired/changed quotes require user reconfirmation.
- Controlled mainnet send returns the local hash and honest CheckTx/unknown state; internal classification accepts only a matching node hash, and neither path can display the generic sent/confirmed banner.
- Unsupported account types remain outside the mnemonic-only S1/S2 adapter contract.
- Unstoppable contains no Maestro or fixture-only runtime.
- The host package resolves the public ThorChainKit product at exact S2-06
  package-state revision `65c8e370db983c6bd500448266a4f8f51561ca5f` from a
  tracked `Package.resolved`; clean detached build/test inputs are
  reproducible.
- The strict-concurrency gate reports no new raw diagnostics, rejects the
  actor-boundary canary and all suppression/unchecked escapes, and proves the
  non-Sendable legacy UI boundary is not crossed by the new outcome path.
- Lock/background, same-ID account replacement, adapter removal/reconstruction,
  and same-client quote-handle swaps fail closed before signer or broadcast
  calls, with hermetic serialized AppTests proving the transitions.
- Mainnet acceptance is either recorded with the bounded amount/recipient,
  identity, preflight, approval, and redacted result evidence above, or is
  explicitly `not-run` without any broadcast when a control is unavailable.

## Pinned Decision

Vultisig is not a host architecture analog here. No KeysignPayload, TSS response, WalletCore transaction compiler, or global THOR service is imported into Unstoppable or ThorChainKit.

## Revision 7 Blocker Resolution Map

The following stable findings from discovery 2/2 are resolved by this revision;
they remain allowlisted for closure-only review:

| ID | Resolution in this revision |
|---|---|
| `THR160-ARCH-001` | Make `ISendHandler.sendData(transactionSettings:)`, `SendViewModel.init`, `sync()`, `autoQuoteIfRequired()`, and `onExpiration()` MainActor-isolated while preserving nonisolated `ISendHandler.send(data:)` and the no-argument `send()` bridge. Nonisolated timer/foreground callbacks schedule a stored `@MainActor @Sendable` action and never call `sync()` directly. `sync()` therefore keeps the non-Sendable legacy result on MainActor; `RegularSendView` still calls one unconditional `@MainActor sendOutcome() async` entry. It branches before reading `ISendData`: outcome-aware handlers read/capture it and invoke their MainActor action entirely on MainActor; legacy handlers call `send()`, which alone invokes nonisolated `send(data:)`. The exact Swift 5 complete probe covers callbacks, both branches, and the sync task, and forbids suppression or an actor-crossing legacy result. |
| `THR160-ARCH-002` | Replace synchronous client lookup with `@MainActor makeThorChainSendClient()`; background adapter construction never creates the client, and the valid non-MainActor probe must compile. |
| `THR160-ARCH-003` | Define the lease as synchronized monotonic generation/revocation plus active-use count. Client use atomically acquires and holds a permit through wrapper/kit use; stop atomically revokes before waiting for permits and releasing the wrapper. Reconstruction creates a fresh client/namespace. |
| `THR160-ARCH-004` | Add `thorChainReceiveAddress` as the adapter's exact S1 `IDepositAdapter.receiveAddress` projection and require the pre-handler's deposit-adapter boundary. |
| `THR160-SEC-001` | Replace the reversible lock check with a monotonic authorization generation incremented on lock and unlock plus other authorization transitions. Capture it at provider creation and atomically compare it in one non-suspending MainActor section immediately before the crypto call; lock→unlock cannot revive an old signer. |
| `THR160-SEC-002` | Store immutable `ThorChainQuoteBinding`, compare all review/signing fields on validation and send, and render signing-relevant review fields from the handle. |
| `THR160-SEC-003` | Require active-account object identity to equal the current visible entry as well as ID/type/key; same-ID replacement is a fail-closed test. |
| `THR160-VO-001` | Pin the public `ThorChainKit` product and tracked `Package.resolved` to the required S2-06 package-state head `65c8e370db983c6bd500448266a4f8f51561ca5f`, including the S2-06 package graph/source changes. |
| `THR160-VO-002` | Use the checked-in template-only config, detached-worktree generation, tracked package graph, and recorded Xcode/Swift toolchain. |
| `THR160-VO-003` | Compare raw diagnostic records including location, severity, notes/fix-its, and multiplicity; replacement-diagnostic mutation must fail. |
| `THR160-VO-005` | Add literal per-suite `-only-testing` commands and nonzero discovery checks for every converter/source/signer/quote/expiry/SlideButton/outcome suite. |
| `THR160-VO-006` | Run global-state tests on an erased purpose-created simulator/container, serialize them, and restore every mutated global domain in teardown. |
| `THR160-VO-007` | Bound funds/recipient, network/build preflight, final operator approval, exact identity capture, and redacted evidence; unavailable controls mean no-run/no-broadcast. |

`THR160-SEC-004`, `THR160-SEC-005`, and `THR160-VO-008` remain non-blocking
backlog items under the slice-closure rules and are not expanded by this
revision.

## Formalization Evidence and Delta Boundary

The current Unstoppable checkout used for analog verification is
`/Users/ant013/Ios/HorizontalSystems/unstoppable-wallet-ios` at active HEAD
`ad125479984aa66e9bbc9022f5a8cb2e52ef6b6`; the pinned load-bearing analog
object remains `520fb7400311b3266cfb6b0db81c3e919e080019`. It is on the
unrelated dirty branch `core/uswap-provider-layering`; its changes are
preserved and are not an implementation base. The load-bearing analogs are the
HEAD versions of
`ISendTronAdapter`, `TronPreSendHandler`, `TronSendHandler`,
`SendHandlerFactory`, `SendViewModel`, `AccountManager`, and the serialized
`Unstoppable/Tests` suites. Gimle project mapping and Serena were unavailable,
so all selected facts were independently checked with codebase-memory followed
by targeted `git grep`/`git show`; no Gimle result is treated as design proof.

The delta is deliberately limited to the exact host files and new files named
above: a narrow internal THOR adapter/client seam; host-owned ephemeral signer
creation and active-account revalidation; quote/review/send outcome mapping;
absolute expiry; the shared `IOutcomeSendHandler` path; the shared
`SlideButton` action seam; serialized global-state tests; the strict
concurrency baseline-delta canary; local WalletCore/AppTests and Development
build evidence; and one controlled mainnet acceptance. No protocol logic,
mnemonic/secret storage, fixture transport, Maestro, launch argument, or
secret-bearing artifact is added to Unstoppable.
