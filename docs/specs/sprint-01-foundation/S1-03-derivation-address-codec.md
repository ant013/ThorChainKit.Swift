# S1-03 — Account Derivation and Address Codec

**Status:** synchronized to S1-01 revision 11 after revision-10 adversarial REVISE; implementation blocked pending fresh review and approval.
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
- zeroization/retention rules for temporary private material.

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
```

## API and Ownership

```swift
public struct DerivationPath: Hashable, Sendable {
    public static let defaultAccount = try! DerivationPath("m/44'/931'/0'/0/0")
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
    case derivationFailed
}
```

S1-01's `AddressError` remains the public codec/validation error surface. `AccountAddressError` is limited to S1-03 public-key derivation. No `return ""`, `try?`, `Bool isDerived`, or string-only errors. `Secp256k1PublicKeyValidator` performs C parsing through `secp256k1.Context.raw`; it does not accept a key merely because its length looks correct.

## Secret-Handling Rules

- Public `Kit` neither accepts nor stores a mnemonic, seed, or private key.
- A temporary private key is created in the smallest lexical scope of the host factory.
- Logs do not contain seed/private/public-key bytes. An address may be logged only in accordance with the app privacy policy.
- `Data` zeroization in Swift does not guarantee destruction of copies; the spec does not claim a false absolute guarantee. Where possible, use the HsCrypto/HdWallet API without additional copies and clear owned mutable buffers through `resetBytes`.
- Derivation errors are not replaced with an empty string or fallback path.

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
2. Cosmos/THORChain-compatible external implementation fixture: mnemonic → public key → address; provenance and tool version are recorded alongside the JSON.
3. Round-trip payload vector from the Cosmos Bech32 reference.

A vector generated only by the implementation under test is not permitted.

`AddressVectors.json` fields:

```json
{
  "source": "...",
  "mnemonic": "test fixture only",
  "path": "m/44'/931'/0'/0/0",
  "compressedPublicKeyHex": "...",
  "payloadHex": "...",
  "mainnetAddress": "thor1...",
  "stagenetAddress": "sthor1...",
  "chainnetAddress": "cthor1..."
}
```

The fixture mnemonic must be an explicitly public test mnemonic with no funds.

## Tests Before Implementation

`DerivationTests.swift` in ThorChainKit and the corresponding host test in S1-06:

- default path/coin type are exact;
- public key matches an independent vector;
- the same public key produces the same 20-byte payload for all networks;
- a different HRP changes the string, not the payload;
- invalid public-key/path input returns a typed error;
- repeated calls do not retain public-key input through observable public state;
- host HdWalletKit derivation from the public fixture mnemonic matches the expected compressed key;
- a public key with a prefix other than `0x02/0x03` is rejected before hashing;
- a 33-byte compressed form with an x-coordinate outside secp256k1 is rejected by a real parser.

`AddressCodecTests.swift`:

- encode/decode mainnet round trip;
- valid uppercase input is canonicalized to lowercase;
- S1-01 negative vectors are rerun through the public `AddressCodec.decode` wrapper to prove there is no divergent parser;
- BIP173 generic valid/invalid checksum vectors;
- fuzz/property: random 20-byte payload `decode(encode(x)) == x`;
- the parser never crashes on arbitrary UTF-8 strings.

### Example/Maestro Acceptance

`AddressViewModel` and `AddressView` accept a public compressed-key fixture or watch-only address, but not a mnemonic/seed. They extend the SwiftUI + Combine Example and import no UIKit. Flow `02-address-codec.yaml` verifies the full expected `thor1…`, canonical uppercase normalization, bad checksum, mixed case, and wrong HRP. Values are read through stable accessibility IDs; a prefix-only assertion is prohibited.

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

S1-03 adds `Tests/ThorChainKitTests/Fixtures/S1-03-public-symbols.txt` and `Scripts/verify-s1-03.sh`; its CI job compares the generated public graph exactly with the S1-03 baseline and requires every canonical declaration in both S1-01 and S1-02 baselines to remain an unchanged subset. New codec/derivation declarations appear only in the S1-03 exact baseline; prior removal or signature mutation fails. S1-03 repeats S1-01's exact production factory capability audit because derivation remains a separate public value operation and does not change `Kit.instance` composition.

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
