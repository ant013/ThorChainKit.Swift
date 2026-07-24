#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
provenance="$root/Sources/ThorChainKit/Network/Generated/Query/PROVENANCE.md"
query_generated="$root/Sources/ThorChainKit/Network/Generated/Query/Query.pb.swift"
auth_generated="$root/Sources/ThorChainKit/Network/Generated/Query/Auth.pb.swift"
upstream="$root/Sources/ThorChainKit/Network/Generated/Query/upstream"
test -f "$provenance" -a -f "$query_generated" -a -f "$auth_generated"
for input in \
  cosmos/auth/v1beta1/auth.proto \
  cosmos/auth/v1beta1/query.proto \
  cosmos/bank/v1beta1/query.proto \
  cosmos/bank/v1beta1/bank.proto \
  cosmos/base/v1beta1/coin.proto \
  cosmos/base/query/v1beta1/pagination.proto \
  cosmos/crypto/secp256k1/keys.proto \
  cosmos/query/v1/query.proto \
  cosmos/vesting/v1beta1/vesting.proto \
  cosmos/msg/v1/msg.proto \
  cosmos_proto/cosmos.proto \
  gogoproto/gogo.proto \
  amino/amino.proto \
  google/api/annotations.proto \
  google/api/http.proto \
  google/protobuf/any.proto \
  google/protobuf/descriptor.proto \
  thorchain/v1/query_network.proto \
  thorchain/v1/query_mimir.proto \
  thorchain/v1/query_version.proto \
  types/type_mimir.proto; do
  test -f "$upstream/$input"
done
grep -Fq 'THORNode source: `a759cb4f`' "$provenance"
grep -Fq 'Cosmos SDK source: `v0.53.0`' "$provenance"
grep -Fq 'cosmossdk.io/api' "$provenance"
grep -Fq 'SwiftProtobuf package: exact `1.33.3`' "$provenance"
grep -Fq 'Xcode: exact `26.3` (`17C529`)' "$provenance"
grep -Fq 'Apple Swift: exact `6.2.4`' "$provenance"
grep -Fq 'libprotoc 34.1' "$provenance"
grep -Fq 'cosmos/auth/v1beta1/query.proto' "$provenance"
grep -Fq 'cosmos/auth/v1beta1/auth.proto' "$provenance"
grep -Fq 'google/protobuf/any.proto' "$provenance"
grep -Fq -- '--proto_path=Sources/ThorChainKit/Network/Generated/Query/upstream' "$provenance"
check_sha() {
  test "$(shasum -a 256 "$upstream/$1" | awk '{print $1}')" = "$2"
}
check_sha cosmos/auth/v1beta1/query.proto 3338b3e8fd6b22d292d4b19b231c5027cf3a95d341bcb97edc9d7dec52b46d36
check_sha cosmos/auth/v1beta1/auth.proto 1c19f884767e07819b16c41ca220ec5adc6cc931abf6984a06d30ca5ad83753e
check_sha cosmos/bank/v1beta1/query.proto c7bec81be1cb37cafe0e53187386e0cea66d3074ce3a33cba18209b17f71abfc
check_sha cosmos/bank/v1beta1/bank.proto d36d05d8ae2e5b39dd0a182f9ad8599e712060100cb6f700cf7e28487bdd3dee
check_sha cosmos/base/v1beta1/coin.proto 408b074f81f3dafb440cd61921bf244eab2ff20cb1f2a9f247265d031481c9ec
check_sha cosmos/base/query/v1beta1/pagination.proto 8a878b43363c1fe2098e7b49b65fc5e5226daa13862d250848f4cf83007c8262
check_sha cosmos/crypto/secp256k1/keys.proto d69386568e35c2c20cf367307489f9e50a2710a71552c531a20aee8d9371ba62
check_sha cosmos/query/v1/query.proto f0251d79e920ddeb91982024859b29230cd230de180ef895c41d0767bec01d1d
check_sha cosmos/vesting/v1beta1/vesting.proto 73a10cc39e3f043acc7557ed5f754e80251df6548ec4e19025adfffbbef8bdf7
check_sha cosmos/msg/v1/msg.proto 4100c0021a143b5a273964f2472523d8e61fe28acaccade898f05becc3af8f31
check_sha thorchain/v1/query_network.proto a1b26fdf0988a2dea0970328c241a16f8af648609d71e3a1eb1d0b7bc10564c5
check_sha thorchain/v1/query_mimir.proto e1a18ca8b9a369807ae9c09e486f1ab38453073be14d2f3f8914e37542c5b334
check_sha thorchain/v1/query_version.proto 77573a5dd17f3e3632ad60c866291a3bb74c937d098b3fabbc4e1099f4bacda8
check_sha types/type_mimir.proto 253e59f2d026185f813b6ebd26717ece91ec76d00fb94516e56cd725175ee496
check_sha cosmos_proto/cosmos.proto 9104e7bc5b757cac81ecd2874b34ad650ff06091e1b68e21ec0b0d9d5c36606b
check_sha gogoproto/gogo.proto a2bef0fb7e233ff2f442da08b3764be6ce59cc3f2df05cd1c9a44dbb5b55c18f
check_sha amino/amino.proto bc4cb71a5b49ce23e7b9ff8e5cd9f42efa9527c8f2d2e3861c901c7e86be202e
check_sha google/api/annotations.proto e79ea741cb605a65e78ca322174764a4af9fde1962c1631e12b84c4934ba9a6c
check_sha google/api/http.proto ead99129aa15dd5f6233942030c72eec33bc0d7b1c7c260dc143293ef66c5b78
check_sha google/protobuf/any.proto d7c79a05a5c7fae89f0aff26d112e0b60f082fc7fc424e8910be99c86b656260
check_sha google/protobuf/descriptor.proto 32f3df357257f556b311c7e4ad33625a7aa13de541cb53a29ae85ac746c11a07
test "$(protoc --version)" = "libprotoc 34.1"
test "$(shasum -a 256 "$(command -v protoc)" | awk '{print $1}')" = "59001d00d60e6ed0e6c49e2ae6591b58882cec5bf45402f937b22566be893d4e"
test "$(xcodebuild -version | sed -n '1p')" = "Xcode 26.3"
test "$(xcodebuild -version | sed -n '2p')" = "Build version 17C529"
printf '%s\n' "$(xcrun swift --version)" | grep -Fq 'Apple Swift version 6.2.4'
if rg -n 'MsgSend|TxBody|AuthInfo|SignDoc|TxRaw|PrivKey|PrivateKey|SignBytes' "$root/Sources/ThorChainKit/Network/Generated/Query" --glob '*.pb.swift'; then
  echo "transaction/signing codec found in query output" >&2
  exit 1
fi
swift build --package-path "$root/.build/checkouts/swift-protobuf" --product protoc-gen-swift
plugin_dir=$(swift build --package-path "$root/.build/checkouts/swift-protobuf" --show-bin-path)
plugin="$plugin_dir/protoc-gen-swift"
test -x "$plugin"
test "$(shasum -a 256 "$plugin" | awk '{print $1}')" = "e5908e3c8d1504ca39ad14c38503b313a84b87def21d5f7dc4d0ce4e3709b8e0"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cosmos/crypto/secp256k1"
pubkey_proto="$tmp/cosmos/crypto/secp256k1/keys_query.proto"
{
  printf '%s\n' 'syntax = "proto3";' 'package cosmos.crypto.secp256k1;' 'import "amino/amino.proto";' 'import "gogoproto/gogo.proto";' 'option go_package = "github.com/cosmos/cosmos-sdk/crypto/keys/secp256k1";'
  awk 'BEGIN { emitting=0; found=0 } /^message PubKey[[:space:]]*\{/ { emitting=1; found++ } emitting { print } emitting && /^\}/ { exit } END { if (found != 1) exit 1 }' "$upstream/cosmos/crypto/secp256k1/keys.proto"
} > "$pubkey_proto"
test "$(shasum -a 256 "$pubkey_proto" | awk '{print $1}')" = "$(grep 'Derived PubKey input SHA-256:' "$provenance" | awk '{print $6}' | tr -d '`.')"
(
  cd "$root"
  protoc --plugin=protoc-gen-swift="$plugin" \
    --proto_path=Sources/ThorChainKit/Network/Generated/Query/upstream \
    --proto_path="$tmp" \
    --swift_out="$tmp" \
    cosmos/auth/v1beta1/auth.proto \
    cosmos/auth/v1beta1/query.proto \
    cosmos/bank/v1beta1/bank.proto \
    cosmos/bank/v1beta1/query.proto \
    cosmos/base/v1beta1/coin.proto \
    cosmos/base/query/v1beta1/pagination.proto \
    cosmos/crypto/secp256k1/keys_query.proto \
    cosmos/query/v1/query.proto \
    cosmos/vesting/v1beta1/vesting.proto \
    thorchain/v1/query_network.proto \
    thorchain/v1/query_mimir.proto \
    thorchain/v1/query_version.proto \
    types/type_mimir.proto
)
cmp "$query_generated" "$tmp/cosmos/auth/v1beta1/query.pb.swift"
cmp "$auth_generated" "$tmp/cosmos/auth/v1beta1/auth.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/Bank.pb.swift" "$tmp/cosmos/bank/v1beta1/bank.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/BankQuery.pb.swift" "$tmp/cosmos/bank/v1beta1/query.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/Coin.pb.swift" "$tmp/cosmos/base/v1beta1/coin.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/Pagination.pb.swift" "$tmp/cosmos/base/query/v1beta1/pagination.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/Secp256k1.pb.swift" "$tmp/cosmos/crypto/secp256k1/keys_query.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/QueryExtensions.pb.swift" "$tmp/cosmos/query/v1/query.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/Vesting.pb.swift" "$tmp/cosmos/vesting/v1beta1/vesting.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/ThorQueryNetwork.pb.swift" "$tmp/thorchain/v1/query_network.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/ThorQueryMimir.pb.swift" "$tmp/thorchain/v1/query_mimir.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/ThorQueryVersion.pb.swift" "$tmp/thorchain/v1/query_version.pb.swift"
cmp "$root/Sources/ThorChainKit/Network/Generated/Query/ThorTypeMimir.pb.swift" "$tmp/types/type_mimir.pb.swift"
echo "query codec generation is deterministic and provenance is present"
