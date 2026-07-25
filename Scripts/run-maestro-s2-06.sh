#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
udid="${THORCHAIN_SIMULATOR_UDID:-}"
[[ "$udid" =~ ^[A-Fa-f0-9-]{36}$ ]] || { echo "THORCHAIN_SIMULATOR_UDID must be an exact simulator UDID" >&2; exit 2; }
command -v maestro >/dev/null || { echo "Maestro is unavailable" >&2; exit 1; }
"$root/Scripts/test-run-maestro-s2-06.sh"
destination="platform=iOS Simulator,id=$udid"
xcodebuild -workspace "$root/iOS Example/iOS Example.xcworkspace" -scheme ThorChainExampleFixture -configuration Debug -destination "$destination" build
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
app=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*ThorChainExampleFixture.app' -print -quit)
[[ -n "$app" ]] || { echo "fixture app artifact unresolved" >&2; exit 1; }
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" org.horizontalsystems.thorchainkit.example.fixture
out="$root/artifacts/s2-06/$(git rev-parse HEAD)/$udid"
mkdir -p "$out"
maestro test --device "$udid" --format junit --output "$out/junit.xml" --test-output-dir "$out/screenshots" "$root/.maestro/sprint-02"
python3 - "$out/junit.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
suite = root if root.tag == "testsuite" else root.find("testsuite")
assert suite is not None
assert suite.attrib.get("tests") == "5"
assert suite.attrib.get("failures", "0") == "0"
assert suite.attrib.get("errors", "0") == "0"
assert suite.attrib.get("skipped", "0") == "0"
assert len(suite.findall("testcase")) == 5
PY
"$root/Scripts/verify-s2-06-artifacts.py" "$out" "$udid"
