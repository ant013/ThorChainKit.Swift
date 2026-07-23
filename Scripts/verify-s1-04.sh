#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"

fail() {
    echo "FAIL verify-s1-04: $1" >&2
    exit 1
}

expected_base=
expected_head=
source_only=false
fixtures_only=false
while (($#)); do
    case "$1" in
        --expected-base)
            (($# >= 2)) || fail "--expected-base requires a value"
            expected_base=$2
            shift 2
            ;;
        --expected-head)
            (($# >= 2)) || fail "--expected-head requires a value"
            expected_head=$2
            shift 2
            ;;
        --source-only)
            source_only=true
            shift
            ;;
        --fixtures-only)
            fixtures_only=true
            shift
            ;;
        *) fail "unknown argument: $1" ;;
    esac
done

if [[ "$source_only" == false && "$fixtures_only" == false ]]; then
    [[ "$expected_base" =~ ^[0-9a-f]{40}$ ]] || fail "expected base must be a 40-character SHA"
    [[ "$expected_head" =~ ^[0-9a-f]{40}$ ]] || fail "expected head must be a 40-character SHA"
    [[ "$(git rev-parse HEAD)" == "$expected_head" ]] || fail "HEAD is not the expected head"
    [[ -z "$(git status --porcelain)" ]] || fail "worktree is not clean"
    [[ "$(git rev-parse refs/remotes/origin/main)" == "$expected_base" ]] \
        || fail "origin/main is not the expected base"
    git merge-base --is-ancestor "$expected_base" "$expected_head" \
        || fail "expected base is not an ancestor of expected head"
fi

python3 - "$repository_root" <<'PY' || fail "source, SPI, Example, or fixture contract differs"
from pathlib import Path
import json
import re
import sys

root = Path(sys.argv[1])
required = [
    "Sources/ThorChainKit/Network/HTTPTransporting.swift",
    "Sources/ThorChainKit/Network/RequestBuilder.swift",
    "Sources/ThorChainKit/Network/ThorNodeReading.swift",
    "Sources/ThorChainKit/Network/LiveThorNodeClient.swift",
    "Sources/ThorChainKit/Network/ReadOperationCoordinator.swift",
    "Sources/ThorChainKit/Network/AccountReadTransport.swift",
    "Sources/ThorChainKit/Network/ThorNodeReadError.swift",
    "Sources/ThorChainKit/Core/TestingAccountReadSession.swift",
    "Tests/ThorChainKitTests/LiveThorNodeClientS1_04Tests.swift",
    "Tests/ThorChainKitTests/ReadOperationCoordinatorS1_04Tests.swift",
    "Tests/ThorChainKitTests/EndpointInstantS1_04Tests.swift",
    "Tests/ThorChainKitTests/TestingAccountReadSessionS1_04Tests.swift",
    "Tests/ThorChainKitTests/S1_04ContractTests.swift",
    "Tests/ThorChainKitLiveTests/MainnetReadTests.swift",
    "Tests/ThorChainKitTests/Fixtures/S1-04-public-symbols.txt",
    "Tests/ThorChainKitTests/Fixtures/S1-04-spi-syntax.txt",
    "Tests/ThorChainKitTests/Fixtures/S1-04-tests.txt",
    "Tests/ThorChainKitLiveTests/Fixtures/S1-04-live-tests.txt",
    "iOS Example/Sources/Presentation/AccountReadViewModel.swift",
    "iOS Example/Sources/Views/AccountReadView.swift",
    ".maestro/flows/03-account-read-fixture.yaml",
]
for relative in required:
    assert (root / relative).is_file(), relative

def text(relative):
    return (root / relative).read_text()

http = text("Sources/ThorChainKit/Network/HTTPTransporting.swift")
probe_contract = text("Sources/ThorChainKit/Network/NodeProbing.swift")
probe = text("Sources/ThorChainKit/Network/LiveNodeProbe.swift")
builder = text("Sources/ThorChainKit/Network/RequestBuilder.swift")
client = text("Sources/ThorChainKit/Network/LiveThorNodeClient.swift")
coordinator = text("Sources/ThorChainKit/Network/ReadOperationCoordinator.swift")
transport = text("Sources/ThorChainKit/Network/AccountReadTransport.swift")
errors = text("Sources/ThorChainKit/Network/ThorNodeReadError.swift")
pool = text("Sources/ThorChainKit/Network/EndpointPool.swift")
health = text("Sources/ThorChainKit/Network/EndpointHealth.swift")
spi = text("Sources/ThorChainKit/Core/TestingAccountReadSession.swift")
new_production = "\n".join([http, builder, client, coordinator, transport, errors, spi])
all_production = "\n".join(path.read_text() for path in (root / "Sources/ThorChainKit").rglob("*.swift"))

assert http.count("protocol HTTPTransporting: Sendable") == 1
assert http.count("struct URLSessionTransport: HTTPTransporting") == 1
assert "protocol HTTPTransporting" not in probe_contract
assert "struct URLSessionTransport" not in probe
assert "protocol HttpTransport" not in all_production
assert "URLSessionHttpTransport" not in all_production
assert "URLComponents" in builder and "percentEncodedPath" in builder and "queryItems" in builder
assert "RequestBuilder" in probe and "RequestBuilder" in client
assert '"/cosmos.auth.v1beta1.BaseAccount"' in client
assert "x-cosmos-block-height" in (builder + client).lower()
assert "maximumBalancePageCount" in client
assert "nextKey" in client or "next_key" in client
assert "pagination.total" not in client
assert "func isCurrent(_ lease: EndpointLease)" in pool
assert "recordFailure(for:" in coordinator and "lease(excludingFamilyIds:" in coordinator
assert "withTaskGroup" in coordinator or "withThrowingTaskGroup" in coordinator
assert "Retry-After" in (builder + client + coordinator + errors)
assert "addingReportingOverflow" in health
assert "isFinite" in health
assert " &+ " not in health
assert "AccountReadWallClock" in coordinator
assert "@unchecked Sendable" not in new_production
assert "import UIKit" not in all_production and "import SwiftUI" not in all_production
assert "try?" not in "\n".join([builder, client, coordinator, transport, errors])
for source in [http, builder, client, coordinator, transport, errors]:
    assert not re.search(r"^public\s|^open\s", source, re.MULTILINE)

spi_roots = re.findall(
    r"^@_spi\(Testing\) public (?:protocol|struct|enum|class) [^\n]+",
    spi,
    re.MULTILINE,
)
assert spi_roots == [
    "@_spi(Testing) public protocol TestingHTTPTransport: Sendable {",
    "@_spi(Testing) public struct TestingAccountReadProjection: Equatable, Sendable {",
    "@_spi(Testing) public struct TestingAccountReadSession: Sendable {",
]
assert spi.count("LiveNodeProbe(") == 1
assert spi.count("EndpointPool(") == 1
assert spi.count("LiveThorNodeClient(") == 1
assert spi.count("ReadOperationCoordinator(") == 1
assert "Kit.instance" not in spi and "URLSession.shared" not in spi
session_body = spi[spi.index("public struct TestingAccountReadSession"):]
session_initializer = session_body[session_body.index("public init("):session_body.index(")", session_body.index("public init("))]
assert "network:" not in session_initializer

example_root = root / "iOS Example/Sources"
example_files = sorted(example_root.rglob("*.swift"))
spi_importers = [path.relative_to(root).as_posix() for path in example_files if "@_spi(Testing) import ThorChainKit" in path.read_text()]
assert spi_importers == ["iOS Example/Sources/Core/ExampleRuntime.swift"]
runtime = text("iOS Example/Sources/Core/ExampleRuntime.swift")
model = text("iOS Example/Sources/Presentation/AccountReadViewModel.swift")
view = text("iOS Example/Sources/Views/AccountReadView.swift")
diagnostics = text("iOS Example/Sources/Views/DiagnosticsView.swift")
example = "\n".join(path.read_text() for path in example_files)
assert runtime.count("TestingAccountReadSession(") == 1
assert "TestingAccountRead" not in model and "TestingAccountRead" not in view
assert not any(token in model + view for token in ["EndpointPool", "LiveNodeProbe", "URLSession", "retry"])
assert model.count("operation?.cancel()") >= 2
assert "guard !Task.isCancelled else { return }" in model
assert "guard generation == requestGeneration else { return }" in model
assert "NavigationLink(destination: AccountReadView" in diagnostics
assert "Text(value)" in view
for identifier in [
    "account-read-open",
    "account-read-mode",
    "account-read-exists",
    "account-read-rune",
    "account-read-height",
    "account-read-family",
]:
    assert identifier in example
assert "import UIKit" not in example

flow = text(".maestro/flows/03-account-read-fixture.yaml")
for value in [
    "id: account-read-open",
    "id: account-read-mode",
    "text: FIXTURE",
    "id: account-read-exists",
    'text: "true"',
    "id: account-read-rune",
    'text: "340282366920938463463374607431768211456"',
    "id: account-read-height",
    'text: "12345678"',
    "id: account-read-family",
    "text: fixture-primary",
]:
    assert flow.count(value) == 1, value

package = text("Package.swift")
assert package.count('name: "ThorChainKitLiveTests"') == 1
assert package.count('swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]') >= 3
assert "platforms: [.iOS(.v13)]" in package

fixture_root = root / "Tests/ThorChainKitTests/Fixtures"
json_fixtures = sorted(fixture_root.glob("S1-04-*.json"))
assert json_fixtures
for path in json_fixtures:
    value = path.read_text()
    json.loads(value)
    assert not re.search(r"(?i)(/Users/|/private/|file://|mnemonic|seed phrase|private key|api.?key|bearer)", value)

syntax = text("Tests/ThorChainKitTests/Fixtures/S1-04-spi-syntax.txt").splitlines()
assert syntax and len(syntax) == len(set(syntax))
combined_spi = "\n".join([spi, runtime, model, view, diagnostics])
assert all(marker and marker in combined_spi for marker in syntax)

test_classes = {
    "LiveThorNodeClientS1_04Tests",
    "ReadOperationCoordinatorS1_04Tests",
    "EndpointInstantS1_04Tests",
    "TestingAccountReadSessionS1_04Tests",
    "S1_04ContractTests",
}
actual_tests = []
test_paths = [root / f"Tests/ThorChainKitTests/{name}.swift" for name in test_classes]
for path in test_paths:
    source = path.read_text()
    assert re.search(r"XCTSkip|XCTExpectFailure|^\s*#if|@available", source, re.MULTILINE) is None
    match = re.search(r"final class (\w+): XCTestCase", source)
    assert match and match.group(1) in test_classes
    for method in re.findall(r"^\s*func (test\w+)\s*\(", source, re.MULTILINE):
        actual_tests.append(f"ThorChainKitTests.{match.group(1)}/{method}")
assert {line.split(".", 1)[1].split("/", 1)[0] for line in actual_tests} == test_classes
expected_tests = [line for line in text("Tests/ThorChainKitTests/Fixtures/S1-04-tests.txt").splitlines() if line]
assert sorted(actual_tests) == sorted(expected_tests)
assert len(expected_tests) == len(set(expected_tests))

live_source = text("Tests/ThorChainKitLiveTests/MainnetReadTests.swift")
assert re.search(r"XCTSkip|XCTExpectFailure|^\s*#if|@available", live_source, re.MULTILINE) is None
live_methods = re.findall(r"^\s*func (test\w+)\s*\(", live_source, re.MULTILINE)
live_expected = [line for line in text("Tests/ThorChainKitLiveTests/Fixtures/S1-04-live-tests.txt").splitlines() if line]
assert sorted(live_expected) == sorted(
    f"ThorChainKitLiveTests.MainnetReadTests/{method}" for method in live_methods
)
assert live_expected and len(live_expected) == len(set(live_expected))

runner = text("Scripts/run-maestro.sh")
manifest = text(".maestro/config.yaml")
assert runner.count("s1-04) flow_path=.maestro/flows/03-account-read-fixture.yaml ;;") == 1
assert manifest.splitlines() == [
    "flows:",
    "  - flows/00-launch-foundation.yaml",
    "  - flows/01-endpoint-policy.yaml",
    "  - flows/02-address-codec.yaml",
    "  - flows/03-account-read-fixture.yaml",
]

for script in ["Scripts/verify-s1-03.sh", "Scripts/verify-bigint-floor.sh", "Scripts/verify-s1-04.sh"]:
    source = text(script)
    assert "-only-testing:ThorChainKitTests" in source, script
assert "-only-testing:ThorChainKitLiveTests" in text("Scripts/verify-s1-04-live.sh")
PY
echo "PASS verify-s1-04-source-contract"

Scripts/verify-s1-02-ci-policy.sh steady-state --ref "$(git rev-parse HEAD)" >/dev/null \
    || fail "build-only Actions policy differs"
echo "PASS verify-s1-04-build-only-actions"

if [[ "$source_only" == true || "$fixtures_only" == true ]]; then
    if [[ "$fixtures_only" == true ]]; then
        echo "PASS verify-s1-04-fixtures-only"
    else
        echo "PASS verify-s1-04-source-only"
    fi
    exit 0
fi

simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
    || fail "THORCHAIN_SIMULATOR_UDID must contain one UUID"

temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
derived_data="$temporary_root/DerivedData"
result_bundle="$temporary_root/ThorChainKitTests.xcresult"
allowlist="$temporary_root/all-tests.txt"
symbol_dir="$temporary_root/Symbols"
actual_symbols="$temporary_root/public-symbols.txt"

cat Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt \
    Tests/ThorChainKitTests/Fixtures/S1-02-tests.txt \
    Tests/ThorChainKitTests/Fixtures/S1-03-tests.txt \
    Tests/ThorChainKitTests/Fixtures/S1-04-tests.txt \
    Tests/ThorChainKitTests/Fixtures/S1-05-tests.txt \
    | sort -u > "$allowlist"

selection=()
while IFS= read -r test_id; do
    [[ "$test_id" == ThorChainKitTests.*/* ]] \
        || fail "test allowlist contains an invalid identifier"
    selection+=("-only-testing:ThorChainKitTests/${test_id#ThorChainKitTests.}")
done < "$allowlist"
((${#selection[@]} > 0)) || fail "test allowlist contains no tests"

xcodebuild \
    -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    "${selection[@]}" \
    SWIFT_VERSION=5 \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=NO \
    test || fail "deterministic strict-concurrency test command failed"
Scripts/verify-xcresult.sh verify-s1-04 "$result_bundle" "$allowlist"
echo "PASS verify-s1-04-tests"

mkdir -p "$symbol_dir"
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
cmp -s Tests/ThorChainKitTests/Fixtures/S1-04-public-symbols.txt "$actual_symbols" \
    || fail "public declarations differ from the exact S1-04 baseline"
echo "PASS verify-s1-04-public-symbols"

for script in \
    Scripts/verify-s1-04.sh \
    Scripts/test-s1-04-mutants.sh \
    Scripts/verify-s1-04-live.sh
do
    [[ -x "$script" ]] || fail "$script is not executable"
    [[ "$(git ls-files -s "$script" | awk '{print $1}')" == 100755 ]] \
        || fail "$script Git mode is not 100755"
done
echo "PASS verify-s1-04-script-modes"
echo "PASS verify-s1-04"
