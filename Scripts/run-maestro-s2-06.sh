#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
udid="${THORCHAIN_SIMULATOR_UDID:-}"
[[ "$udid" =~ ^[A-Fa-f0-9-]{36}$ ]] || { echo "THORCHAIN_SIMULATOR_UDID must be an exact simulator UDID" >&2; exit 2; }
command -v maestro >/dev/null || { echo "Maestro is unavailable" >&2; exit 1; }
"$root/Scripts/test-run-maestro-s2-06.sh"
"$root/Scripts/audit-example-target-graph.sh"

destination="platform=iOS Simulator,id=$udid"
head=$(git -C "$root" rev-parse HEAD)
fixture_derived="$root/.build/s2-06-fixture"
live_derived="$root/.build/s2-06-live"
out="$root/artifacts/s2-06/$head/$udid"
mkdir -p "$out"

xcodebuild \
    -workspace "$root/iOS Example/iOS Example.xcworkspace" \
    -scheme ThorChainExampleFixture \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$fixture_derived" \
    SWIFT_SUPPRESS_WARNINGS=NO \
    build

xcodebuild \
    -workspace "$root/iOS Example/iOS Example.xcworkspace" \
    -scheme ThorChainExampleLive \
    -configuration Release \
    -destination "$destination" \
    -derivedDataPath "$live_derived" \
    SWIFT_SUPPRESS_WARNINGS=NO \
    build

fixture_app="$fixture_derived/Build/Products/Debug-iphonesimulator/ThorChainExampleFixture.app"
live_app="$live_derived/Build/Products/Release-iphonesimulator/ThorChainExampleLive.app"
[[ -d "$fixture_app" ]] || { echo "fixture app artifact missing" >&2; exit 1; }
[[ -d "$live_app" ]] || { echo "live app artifact missing" >&2; exit 1; }
"$root/Scripts/audit-example-release-binary.sh" \
    --destination "$destination" \
    --derived-data-path "$live_derived" \
    --app-path "$live_app" \
    --expected-head "$head" \
    --expected-udid "$udid"

xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$fixture_app"
xcrun simctl launch "$udid" org.horizontalsystems.thorchainkit.example.fixture
mkdir -p "$out/screenshots"
maestro test \
    --device "$udid" \
    --format junit \
    --output "$out/junit.xml" \
    --test-output-dir "$out/screenshots" \
    "$root/.maestro/sprint-02/send-checktx-accepted.yaml"

python3 - "$out/junit.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
suite = root if root.tag == "testsuite" else root.find("testsuite")
assert suite is not None
assert suite.attrib.get("tests") == "1"
assert suite.attrib.get("failures", "0") == "0"
assert suite.attrib.get("errors", "0") == "0"
assert suite.attrib.get("skipped", "0") == "0"
assert len(suite.findall("testcase")) == 1
PY

echo "S2-06 accepted-send flow passed"
