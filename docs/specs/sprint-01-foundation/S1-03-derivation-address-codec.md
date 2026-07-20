# S1-03 — Account Derivation and Address Codec

**Status:** revision 2 after discovery-1 adversarial REVISE; implementation blocked pending fresh review and approval.
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
.maestro/flows/02-address-codec.yaml
Scripts/verify-s1-03.sh
Tests/ThorChainKitTests/Fixtures/S1-03-public-symbols.txt
Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt
.maestro/config.yaml
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
Scripts/scan-s1-01-artifacts.swift
.github/workflows/ci.yml
Scripts/verify-s1-02-ci-policy.sh
```

## API and Ownership

```swift
public struct DerivationPath: Hashable, Sendable {
    public static let defaultAccount: DerivationPath
    public init(_ raw: String) throws
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
        network: Network = .mainnet
    ) throws -> Address
}

public struct AddressCodec: Sendable {
    public init()
    public func encode(payload: Data, network: Network) throws -> Address
    public func decode(_ string: String, network: Network) throws -> Address
    public func isValid(_ string: String, network: Network) -> Bool
}
```

`DerivationPath.defaultAccount` is the exact non-trapping value contract for
the later host integration. Its construction must not use `try!`, force
unwraps, `fatalError`, or preconditions; a private validated literal
initializer is permitted. S1-03 does not derive a private key and the public
factory does not accept a path.

`AddressCodec.decode` delegates to the fail-closed `Address.init(_:, network:)` delivered in S1-01. S1-03 adds the public payload-to-address encoder plus derivation; it does not add a second parser, unchecked initializer, or alternate network-binding rule.

`AccountAddressDeriving` remains an internal DI seam. The only public derivation boundary is `AccountAddressFactory.address(compressedPublicKey:network:)`; the parameter name is exactly `compressedPublicKey` everywhere so the caller cannot assume support for the uncompressed form.

Mnemonic/seed and HdWalletKit remain in the WalletCore account layer; `Kit.instance` receives an already constructed `Address`. ThorChainKit adds HsCryptoKit `1.3.2` for HASH160 primitives and a direct dependency on the `secp256k1` product from `secp256k1.swift` `0.10.0`. The direct dependency is mandatory: a Swift module cannot be imported as an accidental transitive dependency of HsCryptoKit. HdWalletKit does not become a kit dependency. This makes the read-only kit suitable for future watch-only support without changing the sync layer.

S1-03 changes `Package.swift`:

```swift
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

| Source | Use | Do not use |
|---|---|---|
| HdWalletKit | host-side purpose/coin/path derivation contract | dependency or wallet object inside ThorChainKit |
| HsCryptoKit | compressed secp256k1 public key, SHA256/RIPEMD160 | recovery-signature assumptions |
| BitcoinCore `Bech32` | polymod/checksum/charset reference | SegWit witness version/program rules |
| Vultisig | path/HRP vectors | WalletCore opaque derivation, TSS helper, duplicate validators |

## Vector Policy

At least three independent sources:

1. Vultisig pinned public-key fixture for `m/44'/931'/0'/0/0`.
2. Cosmos/THORChain-compatible external implementation fixture: public key → address; provenance and tool version are recorded alongside the JSON.
3. Round-trip payload vector from the Cosmos Bech32 reference.

A vector generated only by the implementation under test is not permitted.

`AddressVectors.json` fields:

```json
{
  "source": {
    "repository": "...",
    "commit": "...",
    "path": "...",
    "tool": "...",
    "version": "...",
    "command": "...",
    "digest": "..."
  },
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
- direct 8→5 padding known-answer tests and strict residual-bit rejection;
- malformed payload lengths (0, 19, 21, and bounded large input) fail closed;
- the exact S1-03 test-discovery baseline, cumulative public-symbol subset,
  package/import/source closure, resolved dependency revisions, and public-only
  iOS 13 consumer are enforced by `Scripts/verify-s1-03.sh`.

### Example/Maestro Acceptance

`AddressViewModel` and `AddressView` accept a public compressed-key fixture or watch-only address, but not a mnemonic/seed. They extend the SwiftUI + Combine Example and import no UIKit. Flow `02-address-codec.yaml` verifies the full expected `thor1…`, canonical uppercase normalization, bad checksum, mixed case, and wrong HRP. Values are read through stable accessibility IDs; a prefix-only assertion is prohibited. The verifier must prove each displayed result has a reachable call path through `AddressCodec`/`AccountAddressFactory`; static-output, hard-coded-error, prefix-only, bypass, and unreachable-fixture mutants must fail.

The S1-03 verifier directly includes the recursive platform-boundary checks,
the exact test/symbol/dependency/source closure, and the runner/manifest/CI
updates needed to make the single S1-03 Maestro flow reachable while retaining
the exact S1-01 and S1-02 flow selections. Its local recipe binds every
transcript to `$(git rev-parse HEAD)` and records pre/post HEAD, worktree
status, command status, artifact hashes, and hosted workflow head identity.

## Host Verification

The S1-06 integration fixture calls `AccountAddress.thorChainAddress(account:)` twice before/after app reconstruction and asserts an identical canonical address. It must not compare only the prefix; the full expected fixture address is required.

Host derivation is pinned to the exact current HdWalletKit contract:

```swift
let wallet = HDWallet(
    seed: seed,
    coinType: 931,
    xPrivKey: HDExtendedKeyVersion.xprv.rawValue,
    purpose: .bip44,
    curve: .secp256k1
)
let compressedPublicKey = try wallet
    .publicKey(account: 0, index: 0, chain: .external)
    .raw
```

Changing `xPrivKey`, account, index, chain, or curve is a fixture-breaking design change, not an implementation detail.

## Slice-versioned contract gates

S1-03 adds exact public-symbol and test-discovery baselines plus
`Scripts/verify-s1-03.sh`. The verifier compares the generated public graph
exactly with the S1-03 baseline and requires every canonical declaration in
both S1-01 and S1-02 baselines to remain an unchanged subset. It also checks
the exact package/import/source closure, resolved dependency revisions, the
non-`@testable` iOS 13 consumer, no disabling constructs, the recursive
UIKit/SwiftUI platform boundary, fixture/provenance/secret scans, and the
reachable Example call path. New codec/derivation declarations appear only in
the S1-03 exact baseline; prior removal or signature mutation fails.

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
