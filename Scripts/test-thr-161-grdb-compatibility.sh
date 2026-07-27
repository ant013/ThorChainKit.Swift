#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
base_revision=65c8e370db983c6bd500448266a4f8f51561ca5f
approved_marketkit_url=https://github.com/horizontalsystems/MarketKit.Swift.git
approved_marketkit_revision=2c327452237cfbbdc4d87bcd5dd417d1da46a61e
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
[[ "$marketkit_url" == "$approved_marketkit_url" ]] || {
    echo "FAIL THR-161: MarketKit URL is not the approved repository" >&2
    exit 1
}
[[ "$marketkit_revision" =~ ^[0-9a-f]{40}$ ]] || {
    echo "FAIL THR-161: MarketKit revision must be a 40-character SHA" >&2
    exit 1
}
[[ "$marketkit_revision" == "$approved_marketkit_revision" ]] || {
    echo "FAIL THR-161: MarketKit revision is not the approved commit" >&2
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
base_kit="$temporary_root/base-kit"
red_fixture="$temporary_root/red-host"
fixture="$temporary_root/host"
mkdir -p "$base_kit" "$red_fixture/Sources/Host" "$fixture/Sources/Host"
git archive "$base_revision" | tar -x -C "$base_kit"
python3 - "$red_fixture/Package.swift" "$red_fixture/Sources/Host/main.swift" "$base_kit" "$fixture/Package.swift" "$fixture/Sources/Host/main.swift" "$repository_root" "$marketkit_url" "$marketkit_revision" <<'PY'
import sys
import json
from pathlib import Path

red_manifest, red_source, red_kit, manifest, source, kit_path, marketkit_url, marketkit_revision = sys.argv[1:]

def write_fixture(manifest, source, kit_path):
    kit_literal = json.dumps(kit_path)
    marketkit_url_literal = json.dumps(marketkit_url)
    marketkit_revision_literal = json.dumps(marketkit_revision)
    Path(manifest).write_text(f'''// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "THR161Host",
    dependencies: [
        .package(name: "ThorChainKit.Swift", path: {kit_literal}),
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

write_fixture(red_manifest, red_source, red_kit)
write_fixture(manifest, source, kit_path)
PY

red_log="$temporary_root/red-resolve.log"
if xcrun swift package --package-path "$red_fixture" resolve --skip-update >"$red_log" 2>&1; then
    echo "FAIL THR-161 frozen 6.29.1 graph unexpectedly resolved" >&2
    exit 1
fi
grep -F "6.29.1" "$red_log" >/dev/null || {
    echo "FAIL THR-161 frozen graph failed for an unexpected reason" >&2
    exit 1
}
grep -F "6.29.3" "$red_log" >/dev/null || {
    echo "FAIL THR-161 frozen graph did not exercise the MarketKit GRDB floor" >&2
    exit 1
}
echo "PASS THR-161 frozen 6.29.1 graph is rejected"

xcrun swift package --package-path "$fixture" resolve --skip-update
python3 - "$fixture/Package.resolved" "$marketkit_revision" <<'PY'
import json
import sys
from pathlib import Path

lock_path, expected_revision = sys.argv[1:]
lock = json.loads(Path(lock_path).read_text(encoding="utf-8"))
marketkit = next((pin for pin in lock["pins"] if pin["identity"] == "marketkit.swift"), None)
if marketkit is None or marketkit["state"].get("revision") != expected_revision:
    raise SystemExit("FAIL THR-161 host lockfile does not pin the approved MarketKit revision")
print("PASS THR-161 host lockfile pins the approved MarketKit revision")
PY
lock_after=$(shasum -a 256 "$repository_root/Package.resolved" | awk '{print $1}')
[[ "$lock_before" == "$lock_after" ]] || {
    echo "FAIL THR-161 host fixture changed the committed lockfile" >&2
    exit 1
}

echo "PASS THR-161 isolated MarketKit host graph and lockfile preservation"
