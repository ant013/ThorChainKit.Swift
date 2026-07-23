#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
    echo "FAIL verify-s2-01-public-surface: THORCHAIN_SIMULATOR_UDID must contain one UUID" >&2
    exit 1
}

python3 - "$root" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
files = list((root / "Sources/ThorChainKit/Send").rglob("*.swift"))
files.append(root / "Sources/ThorChainKit/Core/Kit+Send.swift")
source = "\n".join(path.read_text(encoding="utf-8") for path in files)
assert ".iOS(.v13)" in (root / "Package.swift").read_text(encoding="utf-8")
assert "import UIKit" not in source
assert "import SwiftUI" not in source
assert "public init" not in source
for forbidden in (
    "TxRaw", "privateKey", "mnemonic", "seed", "rawTransaction",
    "transactionBuilder", "gasOverride", "feeOverride", "sequenceOverride",
    "accountNumberOverride", "URL", "credential", "responseBody",
):
    assert forbidden not in source, forbidden
PY

while IFS= read -r path; do
    git -C "$root" ls-files --error-unmatch "$path" >/dev/null
done < <(rg --files "$root/Sources/ThorChainKit/Send" | sort)
git -C "$root" ls-files --error-unmatch "$root/Sources/ThorChainKit/Core/Kit+Send.swift" >/dev/null

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
derived_data="$temporary_root/derived-data"
consumer_dir="$temporary_root/consumer"
mkdir -p "$derived_data" "$consumer_dir"
log="$derived_data/build.log"
xcodebuild -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -derivedDataPath "$derived_data" \
    SWIFT_VERSION=5 SWIFT_SUPPRESS_WARNINGS=NO CODE_SIGNING_ALLOWED=NO \
    build >"$log" 2>&1

module_dir=$(find "$derived_data/Build/Products" -type d -name ThorChainKit.swiftmodule -print -quit)
include_args=(-I "$module_dir")
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

sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
positive_file="$consumer_dir/PositiveConsumer.swift"
python3 - "$positive_file" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    "import ThorChainKit\nlet _ = SendAmount.maximum\nlet _ = SendError.invalidAmount\n",
    encoding="utf-8",
)
PY
positive_log="$positive_file.log"
if ! xcrun swiftc -target arm64-apple-ios13.0-simulator -sdk "$sdk" -typecheck \
    "${include_args[@]}" "${clang_args[@]}" "$positive_file" >"$positive_log" 2>&1; then
    cat "$positive_log" >&2
    echo "FAIL verify-s2-01-public-surface: external consumer control did not typecheck" >&2
    exit 1
fi

for case_name in SendQuote SigningRequest TransactionID QuoteChanges QuoteChangedArray QuoteAuthorityEnvelope QuoteAuthorityRecord; do
    case_file="$consumer_dir/$case_name.swift"
    python3 - "$case_file" "$case_name" <<'PY'
from pathlib import Path
import sys

case = sys.argv[2]
body = {
    "SendQuote": "import ThorChainKit\nimport Foundation\nlet _ = SendQuote(recipient: fatalError(), amountMagnitude: Data(), isMaximum: false, nativeFeeMagnitude: Data(), totalDebitMagnitude: Data(), memo: nil, acceptedHeight: 1, expiresAt: Date(), authorityRecord: fatalError(), sender: \"sender\")\n",
    "SigningRequest": "import ThorChainKit\nimport Foundation\nlet _ = SigningRequest(digest: Data(repeating: 0, count: 32), serializedSignDoc: Data(), chainId: \"chain\", requestId: \"id\", summary: fatalError())\n",
    "TransactionID": "import ThorChainKit\nlet _ = TransactionID(hash: String(repeating: \"A\", count: 64))\n",
    "QuoteChanges": "import ThorChainKit\nlet _ = QuoteChanges(validating: [])\n",
    "QuoteChangedArray": "import ThorChainKit\nlet _ = SendError.quoteChanged([])\n",
    "QuoteAuthorityEnvelope": "import ThorChainKit\nimport Foundation\nlet _ = QuoteAuthorityEnvelope(clientID: fatalError(), generation: 1, deadline: 1, token: Data())\n",
    "QuoteAuthorityRecord": "import ThorChainKit\nfunc check(_ quote: SendQuote) { _ = quote.internalAuthorityRecord }\n",
}[case]
Path(sys.argv[1]).write_text(body, encoding="utf-8")
PY
    if xcrun swiftc -target arm64-apple-ios13.0-simulator -sdk "$sdk" -typecheck \
        "${include_args[@]}" "${clang_args[@]}" "$case_file" >"$case_file.log" 2>&1; then
        echo "FAIL verify-s2-01-public-surface: $case_name memberwise initializer compiled" >&2
        exit 1
    fi
    case "$case_name" in
        QuoteAuthorityEnvelope)
            expected='cannot call value of non-function type.*module<QuoteAuthorityEnvelope>'
            ;;
        QuoteAuthorityRecord)
            expected="internalAuthorityRecord.*inaccessible due to 'internal' protection level"
            ;;
        QuoteChangedArray)
            expected='cannot convert value of type|no exact matches in call'
            ;;
        *)
            expected="initializer is inaccessible|internal protection level"
            ;;
    esac
    if ! rg -e "$expected" "$case_file.log" >/dev/null; then
        cat "$case_file.log" >&2
        echo "FAIL verify-s2-01-public-surface: $case_name failed without its intended access/name-resolution diagnostic" >&2
        exit 1
    fi
done

echo "PASS verify-s2-01-public-surface"
