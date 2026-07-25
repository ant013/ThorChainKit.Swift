#!/usr/bin/env bash
set -euo pipefail

scheme="ThorChainExampleLive"
configuration="Release"
destination=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) scheme="$2"; shift 2 ;;
    --configuration) configuration="$2"; shift 2 ;;
    --destination) destination="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$destination" ]] || { echo "--destination is required" >&2; exit 2; }
settings=$(xcodebuild -workspace "iOS Example/iOS Example.xcworkspace" -scheme "$scheme" -configuration "$configuration" -destination "$destination" -showBuildSettings)
product=$(awk -F ' = ' '/TARGET_BUILD_DIR/{dir=$2} /WRAPPER_NAME/{name=$2} END{if(dir && name) print dir "/" name}' <<<"$settings")
[[ -n "$product" && -f "$product/$scheme" ]] || { echo "unresolved Live executable" >&2; exit 1; }
if strings "$product/$scheme" | rg -q 'FixtureScenario|FixtureTransport|FixtureSigner|ThorChainExampleFixture'; then
  echo "fixture symbol found in Live executable" >&2
  exit 1
fi
echo "Live executable boundary OK: $product/$scheme"
