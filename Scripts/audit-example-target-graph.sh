#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
project="$root/iOS Example/iOS Example.xcodeproj/project.pbxproj"
grep -q 'ThorChainExampleLive' "$project"
grep -q 'ThorChainExampleFixture' "$project"
grep -q 'ThorChainExampleFixtureSupport' "$project"
grep -q 'ThorChainExampleLiveSupport' "$project"
grep -q 'EXAMPLE_FIXTURE' "$project"
grep -q 'FixtureSupport' "$project"
grep -q 'LiveSupport' "$project"
if rg -n 'UIKit|AppDelegate|UIViewController|UIViewRepresentable' "$root/iOS Example"; then
  echo "forbidden UIKit Example surface" >&2
  exit 1
fi
if rg -n 'FixtureSupport|FixtureScenario|FixtureTransport|FixtureSigner' "$root/Sources/ThorChainKit" "$root/iOS Example/LiveSupport"; then
  echo "fixture symbols escaped their Example boundary" >&2
  exit 1
fi
echo "target graph boundary OK"
