# S2-03 transaction codec provenance

The generated transaction subset is pinned to these authoritative sources:

- THORNode `a759cb4f` (`proto/thorchain/v1/types/msg_send.proto`), full source
  SHA-256 `3396f77b196748d187206dc4235eec9112bd9a914e84ca7ee4d466078a4ceff8`.
- Cosmos SDK `v0.53.0` (`proto/cosmos/tx/v1beta1/tx.proto` and
  `proto/cosmos/tx/signing/v1beta1/signing.proto`), with only the messages
  required by this codec retained in the local generator inputs.
- SwiftProtobuf package exact `1.33.3`, source commit
  `c169a5744230951031770e27e475ff6eefe51f9d`.
- Xcode exact `26.3` (`17C529`), Apple Swift exact `6.2.4`, and `libprotoc`
  exact `34.1`.

The generator uses the checked-in inputs under `Generated/upstream`, the
existing pinned Cosmos `Coin` and protobuf `Any` inputs under
`Network/Generated/Query/upstream`, and the exact SwiftProtobuf plugin from
`.build/checkouts/swift-protobuf`. It emits only `MsgSend`, `SignMode`,
`ModeInfo`, `TxBody`, `SignerInfo`, `Fee`, `AuthInfo`, `SignDoc`, and `TxRaw`.
No private-key or generic transaction messages are generated.
