#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"

fail() {
    echo "FAIL verify-s1-02-live: $1" >&2
    exit 1
}

[[ ${THORCHAIN_S1_02_LIVE:-} == 1 ]] || fail "THORCHAIN_S1_02_LIVE=1 is required"
for variable in \
    THORCHAIN_S1_02_FAMILY_A_ID \
    THORCHAIN_S1_02_FAMILY_A_COSMOS_URL \
    THORCHAIN_S1_02_FAMILY_A_COMET_URL \
    THORCHAIN_S1_02_FAMILY_B_ID \
    THORCHAIN_S1_02_FAMILY_B_COSMOS_URL \
    THORCHAIN_S1_02_FAMILY_B_COMET_URL
do
    [[ -n ${!variable:-} ]] || fail "$variable is required"
done

[[ -z $(git status --porcelain) ]] || fail "implementation HEAD must be clean"
implementation_head=$(git rev-parse HEAD)
[[ "$implementation_head" =~ ^[0-9a-f]{40}$ ]] || fail "implementation HEAD is not exact"

output_dir="$repository_root/build/s1-02-live/$implementation_head"
output="$output_dir/evidence.json"
[[ ! -e "$output_dir" ]] || fail "live evidence output already exists"
mkdir -p "$output_dir"
temporary=$(mktemp "$output_dir/.evidence.XXXXXX")
binary_dir=$(mktemp -d)
binary="$binary_dir/verify-s1-02-live-evidence"
trap 'rm -f "$temporary"; rm -rf "$binary_dir"' EXIT

xcrun swiftc -parse-as-library Scripts/verify-s1-02-live-evidence.swift -o "$binary"
"$binary" probe "$temporary" "$output" "$repository_root" "$implementation_head" \
    || fail "provider probe or evidence validation failed"
mv "$temporary" "$output"

echo "PASS verify-s1-02-live head=$implementation_head evidence=build/s1-02-live/$implementation_head/evidence.json"
