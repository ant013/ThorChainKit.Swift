#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
scheme="ThorChainExampleLive"
configuration="Release"
destination=""
derived_data_path=""
app_path=""
expected_head=""
expected_udid=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) scheme="$2"; shift 2 ;;
    --configuration) configuration="$2"; shift 2 ;;
    --destination) destination="$2"; shift 2 ;;
    --derived-data-path) derived_data_path="$2"; shift 2 ;;
    --app-path) app_path="$2"; shift 2 ;;
    --expected-head) expected_head="$2"; shift 2 ;;
    --expected-udid) expected_udid="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$destination" && -n "$derived_data_path" && -n "$app_path" && -n "$expected_head" && -n "$expected_udid" ]] || {
  echo "--destination, --derived-data-path, --app-path, --expected-head, and --expected-udid are required" >&2
  exit 2
}
[[ "$destination" == *"id=$expected_udid"* ]] || { echo "destination UDID mismatch" >&2; exit 1; }
[[ "$(git -C "$root" rev-parse HEAD)" == "$expected_head" ]] || { echo "HEAD mismatch" >&2; exit 1; }
expected_app="$derived_data_path/Build/Products/${configuration}-iphonesimulator/$scheme.app"
[[ "$app_path" == "$expected_app" && -d "$app_path" ]] || { echo "resolved app path mismatch" >&2; exit 1; }
[[ -f "$app_path/$scheme" ]] || { echo "unresolved Live executable" >&2; exit 1; }
if find "$app_path" -type d -name 'FixtureSupport.framework' -print -quit | rg -q .; then
  echo "fixture support product found in Live app" >&2
  exit 1
fi
executables=$(find "$app_path" -type f -perm -111 -print)
[[ -n "$executables" ]] || { echo "no executable binaries resolved" >&2; exit 1; }
while IFS= read -r executable; do
  if strings "$executable" | rg -q 'FixtureScenario|FixtureTransport|FixtureSigner|ThorChainExampleFixture|ThorChainExampleFixtureSupport'; then
    echo "fixture symbol found in Live executable: $executable" >&2
    exit 1
  fi
done <<< "$executables"
echo "Live executable boundary OK: $app_path/$scheme"
