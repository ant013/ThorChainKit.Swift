# S2-07 — Unstoppable Native RUNE Send Integration

**Risk:** critical
**Depends on:** accepted/released S2-01 through S2-06 package revision and completed S1-07 MarketKit/WalletCore host release
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
- future host tests in `Unstoppable/Tests/ThorChain/` created by S1 and extended here.

`Core/Core.swift` requires no edit or THOR-specific branch: its existing registration loops consume the updated handler arrays. `SendHandlerFactory`, `ISendHandler`, and `ISendData` are not globally MainActor-isolated in Sprint 2. That larger migration breaks current nonisolated OpenCryptoPay call sites and is not required for the THOR outcome. The new outcome protocol and `SendViewModel` own only the narrower UI isolation described below; any extra transitive file discovered by the strict gate requires a spec revision rather than an opportunistic annotation.

## Adapter and Wrapper Contract

Add internal `ISendThorChainAdapter` in `Core/Protocols.swift` following `ISendTronAdapter` ownership. It is intentionally not public because it returns the internal send-client seam and has no external consumer:

```swift
protocol ISendThorChainAdapter {
    var thorChainSendClient: any IThorChainSendClient { get }
    var thorChainAccountID: String { get }
}
```

The existing resolver still requires `ISendThorChainAdapter & IBalanceAdapter`; `balanceData` is not duplicated in the THOR protocol. Extend the Sprint 1 internal `IThorChainKit`/wrapper seam rather than exposing codec/account/fee internals. The wrapper stores no signer—optional or otherwise.

Kit authority remains unforgeable outside ThorChainKit, so WalletCore does not require a fake to construct `ThorChainKit.SendQuote` or `SendSubmission`. Add this internal host-owned boundary:

```swift
protocol IThorChainQuoteHandle: Sendable {
    var review: ThorChainQuoteReview { get }
}

@MainActor
protocol IThorChainSendClient: AnyObject, Sendable {
    func quote(to: ThorChainKit.Address, amount: ThorChainKit.SendAmount, memo: String?) async throws -> any IThorChainQuoteHandle
    func validate(quote: any IThorChainQuoteHandle) throws
    func send(quote: any IThorChainQuoteHandle, signer: any ThorChainKit.Signer) async throws -> ThorChainClientSubmission
}

enum ThorChainClientSubmission: Equatable, Sendable {
    case checkTxAccepted(transactionHash: String)
    case unknown(transactionHash: String)
}
```

`ThorChainQuoteReview` is an immutable `Sendable` WalletCore DTO with exact fields `recipient: String`, `amountBaseUnits: String`, `isMaximum: Bool`, `nativeFeeBaseUnits: String`, `totalDebitBaseUnits: String`, `memo: String?`, `height: Int64`, and `expiresAt: Date`. The address is canonical Bech32; each amount is canonical unsigned base-10 with no leading zero except `"0"`. The host's existing display converter parses these checked strings locally; no `BigUInt` is stored in the DTO.

Production `ThorChainSendClient` is a `@MainActor final class` conforming to the global-actor protocol. It owns the Sprint 1 wrapper and one private immutable `LiveQuoteOwner: Sendable` reference created per client. `LiveThorChainQuoteHandle` stores only that owner reference, the now checked-`Sendable` real `ThorChainKit.SendQuote` from S2-01, and its immutable review snapshot. Its type, initializer, quote, and owner are file-private. `validate(quote:)` requires both the live type and `handle.owner === self.owner`; the handler calls it before constructing a signer. `send` repeats the same guard before calling the wrapper/kit. Fake and cross-client live handles therefore fail with zero signer/kit calls. The client maps the public kit submission to `ThorChainClientSubmission`.

AppTests implement `@MainActor FakeThorChainSendClient` plus their own Sendable fake handle and can deterministically return accepted/unknown without `@testable import ThorChainKit`, test SPI, network, or production-only branches. `ThorChainSendData` stores the client and handle received together. Public compile tests still prove external code cannot construct quote/request/transaction-ID authority. `@unchecked Sendable` and `@preconcurrency` are forbidden in this seam.

Sprint 2 remains mnemonic-only exactly as S1-06/S1-07: unsupported/watch-only account types do not produce a ThorChain wrapper/adapter. Future watch-only read support requires its own account/address/manager design and is not implied here.

## `ThorChainSigner`

`ThorChainSigner` is an ephemeral host actor conforming to `ThorChainKit.Signer`. It stores only immutable `nonisolated let compressedPublicKey: Data` and a host-owned `ThorChainSigningKeySource` capability for the duration of one `send` call. The wrapper, adapter, manager, and factory store no signer, `Account`, `AccountType`, mnemonic, seed, HD wallet, or private key.

Signer construction is deliberately removed from synchronous `ThorChainKitManager.thorChainKitWrapper(account:)` and background `AdapterFactory`/`initAdaptersQueue`. `ThorChainSendHandler.submit(data:)`, reached only through `outcomeAction`, calls an injected async `@Sendable (String) async throws -> any ThorChainKit.Signer` provider. Production delegates to `await ThorChainSignerProvider.signer(accountID:)`; tests inject a provider without `Core.shared`.

The internal ownership contract is fixed:

```swift
@MainActor
final class ThorChainSigningKeySource {
    init(accountManager: AccountManager, accountID: String)
    func compressedPublicKey() throws -> Data
    func sign(digest: Data, expectedPublicKey: Data) throws -> Data
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

`ThorChainSignerProvider.signer` is the only construction path. Because the handler awaits this global-actor method from its async send path, no synchronous MainActor hop occurs on `AdapterManager.initAdaptersQueue`; strict-concurrency compilation must prove the call. The provider creates the source with `Core.shared.accountManager`, obtains the public key, and returns the actor in one MainActor-isolated operation. `ThorChainSigner.sign` later awaits the same source and passes only `request.digest` plus expected public key. No `Account`/`AccountType` or raw key crosses into the signer actor.

On both `compressedPublicKey()` and every `sign`, the source reads `accountManager.activeAccount`—never `account(id:)`/`_allAccounts`—and requires its ID to equal the bound `accountID`, its type to be mnemonic, and its freshly derived compressed key to equal the immutable signer key. Missing active account, passcode/duress-level switch, active-account switch, removal/replacement, or key mismatch fails before any signature is returned. This ensures a stale adapter cannot sign with an account hidden by the current authorization level.

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

This is exactly `m/44'/931'/0'/0/0`. At ephemeral signer construction the source performs one scoped derivation from the currently authorized active account and returns only the compressed public key, which must equal the key used by S1 address creation. For `sign(_:)`, it repeats the active-account authorization, obtains `AccountType.mnemonicSeed`, rederives the temporary private key, checks the compressed public key, calls `HsCryptoKit.Crypto.sign(data:request.digest, privateKey:key.raw, compact:true)`, and returns only the compact signature. Each invocation consumes one scoped key operation; no seed/private-key value escapes or survives as a signer/key-source property.

It additionally:

- is constructed asynchronously at send time by the MainActor provider from the current authorized active mnemonic account; manager/factory remain secret-free;
- exposes only the immutable compressed public key and actor-isolated `sign(_:)` capability;
- never logs/caches the mnemonic, private key, request bytes, digest, or signature;
- best-effort overwrites only mutable temporary buffers that this code exclusively owns in `defer`. It does not claim to erase COW copies or opaque storage inside `HDWallet`, `HDPrivateKey`, `Data`, or `Crypto.sign`; the enforceable guarantees are scoped lifetime, no secret property/cache/persistence, and no logging.

ThorChainKit independently rebinds the public key to its address and verifies the signature. The signer does not build protobuf or broadcast.

## Pre-Send Handler

`ThorChainPreSendHandler: PreSendHandler, IPreSendHandler` mirrors current `TronPreSendHandler` for host conventions:

- `instance(wallet:address:)` resolves `ISendThorChainAdapter & IBalanceAdapter`;
- republishes adapter state/balance;
- `hasMemo(address:) == true` for optional plain memo;
- `sendData(amount:address:memo:)` uses a THOR-specific fail-closed exact converter; it must not call Tron's `roundedString`, `coinAmount`, or any rounding API. The converter requires a finite positive value, renders it locale-independently, removes only trailing fractional zeros, rejects more than eight significant fractional digits, pads to eight places, parses checked `BigUInt`, and round-trips back to the original `Decimal`. Thus `0.000000001`, half-base-unit and overflow fail rather than round. Fiat-derived input with extra precision must be normalized visibly by the existing amount UI before this boundary or receives the typed precision caution; the handler never changes it silently;
- constructs strict `ThorChainKit.Address`, rejects own address, canonicalizes both input and available balance through the same exact base-unit converter, and returns `.maximum` only for exact base-unit equality or `.exact(amount)` otherwise;
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
    var outcomeAction: @MainActor (any ISendData) async throws -> SendOutcome { get }
}
```

`SendViewModel` becomes `@MainActor`. `send()` checks whether its existing handler also conforms to `IOutcomeSendHandler`; if so it invokes `outcomeAction(sendData)`, otherwise it calls the unchanged `ISendHandler.send(data:)` and records `.sent`. The global-actor closure keeps the existing non-Sendable `ISendData` on MainActor without making the entire conforming handler or factory actor-isolated; a Swift 5 complete-mode compiler probe is mandatory for this exact shape. The ViewModel stores the result and saves the recent address for every submitted outcome, and resets any prior result before a new attempt.

The `Task` created by `SendViewModel.sync()` is written as `Task { @MainActor ... }`; it awaits existing async services but assigns `ISendData`, state, rates, and outcome only on MainActor and removes the current `MainActor.run` transfer. `SendHandlerFactory` retains its existing synchronous surface so `OpenCryptoPayManager` and `OpenCryptoPaySendHandlerFactory` are not pulled into an unrelated global-actor migration. The strict baseline-delta build-for-testing must prove this smaller change introduces no new actor diagnostics anywhere in repository-owned Swift, including unchanged transitive callers.

`ThorChainSendHandler: SendHandler, ISendHandler, IOutcomeSendHandler`:

- `instance(sendData:)` resolves the native RUNE base token and `ISendThorChainAdapter`;
- `autoRefreshEnabled == false`; `ThorChainSendData.expiresAt` is the authoritative absolute kit deadline, so expiry exposes Refresh and requires a new review;
- `sendData(transactionSettings:) async` captures `adapter.thorChainSendClient` once, calls its `quote`, and returns `ThorChainSendData` containing that exact client plus the immutable handle/review projection;
- an internal `submit(data:)` type-checks `ThorChainSendData`, guards its absolute deadline, calls the stored MainActor client's synchronous `validate(quote:)`, then awaits the ephemeral signer provider for `adapter.thorChainAccountID` and calls that same client with the stored handle; it never re-resolves a potentially different client, and invalid/cross-client handles create zero signers;
- `outcomeAction` captures the handler and calls its MainActor `submit(data:)`, mapping both `.checkTxAccepted` and `.unknown` to explicit `SendOutcome` cases with the full local hash; unknown is not thrown into the generic unexpected-error sheet;
- the legacy `send(data:)` never submits and immediately throws bounded `outcomeAwarePresentationRequired`; only the MainActor outcome-aware SendViewModel path can invoke `submit`, so no duplicate send or generic success is possible;
- maps definitive quote validation failures to standard cautions and definitive send rejection to the normal error path;
- never recreates a quote inside `send` and never silently signs after expiry/change.

`ThorChainSendData: ISendData` has exact stored properties `input`, `sendClient: any IThorChainSendClient`, `quoteHandle: (any IThorChainQuoteHandle)?`, `transactionError?`, `token`, and `rateCoins == [token.coin]`. Its contract is:

- `feeData == nil` and `customSendButtonTitle == nil` because there are no adjustable gas settings;
- `expiresAt == quoteHandle?.review.expiresAt`;
- `canSend == (transactionError == nil && quoteHandle.map { Date() < $0.review.expiresAt } == true)`; the ViewModel also guards the deadline to avoid relying on rendering;
- `sections(...)` always preserves input recipient/memo and, when the handle exists, renders its resolved actual amount (including Max), native fee, total debit, and height; fee presentation reuses `UtxoSendHelper.feeFields`;
- `cautions(...)` maps typed halted/module/memo/funds/coherence errors through `ThorChainSendHelper`.

`sendData(transactionSettings:)` catches typed quote errors and returns `ThorChainSendData(quoteHandle:nil, transactionError:error)` with the captured client so the review retains user input and shows a specific caution/Refresh. Programmer/invariant errors still throw to the generic failed state.

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
- signer compressed key/address vector and compact signing; no active account, passcode/duress-level switch, active-account switch, removal/replacement, non-mnemonic type, and key mismatch between quote and sign make zero Crypto.sign/broadcast calls; each invocation performs one scoped key operation and no long-lived property contains seed/private-key/account type;
- the exact baseline-delta strict-concurrency gate below constructs the signer only through awaited `ThorChainSignerProvider.signer`, proves SendQuote/live-handle crossing, compiles AppTests, compares every repository-owned diagnostic including unchanged transitive call sites, and uses the real `Debug-Dev` configuration; synchronous AdapterFactory/wrapper/OpenCryptoPay construction contains no newly actor-isolated factory call;
- a public-only negative compile test still cannot construct kit quote/request authority, while `FakeThorChainSendClient` creates its own handle/outcomes and deterministically drives accepted, unknown, and expired host UI with no network;
- public-only external signer compiles against the exact `SigningRequest` accessors and cannot construct or mutate it;
- production client accepts its own live handle but rejects fake and another production client's same-type live handle during pre-signer validation and again at send; rejected cases make zero signer/kit calls;
- default handlers still produce `.sent`; drag and accessibility SlideButton entry closures each call the sole `performAction()` and complete exactly once for generic success; THOR accepted/unknown make the scheduled generic completion a no-op, show their dedicated full-hash result, and dismiss through the direct-navigation or wrapper outcome closure without `onSuccess`/`HudHelper.banner(.sent)`; rejection remains on the typed error path and never completes;
- changing/malicious public-key reads cannot affect the sign request because `nonisolated let` is immutable and kit snapshots it once;
- adapter/manager reconstruction preserves journal namespace and pending hash;
- localization keys, precision caution, and secret/log canaries; cleanup assertions are limited to owned buffers and never claim erasure of third-party copies;
- diff test/audit finds no `.maestro`, fixture transport, or acceptance launch argument in host.

Tests that mutate `Core.shared`, `SendHandlerFactory` registries, active/passcode account state, or global adapter state run with the literal `Debug-Dev` command below and `-parallel-testing-enabled NO`. Their Swift Testing suite is exactly `ThorChainGlobalStateTests`, uses `@Suite(.serialized)`, and has a shared overlap sentinel which fails if two cases enter together. Each test snapshots/restores registries and active-account state in teardown. Pure converter/model tests may remain parallel; a parallelizable Development AppTests plan is not accepted as evidence for the global-state scenarios.

## Executable Strict-Concurrency Gate

`Scripts/CI/check-thorchain-send-concurrency.sh --baseline <approved-base-sha>` runs from the Unstoppable root. It verifies the baseline is an ancestor, creates a disposable detached worktree, and performs the same exact Development build-for-testing for baseline and HEAD in separate DerivedData directories so `AppTests` is compiled even though the scheme marks it `buildForRunning="NO"`:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev \
  -destination 'generic/platform=iOS Simulator' \
  SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' build-for-testing
```

The script preserves both real `xcodebuild` exit codes, normalizes diagnostics by repository-relative path plus diagnostic text and multiplicity, and compares the complete diagnostic multiset for **all repository-owned Swift files**. Every HEAD diagnostic absent from the baseline fails, including a warning in an unchanged transitive caller such as OpenCryptoPay. Package/DerivedData paths outside the repository are reported separately but do not hide repository failures. The script still emits the complete `git diff --name-only <baseline>...HEAD` Swift manifest for review/source audits, treats every new file as having no baseline diagnostics, and fails an empty changed-file set; the manifest is not a filter on compiler diagnostics.

The script then invokes `xcrun swiftc -typecheck -swift-version 5 -strict-concurrency=complete -warnings-as-errors` on the deliberately invalid non-target canary and requires a nonzero exit plus the expected global-actor isolation diagnostic; an unexpectedly compiling canary fails the gate. A valid compile probe calls the awaited provider from a non-MainActor async context and crosses a `SendQuote`/live handle. Parser self-tests prove a synthetic new diagnostic fails and a baseline-identical one does not. `@unchecked Sendable`, `@preconcurrency`, and warning-suppression flags in the changed manifest fail a source audit.

Global-state acceptance uses this literal serialized command with one exact CI simulator:

```text
xcodebuild -workspace Wallet.xcworkspace -scheme Development -configuration Debug-Dev \
  -destination "platform=iOS Simulator,id=$UNSTOPPABLE_SIMULATOR_UDID" \
  -only-testing:AppTests/ThorChainGlobalStateTests \
  SWIFT_STRICT_CONCURRENCY=complete \
  OTHER_SWIFT_FLAGS='$(inherited) -warn-concurrency' \
  -parallel-testing-enabled NO test
```

The runner requires a nonzero discovered test count and the suite's overlap sentinel; missing `UNSTOPPABLE_SIMULATOR_UDID`, zero tests, or a parallel invocation fails.

## Build and Product Acceptance

1. Pin the reviewed ThorChainKit revision/package product.
2. Run narrow WalletCore tests and the global-state ThorChain AppTests with parallel testing explicitly disabled.
3. Build the Development app using the repository's established workspace/scheme.
4. On a purpose-created controlled mnemonic account, enable native RUNE and open SendNew.
5. Enter controlled recipient/amount/memo, verify exact native fee/total, confirm, and record the local hash and CheckTx result. The classifier tests prove the node response hash must equal that local hash; no separate remote-hash UI/API is invented.
6. Exercise one controlled ambiguous response if the approved proxy/test environment is available; otherwise record it as deterministic kit evidence, not a fake host live result.
7. Confirm CheckTx acceptance stays on the dedicated local-hash/not-confirmed result and never shows the generic sent banner; for a controlled ambiguous-response test, confirm the host shows unknown plus local hash, does not dismiss/show sent, and does not request a second signature.
8. Audit host diff and generated artifacts for secret/acceptance-only code.

## Acceptance Criteria

- Native RUNE is selected through existing generic SendNew factories, with no `Core.swift` special case.
- Host owns signing key material; kit owns quote, bytes, verification, journal, and broadcast.
- Signing is authorized only for the currently active account visible at the current passcode/duress level, rechecked at the actual sign operation.
- Review shows the exact quote used by send and expired/changed quotes require user reconfirmation.
- Controlled mainnet send returns the local hash and honest CheckTx/unknown state; internal classification accepts only a matching node hash, and neither path can display the generic sent/confirmed banner.
- Unsupported account types remain outside the mnemonic-only S1/S2 adapter contract.
- Unstoppable contains no Maestro or fixture-only runtime.

## Pinned Decision

Vultisig is not a host architecture analog here. No KeysignPayload, TSS response, WalletCore transaction compiler, or global THOR service is imported into Unstoppable or ThorChainKit.
