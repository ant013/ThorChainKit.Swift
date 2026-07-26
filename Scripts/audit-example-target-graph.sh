#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
package="$root/Package.swift"
project="$root/iOS Example/iOS Example.xcodeproj/project.pbxproj"
grep -q 'revision: "2fc0dbfc089f78a9804baafe8e1bc4aab69cbad1"' "$package"
if rg -n 'name: "ThorChainExampleLiveSupport"|name: "LiveSupport"' "$package"; then
  echo "LiveSupport must remain an Xcode Foundation-only target" >&2
  exit 1
fi
test "$(rg -c 'isa = XCLocalSwiftPackageReference' "$project")" -eq 1
if rg -n 'XCRemoteSwiftPackageReference|HdWalletKit.Swift' "$project"; then
  echo "direct remote package root remains" >&2
  exit 1
fi
grep -q 'ThorChainExampleLive' "$project"
grep -q 'ThorChainExampleFixture' "$project"
grep -q 'ThorChainExampleFixtureSupport' "$project"
grep -q 'ThorChainExampleLiveSupport' "$project"
grep -q 'EXAMPLE_FIXTURE' "$project"
grep -q 'FixtureSupport' "$project"
grep -q 'LiveSupport' "$project"
grep -q 'PRODUCT_MODULE_NAME = FixtureSupport; PRODUCT_NAME = FixtureSupport;' "$project"
test "$(rg -c 'IPHONEOS_DEPLOYMENT_TARGET = 14.0; LD_DYLIB_INSTALL_NAME = "@rpath/\$\(EXECUTABLE_PATH\)"; PRODUCT_BUNDLE_IDENTIFIER = org\.horizontalsystems\.thorchainkit\.example\.fixture\.support; PRODUCT_MODULE_NAME = FixtureSupport; PRODUCT_NAME = FixtureSupport;' "$project")" -eq 2
test "$(rg -c 'PRODUCT_BUNDLE_IDENTIFIER = org.horizontalsystems.thorchainkit.example.fixture.support; PRODUCT_MODULE_NAME = FixtureSupport;' "$project")" -eq 2
test "$(rg -c 'LD_DYLIB_INSTALL_NAME = "@rpath/\$\(EXECUTABLE_PATH\)"; PRODUCT_BUNDLE_IDENTIFIER = org\.horizontalsystems\.thorchainkit\.example\.fixture\.support;' "$project")" -eq 2
test "$(rg -c 'PRODUCT_MODULE_NAME = LiveSupport; PRODUCT_NAME = LiveSupport;' "$project")" -eq 2
test "$(rg -c 'LD_DYLIB_INSTALL_NAME = "@rpath/\$\(EXECUTABLE_PATH\)"; PRODUCT_BUNDLE_IDENTIFIER = org\.horizontalsystems\.thorchainkit\.example\.live\.support; PRODUCT_MODULE_NAME = LiveSupport; PRODUCT_NAME = LiveSupport;' "$project")" -eq 2
test "$(rg -c '"EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]" = x86_64;' "$project")" -eq 10
test "$(rg -c 'LD_RUNPATH_SEARCH_PATHS = "@executable_path/Frameworks"; PRODUCT_BUNDLE_IDENTIFIER = org\.horizontalsystems\.thorchainkit\.example\.(fixture|live);' "$project")" -eq 4
grep -q 'B60000000000000000000007 = {isa = PBXCopyFilesBuildPhase;.*dstSubfolderSpec = 10; files = (B20000000000000000000027); name = Frameworks;' "$project"
grep -q 'B20000000000000000000027 .*CodeSignOnCopy.*RemoveHeadersOnCopy' "$project"
grep -q 'B10000000000000000000001 = .*B60000000000000000000007.*name = ThorChainExampleLive;' "$project"
grep -q 'B60000000000000000000006 = {isa = PBXCopyFilesBuildPhase;.*dstSubfolderSpec = 10; files = (B20000000000000000000025); name = Frameworks;' "$project"
grep -q 'B20000000000000000000025 .*CodeSignOnCopy.*RemoveHeadersOnCopy' "$project"
grep -q 'B10000000000000000000002 = .*B60000000000000000000006.*name = ThorChainExampleFixture;' "$project"
for target in B10000000000000000000001 B10000000000000000000003; do
  target_line=$(rg "^[[:space:]]*$target = " "$project")
  if [[ "$target_line" == *B60000000000000000000006* ]]; then
    echo "FixtureSupport embedding must remain absent from Live targets" >&2
    exit 1
  fi
done
grep -q 'name = ThorChainExampleLive; packageProductDependencies = (B90000000000000000000001, B90000000000000000000004, B90000000000000000000005, B90000000000000000000006);' "$project"
grep -q 'name = ThorChainExampleFixture; packageProductDependencies = (B90000000000000000000001);' "$project"
grep -q 'name = ThorChainExampleFixtureSupport;' "$project"
if rg -n 'name = ThorChainExampleFixtureSupport;.*packageProductDependencies|name = ThorChainExampleFixtureSupport;.*B400|B40000000000000000000004 = .*B20000000000000000000020' "$project"; then
  echo "FixtureSupport must not link ThorChainKit" >&2
  exit 1
fi
test "$(find "$root/iOS Example/LiveSupport" -type f -name '*.swift' | wc -l | tr -d ' ')" -eq 1
test "$(find "$root/iOS Example/FixtureSupport" -type f -name '*.swift' | wc -l | tr -d ' ')" -eq 1
if rg -n 'import ThorChainKit|import HdWalletKit|import HsCryptoKit|import secp256k1' "$root/iOS Example/LiveSupport" "$root/iOS Example/FixtureSupport"; then
  echo "support targets must remain Foundation-only" >&2
  exit 1
fi
for source in LiveSendSession.swift FixtureSigner.swift FixtureTransport.swift; do
  test -f "$root/iOS Example/Sources/Signing/$source"
done
if rg -n 'UIKit|AppDelegate|UIViewController|UIViewRepresentable' "$root/iOS Example"; then
  echo "forbidden UIKit Example surface" >&2
  exit 1
fi
if rg -n 'FixtureSupport|FixtureScenario|FixtureTransport|FixtureSigner' "$root/Sources/ThorChainKit" "$root/iOS Example/LiveSupport"; then
  echo "fixture symbols escaped their Example boundary" >&2
  exit 1
fi
echo "target graph boundary OK"
