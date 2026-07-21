# S1-03 — Account Derivation and Address Codec

**Status:** revision 7, Board-approved iOS-only platform correction. Discovery 2/2 is frozen; closure 4/5 was accepted before this revision and is not reset. Implementation is blocked pending revision-bound adversarial review.
**Risk:** high/cryptographic boundary.
**Observable outcome:** an independent seed/public-key vector produces the expected THORChain address; checksum, payload length, mixed case, and wrong-network HRP are rejected before any network/signing call.

## Goal

Implement a transparent Cosmos-style derivation/address pipeline using existing Horizontal Systems primitives without bringing seed ownership, WalletCore, or Vultisig MPC/TSS types into the kit.

## Normative Pipeline

```text
mnemonic seed (host boundary)
  → BIP44 m/44'/931'/0'/0/0
  → secp256k1 private key (temporary host/address factory scope)
  → compressed 33-byte public key
  → SHA256(publicKey)
  → RIPEMD160(hash) = 20-byte account payload
  → convertBits 8 → 5, pad=true
  → Bech32 (not Bech32m) with Network.accountHrp
```

Sources: [THORChain path example](https://dev.thorchain.org/concepts/sending-transactions.html), [Cosmos address derivation/validation](https://docs.cosmos.network/sdk/latest/guides/reference/bech32), [SLIP-0044 coin type 931](https://github.com/satoshilabs/slips/blob/master/slip-0044.md).

## Scope

In scope:

- default derivation path;
- documented default path and host derivation contract through the existing HdWalletKit;
- address derivation from a compressed public key;
- public Cosmos-compatible Bech32 payload encoding built on the S1-01 decoder/convertBits implementation;
- reuse of S1-01's strict network-aware parser/normalizer;
- official, cross-library, and negative vectors;
- a fail-closed capability/source-closure gate proving that no seed, mnemonic,
  private key, wallet dependency, logging, I/O, or retained secret capability
  enters the kit.

Executable mnemonic/private-key lifetime and zeroization remain host-owned
acceptance for S1-06. S1-03 must not add host derivation merely to satisfy that
later integration requirement.

Out of scope:

- signing;
- extended public-key/watch-only account policy;
- MPC/TSS;
- THORName/TNS;
- validator/operator/module addresses;
- ed25519 account support.

## Board-approved platform and verification correction

The package is iOS-only: `Package.swift` must declare exactly
`platforms: [.iOS(.v13)]`. The macOS hosted runner is only the environment
that supplies Xcode and an iOS Simulator; macOS is not a supported package
platform and must be removed from the inherited S1-01 package-topology
acceptance surface. The iOS 13 library floor and iOS 14+ SwiftUI Example floor
are unchanged.

Product package compilation and tests must run through the proven simulator
command, never host SwiftPM acceptance commands:

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

The narrow derivation and codec gates add the corresponding
`-only-testing:ThorChainKitTests/DerivationTests` and
`-only-testing:ThorChainKitTests/AddressCodecTests` selectors; the full command
is the package regression gate. `swift package dump-package` and dependency
resolution inspection remain static checks, but `swift build` and `swift test`
are not product acceptance commands. The inherited S1-01/S1-02 policy and
S1-03 verifier must enforce this command boundary.

Each narrow/full result is inspected by `xcrun xcresulttool get test-results
summary --path "$RESULT_BUNDLE_PATH" --compact` and
`xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE_PATH"
--compact`. The repository verifiers `Scripts/verify-s1-01.sh`,
`Scripts/verify-s1-02.sh`, and `Scripts/verify-s1-03.sh` parse those JSON
documents and fail closed unless the selected test names and count match the
allowlist, `totalTestCount`/`passedTests` match, `failedTests` and
`skippedTests` are zero, every test node has result `Passed`, and the summary
result is `Passed`. `Scripts/test-s1-01-mutants.sh` uses the same parser for
each base/mutant result and requires the guarded mutant result to be
`Failed`, so a missing, empty, skipped, or partially parsed xcresult never
receives test credit.

The exact-head operator proof reached the iOS package and exposed one direct
implementation defect: `CosmosAccountAddressDeriver` is declared both at
`Sources/ThorChainKit/Crypto/AccountAddressFactory.swift:3` and
`Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift:17`. The
approved ownership is one declaration in `CosmosAccountAddressDeriver.swift`;
`AccountAddressFactory.swift` owns only factory/composition code. The verifier
must fail closed if this ownership split is duplicated.

### Inherited host-gate closure

The iOS-only correction must account for every package acceptance path in the
current tree, not only the headline CI and S1-03 commands:

| Path | Existing product-gate surface | Revision-7 contract |
|---|---|---|
| `.github/workflows/ci.yml` and `Scripts/verify-s1-02-ci-policy.sh` | Host `swift build`, strict `swift build`, and `swift test` | Exact selected-simulator `xcodebuild` package test block; policy matcher requires the same block |
| `Scripts/verify-s1-03.sh` | Two filtered host tests plus full host test | Simulator `xcodebuild` with `-only-testing` selectors plus full test |
| `Scripts/verify-s1-01.sh` | Host symbolgraph build/extraction, host test discovery, PublicApi xUnit execution, strict build, and skip canary | iOS Simulator/Xcode build and symbolgraph extraction; xcresult-based discovery, execution, strict-concurrency, and skip-canary assertions |
| `Scripts/verify-s1-02.sh` | Host test discovery, symbolgraph build/extraction, strict build, and three filtered tests | iOS Simulator/Xcode/xcresult equivalents, with the existing iOS public-consumer check retained |
| `Scripts/test-s1-01-mutants.sh` | Base and mutant `swift test --package-path` calls | The same exact simulator Xcode helper for base and mutant packages; mutant failure is read from xcresult |
| `Scripts/verify-bigint-floor.sh` | Host strict build/test of a copied package | iOS Simulator Xcode build/test of the copy, with the resolved lock hash check retained |

The remaining `xcrun swift` calls in `Scripts/run-maestro.sh`,
`Scripts/test-run-maestro.sh`, `Scripts/verify-s1-01-factory.swift`, and
`Scripts/verify-s1-02-live-evidence.swift` are standalone host scanner/evidence
tools. They do not resolve `Package.swift`, compile a ThorChainKit target, or
receive product test credit, so they are explicitly retained and must be
covered by a non-package-tooling assertion rather than converted to a package
test.

CI must select an available pinned iOS runtime, export
`THORCHAIN_SIMULATOR_UDID`, and pass
`platform=iOS Simulator,id=${THORCHAIN_SIMULATOR_UDID}` to every package gate.
The committed workflow and verifiers must contain no operator-local UDID and
must fail closed for a missing selection, literal UDID, destination without the
selected id, or any remaining host SwiftPM package-gate command.

## Files

```text
Sources/ThorChainKit/Crypto/DerivationPath.swift
Sources/ThorChainKit/Crypto/AccountAddressDeriving.swift
Sources/ThorChainKit/Crypto/AccountAddressFactory.swift
Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift
Sources/ThorChainKit/Crypto/Secp256k1PublicKeyValidator.swift
Sources/ThorChainKit/Address/AddressCodec.swift
Tests/ThorChainKitTests/DerivationTests.swift
Tests/ThorChainKitTests/AddressCodecTests.swift
Tests/ThorChainKitTests/Fixtures/AddressVectors.json
iOS Example/Sources/Presentation/AddressViewModel.swift
iOS Example/Sources/Views/AddressView.swift
iOS Example/Sources/ThorChainExampleApp.swift
.maestro/flows/02-address-codec.yaml
.maestro/S1-03-analog-manifest.txt
Scripts/verify-s1-03.sh
Scripts/test-s1-03-mutants.sh
Scripts/verify-s1-01.sh
Scripts/verify-s1-02.sh
Scripts/test-s1-01-mutants.sh
Scripts/verify-bigint-floor.sh
docs/specs/sprint-01-foundation/S1-01-package-public-api.md
Tests/ThorChainKitTests/Fixtures/S1-03-public-symbols.txt
Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt
Tests/ThorChainKitTests/Fixtures/S1-03-dependency-revisions.txt
Tests/ThorChainKitTests/Fixtures/S1-03-capability-closure.txt
Tests/ThorChainKitTests/Fixtures/S1-03-fuzz-seed.txt
.maestro/config.yaml
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
Scripts/scan-s1-01-artifacts.swift
iOS Example/iOS Example.xcodeproj/project.pbxproj
.github/workflows/ci.yml
Scripts/verify-s1-02-ci-policy.sh
```

## API and Ownership

```swift
public struct DerivationPath: Hashable, Sendable {
    public static let defaultAccount: DerivationPath
    public init(_ raw: String) throws
    public var rawValue: String { get }
}

public enum DerivationPathError: Error, Equatable {
    case invalidComponentCount
    case invalidPurpose
    case invalidCoinType
    case invalidAccount
    case invalidChain
    case invalidIndex
    case malformedComponent
}

protocol AccountAddressDeriving: Sendable {
    func address(
        compressedPublicKey: Data,
        network: Network
    ) throws -> Address
}

public enum AccountAddressFactory {
    public static func address(
        compressedPublicKey: Data,
        network: Network
    ) throws -> Address
}

public struct AddressCodec: Sendable {
    public init()
    public func encode(payload: Data, network: Network) throws -> Address
    public func decode(_ string: String, network: Network) throws -> Address
}
```

`DerivationPath.defaultAccount` is the exact non-trapping value contract for
the later host integration. Its construction must not use `try!`, force
unwraps, `fatalError`, or preconditions; a private validated literal
initializer is permitted. The representation is the immutable exact
`rawValue` string. `init(_:)` accepts only five slash-separated components:
`m/44'/931'/<account>'/<chain>/<index>`, with hardened purpose/coin/account,
decimal non-negative account/chain/index components, no whitespace, and no
leading-zero aliases. It throws the specific `DerivationPathError` case for
the first invalid component and never normalizes an alternate path. S1-03
does not derive a private key and the public factory does not accept a path.

The operational consumer is the later host adapter
`AccountAddress.thorChainAddress(account:)`: it passes
`DerivationPath.defaultAccount.rawValue` to the pinned HdWalletKit
`privateKey(path:)` contract, converts that key to a secp256k1 public key, and
passes only the resulting compressed public key to the kit. The S1-03 contract
test asserts the exact raw value and the host call shape below; the host adapter
must not independently construct a path from account, chain, index, or coin
type literals.

`AddressCodec.decode` delegates directly to the fail-closed
`Address.init(_:, network:)` delivered in S1-01. S1-03 adds the public
payload-to-address encoder plus derivation; it does not add a second parser,
unchecked initializer, alternate network-binding rule, or Boolean validation
wrapper. Callers that need diagnostics use the typed throwing initializer;
there is no `AddressCodec.isValid` surface that erases the inherited error.

`AccountAddressDeriving` remains an internal DI seam. The only public derivation boundary is `AccountAddressFactory.address(compressedPublicKey:network:)`; the parameter name is exactly `compressedPublicKey` everywhere so the caller cannot assume support for the uncompressed form.

Mnemonic/seed and HdWalletKit remain in the WalletCore account layer; `Kit.instance` receives an already constructed `Address`. ThorChainKit adds HsCryptoKit `1.3.2` for HASH160 primitives and a direct dependency on the `secp256k1` product from `secp256k1.swift` `0.10.0`. The direct dependency is mandatory: a Swift module cannot be imported as an accidental transitive dependency of HsCryptoKit. HdWalletKit does not become a kit dependency. This makes the read-only kit suitable for future watch-only support without changing the sync layer.

S1-03 changes `Package.swift` and removes its macOS platform declaration:

```swift
platforms: [.iOS(.v13)]

.package(
    url: "https://github.com/horizontalsystems/HsCryptoKit.Swift.git",
    exact: "1.3.2"
),
.package(
    url: "https://github.com/GigaBitcoin/secp256k1.swift.git",
    exact: "0.10.0"
)

.product(name: "HsCryptoKit", package: "HsCryptoKit.Swift"),
.product(name: "secp256k1", package: "secp256k1.swift")
```

`Tests/ThorChainKitTests/Fixtures/S1-03-dependency-revisions.txt` is a complete
two-section lock contract. The `inherited-s1-01` section is immutable baseline
state and the `s1-03-closure` section is the exact direct-plus-transitive
addition set. The fixture contains exactly these five rows:

```text
# inherited-s1-01
bigint|https://github.com/attaswift/BigInt.git|5.7.0|e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe

# s1-03-closure
hscryptokit.swift|https://github.com/horizontalsystems/HsCryptoKit.Swift.git|1.3.2|7c11ad0e690cbb178a70f3b9d1116d0a37a51a41
hsextensions.swift|https://github.com/horizontalsystems/HsExtensions.Swift.git|1.0.6|0012014f98ae81ffb89b0d3a2e9c204559e1c278
secp256k1.swift|https://github.com/GigaBitcoin/secp256k1.swift.git|0.10.0|48fb20fce4ca3aad89180448a127d5bc16f0e44c
swift-crypto|https://github.com/apple/swift-crypto.git|2.6.0|60f13f60c4d093691934dc6cfdf5f508ada1f894
```

The implementation verifier parses the expected-base `Package.resolved` from
Git and requires the
`inherited-s1-01` section to equal that immutable baseline. It then compares the
current `Package.resolved` pin set, including every transitive pin, to the exact
union of both sections by identity, URL, version, and revision; missing, extra,
reordered-section, or duplicate rows fail. The verifier also contains the
literal S1-03 closure rows above, so changing the fixture and lockfile together
cannot move a dependency. Any new direct or transitive package requires a new
spec revision.

In S1-06, private derivation is performed in `AccountAddress.thorChainAddress(account:)` through the existing HdWalletKit, after which the compressed public key is passed to `ThorChainKit`.

## Inherited `Address` Invariants and S1-03 Additions

S1-01 already owns non-empty/whitespace, case, classic checksum, exact HRP, strict padding, 20-byte payload, canonical re-encode, and stored-network validation. S1-03 preserves those rules and adds:

- the public encoder always returns the same canonical lowercase representation accepted by S1-01;
- the compressed public key is exactly 33 bytes and has prefix `0x02` or `0x03`;
- `secp256k1_ec_pubkey_parse` successfully parses the entire input: length and prefix are insufficient because the x-coordinate may not represent a point on the curve.

`thor`, `sthor`, `cthor`, and `tthor` are recognized by the protocol source, but public `Network` determines which HRP is permitted. The mainnet parser does not accept other HRPs.

## Errors

```swift
public enum AccountAddressError: Error, Equatable {
    case invalidCompressedPublicKeyLength(Int)
    case invalidCompressedPublicKeyPrefix(UInt8)
    case invalidSecp256k1Point
    case secp256k1ContextUnavailable
}
```

S1-01's `AddressError` remains the public codec/validation error surface.
`AccountAddressError` is limited to S1-03 public-key validation and parser
setup. No `return ""`, `try?`, `Bool isDerived`, or string-only errors.
`Secp256k1PublicKeyValidator` parses the entire input through secp256k1 C
APIs; it does not accept a key merely because its length looks correct.

The implementation must not rely on a dependency static context accessor that
can trap during initialization. It must create or obtain the secp256k1 parser
context through a failure-reporting API and map unavailable context/parser
setup to `.secp256k1ContextUnavailable`; no `try!`, force unwrap, `fatalError`,
or precondition may be reachable from `AccountAddressFactory.address`.
The internal `Secp256k1ContextProviding` seam has a production provider and a
deterministic failure provider used by tests; the latter must prove the typed
error without global state, environment dependence, or process termination.

The factory has no default `network` argument. Callers must select an explicit
`Network`, so S1-03 cannot introduce a hidden evaluation of the inherited
S1-01 `Network.mainnet` `try!` during default-argument evaluation. The S1-03
verifier records the inherited S1-01 initializer as a baseline dependency and
fails if S1-03 adds any new static initialization or trap path.

## Secret-Handling Rules

- Public `Kit` neither accepts nor stores a mnemonic, seed, or private key.
- No S1-03 library source accepts or stores a mnemonic, seed, or private key;
  no S1-03 source imports HdWalletKit or WalletCore.
- The complete executable closure of `AccountAddressFactory` and
  `AddressCodec` is audited for allowed imports/callees and rejects logging,
  I/O, tasks, static key retention, UI imports, and bypasses of `Address.init`.
- Host-side temporary-key lifetime and zeroization are specified and tested in
  S1-06, not implemented in this kit slice.
- Derivation/public-key errors are never replaced with an empty string,
  `try?`, or a fallback path.

## Analog Delta

| Source (pinned commit) | Repository URL | Path and role | Use | Do not use |
|---|---|---|---|---|
| HdWalletKit `163b4e253aa763babeb6d14f246e1d81cfa0473e` | `https://github.com/horizontalsystems/HdWalletKit.Swift.git` | `Sources/HdWalletKit/HDWallet.swift:4-49`, `HDKeychain.swift:37-59`; primary host path/lifecycle analog | host-side purpose/coin/path derivation contract | dependency or wallet object inside ThorChainKit |
| HsCryptoKit `7c11ad0e690cbb178a70f3b9d1116d0a37a51a41` | `https://github.com/horizontalsystems/HsCryptoKit.Swift.git` | `Sources/HsCryptoKit/Crypto.swift:72-107,194-209`; crypto/hash support | SHA256/RIPEMD160 and public-key support | private-key convenience ownership or signing |
| BitcoinCore `5b49f424f495904cf06519b1a7b861ef37b45b50` | `https://github.com/horizontalsystems/BitcoinCore.Swift.git` | `Sources/BitcoinCore/Classes/SegWit/Bech32.swift:14-147,188-205`; checksum counter-reference | classic polymod/checksum/charset reference | SegWit witness version/program rules |
| Vultisig iOS `d3123dbe6ef1103937c272a8b1cd81f613af0acc` | `https://github.com/vultisig/vultisig-ios.git` | `VultisigApp/VultisigAppTests/Chains/PublicKeyTest.swift:11-19`; THOR-specific public vector support | path/public-key vector support | WalletCore opaque derivation, TSS helper, duplicate validators |

The committed analog manifest must reproduce these repository URLs, commits,
paths, and roles. A changed analog commit is a design revision, not an
implementation detail.

## Vector Policy

At least three independent sources:

1. Vultisig pinned public-key fixture for `m/44'/931'/0'/0/0`.
2. HsCryptoKit and BitcoinCore pinned implementations for independent
   HASH160/classic-Bech32 calculation.
3. The THOR address oracle in the pinned Vultisig public test data, kept
   separate from the implementation-generated result.

A vector generated only by the implementation under test is not permitted.

The first bound vector is not a placeholder:

| Field | Value |
|---|---|
| `path` | `m/44'/931'/0'/0/0` |
| `compressedPublicKeyHex` | `02a9ac9f7a97da41559e1684011b6a9b0b9c0445297d5f51dea0897fd4a39c31c7` |
| `sha256Hex` | `3cc06d8afebb6ba8310671a54c5c616b7b6c87e0dcdccf2a5bf33356e6a59a49` |
| `payloadHex` | `5a0dba49dab8fec87c6dd7c01b564ee72a8515a6` |
| `mainnetAddress` | `thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean` |
| `stagenetAddress` | `sthor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxsjl0td` |
| `chainnetAddress` | `cthor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxgmq2h0` |

Its primary provenance is Vultisig commit
`d3123dbe6ef1103937c272a8b1cd81f613af0acc`,
`VultisigApp/VultisigAppTests/Chains/PublicKeyTest.swift:11-19`, where the
public compressed key is asserted for the exact path. The THOR address oracle
is independently present at that checkout in
`VultisigApp/VultisigAppTests/TestData/thorchain.json`; the implementation PR
must record the exact matching line and digest. HsCryptoKit commit
`7c11ad0e690cbb178a70f3b9d1116d0a37a51a41` at
`Sources/HsCryptoKit/Crypto.swift:194-209` supplies the independent
`ripeMd160Sha256` calculation, and BitcoinCore commit
`5b49f424f495904cf06519b1a7b861ef37b45b50` at
`Sources/BitcoinCore/Classes/SegWit/Bech32.swift:14-147,188-205` supplies the independent
classic checksum calculation. Their exact commands and output digest must be
recorded in the fixture; a missing command, digest, or source identity is a
hard failure.

`AddressVectors.json` schema (the schema itself is not a fixture and contains
no placeholder vector values):

```json
{
  "sources": [{
    "role": "string",
    "repository": "url",
    "commit": "40-hex revision",
    "path": "repository-relative path and line",
    "tool": "string",
    "version": "string",
    "command": "exact shell command",
    "inputOrigin": "public input description",
    "outputDigest": "64-hex SHA256"
  }],
  "path": "m/44'/931'/0'/0/0",
  "compressedPublicKeyHex": "...",
  "sha256Hex": "...",
  "payloadHex": "...",
  "mainnetAddress": "thor1...",
  "stagenetAddress": "sthor1...",
  "chainnetAddress": "cthor1..."
}
```

Fixtures contain no mnemonic, seed, private key, credentials, or host-local
path. Every expected field records immutable provenance (repository URL and
commit or tag, path, tool/version, invocation, input origin, and digest).
At least two algorithmically independent implementations must agree on the
compressed-key → SHA256 → RIPEMD160 → classic-Bech32 result; the independent
THORNode payload/address vector remains a separate oracle.

For the bound vector, the canonical output digest is
`c198c6f92f12029403394759ee6fde166758a9e1916da333ef84f4e685966b10`, the
SHA256 of the pipe-delimited compressed key, hash, payload, and three network
addresses shown above. The fixture test must recompute and compare this digest
before accepting any vector.

## Tests Before Implementation

`DerivationTests.swift` in ThorChainKit and the corresponding host test in S1-06:

- default path/coin type are exact;
- public key matches an independent vector;
- the same public key produces the same 20-byte payload for all networks;
- a different HRP changes the string, not the payload;
- invalid public-key/path input returns a typed error;
- repeated calls do not retain public-key input through observable public state;
- host HdWalletKit derivation remains an S1-06-only integration check and is
  not implemented or fixture-backed by this kit slice;
- a public key with a prefix other than `0x02/0x03` is rejected before hashing;
- a 33-byte compressed form with an x-coordinate outside secp256k1 is rejected by a real parser;
- parser context setup failure maps to `.secp256k1ContextUnavailable` without a trap;
- no `try!`, force unwrap, `fatalError`, or precondition is reachable from the public factory;
- the production context provider and injected failure provider both execute
  deterministically, with no environment or global-state switch;
- isolated SHA256 and HASH160 known-answer values match independent provenance;
- non-20-byte public encoder payloads fail before bit conversion with
  `AddressError.invalidPayloadLength`;
- a valid classic-Bech32 `tthor` oracle is rejected by `.mainnet` with the
  exact wrong-HRP error, without adding public mocknet support.

`AddressCodecTests.swift`:

- encode/decode mainnet round trip;
- valid uppercase input is canonicalized to lowercase;
- S1-01 negative vectors are rerun through the public `AddressCodec.decode` wrapper to prove there is no divergent parser;
- BIP173 generic valid/invalid checksum vectors;
- fuzz/property: random 20-byte payload `decode(encode(x)) == x`;
- the parser never crashes on arbitrary UTF-8 strings;
- deterministic fuzz replay uses the committed seed/count in
  `S1-03-fuzz-seed.txt` and records the first failing input; it does not use
  wall-clock randomness or an unrecorded random seed;
- direct 8→5 padding known-answer tests and strict residual-bit rejection;
- malformed payload lengths (0, 19, 21, and bounded large input) fail closed;
- the exact S1-03 test-discovery baseline, cumulative public-symbol subset,
  package/import/source closure, resolved dependency revisions, and public-only
  iOS 13 consumer are enforced by `Scripts/verify-s1-03.sh`.

`S1-03-fuzz-seed.txt` is an exact four-line UTF-8 fixture, not a descriptive
placeholder:

```text
version=1
algorithm=splitmix64
seed=0x534c30332d46555a
count=1024
```

The replay is canonical and byte-exact: initialize one unsigned 64-bit
`state` to `seed`; for each case in order, advance the state exactly three
times by `0x9E3779B97F4A7C15` using modulo-2⁶⁴ wrapping arithmetic (`&+`),
then apply the standard SplitMix64 mix
(`z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27))
&* 0x94D049BB133111EB; z ^= z >> 31`), and append each `z` as eight
little-endian bytes. The first 20 bytes of the resulting 24-byte buffer are
the payload; the final four bytes are discarded. Thus the corpus consumes
exactly `3 * 1024 = 3072` SplitMix64 outputs, with no case reseeding,
endianness choice, or variable truncation. The test must replay the same
sequence with the iOS Simulator package command and
`-only-testing:ThorChainKitTests/AddressCodecTests/testDeterministicFuzzReplay`.
The verifier requires the
four fields exactly once, a seed in the unsigned 64-bit range, and
`count == 1024`; any alternate generator, output count, byte order, or
payload packing fails.

### Example/Maestro Acceptance

`ThorChainExampleApp.swift` owns the existing `ExampleRuntime` instance and
passes it through the root navigation destination to `AddressView`;
`AddressViewModel` and `AddressView` accept a public compressed-key fixture or
watch-only address, but not a mnemonic/seed. They extend the SwiftUI + Combine
Example and import no UIKit. The Xcode project must contain the new files in
the existing application target's Sources build phase and group hierarchy;
`ThorChainExampleApp` must navigate from its existing root to `AddressView`
with the same `ExampleRuntime` instance, and the view model must call
`AccountAddressFactory.address(compressedPublicKey:network:)` rather than
displaying fixture text directly. The implementation PR must include a
non-`@testable` Xcode build/target-membership check and a navigation test that
fails when any of those edges is removed.

Flow `02-address-codec.yaml` verifies the full expected `thor1…`, canonical
uppercase normalization, bad checksum, mixed case, and wrong HRP. Values are
read through stable accessibility IDs; a prefix-only assertion is prohibited.
The verifier must prove each displayed result has a reachable call path
through `AddressCodec`/`AccountAddressFactory`; static-output, hard-coded-error,
prefix-only, bypass, and unreachable-fixture mutants must fail.

The S1-03 verifier directly includes the recursive platform-boundary checks,
the exact test/symbol/dependency/source closure, and the runner/manifest/CI
updates needed to make the three-flow S1-01 → S1-02 → S1-03 Maestro sequence
reachable. The implementation changes exactly
`.maestro/config.yaml`, `Scripts/run-maestro.sh`,
`Scripts/test-run-maestro.sh`, `.github/workflows/ci.yml`, and
`Scripts/verify-s1-02-ci-policy.sh` together with the S1-03 verifier. The
manifest contains exactly `00-launch-foundation.yaml`,
`01-endpoint-policy.yaml`, and `02-address-codec.yaml`; `run-maestro.sh`
accepts exactly `s1-01`, `s1-02`, and `s1-03`.

The expected CI contract is literal: the existing exact-head preflight and
pinned tool setup remain unchanged. The checkout and base-ref establishment
must be exactly these steps before package verification:

```yaml
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
  with:
    ref: ${{ inputs.expected_head_sha }}
    fetch-depth: 0
    persist-credentials: true
- name: Establish exact expected base ref
  env:
    EXPECTED_BASE_SHA: 7fd9663442a0e6dcd9c01c4ab04d35f3abd96fc4
  run: |
    set -euo pipefail
    git fetch --no-tags --prune origin "+refs/heads/main:refs/remotes/origin/main"
    test "$(git rev-parse refs/remotes/origin/main)" = "$EXPECTED_BASE_SHA"
```

The cumulative CI-policy matcher includes the checkout `fetch-depth` and
credential settings plus the literal fetch refspec and equality check; a
shallow checkout or an unverified remote-tracking ref is rejected. Then the
following two steps appear exactly once, with no additional job or flow:

```yaml
- name: Verify package and S1-03 contract
  env:
    EXPECTED_HEAD_SHA: ${{ inputs.expected_head_sha }}
  run: |
    set -euo pipefail
    Scripts/verify-s1-02-ci-policy.sh steady-state --ref "$(git rev-parse HEAD)"
    : "${THORCHAIN_SIMULATOR_UDID:?exact simulator selection missing}"
    DERIVED_DATA_PATH="${RUNNER_TEMP:-/tmp}/thorchain-s1-03-derived-data"
    RESULT_BUNDLE_PATH="${RUNNER_TEMP:-/tmp}/thorchain-s1-03.xcresult"
    xcodebuild -scheme ThorChainKit \
      -destination "platform=iOS Simulator,id=${THORCHAIN_SIMULATOR_UDID}" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -resultBundlePath "$RESULT_BUNDLE_PATH" \
      CODE_SIGNING_ALLOWED=NO test
    Scripts/verify-s1-02.sh
    Scripts/verify-s1-03.sh --expected-base 7fd9663442a0e6dcd9c01c4ab04d35f3abd96fc4 --expected-head "$EXPECTED_HEAD_SHA"
    Scripts/test-s1-03-mutants.sh
- name: Run fixture acceptance
  run: |
    set -euo pipefail
    : "${THORCHAIN_SIMULATOR_UDID:?exact simulator selection missing}"
    export THORCHAIN_SIMULATOR_UDID
    Scripts/run-maestro.sh s1-01
    Scripts/run-maestro.sh s1-02
    Scripts/run-maestro.sh s1-03
```

`Scripts/verify-s1-02-ci-policy.sh` must compare that complete expected block
and reject omission, reordering, or an additional job/flow.

`Scripts/test-s1-03-mutants.sh` is the named executable fail-closed harness.
Its command is run from the repository root and must mutate each of
`ThorChainExampleApp` navigation, the view-model factory call, fixture output,
the displayed error, and the full-address assertion; every mutant must make
the verifier or Maestro acceptance command fail. Static-output, hard-coded
error, factory-bypass, prefix-only, and unreachable-fixture mutants are never
accepted as test substitutes.

Its local recipe requires literal `--expected-base` and `--expected-head`
arguments, checks `git rev-parse HEAD`, `git rev-parse
refs/remotes/origin/main`, `git status --porcelain` (empty), and the expected
base/head relationship before any test. Hosted CI must establish that exact
remote-tracking ref with the fetch step above; the verifier and cumulative
policy matcher both reject a missing or differently named ref. It records
pre/post HEAD, worktree status, command status, artifact hashes, and hosted
workflow head identity; there is no movable-HEAD fallback.

## Host Verification

The S1-06 integration fixture calls `AccountAddress.thorChainAddress(account:)` twice before/after app reconstruction and asserts an identical canonical address. It must not compare only the prefix; the full expected fixture address is required.

Host derivation is pinned to the exact current HdWalletKit contract. The raw
path is the only derivation input; `privateKey(path:)` consumes the validated
S1-03 value, so the host cannot silently drift by changing separate account,
chain, index, or coin-type literals:

```swift
let wallet = HDWallet(
    seed: seed,
    coinType: 931,
    xPrivKey: HDExtendedKeyVersion.xprv.rawValue,
    purpose: .bip44,
    curve: .secp256k1
)
let path = DerivationPath.defaultAccount.rawValue
let compressedPublicKey = try wallet
    .privateKey(path: path)
    .publicKey(curve: .secp256k1)
    .raw
```

The host test asserts `path == "m/44'/931'/0'/0/0"` and the adapter source
contains the `privateKey(path: path)` call. Changing `xPrivKey`, the validated
path, or curve is a fixture-breaking design change, not an implementation
detail; the constructor's `coinType: 931` and `purpose: .bip44` remain pinned
to the same contract but cannot override the explicit raw path.

## Slice-versioned contract gates

S1-03 adds exact public-symbol and test-discovery baselines plus
`Scripts/verify-s1-03.sh`. The verifier requires literal invocation:

```text
Scripts/verify-s1-03.sh \
  --expected-base 7fd9663442a0e6dcd9c01c4ab04d35f3abd96fc4 \
  --expected-head <immutable-pr-head>
```

It fails unless the worktree is clean, `HEAD` equals the expected head,
`origin/main` equals the expected base, and the expected base is an ancestor
of the expected head. It compares the generated public graph exactly with the
S1-03 baseline and requires every canonical declaration in both S1-01 and
S1-02 baselines to remain an unchanged subset. It also checks the exact
package/import/source closure, the committed
`S1-03-dependency-revisions.txt` SHA list against `Package.resolved`, the
non-`@testable` iOS 13 consumer, no disabling constructs, the recursive
UIKit/SwiftUI platform boundary, fixture/provenance/secret scans, the
deterministic fuzz seed, injected context-failure test, and reachable Example
call path. New codec/derivation declarations appear only in the S1-03 exact
baseline; prior removal or signature mutation fails.

The capability closure is falsifiable, not narrative: the committed
`S1-03-capability-closure.txt` allowlist names the only permitted module
imports (`ThorChainKit`, `HsCryptoKit`, `secp256k1`, Foundation/Data) and
permitted crypto/hash symbols. The verifier rejects any `HdWalletKit`,
WalletCore, Vultisig, UI, logging, I/O, task, static-key, signing, or
unlisted-callee edge in the executable closure of
`AccountAddressFactory`/`AddressCodec`, and a mutant test adds each forbidden
edge to prove the verifier fails closed.

## Acceptance Criteria

- Exact default path and coin type proven.
- Exact independent mainnet address vector passes.
- Mainnet cannot accept a stagenet/chainnet/mocknet address.
- Prefix, length, and real secp256k1 point validity are proven independently.
- The kit's public facade never owns secret material.
- The codec is a Cosmos account codec, not a SegWit codec.
- All negative/fuzz/property tests pass.
- Vultisig assertion-free tests do not count as evidence; new tests actually assert the result.

## Pinned Decision

Seed derivation remains at the host boundary. The public ThorChainKit primitive is `AccountAddressFactory.address(compressedPublicKey:network:)`; seed/private key never enter the kit's API or dependencies.
