#!/usr/bin/env bash

set -euo pipefail

dependency=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dependency) dependency=$2; shift 2 ;;
        *) echo "usage: $0 --dependency 5.7.0|5.0.0" >&2; exit 2 ;;
    esac
done
[[ "$dependency" == "5.7.0" || "$dependency" == "5.0.0" ]] || {
    echo "FAIL verify-s2-01-concurrency: unsupported dependency $dependency" >&2
    exit 1
}

root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
package_copy="$temporary_root/package"
mkdir -p "$package_copy/Sources" "$package_copy/Tests"
cp "$root/Package.swift" "$root/Package.resolved" "$package_copy/"
rsync -a "$root/Sources/ThorChainKit/" "$package_copy/Sources/ThorChainKit/" >/dev/null
rsync -a "$root/Tests/ThorChainKitTests/" "$package_copy/Tests/ThorChainKitTests/" >/dev/null
rsync -a "$root/Tests/ThorChainKitLiveTests/" "$package_copy/Tests/ThorChainKitLiveTests/" >/dev/null

if [[ "$dependency" == "5.0.0" ]]; then
    python3 - "$package_copy/Package.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
needle = '.package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0")'
replacement = '.package(url: "https://github.com/attaswift/BigInt.git", exact: "5.0.0")'
assert source.count(needle) == 1
path.write_text(source.replace(needle, replacement), encoding="utf-8")
PY
    rm "$package_copy/Package.resolved"
    (cd "$package_copy" && swift package resolve)
fi

derived_data="$temporary_root/derived-data"
(cd "$package_copy" && xcodebuild -scheme ThorChainKit \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$derived_data" \
    SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO build >/dev/null)

include_args=()
while IFS= read -r module; do
    include_args+=(-I "$(dirname "$(dirname "$module")")")
done < <(find "$derived_data/Build/Products" -type f -name '*.swiftmodule')
clang_args=()
module_maps_dir=$(find "$derived_data/Build/Intermediates.noindex" -maxdepth 2 -type d -name 'GeneratedModuleMaps-*' -print -quit)
for module_map in \
    "$module_maps_dir/HsCryptoKitC.modulemap" \
    "$module_maps_dir/secp256k1_bindings.modulemap" \
    "$derived_data/SourcePackages/checkouts/GRDB.swift/Sources/CSQLite/module.modulemap"; do
    [[ -f "$module_map" ]] && clang_args+=(-Xcc "-fmodule-map-file=$module_map")
done
for include in \
    "$derived_data/SourcePackages/checkouts/HsCryptoKit.Swift/Sources/HsCryptoKitC/include" \
    "$derived_data/SourcePackages/checkouts/secp256k1.swift/Sources/secp256k1_bindings/include"; do
    [[ -d "$include" ]] && clang_args+=(-Xcc "-I$include")
done
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
positive="$temporary_root/PositiveConcurrency.swift"
python3 - "$positive" "$root/Sources/ThorChainKit/Core/Kit+Send.swift" <<'PY'
from pathlib import Path
import sys

facade = Path(sys.argv[2]).read_text(encoding="utf-8")
snapshot = facade.index("let snapshot = acceptingNativeFee.map")
hop = facade.index("dependencies.sendRuntime.retryBroadcast")
assert snapshot < hop
Path(sys.argv[1]).write_text(
    "import BigInt\nimport ThorChainKit\n\nfunc callerTask(kit: Kit, id: TransactionID, fee: BigUInt) async {\n    _ = try? await kit.retryBroadcast(transactionId: id, acceptingNativeFee: fee)\n}\n",
    encoding="utf-8",
)
PY
positive_log="$temporary_root/positive.log"
if xcrun swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
    -target arm64-apple-ios13.0 -sdk "$sdk" -typecheck \
    "${include_args[@]}" "${clang_args[@]}" "$positive" >"$positive_log" 2>&1; then
    :
else
    cat "$positive_log" >&2
    echo "FAIL verify-s2-01-concurrency: caller-task retry-fee snapshot probe did not compile" >&2
    exit 1
fi
stored_control="$temporary_root/StoredBigUIntConcurrency.swift"
python3 - "$stored_control" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "import BigInt\nstruct StoredBigUInt: Sendable { let value: BigUInt }\n",
    encoding="utf-8",
)
PY
if [[ "$dependency" == "5.0.0" ]]; then
    stored_log="$temporary_root/stored-biguint.log"
    if xcrun swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
        -target arm64-apple-ios13.0 -sdk "$sdk" -typecheck \
        "${include_args[@]}" "${clang_args[@]}" "$stored_control" >"$stored_log" 2>&1; then
        echo "FAIL verify-s2-01-concurrency: BigInt 5.0.0 stored-BigUInt Sendable control compiled" >&2
        exit 1
    fi
    if ! rg -F "non-Sendable type 'BigUInt'" "$stored_log" >/dev/null; then
        cat "$stored_log" >&2
        echo "FAIL verify-s2-01-concurrency: BigInt 5.0.0 failed without the expected BigUInt Sendable diagnostic" >&2
        exit 1
    fi
else
    if ! xcrun swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
        -target arm64-apple-ios13.0 -sdk "$sdk" -typecheck \
        "${include_args[@]}" "${clang_args[@]}" "$stored_control" >/dev/null 2>&1; then
        echo "FAIL verify-s2-01-concurrency: BigInt 5.7.0 stored-BigUInt Sendable control did not compile" >&2
        exit 1
    fi
    reference_control="$temporary_root/BadReferenceConcurrency.swift"
    python3 - "$reference_control" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "import BigInt\nfinal class BadReference {}\nfunc accepts(_ body: @Sendable () -> Void) {}\nfunc bad(_ value: BadReference, fee: BigUInt) { accepts { _ = value; _ = fee } }\n",
    encoding="utf-8",
)
PY
    reference_log="$temporary_root/bad-reference.log"
    if xcrun swiftc -swift-version 5 -strict-concurrency=complete -warnings-as-errors \
        -target arm64-apple-ios13.0 -sdk "$sdk" -typecheck \
        "${include_args[@]}" "${clang_args[@]}" "$reference_control" >"$reference_log" 2>&1; then
        echo "FAIL verify-s2-01-concurrency: non-Sendable reference capture control compiled" >&2
        exit 1
    fi
    if ! rg -F "capture of 'value' with non-Sendable type 'BadReference'" "$reference_log" >/dev/null; then
        cat "$reference_log" >&2
        echo "FAIL verify-s2-01-concurrency: reference capture failed without the expected strict-concurrency diagnostic" >&2
        exit 1
    fi
fi

echo "PASS verify-s2-01-concurrency dependency=$dependency"
