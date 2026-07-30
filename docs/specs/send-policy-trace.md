# Send policy-unavailable trace

## Goal

Make a `policyUnavailable` failure diagnosable through the complete native RUNE
send path, from `Kit` public send entry points to the broadcaster, without
logging secrets or changing send decisions.

## Assumptions

- The current failure occurs during a real native RUNE send through `Kit`.
- The immediate suspected provider incompatibility is Comet ABCI JSON-RPC
  response `id == -1`; changing acceptance of that value is a separate
  behavioral fix, not part of the trace-only patch.
- There is no established ThorChainKit logging abstraction to reuse.

## Scope

- Add one internal, injectable trace sink, disabled by default.
- Emit ordered, redacted events at: Kit send entry; quote/preflight start,
  route selection and each policy rejection; signing handoff and result;
  durable transaction state transitions; broadcast request, response,
  rejection and retry outcome.
- Include stable event name, stage, sanitized error case, endpoint role and
  route identifier, generation/attempt identifiers, and HTTP status or
  broadcast code when available.
- Explicitly omit raw addresses, memo, transaction bytes, signatures,
  auth headers, full URL/path/query, and raw response bodies.

## Affected areas

- `Sources/ThorChainKit/Core/Kit+Send.swift`
- `Sources/ThorChainKit/Core/KitFactory.swift`
- `Sources/ThorChainKit/Send/Preflight/SendPreflightCoordinator.swift`
- `Sources/ThorChainKit/Send/Internal/TransactionSender.swift`
- `Sources/ThorChainKit/Send/Signing/SendCoordinator.swift`
- `Sources/ThorChainKit/Send/Broadcast/CosmosTransactionBroadcaster.swift`
- `Sources/ThorChainKit/Storage/TransactionManager.swift`
- Focused send tests under `Tests/ThorChainKitTests/Send/`

## Non-goals

- Do not relax provider, height, endpoint, signing, or broadcast policy in
  this patch.
- Do not change persistence schema or public send result semantics.
- Do not use `print` or expose confidential send payloads.

## Acceptance criteria

1. A trace sink receives events in execution order for a successful mocked
   send and for a mocked `policyUnavailable` failure.
2. The failure trace identifies the stage that emitted `policyUnavailable`.
3. The trace contains no address, memo, raw transaction, signature, URL path,
   query, header, or response body.
4. The sink is inactive unless explicitly supplied by the host.
5. Existing behavior is unchanged apart from emitting trace events.

## Verification

- Add focused XCTest coverage for stage order, failure-stage attribution and
  redaction.
- Run only those focused ThorChainKit tests after implementation; do not run
  Wallet/AppTests unless explicitly requested.

## Open question

- After the trace identifies the live failing guard, should Comet ABCI accept
  only response id `-1`, or both `-1` and `1` for provider compatibility?
  The requested production behavior is currently understood as accepting
  `-1`; the trace will keep the source observable before changing it.
