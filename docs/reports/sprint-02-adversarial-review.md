# Sprint 2 — adversarial architecture review

## Conclusion

**Decision: ACCEPT.** Three independent review lanes accepted architecture revision 10 with no remaining critical, high, medium, or low corrective finding. The accepted canonical bundle digest is:

```text
a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc
```

The bundle is the ordered SHA-256 manifest of `S2-01` through `S2-07` plus `test-plan.md`. The reviewers checked that digest before and after their read-only analysis. Acceptance permits presenting the package to the user for approval; it is not user approval and does not authorize implementation.

No ThorChainKit or Unstoppable source code was implemented or changed by this design review.

## Independent final review

| Lane | Decision | Final challenge |
|---|---|---|
| protocol and public API | ACCEPT | official Cosmos/THOR wire authority, nonempty error invariants, sdk/22, module policy, vectors, and strict broadcast/lookup envelopes |
| lifecycle, storage, and concurrency | ACCEPT | lifecycle-first admission, stop/start generations, non-cooperative tasks, publication ordering, journal/reservation atomicity, one writer, repair, and observation replacement |
| product, Unstoppable, and Example | ACCEPT | checked-Sendable host seam, signer authorization, honest CheckTx/unknown UX, strict AppTests, fixture secrecy, and Example-only Maestro |

The main review rechecked each lane's cited spec anchors and independently reproduced the two compiler-sensitive claims: the complete public error graph passes Swift 5 complete strict concurrency, while an external consumer cannot construct `QuoteChanges` or `.quoteChanged([])`.

## Revision history

The review deliberately returned `REVISE` whenever a load-bearing contract could not be executed or falsified deterministically.

| Revision | Result | Material corrections before the next review |
|---:|---|---|
| 1 | REVISE | exact Mimir/native-fee rules, coherent heights, sequence reservation, first-send pubkey, cancellation, durable pending states, Send Max, expiry, mnemonic-only host boundary, and Example isolation |
| 2 | REVISE | route-owned historical-height proof, atomic rejection/reservation release, non-cooperative signer liveness, physical runtime ownership, precision-safe host conversion, and explicit Example flows |
| 3 | REVISE | hash-first exact `sdk/19`, active broadcast generations, live repair, authorized active-account signer construction, and dedicated accepted/unknown host outcomes |
| 4 | REVISE | fixed-eight signer summary, independently decoded SignDoc, official gas provenance, full signed TxRaw vector, endpoint-operation races, and a legal host fake seam |
| 5 | REVISE | protocol and lifecycle lanes accepted; product lane required checked-Sendable BigUInt snapshots, private live-handle ownership, Debug-Dev diagnostics, and outcome-gated completion |
| 6 | REVISE | route-specific height proof for the real provider, one physical-database writer, generation-replacing GRDB observations, complete direct/wrapper outcome UX, and full AppTests build coverage |
| 7 | REVISE | recipient-specific account classification replaced the broken bulk ModuleAccounts path; complete public error graph, retry hash equality, lifecycle holds, and migration/recovery ownership were fixed |
| 8 | REVISE | nonempty `QuoteChanges`, exact Cosmos GetTx positive/NotFound authority, sdk/22 null normalization, lifecycle-first storage access, and H0 stop/start generation binding were fixed |
| 9 | REVISE | protocol lane found that broadcast could terminalize from a permissively parsed JSON response; lifecycle and product lanes otherwise accepted |
| 10 | ACCEPT | exact versioned broadcast POST/status/media/redirect/bounds/schema plus one preselected-mode duplicate-key-rejecting decoder closed the final finding; all three lanes accepted |

## Final protocol invariants

- Native transfer uses local `/types.MsgSend`, `SIGN_MODE_DIRECT`, empty serialized fee coins, official gas `3_000_000`, and literal denom `rune`.
- The complete scalar-one vector fixes a 193-byte SignDoc, 64-byte low-S compact signature, 242-byte TxRaw, and local transaction hash.
- One provider family supplies every H0/H1/H2 value with a route-specific proof. A value and its height proof come from the same request.
- The broken bulk ModuleAccounts route is prohibited. The specific recipient is classified at the exact height, then checked against a version-gated source-derived forbidden module-address set.
- Exact `sdk/22` with matching height and absent, JSON-null, or empty-base64 response bytes is the only account-absence proof. Nonempty, invalid, duplicate, foreign-codespace, or wrong-height responses fail closed.
- A read-only nonempty `QuoteChanges` wrapper makes an empty public `quoteChanged` payload structurally unconstructible.
- Broadcast authority is exactly Cosmos REST `POST /cosmos/tx/v1beta1/txs`. Only the bounded HTTP-200 normalized JSON `BroadcastTxResponse.tx_response` schema is classifiable.
- Lookup authority is exactly Cosmos REST `GET /cosmos/tx/v1beta1/txs/{UPPERCASE_HASH}`. Only a matching bounded positive response or the family-pinned HTTP-404/code-5/hash-bearing NotFound envelope has authority.
- The strict JSON parser is invoked with a preselected broadcast, lookup-found, or lookup-not-found schema. It rejects BOM, trailing tokens, non-UTF-8, duplicate keys at any depth, wrong nesting/cardinality/type/range/media/status/size, and cross-route reinterpretation.
- Hash equality precedes code/codespace interpretation. Only matching-hash code 0 or exact `sdk/19` is CheckTx-accepted. No malformed or non-authoritative response can terminalize or release a reservation.

## Final lifecycle and storage invariants

- A stopped or never-started client fails before QuoteStore or journal access. Quote H0 and final insertion remain bound to the exact client lifecycle generation, so stop followed by rapid start cannot revive a late quote.
- Every admitted send/retry acquires an operation hold before quote/row admission. Client stop does not orphan the already admitted financial operation or its repair.
- One process-wide runtime per physical SQLite `(device,inode)` identity owns one writer. Wallet/network namespaces are child runtimes with separate recovery, not separate writers.
- Exact signed bytes, local hash, active generation, and sequence-reservation link commit atomically before endpoint I/O.
- The pending publisher acknowledges the exact initial or retry generation as `unknown/inFlight` before the first endpoint call.
- CheckTx rejection and deletion of only its linked reservation commit in one transaction. Acceptance retains the reservation. Every ambiguous or malformed response remains unknown and retains it.
- A failed normalization transfers the operation hold to a versioned repair intent. Repair touches only inactive exact owner tokens/generations and survives the last client stopping.
- Failed GRDB observations are replaced with a new observation generation; a standalone reread is not mistaken for recovery.
- Signer, H0/H1/H2, lookup, retry, broadcast, and backoff operations are owned tasks raced against cancellation/deadline. The caller never waits for a non-cooperative dependency, and late callbacks cannot start the next operation or commit.

## Final product boundaries

- ThorChainKit owns quote authority, protobuf, signature verification, exact bytes/hash, journal, broadcast classification, retry, and pending projection. The host owns secret material, signing capability, localization, and app composition.
- Public and host-crossing state stores only checked-Sendable address/data/string/integer snapshots. `BigUInt` inputs are copied before actor entry and reconstructed for read-only access.
- Unstoppable creates an ephemeral signer only from the currently authorized active mnemonic account and rechecks account identity/type/key at the actual signature operation.
- CheckTx-accepted and unknown are dedicated full-local-hash outcomes. Neither can enter the generic Sent/error path, consume SlideButton success, show the sent banner, or invoke `onSuccess`.
- The complete Unstoppable strict-concurrency gate uses `Debug-Dev build-for-testing`, includes AppTests and unchanged repository-owned callers, and keeps OpenCryptoPay's existing synchronous factory surface intact.
- Maestro, fixture transport, fixture signer, and acceptance launch arguments exist only in `ThorChainKit/iOS Example`. Unstoppable receives WalletCore/AppTests plus a controlled manual Development-app scenario, never Maestro.

## Verification evidence

- canonical eight-file digest and per-file integrity manifest;
- Swift 5 complete strict-concurrency positive public-error probe;
- emitted-module external negative probes for `.quoteChanged([])` and `QuoteChanges(validating:)`;
- Foundation duplicate-code JSON reproduction proving permissive parsing is unsafe for terminal broadcast classification;
- official Cosmos SDK `v0.53.0` BroadcastTx/GetTx route, response, and NotFound source verification;
- official THORNode protocol/gas/module-source verification and independent protobuf/signature/hash reconstruction;
- deterministic test matrices for cancellation, stop/start, duplicate writers, partial writes, publication, repair, retry, strict JSON, host outcomes, and fixture secrecy;
- local Markdown integrity, link, fence, whitespace, and `git diff --check` gates.

## Constraints and remaining authority

- Gimle evidence Trust is **YELLOW**, not RED: every load-bearing indexed claim agrees with its current-tree Serena/targeted-`rg` verification, but this long-lived Codex connector retained a dead StreamableHTTP session after the Palace restart. Fresh sessions and Palace/Neo4j health were independently confirmed. The transport defect and fallback are recorded in the Gimle report.
- A current-family native MsgSend lookup/broadcast compatibility gate may conservatively reject an oversized or changed provider envelope and leave the transaction unknown. This is intentional; it never guesses authority.
- Inclusion, confirmation, history merge, and reconciliation are Sprint 3 scope.
- Implementation remains blocked until the user explicitly approves this exact revision 10 design package.
