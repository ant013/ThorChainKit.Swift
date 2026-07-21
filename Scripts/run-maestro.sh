#!/usr/bin/env bash

set -euo pipefail

fail() {
    echo "FAIL run-maestro: $1" >&2
    exit 1
}

script_root=$(cd "$(dirname "$0")/.." && pwd -P)
repository_root=$(git -C "$script_root" rev-parse --show-toplevel)
repository_root=$(cd "$repository_root" && pwd -P)
cd "$repository_root"

[[ $# == 1 ]] || fail "exactly one slice token is required"
slice=$1
case "$slice" in
    s1-01) flow_path=.maestro/flows/00-launch-foundation.yaml ;;
    s1-02) flow_path=.maestro/flows/01-endpoint-policy.yaml ;;
    s1-03) flow_path=.maestro/flows/02-address-codec.yaml ;;
    *) fail "slice must be s1-01, s1-02, or s1-03" ;;
esac

udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
    || fail "THORCHAIN_SIMULATOR_UDID must contain one UUID"

[[ "$(MAESTRO_CLI_NO_ANALYTICS=1 maestro --version | tr -d '\r')" == "2.6.1" ]] \
    || fail "Maestro 2.6.1 is required"
java_identity=$(java -version 2>&1)
[[ "$java_identity" == *"17.0.19"* && "$java_identity" == *"Temurin-17.0.19+10"* ]] \
    || fail "Temurin 17.0.19+10 is required"

device_list=$(xcrun simctl list devices available -j)
device_state=$(python3 - "$udid" "$device_list" <<'PY'
import json
import sys

udid = sys.argv[1].lower()
devices = json.loads(sys.argv[2])["devices"]
matches = [
    device
    for runtime in devices.values()
    for device in runtime
    if device.get("isAvailable") and device.get("udid", "").lower() == udid
]
assert len(matches) == 1
assert matches[0].get("state") in {"Shutdown", "Booted"}
print(matches[0]["state"])
PY
) || fail "the configured simulator is unavailable"

flow_count=$(find .maestro/flows -type f -name '*.yaml' | wc -l | tr -d ' ')
[[ "$flow_count" == 3 ]] || fail "exactly three slice flows are required"
[[ "$(<.maestro/config.yaml)" == $'flows:\n  - flows/00-launch-foundation.yaml\n  - flows/01-endpoint-policy.yaml\n  - flows/02-address-codec.yaml' ]] \
    || fail "Maestro manifest must contain exactly the three slice flows"
[[ -f "$flow_path" ]] || fail "selected slice flow is unavailable"

results_root="$repository_root/build/$slice-maestro-results"
derived_data="$repository_root/build/$slice-derived-data"
python3 - "$repository_root" "$results_root" "$derived_data" <<'PY' \
    || fail "an output path escapes the repository or contains a symlink"
import os
import stat
import sys

root = os.path.realpath(sys.argv[1])
assert root == sys.argv[1]
for raw in sys.argv[2:]:
    assert os.path.isabs(raw)
    path = os.path.abspath(raw)
    assert os.path.commonpath([root, path]) == root
    relative = os.path.relpath(path, root)
    current = root
    for component in relative.split(os.sep):
        current = os.path.join(current, component)
        if os.path.lexists(current):
            assert not stat.S_ISLNK(os.lstat(current).st_mode)
PY
[[ ! -e "$results_root" && ! -e "$derived_data" ]] \
    || fail "generated output already exists; use a clean working output tree"
mkdir -p "$results_root/artifacts" "$results_root/debug" "$derived_data"

python3 - "$results_root/commands.json" "$udid" "$results_root" "$derived_data" "$flow_path" <<'PY'
import json
import sys

output, udid, results, derived, flow = sys.argv[1:]
commands = {
    "boot": ["xcrun", "simctl", "boot", udid],
    "bootstatus": ["xcrun", "simctl", "bootstatus", udid, "-b"],
    "buildDestination": f"platform=iOS Simulator,id={udid}",
    "derivedData": derived,
    "install": [udid, f"{derived}/Build/Products/Debug-iphonesimulator/iOS Example.app"],
    "launch": [udid, "org.horizontalsystems.thorchainkit.example"],
    "maestro": {
        "device": udid,
        "junit": f"{results}/junit.xml",
        "artifacts": f"{results}/artifacts",
        "debug": f"{results}/debug",
        "flow": flow,
    },
}
with open(output, "w", encoding="utf-8") as handle:
    json.dump(commands, handle, indent=2, sort_keys=True)
PY

if [[ "$device_state" == Shutdown ]]; then
    xcrun simctl boot "$udid"
fi
xcrun simctl bootstatus "$udid" -b

set -o pipefail
xcodebuild \
    -workspace 'iOS Example/iOS Example.xcworkspace' \
    -scheme 'iOS Example' \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tee "$results_root/xcodebuild.log"

app_path="$derived_data/Build/Products/Debug-iphonesimulator/iOS Example.app"
[[ -d "$app_path" ]] || fail "built Example application is unavailable"
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch "$udid" org.horizontalsystems.thorchainkit.example \
    2>&1 | tee "$results_root/launch.log"

maestro \
    --device "$udid" \
    test \
    --format junit \
    --output "$results_root/junit.xml" \
    --test-output-dir "$results_root/artifacts" \
    --debug-output "$results_root/debug" \
    --flatten-debug-output \
    "$flow_path" 2>&1 | tee "$results_root/maestro.log"

python3 - "$results_root/junit.xml" <<'PY' \
    || fail "JUnit must contain one passing, unskipped flow"
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
suites = [root] if root.tag == "testsuite" else list(root.findall("testsuite"))
assert len(suites) == 1
suite = suites[0]
assert suite.attrib.get("tests") == "1"
assert suite.attrib.get("failures", "0") == "0"
assert suite.attrib.get("errors", "0") == "0"
assert suite.attrib.get("skipped", "0") == "0"
assert len(suite.findall("testcase")) == 1
assert not suite.findall(".//failure")
assert not suite.findall(".//error")
assert not suite.findall(".//skipped")
PY

tracked_list="$results_root/tracked-files.txt"
git ls-files -- \
    'iOS Example' \
    '.maestro' \
    '.github/workflows/ci.yml' \
    'Scripts/run-maestro.sh' \
    'Scripts/scan-s1-01-artifacts.swift' > "$tracked_list"
[[ -s "$tracked_list" ]] || fail "tracked scan input is empty"

clang_resource=$(xcrun clang -print-resource-dir)
sdk=$(xcrun --sdk macosx --show-sdk-path)
xcrun swift \
    -Xcc -nostdinc \
    -Xcc -isystem -Xcc "$clang_resource/include" \
    -Xcc -isystem -Xcc "$sdk/usr/include" \
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" \
    Scripts/scan-s1-01-artifacts.swift \
    "$repository_root" \
    "$results_root" \
    "$tracked_list"

echo "PASS run-maestro"
