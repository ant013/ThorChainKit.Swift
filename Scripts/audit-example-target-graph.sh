#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
package="$root/Package.swift"
project="$root/iOS Example/iOS Example.xcodeproj/project.pbxproj"
grep -q 'name: "ThorChainExampleLiveSupport"' "$package"
grep -q 'type: .dynamic' "$package"
grep -q 'revision: "2fc0dbfc089f78a9804baafe8e1bc4aab69cbad1"' "$package"
grep -q 'path: "iOS Example/LiveSupport"' "$package"
test "$(rg -c 'isa = XCLocalSwiftPackageReference' "$project")" -eq 1
if rg -n 'XCRemoteSwiftPackageReference|HdWalletKit.Swift' "$project"; then
  echo "direct remote package root remains" >&2
  exit 1
fi
if rg -n 'PBXNativeTarget.*LiveSupport' "$project"; then
  echo "native LiveSupport target remains" >&2
  exit 1
fi
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
