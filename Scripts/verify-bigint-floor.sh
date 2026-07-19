#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
package_copy="$temporary_root/package"

[[ -f "$repository_root/Package.resolved" ]] || {
    echo "FAIL verify-bigint-floor: default Package.resolved is unavailable" >&2
    exit 1
}

default_lock_hash=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')
mkdir -p "$package_copy"
rsync -a --exclude .build --exclude .git "$repository_root/" "$package_copy/"

python3 - "$package_copy/Package.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = '.package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0")'
new = '.package(url: "https://github.com/attaswift/BigInt.git", exact: "5.0.0")'
if source.count(old) != 1:
    raise SystemExit("manifest BigInt range does not match the approved form")
path.write_text(source.replace(old, new), encoding="utf-8")
PY

rm -f "$package_copy/Package.resolved"
swift package --package-path "$package_copy" resolve

python3 - "$package_copy/Package.resolved" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    lock = json.load(handle)

pins = lock["pins"]
assert len(pins) == 1
pin = pins[0]
assert pin["identity"] == "bigint"
assert pin["state"] == {
    "revision": "19f5e8a48be155e34abb98a2bcf4a343316f0343",
    "version": "5.0.0",
}
PY

strict_flags=(
    -Xswiftc -swift-version
    -Xswiftc 5
    -Xswiftc -strict-concurrency=complete
    -Xswiftc -warnings-as-errors
    -Xcc -nostdinc
    -Xcc -isystem
    -Xcc "$(xcrun clang -print-resource-dir)/include"
    -Xcc -isystem
    -Xcc "$(xcrun --sdk macosx --show-sdk-path)/usr/include"
    -Xcc -iframework
    -Xcc "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks"
)
swift build --package-path "$package_copy" "${strict_flags[@]}"
swift test --package-path "$package_copy" "${strict_flags[@]}"

current_lock_hash=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')
[[ "$current_lock_hash" == "$default_lock_hash" ]] || {
    echo "FAIL verify-bigint-floor: default Package.resolved changed" >&2
    exit 1
}

echo "PASS verify-bigint-floor"
