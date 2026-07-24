# S2-03 transaction codec provenance

## Pinned sources and toolchain

- THORNode commit `a759cb4f` (`proto/thorchain/v1/types/msg_send.proto`), source
  SHA-256 `3396f77b196748d187206dc4235eec9112bd9a914e84ca7ee4d466078a4ceff8`.
- Cosmos SDK `v0.53.0`; `cosmossdk.io/api v0.9.2`.
- Transaction inputs:
  - `cosmos/tx/signing/v1beta1/signing.proto`:
    `744c8e2ed515a064abe34a9fe2ec23556dd8d52776e52cc8dbaed89999b7805a`.
  - `cosmos/tx/v1beta1/tx.proto`:
    `47cc8faa152137126a9fc7d30d0d146eb3500704990a0d6d6e6e9a3f2fd2523f`.
  - `thorchain/v1/types/msg_send.proto`:
    `3396f77b196748d187206dc4235eec9112bd9a914e84ca7ee4d466078a4ceff8`.
- Required dependency inputs are the pinned query-kit files under
  `Sources/ThorChainKit/Network/Generated/Query/upstream`:
  - `cosmos/base/v1beta1/coin.proto`:
    `408b074f81f3dafb440cd61921bf244eab2ff20cb1f2a9f247265d031481c9ec`.
  - `google/protobuf/any.proto`:
    `d7c79a05a5c7fae89f0aff26d112e0b60f082fc7fc424e8910be99c86b656260`.
  - `gogoproto/gogo.proto`:
    `a2bef0fb7e233ff2f442da08b3764be6ce59cc3f2df05cd1c9a44dbb5b55c18f`.
  - `amino/amino.proto`:
    `bc4cb71a5b49ce23e7b9ff8e5cd9f42efa9527c8f2d2e3861c901c7e86be202e`.
- SwiftProtobuf exact `1.33.3`, source commit
  `c169a5744230951031770e27e475ff6eefe51f9d`.
- Xcode exact `26.3` (`17C529`), Apple Swift exact `6.2.4`, and `libprotoc 34.1`.
- protoc executable SHA-256:
  `59001d00d60e6ed0e6c49e2ae6591b58882cec5bf45402f937b22566be893d4e`.
- protoc-gen-swift `1.33.3` source checksum:
  `18bb412f527df413e3f0aacf20b6b8ab95ca99191b7c75a991505c6b25fd3d7a`.

## Generation binding

The generator reads only these include roots:

- `Sources/ThorChainKit/Protocol/Generated/upstream`
- `Sources/ThorChainKit/Network/Generated/Query/upstream`

The complete regeneration command is:

```text
tmp=$(mktemp -d)
swift build --package-path .build/checkouts/swift-protobuf --product protoc-gen-swift
plugin_dir=$(swift build --package-path .build/checkouts/swift-protobuf --show-bin-path)
plugin="$plugin_dir/protoc-gen-swift"
protoc --plugin=protoc-gen-swift="$plugin" \
  --proto_path=Sources/ThorChainKit/Protocol/Generated/upstream \
  --proto_path=Sources/ThorChainKit/Network/Generated/Query/upstream \
  --swift_out="$tmp" \
  cosmos/tx/signing/v1beta1/signing.proto \
  cosmos/tx/v1beta1/tx.proto \
  thorchain/v1/types/msg_send.proto
cmp "$tmp/cosmos/tx/signing/v1beta1/signing.pb.swift" Sources/ThorChainKit/Protocol/Generated/Signing.pb.swift
cmp "$tmp/cosmos/tx/v1beta1/tx.pb.swift" Sources/ThorChainKit/Protocol/Generated/Tx.pb.swift
cmp "$tmp/thorchain/v1/types/msg_send.pb.swift" Sources/ThorChainKit/Protocol/Generated/MsgSend.pb.swift
rm -rf "$tmp"
```

The checked-in outputs are `Signing.pb.swift`, `Tx.pb.swift`, and
`MsgSend.pb.swift`, containing only `SignMode`, `ModeInfo`, `TxBody`,
`SignerInfo`, `Fee`, `AuthInfo`, `SignDoc`, `TxRaw`, and `MsgSend`. The
generated surface contains no private-key messages; the codec-specific Swift
types remain internal.
