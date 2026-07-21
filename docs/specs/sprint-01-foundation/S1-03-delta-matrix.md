# S1-03 — Analog Delta Matrix and Test Plan

This document is the review-bound delta matrix for
`S1-03-derivation-address-codec.md`. It is revision 7 after discovery 2/2
REVISE; implementation remains blocked until closure review and explicit
approval. Revision 7 binds the Board-approved iOS-only package correction.

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

## Board-approved platform and verifier delta

`Package.swift` declares exactly `platforms: [.iOS(.v13)]`. The macOS hosted
runner supplies Xcode and an iOS Simulator only; macOS is not a package
platform or product acceptance target. Narrow and full package tests use the
same authenticated simulator command and emit an xcresult bundle:

```bash
: "${THORCHAIN_SIMULATOR_UDID:?exact simulator selection missing}"
: "${DERIVED_DATA_PATH:?derived-data path missing}"
: "${RESULT_BUNDLE_PATH:?xcresult path missing}"
xcodebuild -scheme ThorChainKit \
  -destination "platform=iOS Simulator,id=${THORCHAIN_SIMULATOR_UDID}" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  CODE_SIGNING_ALLOWED=NO test
```

Narrow runs add `-only-testing:ThorChainKitTests/DerivationTests` or
`-only-testing:ThorChainKitTests/AddressCodecTests`; the full run is the
package regression gate. Static manifest/dependency inspection remains
allowed, but no host `swift build` or `swift test` result receives product
acceptance credit.

The named parser contract is `xcrun xcresulttool get test-results summary`
and `xcrun xcresulttool get test-results tests`, both with `--path
"$RESULT_BUNDLE_PATH" --compact`, consumed by the repository verifiers. They
must assert the selected test names and count, `totalTestCount`,
`passedTests`, `failedTests`, `skippedTests`, summary `result`, and every
test-node `result == Passed`; mutant runs use the same parser and require the
guarded result to be `Failed`. Missing or malformed JSON, an empty node list,
an unexpected name, failure/error/skip, or a parser/tool exit failure is a
hard verification failure.

The bounded current-tree census closes every inherited package-gate path:

| Path | Former host operation | Required evidence |
|---|---|---|
| `.github/workflows/ci.yml`, `Scripts/verify-s1-02-ci-policy.sh` | build, strict build, test block and literal policy expectation | authenticated selected-simulator `xcodebuild` block |
| `Scripts/verify-s1-03.sh` | derivation, codec, and full `swift test` | narrow selector and full simulator xcresult runs |
| `Scripts/verify-s1-01.sh` | host build/symbolgraph, discovery, xUnit, strict build, skip canary | iOS-target symbolgraph plus simulator/xcresult discovery, execution, strict-concurrency, and skip assertions |
| `Scripts/verify-s1-02.sh` | host discovery, build/symbolgraph, strict build, filtered tests | simulator Xcode/xcresult equivalents and iOS public-consumer build |
| `Scripts/test-s1-01-mutants.sh` | base/mutant `swift test --package-path` | the same simulator helper and xcresult mutant failures |
| `Scripts/verify-bigint-floor.sh` | copied-package host strict build/test | copied-package simulator Xcode build/test with lock-hash assertion |

The remaining `xcrun swift` invocations in `Scripts/run-maestro.sh`,
`Scripts/test-run-maestro.sh`, `Scripts/verify-s1-01-factory.swift`, and
`Scripts/verify-s1-02-live-evidence.swift` are standalone scanner/evidence
tools. They do not resolve `Package.swift`, compile a ThorChainKit target, or
claim product test credit, so they remain explicitly allowed host tooling.
CI selects an available pinned runtime and exports
`THORCHAIN_SIMULATOR_UDID`; committed files contain no operator-local UDID,
and missing selection, a literal UDID, a destination without the selected id,
or any remaining host SwiftPM package gate fails closed.

## Slice A — host derivation contract and public-key validation

| Field | Decision |
|---|---|
| Analog family | Primary: HdWalletKit commit `163b4e253aa763babeb6d14f246e1d81cfa0473e`, `Sources/HdWalletKit/HDWallet.swift:4-49` and `HDKeychain.swift:37-59`; supporting: HsCryptoKit `7c11ad0e690cbb178a70f3b9d1116d0a37a51a41`, `Crypto.swift:72-107,194-209`, and Vultisig `d3123dbe6ef1103937c272a8b1cd81f613af0acc`, `VultisigApp/VultisigAppTests/Chains/PublicKeyTest.swift:11-19`. Rejected: HsCryptoKit private-key convenience API as a kit boundary. |
| Coverage | Responsibility, boundary, dependency direction, lifecycle/error, trust, consumer, composition, and test roles are covered by the evidence checkpoint. Vultisig is supporting THOR-specific evidence only. |
| Invariants to preserve | Exact `m/44'/931'/0'/0/0`; secp256k1; compressed 33-byte public key; host-only seed/private ownership; typed errors; no fallback strings or `try?`. |
| Required differences | Introduce immutable `DerivationPath.rawValue` plus typed grammar errors, the internal derivation/context seams, the sole public `AccountAddressFactory.address(compressedPublicKey:network:)` boundary with explicit network selection, and real full-input secp256k1 parsing. |
| Rejected differences | No mnemonic/seed/private-key parameter, wallet object, signing helper, extended-public-key policy, curve auto-detection, or alternate path fallback. |
| Failure modes | Reject wrong length/prefix, invalid curve point, and unavailable parser context with typed errors; never hash malformed input or continue with an empty value. `DerivationPath.defaultAccount` is a non-trapping exact value; host path parsing failures remain S1-06 scope. |
| Tests before code | Exact path/coin assertions and host-adapter call shape; independent compressed-key vector with bound values; wrong length/prefix; invalid curve point; injected parser-context failure; no-trap and typed-error assertions; repeated-call/public-state retention check; public-symbol baseline. |
| Verification | Simulator `xcodebuild` with the DerivationTests selector and full xcresult run, exact expected-base/head/clean-worktree verifier, dependency/source/platform/secret verifier, strict-concurrency/public-consumer checks, and provenance audit. Host derivation is verified only in its later S1-06 integration slice, with the S1-03 test binding the exact raw path and adapter call shape. |

## Slice B — HASH160 and network-bound classic Bech32 codec

| Field | Decision |
|---|---|
| Analog family | Primary: current S1-01 `Address`/`Network`/`Bech32Codec`/`BitConversion` family. Supporting: HsCryptoKit commit `7c11ad0e690cbb178a70f3b9d1116d0a37a51a41`, `Crypto.swift:194-209`, and BitcoinCore commit `5b49f424f495904cf06519b1a7b861ef37b45b50`, `Sources/BitcoinCore/Classes/SegWit/Bech32.swift:14-147,188-205`. Rejected: BitcoinCore SegWit witness wrapper. |
| Coverage | Responsibility, boundary, dependency direction, lifecycle/error, trust, consumer, composition, and test roles are covered by the evidence checkpoint. |
| Invariants to preserve | Network selects the exact HRP; classic Bech32 only; strict convertBits padding; exact 20-byte payload; canonical lowercase storage; wrong HRP/checksum/mixed case fail closed. |
| Required differences | Add payload encoding and public `AddressCodec`; hash a validated compressed key as `RIPEMD160(SHA256(key))`; delegate decode directly to `Address.init`; expose no Boolean error-erasing parser wrapper and only the approved public symbols. |
| Rejected differences | No second decoder, unchecked initializer, Bech32m, SegWit witness version/program handling, arbitrary HRP, public payload storage, or silent canonicalization of invalid input. |
| Failure modes | Reject invalid payload lengths before bit conversion, invalid padding, checksum/case/HRP mismatch, and all unsupported network combinations with existing typed `AddressError`. Include a valid `tthor` wrong-HRP negative oracle; no mocknet address is added to the public `Network` set. |
| Tests before code | Encode/decode round trip for all supported networks; isolated SHA256/HASH160 KATs; exact independent public vectors; uppercase canonicalization; all S1-01 negative cases through `AddressCodec`; BIP173 valid/invalid vectors; direct padding and malformed-length tests; arbitrary UTF-8/property tests; public-symbol subset test. |
| Verification | Simulator `xcodebuild` with the AddressCodecTests selector and full xcresult run, exact expected-base/head/clean-worktree verifier, dependency/source/platform/secret verifier, Xcode target/navigation check, real-call-path Maestro mutant checks, deterministic fuzz replay, provenance audit, and `THORCHAIN_SIMULATOR_UDID=<selected-runtime> Scripts/run-maestro.sh s1-03` for the Example only. |

## Frozen blocker closure map — discovery 2/2, closure 4/5 pending

| Frozen IDs | Mechanical closure in revision 6 |
|---|---|
| `S103-ARCH-01` | `.maestro/S1-03-analog-manifest.txt` must reproduce the literal URLs `https://github.com/horizontalsystems/HdWalletKit.Swift.git`, `https://github.com/horizontalsystems/HsCryptoKit.Swift.git`, `https://github.com/horizontalsystems/BitcoinCore.Swift.git`, and `https://github.com/vultisig/vultisig-ios.git` alongside each pinned commit, path, and role. |
| `S103-ARCH-02`, `THR62-SEC-B02` | `DerivationPath.rawValue`, exact five-component grammar, typed `DerivationPathError`, and host `privateKey(path: DerivationPath.defaultAccount.rawValue)` call shape are normative; the host must not reconstruct the path from independent literals. |
| `S103-ARCH-03` | `AddressCodec.decode` delegates to `Address.init`; `isValid` is removed, so inherited typed errors are not erased. |
| `S103-ARCH-04`, `VOP-01` | `iOS Example/Sources/ThorChainExampleApp.swift`, Xcode project target membership, root navigation, shared runtime composition, non-`@testable` build, and `Scripts/test-s1-03-mutants.sh` real-call-path mutants are required. |
| `S103-ARCH-05` | `.maestro/config.yaml`, both Maestro runners, `.github/workflows/ci.yml`, and `Scripts/verify-s1-02-ci-policy.sh` are one cumulative S1-02 → S1-03 change; the exact expected CI command block and three-flow manifest are fixed. |
| `THR62-SEC-B01` | Factory has no default `.mainnet`; inherited S1-01 trap is recorded as baseline and cannot be introduced into the S1-03 call path. |
| `THR62-SEC-B03`, `VOP-04` | Exact bound vector values, output digest, pinned source commits/paths, independent hash/checksum sources, and oracle provenance are specified. |
| `THR62-SEC-B04` | Capability allowlist, forbidden-edge mutants, exact package products, and the complete two-section resolved-pin fixture are mandatory and fail closed. The inherited S1-01 baseline is the exact `bigint` row from `expected-base:Package.resolved`; the S1-03 closure is the four literal direct/transitive rows for HsCryptoKit `1.3.2`, HsExtensions `1.0.6`, secp256k1 `0.10.0`, and swift-crypto `2.6.0`, with the revisions recorded in the spec. |
| `THR62-SEC-B05`, `VOP-05` | Internal context-provider seam has production and deterministic injected-failure providers; `S1-03-fuzz-seed.txt` is exactly `version=1`, `algorithm=splitmix64`, `seed=0x534c30332d46555a`, `count=1024`, with three SplitMix64 outputs per case, modulo-2⁶⁴ state advancement (`&+`), little-endian packing, and four-byte truncation, replayed by the named test command. |
| `VOP-02` | Verifier requires literal expected base/head, exact `HEAD`, an explicitly fetched and SHA-checked `refs/remotes/origin/main`, clean worktree, and ancestor relation; the cumulative CI matcher includes the exact checkout/fetch/refspec block. |
| `VOP-03` | `S1-03-dependency-revisions.txt` has an immutable inherited-baseline section plus an exact four-row S1-03 closure. The verifier compares the expected-base lockfile baseline and the complete current direct/transitive pin union by package identity, URL, version, and revision, while also enforcing the literal closure rows; no version-only, movable-HEAD, missing, extra, or coordinated fixture/lockfile drift is accepted. |
| All IDs | Any mismatch is a closure finding on the exact changed head, not a new discovery cycle or blocker-list expansion. |

Revision 7 is documentation-only and preserves the accepted protocol choices.
Any implementation PR must populate the declared fixture/provenance artifacts
with exact values and fail closed if a schema field is absent.
