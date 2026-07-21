#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "usage: $0 <label> <result-bundle> <allowlist> [expect-failure]" >&2
    exit 2
}

(($# >= 3 && $# <= 4)) || usage
label=$1
result_bundle=$2
allowlist=$3
expect_failure=${4:-false}

summary=$(mktemp)
tests=$(mktemp)
trap 'rm -f "$summary" "$tests"' EXIT

xcrun xcresulttool get test-results summary --path "$result_bundle" --compact > "$summary" \
    || { echo "FAIL $label: summary xcresult is unavailable" >&2; exit 1; }
xcrun xcresulttool get test-results tests --path "$result_bundle" --compact > "$tests" \
    || { echo "FAIL $label: test-node xcresult is unavailable" >&2; exit 1; }

python3 - "$summary" "$tests" "$allowlist" "$expect_failure" <<'PY'
import json
import sys
from pathlib import Path

summary_path, tests_path, allowlist_path, expect_failure = sys.argv[1:]
summary = json.loads(Path(summary_path).read_text())
tests = json.loads(Path(tests_path).read_text())
expected = [line.strip() for line in Path(allowlist_path).read_text().splitlines() if line.strip()]

if not expected:
    raise SystemExit("empty test allowlist")

def cases(node):
    if not isinstance(node, dict):
        return
    if node.get("nodeType") == "Test Case":
        yield node
    for child in node.get("children", []) + node.get("testNodes", []):
        yield from cases(child)

observed = list(cases(tests))
if len(observed) != len(expected):
    raise SystemExit(f"test count mismatch: expected {len(expected)}, observed {len(observed)}")

observed_names = []
for node in observed:
    identifier = node.get("nodeIdentifier")
    if not isinstance(identifier, str) or "/" not in identifier:
        raise SystemExit("test case has no canonical node identifier")
    observed_names.append("ThorChainKitTests." + identifier.removesuffix("()"))

if set(observed_names) != set(expected):
    raise SystemExit(f"test names mismatch: expected {sorted(expected)}, observed {sorted(observed_names)}")

results = [node.get("result") for node in observed]
if expect_failure == "reject":
    required = {
        "result": "Passed",
        "totalTestCount": len(expected),
        "passedTests": len(expected) - 1,
        "failedTests": 0,
        "skippedTests": 1,
    }
    for key, value in required.items():
        if summary.get(key) != value:
            raise SystemExit(f"rejected result {key} mismatch: expected {value}, observed {summary.get(key)!r}")
    if results.count("Skipped") != 1 or any(result not in {"Passed", "Skipped"} for result in results):
        raise SystemExit(f"rejected result nodes are not exactly one skipped allowlisted test: {results!r}")
elif expect_failure == "true":
    if summary.get("result") != "Failed" or summary.get("failedTests") != 1:
        raise SystemExit("guarded failure did not produce one failed test")
    if summary.get("skippedTests") != 0 or results != ["Failed"]:
        raise SystemExit("guarded failure was skipped, partial, or otherwise malformed")
else:
    required = {
        "result": "Passed",
        "totalTestCount": len(expected),
        "passedTests": len(expected),
        "failedTests": 0,
        "skippedTests": 0,
    }
    for key, value in required.items():
        if summary.get(key) != value:
            raise SystemExit(f"summary {key} mismatch: expected {value}, observed {summary.get(key)!r}")
    if any(result != "Passed" for result in results):
        raise SystemExit(f"test node result mismatch: {results!r}")
PY

echo "PASS $label"
