# Sprint 2 — Native RUNE Send Design Package

## Status

**Architecture revision 10 passed the fresh three-lane adversarial review with no remaining corrective finding. Explicit user approval of the canonical digest is required before implementation.**

This package specifies a safe vertical send path for native RUNE. It extends the approved Sprint 1 read-only kit without changing its provider identity, address, synchronization, or lifecycle contracts.

## Goal and Success Criterion

A user reviews a coherent fee/total, authorizes exactly one local direct-sign transaction through a host-owned signer, receives the locally computed hash, and can recover from an ambiguous broadcast by rebroadcasting the exact persisted bytes. The same contract is demonstrated in the kit-owned Example and the standard Unstoppable SendNew flow.

## Slices

| ID | Spec | Verifiable outcome |
|---|---|---|
| S2-01 | [`S2-01-send-domain-quote-contract.md`](S2-01-send-domain-quote-contract.md) | immutable one-use quote and stable public errors compile and validate input |
| S2-02 | [`S2-02-pinned-preflight.md`](S2-02-pinned-preflight.md) | fee/account/halt/recipient policy is proven from one family and height |
| S2-03 | [`S2-03-direct-sign-codec.md`](S2-03-direct-sign-codec.md) | exact SignDoc/TxRaw/hash golden vectors pass |
| S2-04 | [`S2-04-external-signer-coordinator.md`](S2-04-external-signer-coordinator.md) | signer identity/signature and per-account single-flight fail closed |
| S2-05 | [`S2-05-durable-broadcast-pending.md`](S2-05-durable-broadcast-pending.md) | exact signed bytes survive ambiguous broadcast and restart |
| S2-06 | [`S2-06-example-acceptance.md`](S2-06-example-acceptance.md) | guarded isolated-fixture Maestro flows prove CheckTx-accepted, unknown, retry, and restart states |
| S2-07 | [`S2-07-unstoppable-integration.md`](S2-07-unstoppable-integration.md) | native RUNE uses current WalletCore SendNew architecture and a controlled mainnet send |

Consolidated verification: [`test-plan.md`](test-plan.md).

## Related Evidence

- [Sprint roadmap](../../roadmap/sprint-02-native-rune-send.md)
- [Verified analog family](../../research/sprint-02-analog-family.md)
- [Protocol and signing notes](../../research/sprint-02-protocol-and-signing.md)
- [Gimle reliability](../../reports/gimle/sprint-02-gimle-reliability.md)
- [Adversarial review](../../reports/sprint-02-adversarial-review.md)

## Assumptions

- Sprint 1 public/network/address/read/lifecycle behavior is implemented as approved before Sprint 2 begins.
- This repository is the standalone product authority; Unstoppable changes occur only in S2-07 on a separate reviewed host branch.
- Only native L1 RUNE MsgSend is supported.
- Swift concurrency checking applies to all new send types and actor boundaries.
- `iOS Example` is fixture-first and contains no committed mnemonic/private key.
- Live evidence uses controlled purpose-created accounts and redacts secrets.

## Scope and Ownership

ThorChainKit owns quote authority, preflight, protobuf construction, signer verification, send serialization, journal, broadcast classification, retry, and pending projection. The host owns secret material, derivation of the signing key, user confirmation, localization, and application composition.

The kit must not import WalletCore or Unstoppable modules. The host may import only the public ThorChainKit product.

## Implementation Order

1. Public domain and quote contract.
2. Pinned read/preflight internals.
3. Codec and golden vectors.
4. Signer boundary and coordinator.
5. Journal/broadcast/retry.
6. Example UI and acceptance.
7. Unstoppable adapter and mainnet product acceptance.

No later slice may introduce a shortcut around an earlier invariant. In particular, S2-06 fixture signing and S2-07 host signing use the same public `Signer` protocol and production codec.

## Pinned Decisions

- quote TTL: 10 seconds;
- all preflight values: one provider family with complete monotonic H0/H1/H2 snapshots; each returned value proves its own height through an approved REST-header, Comet-ABCI, or authoritative-body mode; recipient policy uses exact-height Account classification plus a versioned source-derived forbidden-module set because current bulk ModuleAccounts panics;
- exact/Max amount intent; Max is spendable RUNE minus the coherent native fee;
- native MsgSend gas: `3_000_000`;
- official gas provenance and a complete deterministic low-S signed TxRaw vector are pinned byte-for-byte;
- public signer: asynchronous compressed-public-key boundary, no secret material;
- amount/quote/submission/pending/error identity: checked `Sendable` storage uses Address/Data/string/integer snapshots; BigUInt inputs snapshot before actor entry, accessors reconstruct new values, `QuoteChanges` is externally read-only and structurally nonempty, the complete public error/supporting-payload graph is declared, and unchecked suppression is forbidden;
- SigningRequest monetary summary: canonical native RUNE with exactly eight fractional digits and decoded-SignDoc cross-checks;
- signature: compact 64-byte low-S secp256k1, verified in kit;
- initial journal commit: active generation, exact bytes/hash, and reservation link atomically before network I/O; every initial/retry unknown/in-flight generation is acknowledged before endpoint I/O;
- broadcast authority: exact versioned Cosmos REST POST/status/media/redirect/body/top-level manifest through one strict duplicate-key-rejecting decoder; only then may matching-hash code 0 or `sdk/19` become terminal CheckTx-accepted, foreign-codespace 19 reject, or another definitive code release a reservation; every wire deviation remains unknown;
- one process-wide database runtime/shared writer per physical SQLite identity with namespace children, atomic alias-safe file migration, child-owned namespace recovery, per-Kit lifecycle generation, lifecycle-first send/retry admission, client/operation/repair activity holds, generation-scoped observation replacement, version-tokened live inactive-work repair, and a durable unique sequence reservation across Kit instances;
- cancellation/deadline does not await non-cooperative signer, H0/H1/H2, retry, or transport work; H0 also races lifecycle stop and every subsequent endpoint call/final quote insertion requires a valid token/generation, so invalid generations cannot commit late results;
- retry: one family lease and exact bytes only, a bounded family-pinned Cosmos REST matching-hash/NotFound manifest, provider-inconsistent blocking, and explicit changed-fee acknowledgement;
- pending is CheckTx/local state; Sprint 3 owns inclusion/history reconciliation;
- Unstoppable creates an ephemeral signer only from the current active account; private owner identity separates live clients; fake handles never forge kit types; outcome-gated drag/accessibility completion renders dedicated accepted/unknown hashes in both presentation routes; `Debug-Dev build-for-testing` adds no diagnostic in any repository-owned Swift file;
- Maestro exists only in a Debug fixture-support target/scheme of `ThorChainKit/iOS Example`; Live Release never links it.

## Areas Affected by Future Implementation

- `Package.swift` and internal SwiftProtobuf/secp256k1 dependency wiring;
- `Sources/ThorChainKit/Send`, `Protocol`, `Storage`, `Network`, and public facade extensions;
- `Tests/ThorChainKitTests/Send` plus fixtures and controlled transports;
- `iOS Example`, `.maestro`, and guarded runner scripts in this repository;
- current `packages/WalletCore/Sources/WalletCore/...` integration files listed in S2-07.

## Integrity Manifest

The table freezes the exact eight-file review bundle before adversarial review. Any design edit invalidates the review and requires updated hashes plus a new bundle digest.

<!-- SPEC_HASHES_START -->
| Artifact | SHA-256 |
|---|---|
| `S2-01-send-domain-quote-contract.md` | `ab208e64a7498644c0c9582e326286adb934fc72ea51ca4d5811fc0b5b663bc0` |
| `S2-02-pinned-preflight.md` | `23041f2426584df75e0a477c129c92afd15565ec0a185ac191d9dc55df02e554` |
| `S2-03-direct-sign-codec.md` | `1d651ddf249016888b053997f3ff7541c95902f2127cd33d8bf5ebcff019038e` |
| `S2-04-external-signer-coordinator.md` | `e208a20b81f1129d680f649663d5fc485003814902b788a897c6eb78d336aab7` |
| `S2-05-durable-broadcast-pending.md` | `b6afab639b1ab0afd5c43918929d66d5e249f7b4d51ec12eef09fc2ebb2252fc` |
| `S2-06-example-acceptance.md` | `d482a62d2ed9b349ba9316b539df6e262879d2cee316399d13f6220be176e23c` |
| `S2-07-unstoppable-integration.md` | `e12500f66891ac508e81af1f2c8b2b7711eea00125ef18054309de3f05043302` |
| `test-plan.md` | `0249a4e4a17d1905a76b74eabecd62895a149cafb41c91208a60a54da60d43fb` |
<!-- SPEC_HASHES_END -->

Canonical revision 10 bundle digest: `a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc`. Reproduce it from the repository root with `sha256sum docs/specs/sprint-02-native-send/S2-*.md docs/specs/sprint-02-native-send/test-plan.md | sha256sum`.
