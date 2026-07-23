#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
    echo "FAIL verify-s2-01-deployment-floor: THORCHAIN_SIMULATOR_UDID must contain one UUID" >&2
    exit 1
}

if rg -n 'import (UIKit|SwiftUI)' "$root/Sources/ThorChainKit"; then
    echo "FAIL verify-s2-01-deployment-floor: UI import in library" >&2
    exit 1
fi
rg -F '.iOS(.v13)' "$root/Package.swift" >/dev/null

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
xcodebuild -scheme ThorChainKit \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$temporary_root/derived-data" \
    IPHONEOS_DEPLOYMENT_TARGET=13.0 SWIFT_VERSION=5 \
    SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO \
    build >"$temporary_root/build.log" 2>&1
rg -F 'arm64-apple-ios13.0' "$temporary_root/build.log" >/dev/null
if rg -F 'arm64-apple-ios13.0-simulator' "$temporary_root/build.log" >/dev/null; then
    echo "FAIL verify-s2-01-deployment-floor: simulator triple used for device-floor proof" >&2
    exit 1
fi

echo "PASS verify-s2-01-deployment-floor runtime=$simulator_udid device-triple=arm64-apple-ios13.0 target=13.0"
