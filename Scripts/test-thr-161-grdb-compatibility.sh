#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
base_revision=65c8e370db983c6bd500448266a4f8f51561ca5f
marketkit_url=
marketkit_revision=

while (($#)); do
    case "$1" in
        --marketkit-url)
            (($# >= 2)) || { echo "FAIL THR-161: --marketkit-url requires a value" >&2; exit 1; }
            marketkit_url=$2
            shift 2
            ;;
        --marketkit-revision)
            (($# >= 2)) || { echo "FAIL THR-161: --marketkit-revision requires a value" >&2; exit 1; }
            marketkit_revision=$2
            shift 2
            ;;
        *)
            echo "FAIL THR-161: unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

[[ -n "$marketkit_url" && -n "$marketkit_revision" ]] || {
    echo "FAIL THR-161: approved MarketKit URL and revision are required" >&2
    exit 1
}
[[ "$marketkit_revision" =~ ^[0-9a-f]{40}$ ]] || {
    echo "FAIL THR-161: MarketKit revision must be a 40-character SHA" >&2
    exit 1
}

lock_before=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')

python3 - "$repository_root" "$base_revision" <<'PY'
import hashlib
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
base = sys.argv[2]
package = (root / "Package.swift").read_text(encoding="utf-8")
lock = json.loads((root / "Package.resolved").read_text(encoding="utf-8"))
base_lock = json.loads(subprocess.check_output(["git", "show", f"{base}:Package.resolved"], text=True))
pins = {pin["identity"]: pin for pin in lock["pins"]}
base_pins = {pin["identity"]: pin for pin in base_lock["pins"]}

assert package.count('exact: "6.29.3"') == 1
assert 'exact: "6.29.1"' not in package
assert "platforms: [.iOS(.v13)" in package
assert pins["grdb.swift"]["state"] == {
    "revision": "2cf6c756e1e5ef6901ebae16576a7e4e4b834622",
    "version": "6.29.3",
}
assert pins["grdb.swift"]["location"] == "https://github.com/groue/GRDB.swift.git"
assert set(pins) == set(base_pins)
for identity in pins:
    if identity != "grdb.swift":
        assert pins[identity] == base_pins[identity], identity
assert lock["originHash"] == hashlib.sha256((root / "Package.swift").read_bytes()).hexdigest()
print("PASS THR-161 manifest and lockfile contract")
PY

temporary_root=$(mktemp -d)
fixture="$temporary_root/host"
mkdir -p "$fixture/Sources/Host"
python3 - "$fixture/Package.swift" "$fixture/Sources/Host/main.swift" "$repository_root" "$marketkit_url" "$marketkit_revision" <<'PY'
import sys
import json
from pathlib import Path

manifest, source, kit_path, marketkit_url, marketkit_revision = sys.argv[1:]
kit_literal = json.dumps(kit_path)
marketkit_url_literal = json.dumps(marketkit_url)
marketkit_revision_literal = json.dumps(marketkit_revision)
Path(manifest).write_text(f'''// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "THR161Host",
    dependencies: [
        .package(path: {kit_literal}),
        .package(url: {marketkit_url_literal}, revision: {marketkit_revision_literal}),
    ],
    targets: [
        .executableTarget(
            name: "Host",
            dependencies: [
                .product(name: "ThorChainKit", package: "ThorChainKit.Swift"),
                .product(name: "MarketKit", package: "MarketKit.Swift"),
            ]
        )
    ]
)
''', encoding="utf-8")
Path(source).write_text("import ThorChainKit\nimport MarketKit\n", encoding="utf-8")
PY

xcrun swift package --package-path "$fixture" resolve --skip-update
lock_after=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')
[[ "$lock_before" == "$lock_after" ]] || {
    echo "FAIL THR-161 host fixture changed the committed lockfile" >&2
    exit 1
}

echo "PASS THR-161 isolated MarketKit host graph and lockfile preservation"
