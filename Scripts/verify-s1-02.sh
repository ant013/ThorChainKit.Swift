#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"

fail() {
    echo "FAIL verify-s1-02: $1" >&2
    exit 1
}

expected_sources=$(mktemp)
actual_sources=$(mktemp)
actual_tests=$(mktemp)
actual_symbols=$(mktemp)
symbol_dir=$(mktemp -d)
live_tool_dir=$(mktemp -d)
trap 'rm -f "$expected_sources" "$actual_sources" "$actual_tests" "$actual_symbols"; rm -rf "$symbol_dir" "$live_tool_dir"' EXIT

cat > "$expected_sources" <<'EOF'
Sources/ThorChainKit/Address/AddressError.swift
Sources/ThorChainKit/Address/Bech32Codec.swift
Sources/ThorChainKit/Address/BitConversion.swift
Sources/ThorChainKit/Core/Kit.swift
Sources/ThorChainKit/Core/KitConfigurationError.swift
Sources/ThorChainKit/Core/KitDependencies.swift
Sources/ThorChainKit/Core/KitFactory.swift
Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift
Sources/ThorChainKit/Models/AccountState.swift
Sources/ThorChainKit/Models/Address.swift
Sources/ThorChainKit/Models/Denom.swift
Sources/ThorChainKit/Models/EndpointConfiguration.swift
Sources/ThorChainKit/Models/Network.swift
Sources/ThorChainKit/Models/SyncError.swift
Sources/ThorChainKit/Models/SyncState.swift
Sources/ThorChainKit/Network/EndpointDiagnostics.swift
Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift
Sources/ThorChainKit/Network/EndpointHealth.swift
Sources/ThorChainKit/Network/EndpointLease.swift
Sources/ThorChainKit/Network/EndpointPolicy.swift
Sources/ThorChainKit/Network/EndpointPool.swift
Sources/ThorChainKit/Network/LiveNodeProbe.swift
Sources/ThorChainKit/Network/NodeProbing.swift
Sources/ThorChainKit/ThorChainKit.swift
EOF
find Sources/ThorChainKit -type f -name '*.swift' | sort > "$actual_sources"
cmp -s "$expected_sources" "$actual_sources" || fail "production source closure differs"

python3 - Sources Tests 'iOS Example' <<'PY' || fail "Testing SPI boundary differs"
from pathlib import Path
import re
import sys

sources, tests, example = map(Path, sys.argv[1:])
production = list(sources.rglob("*.swift"))
all_swift = production + list(tests.rglob("*.swift")) + list(example.rglob("*.swift"))
imports = [str(path) for path in all_swift if "@_spi(Testing) import ThorChainKit" in path.read_text()]
assert imports
assert all(path.startswith("Tests/") or path.startswith("iOS Example/") for path in imports)

session = (sources / "ThorChainKit/Core/TestingEndpointPolicySession.swift").read_text()
spi_roots = re.findall(r"^@_spi\(Testing\) public (?:struct|enum|class) [^\n]+", session, re.MULTILINE)
assert spi_roots == [
    "@_spi(Testing) public struct TestingEndpointPolicySnapshot: Equatable, Sendable {",
    "@_spi(Testing) public struct TestingEndpointPolicySession: Sendable {",
]
assert session.count("EndpointPool(") == 1
assert session.count("try await pool.lease(excludingFamilyIds: [])") == 1
assert "LiveNodeProbe" not in session

example_source = "\n".join(path.read_text() for path in example.rglob("*.swift"))
assert "EndpointPool" not in example_source
assert "LiveNodeProbe" not in example_source
assert "foreign-secret-chain" not in example_source
PY
echo "PASS verify-s1-02-spi-boundary"

python3 - Tests/ThorChainKitTests <<'PY' || fail "S1-02 tests contain a disabling construct"
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
for name in [
    "EndpointDiagnosticsTests.swift",
    "EndpointPoolTests.swift",
    "LiveNodeProbeTests.swift",
    "TestingEndpointPolicySessionTests.swift",
]:
    source = (root / name).read_text()
    assert re.search(r"XCTSkip|XCTExpectFailure|^\s*#if", source, re.MULTILINE) is None
PY
swift test list --enable-xctest --disable-swift-testing \
    | rg '^ThorChainKitTests\.(EndpointDiagnosticsTests|EndpointPoolTests|LiveNodeProbeTests)/' \
    | sort > "$actual_tests"
cmp -s Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt "$actual_tests" \
    || fail "S1-02 discovered tests differ from the exact allowlist"
echo "PASS verify-s1-02-test-discovery"

swift build --target ThorChainKit >/dev/null
bin_dir=$(swift build --show-bin-path)
target_triple=$(xcrun swiftc -print-target-info | python3 -c 'import json,sys; print(json.load(sys.stdin)["target"]["triple"])')
sdk_dir=$(xcrun --sdk macosx --show-sdk-path)
xcrun swift-symbolgraph-extract \
    -module-name ThorChainKit \
    -I "$bin_dir/Modules" \
    -target "$target_triple" \
    -sdk "$sdk_dir" \
    -minimum-access-level public \
    -skip-synthesized-members \
    -omit-extension-block-symbols \
    -output-dir "$symbol_dir"
python3 - "$symbol_dir/ThorChainKit.symbols.json" > "$actual_symbols" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    graph = json.load(handle)
lines = []
for symbol in graph["symbols"]:
    declaration = "".join(value.get("spelling", "") for value in symbol.get("declarationFragments", []))
    lines.append(f'{symbol["kind"]["identifier"]}\t{".".join(symbol["pathComponents"])}\t{declaration}')
print("\n".join(sorted(lines)))
PY
cmp -s Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt "$actual_symbols" \
    || fail "S1-02 public declarations differ from the exact baseline"
python3 - Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt "$actual_symbols" <<'PY' \
    || fail "an S1-01 declaration was removed or changed"
from pathlib import Path
import sys

baseline = set(Path(sys.argv[1]).read_text().splitlines())
actual = set(Path(sys.argv[2]).read_text().splitlines())
assert baseline <= actual
PY
echo "PASS verify-s1-02-public-symbols"

xcrun swift Scripts/verify-s1-01-factory.swift Tests/ThorChainKitTests/Fixtures/S1-01-factory-syntax.txt >/dev/null \
    || fail "production Kit factory is no longer inert"
echo "PASS verify-s1-02-inert-factory"

xcrun swiftc -parse-as-library Scripts/verify-s1-02-live-evidence.swift \
    -o "$live_tool_dir/verify-s1-02-live-evidence"
"$live_tool_dir/verify-s1-02-live-evidence" self-test \
    "$repository_root" 0123456789abcdef0123456789abcdef01234567
echo "PASS verify-s1-02-live-evidence-mutants"

swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors >/dev/null
swift test --filter LiveNodeProbeTests >/dev/null
swift test --filter EndpointPoolTests >/dev/null
swift test --filter EndpointDiagnosticsTests >/dev/null
echo "PASS verify-s1-02-build-and-tests"

echo "PASS verify-s1-02"
