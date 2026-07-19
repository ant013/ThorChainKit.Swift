#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)

fail() {
    echo "FAIL $1: $2" >&2
    exit 1
}

verify_package_topology() {
    local manifest
    manifest=$(mktemp)
    trap 'rm -f "$manifest"' RETURN

    cd "$repository_root"
    swift package dump-package > "$manifest" 2>/dev/null \
        || fail "verify-s1-01-package-topology" "Package.swift is unavailable or invalid"

    python3 - "$manifest" <<'PY' \
        || fail "verify-s1-01-package-topology" "unexpected product, target, or dependency topology"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    package = json.load(handle)

products = package["products"]
targets = package["targets"]
dependencies = package["dependencies"]

assert package["name"] == "ThorChainKit"
assert package["platforms"] == [{
    "options": [],
    "platformName": "ios",
    "version": "13.0",
}]
assert len(products) == 1
assert products[0]["name"] == "ThorChainKit"
assert products[0]["type"] == {"library": ["automatic"]}
assert products[0]["targets"] == ["ThorChainKit"]

assert [(target["name"], target["type"]) for target in targets] == [
    ("ThorChainKit", "regular"),
    ("ThorChainKitTests", "test"),
]
assert [target["dependencies"] for target in targets] == [
    [{"byName": ["BigInt", None]}],
    [{"byName": ["ThorChainKit", None]}],
]

assert len(dependencies) == 1
dependency = dependencies[0]["sourceControl"][0]
assert dependency["identity"] == "bigint"
assert dependency["location"]["remote"] == [
    {"urlString": "https://github.com/attaswift/BigInt.git"}
]
assert dependency["requirement"] == {
    "range": [{"lowerBound": "5.0.0", "upperBound": "6.0.0"}]
}
PY

    echo "PASS verify-s1-01-package-topology"
}

verify_default_bigint_resolution() {
    local graph
    graph=$(mktemp)
    trap 'rm -f "$graph"' RETURN

    [[ -f "$repository_root/Package.resolved" ]] \
        || fail "verify-s1-01-bigint-default" "Package.resolved is unavailable"

    cd "$repository_root"
    swift package show-dependencies --format json > "$graph"

    python3 - "$repository_root/Package.resolved" "$graph" <<'PY' \
        || fail "verify-s1-01-bigint-default" "BigInt is not locked and resolved at the approved default"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    lock = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    graph = json.load(handle)

pins = lock["pins"]
assert len(pins) == 1
pin = pins[0]
assert pin["identity"] == "bigint"
assert pin["location"] == "https://github.com/attaswift/BigInt.git"
assert pin["state"] == {
    "revision": "e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe",
    "version": "5.7.0",
}

dependencies = graph["dependencies"]
assert len(dependencies) == 1
dependency = dependencies[0]
assert dependency["identity"] == "bigint"
assert dependency["version"] == "5.7.0"
assert dependency["url"] == "https://github.com/attaswift/BigInt.git"
PY

    echo "PASS verify-s1-01-bigint-default"
}

verify_package_topology
verify_default_bigint_resolution
