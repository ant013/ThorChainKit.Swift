# S2-02 query codec provenance

- THORNode source: `a759cb4f`.
- Cosmos SDK source: `v0.53.0`.
- `cosmossdk.io/api`: `v0.9.2`.
- SwiftProtobuf package: exact `1.33.3`.
- SwiftProtobuf source commit: `c169a5744230951031770e27e475ff6eefe51f9d` (tag `1.33.3`).
- Xcode: exact `26.3` (`17C529`).
- Apple Swift: exact `6.2.4`.
- protoc: `libprotoc 34.1`.
- protoc executable SHA-256: `59001d00d60e6ed0e6c49e2ae6591b58882cec5bf45402f937b22566be893d4e`.
- protoc-gen-swift: `1.33.3`.
- Source `cosmos/crypto/secp256k1/keys.proto` SHA-256: `d69386568e35c2c20cf367307489f9e50a2710a71552c531a20aee8d9371ba62`.
- Derived PubKey input SHA-256: `84c4f4b93a6d9526e90686d611f13e6fa5ec6675243a7b429050bdc67c9529bb`.
- Derived query-only `keys_query.proto` SHA-256: `84c4f4b93a6d9526e90686d611f13e6fa5ec6675243a7b429050bdc67c9529bb`.
- protoc plugin source checksum: `18bb412f527df413e3f0aacf20b6b8ab95ca99191b7c75a991505c6b25fd3d7a`.
- Vendored upstream input root: `Sources/ThorChainKit/Network/Generated/Query/upstream`.
- Byte-pinned upstream inputs are verified byte-for-byte; whitespace hygiene
  checks intentionally exclude this directory because source whitespace is part
  of the recorded provenance.
- Input list and SHA-256: `cosmos/auth/v1beta1/query.proto`
  (`3338b3e8fd6b22d292d4b19b231c5027cf3a95d341bcb97edc9d7dec52b46d36`),
  `cosmos/auth/v1beta1/auth.proto`
  (`1c19f884767e07819b16c41ca220ec5adc6cc931abf6984a06d30ca5ad83753e`),
  `thorchain/v1/query_network.proto`
  (`a1b26fdf0988a2dea0970328c241a16f8af648609d71e3a1eb1d0b7bc10564c5`),
  `thorchain/v1/query_mimir.proto`
  (`e1a18ca8b9a369807ae9c09e486f1ab38453073be14d2f3f8914e37542c5b334`),
  and `thorchain/v1/query_version.proto`
  (`77573a5dd17f3e3632ad60c866291a3bb74c937d098b3fabbc4e1099f4bacda8`).
  Additional exact dependencies are `cosmos/base/query/v1beta1/pagination.proto`
  (`8a878b43363c1fe2098e7b49b65fc5e5226daa13862d250848f4cf83007c8262`),
  `cosmos/query/v1/query.proto`
  (`f0251d79e920ddeb91982024859b29230cd230de180ef895c41d0767bec01d1d`),
  `types/type_mimir.proto`
  (`253e59f2d026185f813b6ebd26717ece91ec76d00fb94516e56cd725175ee496`),
  and `google/protobuf/any.proto`
  (`d7c79a05a5c7fae89f0aff26d112e0b60f082fc7fc424e8910be99c86b656260`).
  The option dependencies consumed by `--check` are also pinned:
  `cosmos_proto/cosmos.proto`
  (`9104e7bc5b757cac81ecd2874b34ad650ff06091e1b68e21ec0b0d9d5c36606b`),
  `gogoproto/gogo.proto`
  (`a2bef0fb7e233ff2f442da08b3764be6ce59cc3f2df05cd1c9a44dbb5b55c18f`),
  `amino/amino.proto`
  (`bc4cb71a5b49ce23e7b9ff8e5cd9f42efa9527c8f2d2e3861c901c7e86be202e`),
  `google/api/annotations.proto`
  (`e79ea741cb605a65e78ca322174764a4af9fde1962c1631e12b84c4934ba9a6c`),
  and `google/api/http.proto`
  (`ead99129aa15dd5f6233942030c72eec33bc0d7b1c7c260dc143293ef66c5b78`).
  The Cosmos bank, coin, vesting, secp256k1, descriptor, and protobuf option
  inputs checked by the reproducible command below are also byte-identical to
  the pinned SDK graph:
  `cosmos/bank/v1beta1/query.proto`
  (`c7bec81be1cb37cafe0e53187386e0cea66d3074ce3a33cba18209b17f71abfc`),
  `cosmos/bank/v1beta1/bank.proto`
  (`d36d05d8ae2e5b39dd0a182f9ad8599e712060100cb6f700cf7e28487bdd3dee`),
  `cosmos/base/v1beta1/coin.proto`
  (`408b074f81f3dafb440cd61921bf244eab2ff20cb1f2a9f247265d031481c9ec`),
  `cosmos/vesting/v1beta1/vesting.proto`
  (`73a10cc39e3f043acc7557ed5f754e80251df6548ec4e19025adfffbbef8bdf7`),
  `cosmos/crypto/secp256k1/keys.proto`
  (`d69386568e35c2c20cf367307489f9e50a2710a71552c531a20aee8d9371ba62`),
  `cosmos/msg/v1/msg.proto`
  (`4100c0021a143b5a273964f2472523d8e61fe28acaccade898f05becc3af8f31`),
  and `google/protobuf/descriptor.proto`
  (`32f3df357257f556b311c7e4ad33625a7aa13de541cb53a29ae85ac746c11a07`).
  These are the complete query-only source and dependency inputs checked by the
  reproducible command below.
  The full secp256k1 source is a byte-pinned transformation input only; it is
  not compiled. The compiled/generated graph is restricted to the derived
  PubKey-only projection below.
- Generated output: `Auth.pb.swift`, `Query.pb.swift`, `Bank.pb.swift`, `BankQuery.pb.swift`,
  `Coin.pb.swift`, `Secp256k1.pb.swift`, `Vesting.pb.swift`, `Pagination.pb.swift`,
  `QueryExtensions.pb.swift`, `ThorQueryNetwork.pb.swift`,
  `ThorQueryMimir.pb.swift`, `ThorQueryVersion.pb.swift`, and
  `ThorTypeMimir.pb.swift`. `Google_Protobuf_Any` is supplied by the pinned
  SwiftProtobuf runtime and is not regenerated as a transaction codec.
- Generation command:

  ```text
  tmp=$(mktemp -d)
  mkdir -p "$tmp/cosmos/crypto/secp256k1"
  # Emit only PubKey from the pinned source keys.proto; the resulting input
  # hash must equal the derived-query hash recorded above.
  awk 'BEGIN { emitting=0; found=0 } /^message PubKey[[:space:]]*\{/ { emitting=1; found++ } emitting { print } emitting && /^\}/ { exit } END { if (found != 1) exit 1 }' \
    Sources/ThorChainKit/Network/Generated/Query/upstream/cosmos/crypto/secp256k1/keys.proto \
    > "$tmp/cosmos/crypto/secp256k1/keys_query.proto"
  shasum -a 256 "$tmp/cosmos/crypto/secp256k1/keys_query.proto"
  plugin_dir=$(swift build --package-path .build/checkouts/swift-protobuf --show-bin-path)
  plugin="$plugin_dir/protoc-gen-swift"
  protoc --plugin=protoc-gen-swift="$plugin" \
    --proto_path=Sources/ThorChainKit/Network/Generated/Query/upstream \
    --proto_path="$tmp" \
    --swift_out="$tmp" \
    cosmos/auth/v1beta1/auth.proto cosmos/auth/v1beta1/query.proto \
    cosmos/bank/v1beta1/bank.proto cosmos/bank/v1beta1/query.proto \
    cosmos/base/v1beta1/coin.proto \
    cosmos/base/query/v1beta1/pagination.proto cosmos/crypto/secp256k1/keys_query.proto \
    cosmos/query/v1/query.proto cosmos/vesting/v1beta1/vesting.proto \
    thorchain/v1/query_network.proto thorchain/v1/query_mimir.proto \
    thorchain/v1/query_version.proto types/type_mimir.proto
  cmp Sources/ThorChainKit/Network/Generated/Query/Query.pb.swift "$tmp/cosmos/auth/v1beta1/query.pb.swift"
  cmp Sources/ThorChainKit/Network/Generated/Query/Auth.pb.swift "$tmp/cosmos/auth/v1beta1/auth.pb.swift"
  rm -rf "$tmp"
  ```

The input definitions are the pinned Cosmos SDK `v0.53.0` Query/Account,
bank spendable, vesting, coin, and secp256k1 query types plus the THORNode
query messages and their exact option/dependency graph. The generated set is
query-only.
The full pinned secp256k1 `keys.proto` is vendored only as a byte-pinned
transformation input and is not compiled. It is deterministically reduced to
the query-only `keys_query.proto` before SwiftProtobuf generation; only the
derived file is a direct protoc input, so the compiled/generated graph is
PubKey-only. `google/protobuf/any.proto` is transitive runtime/dependency input,
not a direct protoc input. The reduction hash above is checked by `--check`,
and generated output is rejected if it contains `PrivKey`.
Transaction/signing messages (`MsgSend`,
`TxBody`, `AuthInfo`, `SignDoc`, `TxRaw`) are deliberately excluded and belong
to S2-03.
