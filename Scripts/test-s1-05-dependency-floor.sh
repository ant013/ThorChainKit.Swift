#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
primary_lock_hash=$(shasum -a 256 Package.resolved | awk '{print $1}')
temporary_root=$(mktemp -d)
trap 'find "$temporary_root" -depth -delete' EXIT
copy="$temporary_root/package"
mkdir -p "$copy"
cp Package.swift Package.resolved "$copy/"
mkdir -p "$copy/Sources" "$copy/Tests"
rsync -a Sources/ThorChainKit/ "$copy/Sources/ThorChainKit/" >/dev/null
rsync -a Tests/ThorChainKitTests/ "$copy/Tests/ThorChainKitTests/" >/dev/null
rsync -a Tests/ThorChainKitLiveTests/ "$copy/Tests/ThorChainKitLiveTests/" >/dev/null

grep -F 'exact: "6.29.1"' "$copy/Package.swift" >/dev/null
grep -F '6.29.1' "$copy/Package.resolved" >/dev/null
grep -F 'dd6b98ce04eda39aa22f066cd421c24d7236ea8a' "$copy/Package.resolved" >/dev/null

lock_before=$(shasum -a 256 "$copy/Package.resolved" | awk '{print $1}')
(cd "$copy" && xcodebuild build \
    -scheme ThorChainKit \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$temporary_root/derived-data" \
    -clonedSourcePackagesDirPath "$temporary_root/packages" \
    SWIFT_VERSION=5 \
    SWIFT_SUPPRESS_WARNINGS=NO)
lock_after=$(shasum -a 256 "$copy/Package.resolved" | awk '{print $1}')
[[ "$lock_before" == "$lock_after" ]] || {
    echo "FAIL S1-05 dependency floor rewrote the copied lockfile" >&2
    exit 1
}
[[ "$primary_lock_hash" == "$(shasum -a 256 "$root/Package.resolved" | awk '{print $1}')" ]] || {
    echo "FAIL S1-05 dependency floor changed the primary Package.resolved" >&2
    exit 1
}

echo "PASS S1-05 dependency floor from temporary copy"
