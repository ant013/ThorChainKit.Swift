#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
s102_contract_head=7fd9663442a0e6dcd9c01c4ab04d35f3abd96fc4

fail() {
    echo "FAIL verify-s1-02: $1" >&2
    exit 1
}

require_simulator() {
    [[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] \
        || fail "THORCHAIN_SIMULATOR_UDID must contain one UUID"
}

run_simulator_tests() {
    local label=$1 selector=$2 allowlist=$3
    local derived_data result_bundle
    local -a selection=()
    while IFS= read -r test_id; do
        [[ "$test_id" == "ThorChainKitTests.${selector}/"* ]] \
            || fail "$label allowlist contains a test outside $selector"
        selection+=("-only-testing:${test_id/./\/}")
    done < "$allowlist"
    ((${#selection[@]} > 0)) || fail "$label allowlist contains no tests"
    require_simulator
    derived_data=$(mktemp -d)
    result_bundle=$(mktemp -d)/"$label.xcresult"
    xcodebuild -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$derived_data" \
        -resultBundlePath "$result_bundle" \
        SWIFT_SUPPRESS_WARNINGS=NO \
        "${selection[@]}" \
        CODE_SIGNING_ALLOWED=NO test \
        || fail "$label" "simulator test command failed"
    Scripts/verify-xcresult.sh "verify-s1-02-$label" "$result_bundle" "$allowlist"
}

verify_endpoint_example_contract() {
    local root=${1:-$repository_root}
    python3 - "$root" "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-02-spi-syntax.txt" <<'PY' \
        || fail "endpoint Example ownership or operation lifetime differs"
from pathlib import Path
import sys

root = Path(sys.argv[1])
fixture_path = Path(sys.argv[2])
fixture = fixture_path.read_text().splitlines()
session = (fixture_path.parents[3] / "Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift").read_text()
example = root / "iOS Example/Sources"
runtime_path = example / "Core/ExampleRuntime.swift"
model_path = example / "Presentation/EndpointsViewModel.swift"
view_path = example / "Views/EndpointsView.swift"
diagnostics_view_path = example / "Views/DiagnosticsView.swift"

def require(condition, reason):
    if not condition:
        raise SystemExit(reason)

require(runtime_path.is_file() and model_path.is_file() and view_path.is_file() and diagnostics_view_path.is_file(), "endpoint-paths")
swift_files = list(example.rglob("*.swift"))
imports = [path for path in swift_files if "@_spi(Testing) import ThorChainKit" in path.read_text()]
require(imports == [runtime_path], "spi-owner")
require(not any("Controller" in path.name for path in swift_files), "controller-path")

runtime = runtime_path.read_text()
model = model_path.read_text()
view = view_path.read_text()
diagnostics_view = diagnostics_view_path.read_text()
combined = "\n".join([session, runtime, model, view, diagnostics_view])
require(runtime.count("TestingEndpointPolicySession(") == 1, "session-owner")
require("TestingEndpointPolicy" not in model and "TestingEndpointPolicy" not in view, "spi-leak")
require(not any(token in model + view for token in ["EndpointPool", "LiveNodeProbe", "URLSession", "retry"]), "duplicate-policy")
require(model.count("operation?.cancel()") >= 2, "operation-cancellation")
require("guard !Task.isCancelled else { return }" in model, "cancellation-guard")
require("guard generation == requestGeneration else { return }" in model, "generation-guard")
require("Text(value)" in view, "dynamic-view")
require(all(token in combined for token in fixture), "spi-fixture")
for identifier in [
    "endpoint-policy-open",
    "endpoint-scenario-healthy",
    "endpoint-scenario-mixed",
    "endpoint-scenario-catching-up",
    "endpoint-scenario-stale-cosmos",
    "endpoint-selected-family",
    "endpoint-expected-identity",
    "endpoint-identity",
    "endpoint-cosmos-origin",
    "endpoint-comet-origin",
    "endpoint-cosmos-height",
    "endpoint-comet-height",
    "endpoint-height-skew",
    "endpoint-catching-up",
    "endpoint-rejection",
]:
    require(identifier in combined, f"identifier-{identifier}")
PY
    echo "PASS verify-s1-02-example-contract"
}

expect_endpoint_example_mutant_rejected() (
    set -euo pipefail
    local label=$1 expected=$2 path=$3 needle=$4 replacement=$5 tmp file output
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/iOS Example"
    cp -R "$repository_root/iOS Example/Sources" "$tmp/iOS Example/Sources"
    file="$tmp/$path"
    python3 - "$file" "$needle" "$replacement" <<'PY' \
        || fail "$label mutation anchor is absent"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
assert sys.argv[2] in source
path.write_text(source.replace(sys.argv[2], sys.argv[3]))
PY
    if output=$(verify_endpoint_example_contract "$tmp" 2>&1); then
        fail "$label mutant passed"
    fi
    [[ "$output" == *"$expected"* ]] \
        || fail "$label mutant failed for the wrong reason: $output"
    echo "mutant rejected: $label"
)

verify_endpoint_example_mutants() {
    expect_endpoint_example_mutant_rejected second-spi-owner spi-owner \
        'iOS Example/Sources/Presentation/EndpointsViewModel.swift' \
        'import Combine' '@_spi(Testing) import ThorChainKit'
    expect_endpoint_example_mutant_rejected missing-cancellation operation-cancellation \
        'iOS Example/Sources/Presentation/EndpointsViewModel.swift' \
        'operation?.cancel()' 'operation = nil'
    expect_endpoint_example_mutant_rejected missing-cancellation-guard cancellation-guard \
        'iOS Example/Sources/Presentation/EndpointsViewModel.swift' \
        'guard !Task.isCancelled else { return }' '_ = Task.isCancelled'
    expect_endpoint_example_mutant_rejected missing-generation-guard generation-guard \
        'iOS Example/Sources/Presentation/EndpointsViewModel.swift' \
        'guard generation == requestGeneration else { return }' '_ = requestGeneration'
    expect_endpoint_example_mutant_rejected static-view dynamic-view \
        'iOS Example/Sources/Views/EndpointsView.swift' \
        'Text(value)' 'Text("static")'
    echo "PASS verify-s1-02-example-mutants"
}

expected_sources=$(mktemp)
actual_sources=$(mktemp)
actual_tests=$(mktemp)
actual_symbols=$(mktemp)
symbol_dir=$(mktemp -d)
live_tool_dir=$(mktemp -d)
test_allowlist_dir=$(mktemp -d)
inert_factory_dir=$(mktemp -d)
trap 'rm -f "$expected_sources" "$actual_sources" "$actual_tests" "$actual_symbols"; rm -rf "$symbol_dir" "$live_tool_dir" "$test_allowlist_dir" "$inert_factory_dir"' EXIT

cat > "$expected_sources" <<'EOF'
Sources/ThorChainKit/Address/AddressCodec.swift
Sources/ThorChainKit/Address/AddressError.swift
Sources/ThorChainKit/Address/Bech32Codec.swift
Sources/ThorChainKit/Address/BitConversion.swift
Sources/ThorChainKit/Core/Kit.swift
Sources/ThorChainKit/Core/KitConfigurationError.swift
Sources/ThorChainKit/Core/KitDependencies.swift
Sources/ThorChainKit/Core/KitFactory.swift
Sources/ThorChainKit/Core/TestingAccountReadSession.swift
Sources/ThorChainKit/Core/TestingEndpointPolicySession.swift
Sources/ThorChainKit/Crypto/AccountAddressDeriving.swift
Sources/ThorChainKit/Crypto/AccountAddressFactory.swift
Sources/ThorChainKit/Crypto/CosmosAccountAddressDeriver.swift
Sources/ThorChainKit/Crypto/DerivationPath.swift
Sources/ThorChainKit/Crypto/Secp256k1PublicKeyValidator.swift
Sources/ThorChainKit/Models/AccountState.swift
Sources/ThorChainKit/Models/Address.swift
Sources/ThorChainKit/Models/Denom.swift
Sources/ThorChainKit/Models/EndpointConfiguration.swift
Sources/ThorChainKit/Models/Network.swift
Sources/ThorChainKit/Models/SyncError.swift
Sources/ThorChainKit/Models/SyncState.swift
Sources/ThorChainKit/Network/AccountReadTransport.swift
Sources/ThorChainKit/Network/EndpointDiagnostics.swift
Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift
Sources/ThorChainKit/Network/EndpointHealth.swift
Sources/ThorChainKit/Network/EndpointLease.swift
Sources/ThorChainKit/Network/EndpointPolicy.swift
Sources/ThorChainKit/Network/EndpointPool.swift
Sources/ThorChainKit/Network/HTTPTransporting.swift
Sources/ThorChainKit/Network/LiveNodeProbe.swift
Sources/ThorChainKit/Network/LiveThorNodeClient.swift
Sources/ThorChainKit/Network/NodeProbing.swift
Sources/ThorChainKit/Network/ReadOperationCoordinator.swift
Sources/ThorChainKit/Network/RequestBuilder.swift
Sources/ThorChainKit/Network/ThorNodeReadError.swift
Sources/ThorChainKit/Network/ThorNodeReading.swift
Sources/ThorChainKit/State/AccountStateManager.swift
Sources/ThorChainKit/State/StatePublishing.swift
Sources/ThorChainKit/State/StateSnapshot.swift
Sources/ThorChainKit/Storage/AccountStateStorage.swift
Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift
Sources/ThorChainKit/Storage/Migrations.swift
Sources/ThorChainKit/Storage/StorageRecord.swift
Sources/ThorChainKit/Sync/AccountSyncer.swift
Sources/ThorChainKit/Sync/AccountSyncing.swift
Sources/ThorChainKit/Sync/LifecycleCommandBridge.swift
Sources/ThorChainKit/Sync/LifecycleGate.swift
Sources/ThorChainKit/Sync/SyncGeneration.swift
Sources/ThorChainKit/Sync/SyncSchedule.swift
Sources/ThorChainKit/ThorChainKit.swift
EOF
find Sources/ThorChainKit -type f -name '*.swift' | sort > "$actual_sources"
cmp -s "$expected_sources" "$actual_sources" || fail "production source closure differs"

verify_endpoint_example_contract
verify_endpoint_example_mutants

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
assert [path for path in imports if path.startswith("iOS Example/")] == [
    "iOS Example/Sources/Core/ExampleRuntime.swift"
]

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
require_simulator
rg '^ThorChainKitTests\.EndpointDiagnosticsTests/' Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt > "$test_allowlist_dir/endpoints.txt"
rg '^ThorChainKitTests\.EndpointPoolTests/' Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt > "$test_allowlist_dir/pool.txt"
rg '^ThorChainKitTests\.LiveNodeProbeTests/' Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt > "$test_allowlist_dir/live.txt"
run_simulator_tests endpoints EndpointDiagnosticsTests "$test_allowlist_dir/endpoints.txt"
run_simulator_tests pool EndpointPoolTests "$test_allowlist_dir/pool.txt"
run_simulator_tests live LiveNodeProbeTests "$test_allowlist_dir/live.txt"
echo "PASS verify-s1-02-test-discovery"

derived_data=$(mktemp -d)
xcodebuild -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -derivedDataPath "$derived_data" \
    SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=NO build >/dev/null \
    || fail "S1-02 public symbols" "iOS Simulator package build failed"
xcrun swift-symbolgraph-extract \
    -module-name ThorChainKit \
    -I "$derived_data/Build/Products/Debug-iphonesimulator" \
    -Xcc -fmodule-map-file="$derived_data/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/secp256k1_bindings.modulemap" \
    -Xcc -fmodule-map-file="$derived_data/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/HsCryptoKitC.modulemap" \
    -Xcc -fmodule-map-file="$derived_data/SourcePackages/checkouts/GRDB.swift/Sources/CSQLite/module.modulemap" \
    -target arm64-apple-ios13.0-simulator \
    -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
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
python3 - Tests/ThorChainKitTests/Fixtures/S1-02-public-symbols.txt "$actual_symbols" <<'PY' \
    || fail "S1-02 public declarations differ from the exact baseline"
from pathlib import Path
import sys

baseline = set(Path(sys.argv[1]).read_text().splitlines())
actual = set(Path(sys.argv[2]).read_text().splitlines())
assert baseline <= actual
PY
python3 - Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt "$actual_symbols" <<'PY' \
    || fail "an S1-01 declaration was removed or changed"
from pathlib import Path
import sys

baseline = set(Path(sys.argv[1]).read_text().splitlines())
actual = set(Path(sys.argv[2]).read_text().splitlines())
assert baseline <= actual
PY
echo "PASS verify-s1-02-public-symbols"

git merge-base --is-ancestor "$s102_contract_head" HEAD \
    || fail "accepted S1-02 contract head is not an ancestor"
git archive "$s102_contract_head" \
    Scripts/verify-s1-01-factory.swift \
    Sources/ThorChainKit/Core/KitFactory.swift \
    Sources/ThorChainKit/Core/KitDependencies.swift \
    Sources/ThorChainKit/Core/Kit.swift \
    Sources/ThorChainKit/Models/Network.swift \
    Tests/ThorChainKitTests/Fixtures/S1-01-factory-syntax.txt \
    | tar -x -C "$inert_factory_dir" \
    || fail "accepted S1-02 factory contract could not be materialized"
(
    cd "$inert_factory_dir"
    xcrun swift Scripts/verify-s1-01-factory.swift \
        Tests/ThorChainKitTests/Fixtures/S1-01-factory-syntax.txt
) >/dev/null \
    || fail "production Kit factory is no longer inert"
echo "PASS verify-s1-02-inert-factory"

xcrun swiftc -parse-as-library Scripts/verify-s1-02-live-evidence.swift \
    -o "$live_tool_dir/verify-s1-02-live-evidence"
"$live_tool_dir/verify-s1-02-live-evidence" self-test \
    "$repository_root" 0123456789abcdef0123456789abcdef01234567
echo "PASS verify-s1-02-live-evidence-mutants"

strict_data=$(mktemp -d)
xcodebuild -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=${simulator_udid}" \
    -derivedDataPath "$strict_data" \
    SWIFT_VERSION=5 \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=NO build >/dev/null \
    || fail "S1-02 build" "strict-concurrency simulator build failed"
echo "PASS verify-s1-02-build-and-tests"

echo "PASS verify-s1-02"
