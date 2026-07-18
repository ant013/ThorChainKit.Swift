# S2-02 — Height-Pinned Send Preflight

**Risk:** critical
**Depends on:** S2-01 and Sprint 1 endpoint/read infrastructure
**Produces:** a coherent authoritative snapshot and immutable quote; no signing

## Goal

Authorize review only from one provider family at one proven Cosmos height. A quote must combine account, sequence, balance, native fee, halt, memo, module-account, and network identity facts without mixing time or providers.

## Scope

- `SendPreflightCoordinator`, `SendSnapshot`, `SendPolicy`, and THORNode send endpoints;
- `EndpointLease`/provider-family pinning for the complete logical quote;
- one bounded owned-operation runner for every lease, retry/backoff, and provider request;
- exact height echo validation and snapshot digest;
- recipient account classification plus a versioned THORNode forbidden-module set, dynamic native fee, Mimir halt evaluation, and auth memo parameter;
- revalidation API consumed by S2-04;
- deterministic cache rules limited to data proven safe at the exact height.

Out of scope: protobuf/signature, broadcast, pending journal, UI, and history.

## Proposed Areas and Functions

```text
Sources/ThorChainKit/Send/Preflight/
  SendPreflightCoordinator.swift
  SendSnapshot.swift
  SendPolicy.swift
  HaltEvaluator.swift
  RecipientAccountClassifier.swift
  ForbiddenModuleAddressSet.swift
Sources/ThorChainKit/Network/
  EndpointOperationRunner.swift
  EndpointLease+Send.swift
  ThorNodeSendClient.swift
  CosmosAuthParametersClient.swift
  HeightProof.swift
Tests/ThorChainKitTests/Send/Preflight/
  EndpointOperationRunnerTests.swift
  SendPreflightCoordinatorTests.swift
  HaltEvaluatorTests.swift
  RecipientAccountClassifierTests.swift
  ForbiddenModuleAddressSetTests.swift
  SendPolicyTests.swift
```

Internal responsibilities:

```swift
func prepareQuote(request: SendQuoteRequest) async throws -> PreparedQuote
func revalidate(_ prepared: PreparedQuote) async throws -> RevalidationResult
func loadSnapshot(request: SendQuoteRequest, lease: EndpointLease) async throws -> SendSnapshot
func evaluate(height: Int64, mimir: MimirSnapshot) throws -> HaltDecision
```

## Bounded Endpoint Operation Contract

`EndpointOperationRunner` is the single internal liveness primitive used by H0, H1, H2, and the S2-05 retry network phase. Each lease acquisition, backoff wait, hash lookup, and HTTP read is one separately owned unstructured `Task` with an immutable request. Its owner waits through an exactly-once result channel that races the operation against caller cancellation, the endpoint-policy absolute deadline, and—only for H0—the captured client lifecycle generation becoming inactive. Cancelling the child is only a hint: the owner never awaits termination of a dependency that ignores cancellation or never resumes.

For H1/H2 and retry, the callback must re-enter the owning runtime actor and match the exact attempt token or durable broadcast generation before its value is accepted. H0 callbacks instead match the exact active client ID/generation captured at quote admission. The actor starts no later endpoint operation until the appropriate guarded callback succeeds. When cancellation/deadline wins, it invalidates ownership and runs the phase-specific S2-04/S2-05 finalizer before returning; when H0 lifecycle invalidation wins, it returns `kitNotStarted`. A late result is discarded and cannot start another request, insert a quote, create a journal row, normalize a generation, or broadcast. H0 has no send gate/reservation, but its lifecycle token and the same non-cooperative race prevent both hanging and post-stop quote creation.

## Snapshot Transaction

1. On the runtime actor, require this Kit client to be active and capture its exact client ID/lifecycle generation before lease or storage work.
2. Apply S2-01's pure local validation order under that admitted generation; failure returns its typed input error with zero lease/storage calls.
3. Acquire one send-capable `EndpointLease` that identifies a provider family and exact chain identity, guarded by that generation.
4. Select the accepted Cosmos read height `H0` using the Sprint 1 family policy.
5. Resolve the family's capability manifest. Every logical preflight route has one approved proof mode; the returned business value and its height proof must come from the same request. The manifest also contains S2-05's non-height-pinned Cosmos REST transaction-lookup contract for retry-capable families. A query parameter, a neighboring request, or a second transport can never retroactively prove an unlabelled value.
6. Load, without switching families and rechecking the captured generation after every callback:
   - sender account number and sequence;
   - exact spendable native balance from the Cosmos single-denom spendable endpoint for literal denom `rune`;
   - `/thorchain/network?height=<H>` and `native_tx_fee_rune`;
   - required Mimir values at `<H>`;
   - Cosmos auth params/memo maximum at `<H>`;
   - THORNode semantic version and the recipient's exact Cosmos auth account classification at `<H>`.
7. Validate network identity/freshness and construct one immutable `SendSnapshot`.
8. Re-enter the runtime actor, require the same client ID/generation still active, and only then atomically insert/return the quote. Compute a stable internal digest over family ID, height, sender account, balance, fee, halt inputs, memo limit, node version, recipient account classification, and the versioned forbidden-module policy revision.

If the server cannot prove `<H>`, the family fails as a whole. A new quote may retry on another complete family, but no partial value survives the switch.

## Executable Height Proof Modes

The implementation supports exactly three internal modes:

```text
RESTHeaderProof
  request: x-cosmos-block-height: H, plus ?height=H only when the route defines it
  accept:  the same response returns a positive x-cosmos-block-height exactly H

CometABCIProof
  request: the route's exact approved ABCI query path and encoded request at height H
  accept:  decode the business value from that ABCI response and require response.height == H

BodyHeightProof
  request: the route's documented historical-height input
  accept:  the authoritative response schema itself identifies the evaluated height exactly H
```

`BodyHeightProof` is opt-in per schema, never inferred from a generic `height`, pagination, or latest-block field. `CometABCIProof` uses the Comet role paired with the same provider family; it does not call REST for a value and Comet only for a height. The family manifest pins query path/request encoding, decoder, proof mode, and supported node revision range for sender account, spendable balance, network fee, each Mimir key, auth params, node version, and recipient account classification. A retry-capable family additionally pins the S2-05 Cosmos REST transaction-lookup role, positive decoder, exact not-found envelope, and bounds; that lookup does not borrow H0/H1/H2 height proof.

Current official Liquify probes on 2026-07-17 returned HTTP 200 but stripped `x-cosmos-block-height` from THOR network, exact-key Mimir, and Cosmos bank REST responses. Those routes are therefore ineligible for `RESTHeaderProof`; a Liquify family is send-capable only when its paired Comet endpoint passes `CometABCIProof` for every stripped route. At height `27049190`, the paired Comet endpoint returned exact-height values for bank spendable balance, network, Mimir, and auth params, while bulk `/cosmos.auth.v1beta1.Query/ModuleAccounts` panicked with code `111222`/height `0` and REST returned HTTP 500. Bulk module enumeration is therefore prohibited. The recipient-specific Account proof below was live-verified at the same height. Query-only REST remains discovery/debug evidence and cannot authorize a quote. A provider with no complete proof plan is read-only for Sprint 2.

## Validation Rules

- Sender account must exist and decode to `/cosmos.auth.v1beta1.BaseAccount` or one of the same five pinned Cosmos `v0.53.0` vesting wrappers listed below, with exactly one embedded matching BaseAccount. A first-send account with `pub_key == nil` is valid. A non-null key must be secp256k1 and is retained for S2-04 equality with the signer key snapshot.
- `.exact` amount is positive native RUNE only and balance must cover checked `amount + native_tx_fee_rune`. The single-denom response must itself contain literal lowercase denom `rune`; a successful route/query with another or missing denom is rejected.
- `.maximum` resolves inside this snapshot to `spendableRune - native_tx_fee_rune`; the result must be positive and becomes the immutable quoted amount.
- `native_tx_fee_rune == 0` is valid and yields `totalDebit == amount`; missing, negative, malformed, or overflowing fee is not valid.
- Recipient must pass S2-01 local validation, the exact-height account classifier, and the versioned forbidden-module-address check below.
- Memo UTF-8 byte count must not exceed the pinned auth parameter.
- Chain must not be halted by the exact rules below.
- Snapshot/quote creation time uses the injected monotonic clock; wall-clock Date is display only.

## Halt Rules

At height `H`, reject when:

```text
HaltChainGlobal > 0       && HaltChainGlobal <= H
NodePauseChainGlobal >= H
HaltTHORChain > 0         && HaltTHORChain <= H
SolvencyHaltTHORChain > 0 && SolvencyHaltTHORChain <= H
```

Read the four exact keys at `H` rather than inferring absence from the bulk map. THORNode's proven unset sentinel `-1` and value `0` are inactive for all four keys; values below `-1`, duplicated responses, overflow, malformed data, transport failure, or an unproven height fail closed. For `NodePauseChainGlobal`, a positive value is active exactly when it is greater than or equal to `H`.

## Module Recipient Rule

The broken bulk module-account endpoint is not used. At each H0/H1/H2 round the same family proves the THORNode semantic version and classifies the **specific recipient** through the exact-height Cosmos `Query/Account` response:

- `code == 0` requires a supported Any and an embedded canonical address payload exactly equal to the requested recipient. `/cosmos.auth.v1beta1.ModuleAccount` is rejected. The only accepted user types from pinned Cosmos SDK `v0.53.0` are `/cosmos.auth.v1beta1.BaseAccount` and `/cosmos.vesting.v1beta1.{BaseVestingAccount,ContinuousVestingAccount,DelayedVestingAccount,PeriodicVestingAccount,PermanentLockedAccount}`; each vesting decoder must unwrap to one matching BaseAccount. Any other Any, wrapper cycle/depth, missing base account, or address mismatch fails closed.
- Exact `codespace == "sdk"`, `code == 22`, zero response bytes, and response height exactly H is the only admissible account-absent result. For the pinned Comet JSON decoder, a unique `value` field that is absent, JSON `null`, or base64 `""` normalizes to zero bytes because protobuf bytes have an empty default; all three forms receive the same fixture. Any nonempty decoded bytes, invalid base64/type, duplicate `value` key, foreign/missing codespace, other code, or height mismatch fails closed. Liquify's live response at H=`27049190` used JSON `null`.

Concrete account type is necessary but not sufficient. `ForbiddenModuleAddressSet` accepts only proven `Query/Version.current` and `.querier` values in the explicit set `{3.19.0, 3.19.1, 3.19.2, 3.19.3}`. These are backed by official tags/commits `v3.19.0@5f2141c3`, `v3.19.1@59a3e925`, `v3.19.2@c6fa8caa`, and `v3.19.3@52e66ad9`; all four have byte-identical `x/thorchain/helpers.go` SHA-256 `72ce4607cfcd45e1546e9c12d79afaeeb897946d0c9f3df31c14b8e05a3a98cf` and `x/thorchain/types/keys.go` SHA-256 `65f6e60694fa3667bf63805f1a933b357164f321bfb822f3459ffce05e5bae69`. Live height `27049190` reported `current=3.19.3` and `querier=3.19.0`, so both fields are required rather than conflated.

The generated set uses the exact pinned `IsModuleAccAddress` names `asgard`, `bond`, `reserve`, `lending`, `affiliate_collector`, `thorchain`, `tcy_claim`, `tcy_stake`, and `treasury` plus Cosmos SDK `v0.53.0`'s legacy no-derivation-key rule: `SHA256(UTF8(moduleName)).prefix(20)`, rendered with the selected network HRP. A recipient matching any derived 20-byte payload is rejected even if the account query unexpectedly decodes as a user account or NotFound. The manifest pins the ordered names and derivation vectors—including `thorchain` → `thor1v8ppstuf6e3x0r4glqc68d5jqcs2tf38cg2q6y`. Any current or querier version outside the explicit set makes the family send-ineligible until its exact tagged source and vectors are reviewed; implementation never assumes semantic-version range compatibility.

This is a versioned source-derived protocol set, not an operator-maintained address list. It protects the exact THORNode MsgSend rule even if the registered module-address set and the concrete stored account type disagree. Sending to the THOR module can become MsgDeposit and is outside Sprint 2; every other detected Cosmos module destination is also rejected conservatively.

## Revalidation Contract

S2-04 calls `revalidate` immediately before requesting the signature and again after the async signer returns, before journal persistence/broadcast. Revalidation never rereads the frozen quote height. It obtains a complete coherent snapshot from the same provider family at fresh accepted heights:

```text
quote:       H0
pre-signer:  H1 >= H0
post-signer: H2 >= H1
```

A height rollback, mixed response height, or family switch fails closed. Each round reloads the complete sender account/sequence, spendable `rune`, fee, four Mimir keys, memo policy, node version, and recipient account classification before comparing:

- chain identity and accepted family;
- account number, sequence, and supported/null account public-key state;
- native fee and sufficient balance;
- halt decision;
- memo limit;
- node version and forbidden-module policy revision;
- recipient account/reserved-module status;
- quote expiry.

Snapshot differences return `SendError.quoteChanged` with `QuoteChanges(validating:)` and this nonempty exact mapping: family/chain → `.providerIdentity`; rollback → `.heightRollback`; account number → `.accountNumber`; sequence → `.sequence`; non-null account key state → `.accountPublicKey`; spendable sufficiency → `.balance`; fee → `.nativeFee`; halt → `.haltStatus`; memo limit → `.memoPolicy`; node version/policy revision/recipient classification → `.recipientPolicy`. An empty comparison returns unchanged success and cannot construct the error payload. Expiry returns `.quoteExpired`, not a changed set. Missing transport, unproven height, and unavailable/unsupported policy return `.providerUnavailable`, `.heightUnproven`, and `.policyUnavailable` respectively. Never silently change review values or ask a signer to approve old bytes.

Every request in H1 and H2 uses the same route-specific proof mode and pinned family capability as H0. `RESTHeaderProof`, `CometABCIProof`, and `BodyHeightProof` each require exact positive equality with the round height. A route may not switch proof mode during one quote/send attempt. Current THORNode maps supported `?height=` values into SDK metadata, but query-only REST is never portable proof and is not accepted.

## Failure/Retry Policy

- A complete family may be retried/fail over only before a quote is returned.
- During send revalidation, family loss or mismatch expires the quote; it does not switch families.
- 429/503/backoff remains bounded by the Sprint 1 endpoint policy and the owned-operation race; dependency cooperation with cancellation is never required for caller liveness.
- No five-minute native-fee cache or cross-provider sequence maximum is allowed.

## Analog Delta

Vultisig proves the required THOR data categories but fetches them independently and caches native fee; THORNode supplies consensus rules. This design adds an atomic provider/height boundary. EvmKit's max-nonce strategy is rejected because a higher value from another provider cannot make a THOR snapshot coherent.

## Tests Before Implementation

- exact success fixtures cover every route's pinned proof mode and one family ID;
- `RESTHeaderProof` requires exact request/response `x-cosmos-block-height`; a proxy-stripped or mismatched header fails that route rather than falling back silently;
- `CometABCIProof` decodes the value from the same ABCI response, requires `response.height == H`, and rejects wrong path/encoding, missing/mismatched height, and a REST-value/ABCI-height merge;
- `BodyHeightProof` is accepted only for a pinned schema whose authoritative evaluated-height field equals H; lookalike/latest/pagination heights fail;
- a THORNode fixture where `?height=H` executes or responds at `H+1` is rejected rather than accepted as pinned;
- missing/mismatched height for each endpoint;
- account absent/wrong Any/overflowing number or sequence;
- native fee zero/missing/malformed/overflowing and balance boundary; returned spendable denom missing/not exactly `rune` is rejected;
- all four Mimir keys unset as `-1` is a normal non-halted success fixture; `< -1` fails;
- every halt rule at `H-1`, `H`, `H+1` boundaries;
- recipient Account at exact height: BaseAccount and each of the five exact supported vesting wrappers, exact sdk/22 NotFound with absent/null/empty-base64 zero-byte encodings, nonempty/invalid/duplicate value rejection, ModuleAccount, nested/missing/embedded-address mismatch, unknown Any, foreign/missing codespace, and height mismatch;
- generated forbidden-module set covers every pinned `IsModuleAccAddress` name/vector and tag/file checksum, rejects an unexpected BaseAccount or NotFound at a reserved payload, accepts the live `current=3.19.3`/`querier=3.19.0` pair, and fails closed at `3.19.4`, `3.20.0`, malformed, or unproven version fields;
- live regression fixture proves bulk ModuleAccounts panic is not called and the recipient-specific normal/module probes remain exact-height;
- memo with multibyte UTF-8 exactly at and one byte over limit;
- cancellation at each request and between pages;
- lease acquisition, every H0/H1/H2 route request, and backoff continuations that never resume or return late after cancellation/deadline; each caller returns promptly, no subsequent endpoint call starts, and H1/H2 release their send ownership through S2-04;
- H0 suspended before/after any callback then `stop()` wins: the caller promptly receives `kitNotStarted`, a late value cannot start another route or insert a quote, and a rapid new `start()` has a different generation and cannot revive the old attempt;
- initial family failure may retry as a whole; no response from family A appears in family B quote;
- `.maximum` with balance above/equal/below fee and fee changes between H0/H1/H2;
- H0/H1/H2 monotonicity and rollback rejection; changes visible only at H1/H2 are detected before signer or discard its result.

## Verification

```text
swift test --filter SendPreflightCoordinatorTests
swift test --filter EndpointOperationRunnerTests
swift test --filter HaltEvaluatorTests
swift test --filter RecipientAccountClassifierTests
swift test --filter ForbiddenModuleAddressSetTests
swift test --filter SendPolicyTests
swift test
opt-in live preflight against at least one complete approved mainnet family; a second family when available
```

## Acceptance Criteria

- A quote proves every authoritative value from the same request that returned its route-specific height evidence, at one height/family, and carries their internal digest.
- Every missing/unproven required value fails closed with a stable public error.
- Module/memo/halt/fee/balance behavior matches pinned THORNode/Cosmos semantics.
- A stopped or superseded client lifecycle generation cannot start another H0 request or insert/return a quote.
- Revalidation never mutates an existing quote or switches providers.
- Tests demonstrate no cross-family or cross-height merge.

## Open Compatibility Evidence

Implementation must record the selected proof mode and live response shape for recipient Account success/NotFound/module variants, both node-version fields, exact-key Mimir, auth params, `/thorchain/network`, and spendable `rune`. It must also retain the bulk ModuleAccounts panic as a regression counterexample proving that route is never selected. It must exercise the exact REST and paired Comet public hosts in the family. If any required route lacks one of the three accepted proofs, or either proven node-version field leaves the explicit manifest set, that family is ineligible for send; a query-only value is never grandfathered in.
