#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$udid" == '0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' ]] || {
    echo "FAIL S1-05 Maestro requires the pinned simulator UDID" >&2
    exit 1
}
[[ "$(MAESTRO_CLI_NO_ANALYTICS=1 maestro --version | tr -d '\r')" == "2.6.1" ]] || {
    echo "FAIL S1-05 Maestro 2.6.1 is required" >&2
    exit 1
}

results=${S105_MAESTRO_RESULTS:-build/s1-05-maestro-results}
derived=${S105_MAESTRO_DERIVED_DATA:-build/s1-05-maestro-derived}
maestro_timeout=${S105_MAESTRO_TIMEOUT:-240}
[[ ! -e "$results" && ! -e "$derived" ]] || {
    echo "FAIL S1-05 Maestro output paths must be absent" >&2
    exit 1
}
mkdir -p "$results/artifacts" "$results/debug" "$derived"

cleanup_workspace() {
    if [[ -e 'iOS Example/iOS Example.xcodeproj/project.xcworkspace' ]]; then
        find 'iOS Example/iOS Example.xcodeproj/project.xcworkspace' -depth -delete
    fi
}
trap cleanup_workspace EXIT

xcrun simctl bootstatus "$udid" -b
xcrun simctl uninstall "$udid" org.horizontalsystems.thorchainkit.example >/dev/null 2>&1 || true
xcodebuild \
    -project 'iOS Example/iOS Example.xcodeproj' \
    -scheme 'iOS Example' \
    -destination "id=$udid" \
    -derivedDataPath "$derived" \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
    SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=NO \
    build >"$results/xcodebuild.log" 2>&1

app="$derived/Build/Products/Debug-iphonesimulator/iOS Example.app"
[[ -d "$app" ]] || { echo "FAIL S1-05 Example app is unavailable" >&2; exit 1; }
xcrun simctl install "$udid" "$app" >/dev/null
xcrun simctl launch "$udid" org.horizontalsystems.thorchainkit.example >"$results/launch.log" 2>&1
maestro --device "$udid" test \
    --format junit \
    --output "$results/junit.xml" \
    --test-output-dir "$results/artifacts" \
    --debug-output "$results/debug" \
    --flatten-debug-output \
    .maestro/flows/04-lifecycle-restart.yaml >"$results/maestro.log" 2>&1 &
maestro_pid=$!
started=$(date +%s)
while kill -0 "$maestro_pid" 2>/dev/null; do
    elapsed=$(( $(date +%s) - started ))
    if (( elapsed >= maestro_timeout )); then
        kill -TERM "$maestro_pid" 2>/dev/null || true
        wait "$maestro_pid" 2>/dev/null || true
        echo "FAIL S1-05 Maestro timed out after ${maestro_timeout}s" >&2
        exit 1
    fi
    sleep 1
done
wait "$maestro_pid" || {
    tail -120 "$results/maestro.log" >&2 || true
    echo "FAIL S1-05 Maestro execution failed" >&2
    exit 1
}

python3 - "$results/junit.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
suite = root if root.tag == "testsuite" else root.find("testsuite")
assert suite is not None
assert suite.attrib.get("tests") == "1"
assert suite.attrib.get("failures", "0") == "0"
assert suite.attrib.get("errors", "0") == "0"
assert suite.attrib.get("skipped", "0") == "0"
assert not suite.findall(".//failure")
assert not suite.findall(".//error")
assert not suite.findall(".//skipped")
PY

container=$(xcrun simctl get_app_container "$udid" org.horizontalsystems.thorchainkit.example data)
fixture_evidence="$container/Library/Application Support/ThorChainKitExample/lifecycle-evidence.json"
[[ -s "$fixture_evidence" ]] || { echo "FAIL S1-05 fixture evidence is missing" >&2; exit 1; }
cp "$fixture_evidence" "$results/fixture-evidence.json"
head=$(git rev-parse HEAD)
python3 - "$results/fixture-evidence.json" "$results/evidence.jsonl" "$head" <<'PY'
import json
import sys

evidence = json.load(open(sys.argv[1], encoding="utf-8"))
assert evidence["syncState"] == "synced"
assert evidence["rune"] == "7"
assert evidence["acceptedHeight"] == 12345678
assert evidence["lastBlockHeight"] == 12345678
assert evidence["acceptedHeight"] == evidence["lastBlockHeight"]
assert evidence["requestCount"] == 20
assert isinstance(evidence["requestCount"], int)
assert isinstance(evidence["acceptedHeight"], int)
assert isinstance(evidence["lastBlockHeight"], int)
record = {
    "slice": "S1-05",
    "head": sys.argv[3],
    "mode": "fixture",
    "events": ["start-start", "pending-stop", "cached-relaunch", "offline-relaunch", "recovery"],
    "final": evidence,
    "passed": True,
}
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(record, handle, separators=(",", ":"))
    handle.write("\n")
PY
echo "PASS S1-05 local Maestro fixture"
