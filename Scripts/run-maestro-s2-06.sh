#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
udid="${THORCHAIN_SIMULATOR_UDID:-}"
[[ "$udid" =~ ^[A-Fa-f0-9-]{36}$ ]] || { echo "THORCHAIN_SIMULATOR_UDID must be an exact simulator UDID" >&2; exit 2; }
command -v maestro >/dev/null || { echo "Maestro is unavailable" >&2; exit 1; }
"$root/Scripts/test-run-maestro-s2-06.sh"
destination="platform=iOS Simulator,id=$udid"
head=$(git rev-parse HEAD)
out="$root/artifacts/s2-06/$head/$udid"
derived="$root/.build/s2-06"
mkdir -p "$out"
xcodebuild -workspace "$root/iOS Example/iOS Example.xcworkspace" -scheme ThorChainExampleFixture -configuration Debug -destination "$destination" -derivedDataPath "$derived" build
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
app="$derived/Build/Products/Debug-iphonesimulator/ThorChainExampleFixture.app"
[[ -n "$app" ]] || { echo "fixture app artifact unresolved" >&2; exit 1; }
[[ -d "$app" ]] || { echo "fixture app artifact missing" >&2; exit 1; }
python3 -c 'import json,sys; p,app,udid=sys.argv[1:]; open(p,"w").write(json.dumps({"scheme":"ThorChainExampleFixture","configuration":"Debug","udid":udid,"resolvedExecutable":app+"/ThorChainExampleFixture"})+"\n")' "$out/build-settings.json" "$app" "$udid"
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" org.horizontalsystems.thorchainkit.example.fixture
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
