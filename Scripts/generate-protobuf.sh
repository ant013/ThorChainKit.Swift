#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
generated="$root/Sources/ThorChainKit/Protocol/Generated"
upstream="$generated/upstream"
query_upstream="$root/Sources/ThorChainKit/Network/Generated/Query/upstream"
provenance="$generated/PROVENANCE.md"
swift_cmd="${SWIFT_COMMAND:-xcrun swift}"
printf '%s\n' "$($swift_cmd --version)" | grep -Fq 'Apple Swift version 6.2.4'
$swift_cmd build --package-path "$root/.build/checkouts/swift-protobuf" --product protoc-gen-swift
test "$(xcodebuild -version | sed -n '1p')" = "Xcode 26.3"
test "$(xcodebuild -version | sed -n '2p')" = "Build version 17C529"
test "$(protoc --version)" = "libprotoc 34.1"
test "$(shasum -a 256 "$(command -v protoc)" | awk '{print $1}')" = "59001d00d60e6ed0e6c49e2ae6591b58882cec5bf45402f937b22566be893d4e"
swift_protobuf_checkout="$root/.build/checkouts/swift-protobuf"
test "$(git -C "$swift_protobuf_checkout" rev-parse HEAD)" = "c169a5744230951031770e27e475ff6eefe51f9d"
test "$(git -C "$swift_protobuf_checkout" describe --tags --exact-match HEAD)" = "1.33.3"
plugin_dir=$($swift_cmd build --package-path "$root/.build/checkouts/swift-protobuf" --show-bin-path)
plugin="$plugin_dir/protoc-gen-swift"
test -x "$plugin"

check_sha() {
  test "$(shasum -a 256 "$1" | awk '{print $1}')" = "$2"
}
check_sha "$upstream/cosmos/tx/signing/v1beta1/signing.proto" 744c8e2ed515a064abe34a9fe2ec23556dd8d52776e52cc8dbaed89999b7805a
check_sha "$upstream/cosmos/tx/v1beta1/tx.proto" 47cc8faa152137126a9fc7d30d0d146eb3500704990a0d6d6e6e9a3f2fd2523f
check_sha "$upstream/thorchain/v1/types/msg_send.proto" 3396f77b196748d187206dc4235eec9112bd9a914e84ca7ee4d466078a4ceff8
check_sha "$query_upstream/cosmos/base/v1beta1/coin.proto" 408b074f81f3dafb440cd61921bf244eab2ff20cb1f2a9f247265d031481c9ec
check_sha "$query_upstream/google/protobuf/any.proto" d7c79a05a5c7fae89f0aff26d112e0b60f082fc7fc424e8910be99c86b656260
check_sha "$query_upstream/gogoproto/gogo.proto" a2bef0fb7e233ff2f442da08b3764be6ce59cc3f2df05cd1c9a44dbb5b55c18f
check_sha "$query_upstream/amino/amino.proto" bc4cb71a5b49ce23e7b9ff8e5cd9f42efa9527c8f2d2e3861c901c7e86be202e
grep -Fq 'protoc-gen-swift `1.33.3` source checksum' "$provenance"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp"
(
  cd "$root"
  protoc --plugin=protoc-gen-swift="$plugin" \
    --proto_path="$upstream" \
    --proto_path="$query_upstream" \
    --swift_out="$tmp" \
    cosmos/tx/signing/v1beta1/signing.proto \
    cosmos/tx/v1beta1/tx.proto \
    thorchain/v1/types/msg_send.proto
)

mkdir -p "$generated"
cp "$tmp/cosmos/tx/signing/v1beta1/signing.pb.swift" "$generated/Signing.pb.swift"
cp "$tmp/cosmos/tx/v1beta1/tx.pb.swift" "$generated/Tx.pb.swift"
cp "$tmp/thorchain/v1/types/msg_send.pb.swift" "$generated/MsgSend.pb.swift"

if [ "${1:-}" = "--check" ]; then
  git -C "$root" diff --exit-code -- \
    Sources/ThorChainKit/Protocol/Generated/Signing.pb.swift \
    Sources/ThorChainKit/Protocol/Generated/Tx.pb.swift \
    Sources/ThorChainKit/Protocol/Generated/MsgSend.pb.swift
else
  echo "transaction protobuf generation complete"
fi
