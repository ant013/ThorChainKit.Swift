#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
package_copy="$temporary_root/package"
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
    echo "FAIL verify-bigint-floor: THORCHAIN_SIMULATOR_UDID must contain one UUID" >&2
    exit 1
}

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

python3 - "$package_copy/Package.resolved" "$package_copy" "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-03-dependency-revisions.txt" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

with open(sys.argv[1], encoding="utf-8") as handle:
    lock = json.load(handle)

expected = {}
for line in Path(sys.argv[3]).read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    identity, location, version, revision = line.split("|")
    expected[identity] = (location, version, revision)
expected["bigint"] = (
    expected["bigint"][0],
    "5.0.0",
    "19f5e8a48be155e34abb98a2bcf4a343316f0343",
)

pins = {pin["identity"]: pin for pin in lock["pins"]}
assert set(pins) == set(expected)
for identity, (location, version, revision) in expected.items():
    assert pins[identity]["location"] == location
    assert pins[identity]["state"] == {"revision": revision, "version": version}

graph = json.loads(subprocess.check_output([
    "swift", "package", "--package-path", sys.argv[2], "show-dependencies", "--format", "json",
], text=True))
observed = {}
def visit(nodes):
    for node in nodes:
        observed[node["identity"]] = (node["url"], node["version"])
        visit(node.get("dependencies", []))
visit(graph["dependencies"])
assert set(observed) == set(expected)
for identity, (location, version, _) in expected.items():
    assert observed[identity] == (location, version)
assert {node["identity"] for node in graph["dependencies"]} == {
    "bigint", "hscryptokit.swift", "secp256k1.swift",
}
PY

derived_data="$temporary_root/derived-data"
result_bundle="$temporary_root/bigint-floor.xcresult"
(cd "$package_copy" && xcodebuild \
    -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    SWIFT_VERSION=5 \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    CODE_SIGNING_ALLOWED=NO test)
cat "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt" \
    "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt" \
    "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt" \
    | sort -u > "$temporary_root/full-tests.txt"
"$repository_root/Scripts/verify-xcresult.sh" verify-bigint-floor \
    "$result_bundle" "$temporary_root/full-tests.txt"

current_lock_hash=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')
[[ "$current_lock_hash" == "$default_lock_hash" ]] || {
    echo "FAIL verify-bigint-floor: default Package.resolved changed" >&2
    exit 1
}

echo "PASS verify-bigint-floor"
