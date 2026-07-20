# S1-03 — Analog Delta Matrix and Test Plan

This document is the review-bound delta matrix for
`S1-03-derivation-address-codec.md`. It is design-only; implementation remains
blocked until this revision is adversarially accepted and explicitly approved.

## Assumptions and scope

- `Network`, `Address`, `Bech32Codec`, and `BitConversion` from S1-01 remain
  the current target contract at the approved base head.
- HdWalletKit and mnemonic/seed handling remain host-owned. ThorChainKit
  receives only `compressedPublicKey`.
- S1-03 adds no signing, account sync, watch-only policy, TNS, module/validator
  addresses, or Unstoppable integration.
- S1-03 fixture data contains public compressed keys and derived addresses only;
  mnemonic, seed, private-key, credential, and host-local-path fields are
  prohibited.
- Executable mnemonic/private-key lifetime and zeroization obligations belong
  to the later host-owned S1-06 integration; this slice proves the kit has no
  such ownership or capability.

## Slice A — host derivation contract and public-key validation

| Field | Decision |
|---|---|
| Analog family | Primary: HdWalletKit host path/public-key API. Supporting: HsCryptoKit secp256k1/hash primitives and the pinned Vultisig THOR public-key assertion. Rejected: HsCryptoKit private-key convenience API as a kit boundary. |
| Coverage | Responsibility, boundary, dependency direction, lifecycle/error, trust, consumer, composition, and test roles are covered by the evidence checkpoint. Vultisig is supporting THOR-specific evidence only. |
| Invariants to preserve | Exact `m/44'/931'/0'/0/0`; secp256k1; compressed 33-byte public key; host-only seed/private ownership; typed errors; no fallback strings or `try?`. |
| Required differences | Introduce `DerivationPath.defaultAccount`, the internal derivation seam, the sole public `AccountAddressFactory.address(compressedPublicKey:network:)` boundary, and real full-input secp256k1 parsing. |
| Rejected differences | No mnemonic/seed/private-key parameter, wallet object, signing helper, extended-public-key policy, curve auto-detection, or alternate path fallback. |
| Failure modes | Reject wrong length/prefix, invalid curve point, and unavailable parser context with typed errors; never hash malformed input or continue with an empty value. `DerivationPath.defaultAccount` is a non-trapping exact value; host path parsing failures remain S1-06 scope. |
| Tests before code | Exact path/coin assertions; independent compressed-key vector; wrong length/prefix; invalid curve point; parser-context failure; no-trap and typed-error assertions; repeated-call/public-state retention check; public-symbol baseline. |
| Verification | `swift test --filter DerivationTests`, full `swift test`, exact S1-03 dependency/source/platform/secret verifier, strict-concurrency/public-consumer checks, and provenance audit. Host derivation is verified only in its later S1-06 integration slice. |

## Slice B — HASH160 and network-bound classic Bech32 codec

| Field | Decision |
|---|---|
| Analog family | Primary: current S1-01 `Address`/`Network`/`Bech32Codec`/`BitConversion` family. Supporting: HsCryptoKit `ripeMd160Sha256` and BitcoinCore classic checksum implementation. Rejected: BitcoinCore SegWit wrapper. |
| Coverage | Responsibility, boundary, dependency direction, lifecycle/error, trust, consumer, composition, and test roles are covered by the evidence checkpoint. |
| Invariants to preserve | Network selects the exact HRP; classic Bech32 only; strict convertBits padding; exact 20-byte payload; canonical lowercase storage; wrong HRP/checksum/mixed case fail closed. |
| Required differences | Add payload encoding and public `AddressCodec`; hash a validated compressed key as `RIPEMD160(SHA256(key))`; expose only the approved public symbols. |
| Rejected differences | No second decoder, unchecked initializer, Bech32m, SegWit witness version/program handling, arbitrary HRP, public payload storage, or silent canonicalization of invalid input. |
| Failure modes | Reject invalid payload lengths before bit conversion, invalid padding, checksum/case/HRP mismatch, and all unsupported network combinations with existing typed `AddressError`. Include a valid `tthor` wrong-HRP negative oracle; no mocknet address is added to the public `Network` set. |
| Tests before code | Encode/decode round trip for all supported networks; isolated SHA256/HASH160 KATs; exact independent public vectors; uppercase canonicalization; all S1-01 negative cases through `AddressCodec`; BIP173 valid/invalid vectors; direct padding and malformed-length tests; arbitrary UTF-8/property tests; public-symbol subset test. |
| Verification | `swift test --filter AddressCodecTests`, full `swift test`, exact S1-03 dependency/source/platform/secret verifier, Example platform scan, real-call-path Maestro mutant checks, provenance audit, and `THORCHAIN_SIMULATOR_UDID=<exact-udid> Scripts/run-maestro.sh` for the Example only. |

## Open design questions before approval

1. The fixture must name at least three independent public sources and record
   immutable repository URL, commit, path, tool/version, command, input origin,
   and output digest; a vector generated only by this implementation is not
   acceptable.
2. The exact `secp256k1.swift` parser API and HsCryptoKit hash call signatures
   must be pinned by the implementation PR without expanding the public API;
   the dependency/source closure verifier must reject undeclared crypto,
   wallet, UI, I/O, logging, task, or static-key capabilities.
3. The S1-03 verifier must authenticate the exact baseline/HEAD, package
   resolution, cumulative public-symbol and test baselines, iOS 13 public
   consumer, platform imports, and the reachable Example Maestro manifest.
4. Any mismatch between this matrix and the authoritative S1-03 spec requires
   a new revision and fresh approval.
