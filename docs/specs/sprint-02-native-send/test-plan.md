# Sprint 2 — Consolidated Test and Verification Plan

## Purpose

This plan makes the seven slice exits executable and separates deterministic protocol proof, Example UI acceptance, opt-in mainnet compatibility, and Unstoppable product acceptance.

## Test Layers

| Layer | Execution | Proof |
|---|---|---|
| pure domain | local MacBook test run | exact/Max intent, opaque quote token, absolute expiry, typed errors, retry decisions |
| protocol codec | local MacBook test run | exact protobuf bytes, digests, signatures, TxRaw, hash |
| controlled async | local MacBook test run | one-family H0/H1/H2 preflight, cancellation, cross-Kit/sequence single-flight |
| storage/crash | local MacBook test run with temporary GRDB | migration, pre-broadcast durability, restart transitions |
| package integration | local MacBook test run | public facade, real internal dependencies, pending publisher |
| Example UI | guarded isolated-fixture Maestro suite | user-visible review/CheckTx-accepted/unknown/retry/restart states |
| opt-in mainnet | manual/release gate | current endpoint, fee, halt, signing, broadcast compatibility |
| WalletCore | local MacBook host-branch verification | handler/factory/signer/error contract |
| Unstoppable manual | Development app | real SendNew transfer; no Maestro in host |

All builds, tests, mutants, simulator checks, Maestro checks, and other
verification for remaining Sprint 2 slices run locally on the MacBook. GitHub
Actions stays disabled and is not an acceptance or merge gate; local evidence
is the authority for test execution. No hosted workflow may be enabled or
dispatched without a new explicit operator approval for that exact run.

## Traceability Matrix

| Invariant | Required tests |
|---|---|
| immutable one-use quote | `SendQuoteTests`, `QuoteStoreTests` |
| one family/fresh heights | `SendPreflightCoordinatorTests`, per-route REST-header/Comet-ABCI/body proof, lifecycle-generation H0, and H0/H1/H2 rollback/mix fixtures |
| non-cooperative endpoint liveness | `EndpointOperationRunnerTests`, H1/H2 and retry never-resume/late-result interleavings |
| exact/Max + dynamic native fee | `SendPreflightCoordinatorTests`, `SendPolicyTests`, Max and insufficient-balance matrices |
| halt/module/memo policy | `HaltEvaluatorTests`, `RecipientAccountClassifierTests`, `ForbiddenModuleAddressSetTests`, `SendPolicyTests` |
| exact protobuf/direct sign | `MsgSendCodecGoldenTests`, `DirectSignGoldenTests` |
| external signer trust | `SignerVerifierTests`, `SendCoordinatorTests`, malformed/high-S/wrong-key vectors |
| one send per namespace/sender/sequence | `SendCoordinatorConcurrencyTests` plus two-Kit/shared-runtime/restart fixtures |
| persist active generation before I/O | `SendJournalOrderingTests` |
| publish every initial/retry generation before I/O | `PendingPublicationBarrierTests` with observation failure/deadline cases |
| CheckTx-accepted/rejected/unknown | `BroadcastClassifierTests` and monotonic CAS tests |
| exact-byte retry | `BroadcastRetryTests`, exact Cosmos REST positive/not-found manifest, restart reconstruction tests |
| pending projection | `PendingTransactionRepositoryTests` and publisher replay/degraded-recovery tests |
| Example states | five guarded Maestro fixture flows |
| host integration | WalletCore live/fake quote-handle client tests, executable strict-concurrency gate, handler/factory/signer tests, and manual mainnet checklist |

## Mandatory Failure Matrix

- exact amount zero/overflow/invalid decimal conversion; returned spendable denom not literally `rune`; Max with balance above/equal/below fee and fee changes at H1/H2;
- wrong network HRP, self-send, malformed recipient, exact-height recipient BaseAccount/supported wrapper/sdk-22-NotFound with absent/null/empty-base64 zero-byte encodings and nonempty/invalid/duplicate value rejection, ModuleAccount/unknown-Any responses, every version-derived forbidden module payload, and unsupported THORNode version;
- missing/mismatched chain identity or route proof: stripped/mismatched REST response header, wrong Comet ABCI response height/path/value, unapproved body-height field, or query-only `?height=H`; one request's proof never validates another request's value;
- any required preflight endpoint unavailable, malformed, unproven, or from another family; the known bulk ModuleAccounts panic route must never be selected;
- all four Mimir keys proven unset as `-1`, zero inactive, each active boundary, `< -1`, malformed and unproven height; native fee zero is valid;
- memo at limit, one UTF-8 byte above limit, malformed representation;
- quote absolute deadline after delayed host quote, quote reused, provider family changed;
- sequence, fee, balance, halt, recipient account/reserved-module policy, node version, or memo policy changed before signer request;
- same fields changed while asynchronous signer is suspended; returned signature must be discarded;
- H0/H1/H2 lease, every route request, and backoff operation that ignores cancellation, never resumes, or returns late; the owner returns at the deadline, starts no later call, and H1/H2 release exact send ownership;
- H0 suspended before/after any response → `stop()` → late success, with and without a rapid new `start()` before expiry: old generation promptly returns `kitNotStarted`, starts no next route, and leaves QuoteStore empty;
- signer cancellation/expiry, never-returning signer, wrong compressed public key, invalid key, short/long signature, zero/out-of-range scalar, high-S signature, cryptographic mismatch;
- simultaneous sends through one Kit and two Kit instances constructed from duplicate/relative/symlink/hard-link URLs for one SQLite file; exact filesystem identity yields one writer/runtime, distinct namespaces share that writer but can overlap, and an independent-connection test proves SQL uniqueness only;
- durable reservation conflict/release/restart; unlinked reservation cleanup versus linked reservation retention;
- atomic initial broadcasting+reservation-link failure, cross-domain committing handoff crash, atomic rejected+reservation-release failure, crash before transport and during broadcasting, database reopen;
- code 0/hash match, exact sdk/19/hash match, foreign-codespace/19 rejection, missing/empty/malformed-codespace/19 unknown, other nonzero rejection, and a missing/malformed/mismatched-hash cross-product proving hash validation wins for every code/codespace;
- exact `CosmosTxRESTBroadcast` POST/path/headers/no-query/no-redirect/request-body contract; only bounded HTTP-200 normalized JSON with the single top-level `tx_response` key is authoritative;
- duplicate root/`tx_response`/hash/code/codespace/log keys including conflicting values, missing/null/wrong nesting/top-level fields, noninteger/negative/overflow code, invalid field types, BOM, trailing JSON, non-UTF-8, wrong media/charset, redirect, oversize, every non-200 status, wrong-route schema mode, timeout/cancellation, and non-returning transport after broadcast begins all remain unknown and retain the linked reservation;
- retry lease/hash lookup/policy operations that never resume or return after generation invalidation; no subsequent call starts and live repair returns the row to unknown without restart;
- exact `CosmosTxRESTLookup` uppercase request, bounded 200 matching-hash/positive canonical JSON-string height envelope, Liquify-pinned exact-key-set 404 with JSON integer code 5/empty details/exact hash-bearing message, and every mismatch/malformed/4xx/429/5xx/content-type/size/duplicate-key/redirect branch; bounded approved-media 200/404 JSON/schema failures are provider-inconsistent, transport acquisition/content-type/size failures remain transport failures, and only exact found/not-found have authority;
- fee changes before retry, sequence lower/advanced with exact not-found lookup, transaction response with exact matching/missing/malformed/mismatched hash, repeated exact `sdk/19`, and no family switch between lookup/snapshot/broadcast inside one retry attempt;
- concurrent retries and late old-generation responses cannot downgrade terminal truth;
- pending GRDB observation initial/replay/update ordering through the shared writer, publication acknowledgement before initial and retry endpoint I/O, continuous broadcasting-as-unknown/in-flight visibility, generation/owner-scoped live repair without restart, reentrant repair-intent token replacement, observation error/replacement/next-commit delivery, never-started/after-stop lifecycle-first rejection—including invalid quote input/foreign quote/missing retry ID—with zero QuoteStore/journal spy access, A-stop-with-B-active repair, stop-during-send operation hold, repair-hold completion after the last client stops, sequence-advanced/provider-inconsistent visibility, and no overwrite of later confirmed history;
- first-send BaseAccount with null pubkey and non-null signer-key match/mismatch;
- signer whose key getter mutates and signer that ignores cancellation/returns late;
- host exact amount never rounds: `1e-8` succeeds, `1e-9`/half-unit/fiat excess precision/overflow fail; Max compares equally canonicalized base units;
- host signer is created only through the awaited MainActor provider; no active account, passcode/duress switch, active-account switch, removal/replacement, or long-lived-secret property; every failure makes zero Crypto.sign/broadcast calls;
- host CheckTx accepted and unknown each render a dedicated full-local-hash state without generic error/sent completion/banner; direct iOS 17 navigation and wrapper Done each dismiss only their own presentation; expired host quote makes zero signer/send calls;
- public consumers still cannot construct kit quote/request authority; WalletCore fake send client constructs only its own handle/outcome and deterministically drives accepted/unknown/expiry, while production rejects a non-live handle before signer/kit calls;
- kit `SendAmount`, `SendQuote`, pending DTO/status/error payloads store only checked-Sendable Address/Data/string/integer state and reconstruct BigUInt accessors; exact/fee public inputs snapshot before actor calls; WalletCore review/handle snapshots store canonical strings, never BigUInt, and use no unchecked/preconcurrency suppression;
- the exact public `QuoteChange`, read-only nonempty `QuoteChanges`, `RetryBlockedReason`, `NativeFeeChange`, `BroadcastRejection`, and every `SendError` case compile as one checked-Sendable graph; internal empty construction returns nil, external initialization and `.quoteChanged([])` fail to compile, fee values above `UInt64` round-trip from Data, diagnostic bounds are enforced, and the stored-BigUInt control fails;
- production send client rejects fake and cross-client same-type live handles by private owner identity before signer/kit calls;
- drag and accessibility SlideButton entry closures are executable tests wired only to one exactly-once action path; only `.sent` consumes generic completion permission, while CheckTx/unknown retain the dedicated result and Done dismisses without `onSuccess`;
- `check-thorchain-send-concurrency.sh --baseline <sha>` uses `Debug-Dev build-for-testing` for baseline/HEAD, rejects every new diagnostic in all repository-owned Swift including unchanged transitive callers, proves invalid actor and diagnostic-parser canaries fail, and proves the valid awaited-provider/SendQuote/live-handle probe compiles; the serialized AppTests command carries the same strict flags;
- zero discovered Swift tests or Maestro flows must fail the gate.

## Golden and Property Tests

- Pin the complete independent Vultisig vector and its 20M control digest.
- Pin the Vultisig-input `3_000_000` gas SignDoc control digest `83a508ff301fc5cf7ab5126d861e7bac8dd1ebc5691df4842d6b2ac84dd3668f` and complete bytes.
- Pin the complete scalar-one RFC6979 low-S signed vector: public key `0279be66…f81798`, SignDoc digest `1ff56dd4…110b68`, the literal 64-byte signature/242-byte TxRaw from S2-03, and transaction ID `3685BF7AD0C65889B763D4B6D1F1EDEEC96E9B63B63F8DB992D00757EB5F136E`; independently decode and verify it.
- Pin official gas provenance to THORNode `a759cb4f…`, `docs/cli/multisig.md:27-56`, blob `537cac65…`, and file SHA-256 `27e39d94…`.
- Independently decode every produced protobuf and compare semantic fields, including literal denom bytes `rune`.
- Verify address/public-key binding and low-S normalization against independent secp256k1 vectors.
- Property/fuzz invalid protobuf lengths, Bech32 recipients, memo UTF-8 boundaries, signature scalars, and broadcast envelopes; log the seed on failure.

## Deterministic Async Rules

- Inject transport, lease source, clock, journal, broadcaster, transaction lookup, signer, host send client, and SlideButton completion spies.
- Fixed sleeps are prohibited.
- Tests coordinate on observed continuations and assert exact ordering.
- Every provider operation is one owned task raced against cancellation/deadline; a token/generation check on actor re-entry precedes any next call. H0 additionally races client lifecycle invalidation, and final quote insertion rechecks that exact generation so stop/start cannot revive it. Cancellation/expiry before a signed journal insert releases the reservation even when signer or H1/H2 I/O never returns; failed deletion is repaired live by exact owner token. After the atomic initial `broadcasting` commit, the observation publication barrier acknowledges unknown/in-flight before I/O; cancellation/deadline returns unknown without waiting for non-cooperative retry/broadcast work, and failed normalization is repaired by inactive generation.
- A fresh repair-intent token created during an active repair pass cannot be cleared by the older pass; the deterministic paused-snapshot interleaving requires an immediate second pass.
- Every request asserts provider-family ID, configured proof mode, and its own exact height evidence.
- Registry/storage tests prove physical database identity, one file-migration owner, one namespace-recovery owner, signature request count and maximum in-flight count across two Kit instances; initial send and retry persist/register/publish an active generation before Kit B can perform endpoint I/O; one-time recovery cannot run when Kit B joins Kit A's live broadcast; client, operation, and repair holds preserve cleanup across stop; attempt-generation checks discard late signer and broadcaster completions.

## Example Maestro Manifest

The guarded runner is the sole Example UI entry and targets one exact `THORCHAIN_SIMULATOR_UDID`:

| Flow | Required state |
|---|---|
| `send-quote-review.yaml` | amount, recipient, non-empty memo, fee, total, height, absolute expiry, FIXTURE badge; exact-deadline clock advance hides/disables confirm, shows Refresh, signer calls remain zero |
| `send-checktx-accepted.yaml` | one signature request, canonical local hash, `CheckTx accepted — not confirmed`; classifier integration separately proves the node hash matched |
| `send-unknown.yaml` | response loss produces unknown with same local hash |
| `send-retry.yaml` | fee acknowledgement and exact-byte idempotent rebroadcast; no new signature |
| `send-restart-pending.yaml` | relaunch restores unknown/CheckTx-accepted pending record and bytes identity |

Selectors use stable accessibility identifiers. Each flow has a unique reset namespace; only the restart flow preserves its own namespace between phases. The runner requires JUnit `tests=5`, `failures=0`, `errors=0`, `skipped=0`, scans text artifacts for byte canaries, and scans every screenshot with a Vision/OCR path whose temporary rendered-canary self-test must first fail as expected. A Release binary audit proves the Live scheme does not link fixture support.

Every narrow Swift test filter is wrapped by a discovery assertion that fails when the selected test count is zero; a command that exits successfully after running no matching test is not evidence.

## Mainnet Evidence Record

Record without secrets:

- kit/host commit and timestamp/timezone;
- provider family/role and public endpoint host;
- chain ID, quote height, and broadcast time;
- public sender/recipient test addresses and purpose-created provenance;
- amount, native fee, total debit, account number/sequence only if safe for evidence;
- SignDoc/TxRaw hashes, never raw signature or secret;
- local hash, CheckTx code/codespace/log sanitized, and the package classification result; no separate remote-hash UI/public field;
- explorer/inclusion observation clearly labeled as observational until Sprint 3;
- unavailable/skipped checks and reason.

## Verification Order

1. format/lint and package manifest checks;
2. narrow slice test class;
3. complete ThorChainKit deterministic suite with non-zero discovery assertion;
4. dependency/import/public API/unchecked-suppression audit, public-negative/internal-token-positive/host-fake-positive/owner-identity quote seam tests, and `Scripts/CI/check-thorchain-send-concurrency.sh --baseline <approved-base-sha>` using `Debug-Dev build-for-testing`;
5. build Example on exact simulator;
6. guarded Maestro fixture suite and artifact scan;
7. opt-in live package gate;
8. S2-07 WalletCore narrow tests, drag/accessibility outcome-completion tests, and literal `AppTests/ThorChainGlobalStateTests` `Debug-Dev` command with suite serialization, overlap sentinel, and `-parallel-testing-enabled NO`;
9. manual Unstoppable controlled send;
10. diff audit proving no Maestro/acceptance-only runtime in Unstoppable.

## Sprint Exit Gate

- All deterministic tests pass with no ignored/skipped send cases.
- Both golden families pass and the official gas/vector is authoritative.
- Crash/restart and response-loss paths preserve exact bytes and hash.
- Maestro fixture count and JUnit assertions pass; artifacts contain no secrets.
- Controlled mainnet CheckTx acceptance is recorded.
- Unstoppable manually demonstrates exact and Max SendNew quote/review/send, absolute expiry/Refresh, and honest unknown without success completion through the standard handler path.
- All high/critical independent-review findings are resolved on one final revision.
