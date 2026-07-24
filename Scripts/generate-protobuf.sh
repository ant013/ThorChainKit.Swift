#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
generated="$root/Sources/ThorChainKit/Protocol/Generated"
upstream="$generated/upstream"
query_upstream="$root/Sources/ThorChainKit/Network/Generated/Query/upstream"
swift_cmd="${SWIFT_COMMAND:-xcrun swift}"
$swift_cmd build --package-path "$root/.build/checkouts/swift-protobuf" --product protoc-gen-swift
plugin_dir=$($swift_cmd build --package-path "$root/.build/checkouts/swift-protobuf" --show-bin-path)
plugin="$plugin_dir/protoc-gen-swift"
test -x "$plugin"
test "$(protoc --version)" = "libprotoc 34.1"

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
