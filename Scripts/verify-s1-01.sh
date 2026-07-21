#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}

fail() {
    echo "FAIL $1: $2" >&2
    exit 1
}

require_simulator() {
    [[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] \
        || fail "verify-s1-01-simulator" "THORCHAIN_SIMULATOR_UDID must contain one UUID"
}

run_simulator_tests() {
    local label=$1 selector=$2 allowlist=$3
    local derived_data result_bundle
    local -a selection=("-only-testing:ThorChainKitTests/$selector")
    require_simulator
    derived_data=$(mktemp -d)
    result_bundle=$(mktemp -d)/"$label.xcresult"
    xcodebuild -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$derived_data" \
        -resultBundlePath "$result_bundle" \
        "${selection[@]}" \
        CODE_SIGNING_ALLOWED=NO test \
        || fail "verify-s1-01-$label" "simulator test command failed"
    Scripts/verify-xcresult.sh "verify-s1-01-$label" "$result_bundle" "$allowlist"
}

verify_platform_boundary() {
    local root=${1:-$repository_root}
    python3 - "$root" <<'PY' \
        || fail "verify-s1-01-platform" "SwiftUI/Combine platform boundary mismatch"
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
library = list((root / "Sources/ThorChainKit").rglob("*.swift"))
example = list((root / "iOS Example/Sources").rglob("*.swift"))

def require(condition, reason):
    if not condition:
        raise SystemExit(reason)

def combined(paths):
    return "\n".join(path.read_text() for path in paths)

library_source = combined(library)
example_source = combined(example)
require("import UIKit" not in library_source and "import UIKit" not in example_source, "ui-import")
require(not re.search(r"\b(UIApplicationDelegate|UIWindow|UIViewController|UIViewRepresentable|UIViewControllerRepresentable)\b", example_source), "ui-type")
require("import SwiftUI" not in library_source, "library-swiftui")

package = (root / "Package.swift").read_text()
require(".iOS(.v13)" in package, "library-floor")

project = (root / "iOS Example/iOS Example.xcodeproj/project.pbxproj").read_text()
targets = [float(value) for value in re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", project)]
require(targets and min(targets) >= 14.0, "example-floor")
require(not any(name in project for name in ["AppDelegate.swift", "MainController.swift", "DiagnosticsController.swift", "EndpointsController.swift"]), "controller-path")

app_path = root / "iOS Example/Sources/ThorChainExampleApp.swift"
diagnostics_path = root / "iOS Example/Sources/Presentation/DiagnosticsViewModel.swift"
diagnostics_view_path = root / "iOS Example/Sources/Views/DiagnosticsView.swift"
require(app_path.is_file() and diagnostics_view_path.is_file(), "missing-swiftui")
app = app_path.read_text()
require("import SwiftUI" in app and "import SwiftUI" in diagnostics_view_path.read_text(), "missing-swiftui")
require(re.search(r"@main\s+struct\s+ThorChainExampleApp\s*:\s*App\b", app), "missing-app")

require(diagnostics_path.is_file(), "diagnostics-model")
diagnostics = diagnostics_path.read_text()
require(re.search(r"(?m)^@MainActor$", diagnostics) and "ObservableObject" in diagnostics, "main-actor")
for publisher in ["lastBlockHeightPublisher", "syncStatePublisher", "accountStatePublisher"]:
    require(publisher in diagnostics, f"publisher-{publisher}")
require(not re.search(r"runtime\.kit\.(lastBlockHeight|syncState|accountState)\b", diagnostics), "scalar-snapshot")
require("Set<AnyCancellable>" in diagnostics and diagnostics.count(".store(in: &cancellables)") >= 3, "retained-cancellation")
require(diagnostics.count(".receive(on: DispatchQueue.main)") >= 3, "main-hop")
PY
    echo "PASS verify-s1-01-platform"
}

expect_platform_mutant_rejected() (
    set -euo pipefail
    local label=$1 expected=$2 path=$3 needle=$4 replacement=$5 tmp file output
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    cp "$repository_root/Package.swift" "$tmp/Package.swift"
    mkdir -p "$tmp/Sources" "$tmp/iOS Example"
    cp -R "$repository_root/Sources/ThorChainKit" "$tmp/Sources/ThorChainKit"
    cp -R "$repository_root/iOS Example/Sources" "$tmp/iOS Example/Sources"
    cp -R "$repository_root/iOS Example/iOS Example.xcodeproj" "$tmp/iOS Example/iOS Example.xcodeproj"
    file="$tmp/$path"
    python3 - "$file" "$needle" "$replacement" <<'PY' \
        || fail "verify-s1-01-platform-$label" "mutation anchor is absent"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
assert sys.argv[2] in source
path.write_text(source.replace(sys.argv[2], sys.argv[3]))
PY
    if output=$(verify_platform_boundary "$tmp" 2>&1); then
        fail "verify-s1-01-platform-$label" "mutant passed"
    fi
    [[ "$output" == *"$expected"* ]] \
        || fail "verify-s1-01-platform-$label" "mutant failed for the wrong reason: $output"
    echo "mutant rejected: $label"
)

verify_platform_mutants() {
    expect_platform_mutant_rejected library-uikit ui-import \
        Sources/ThorChainKit/Core/Kit.swift 'import Combine' $'import Combine\nimport UIKit'
    expect_platform_mutant_rejected example-uikit ui-import \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' 'import Combine' $'import Combine\nimport UIKit'
    expect_platform_mutant_rejected ui-type ui-type \
        'iOS Example/Sources/ThorChainExampleApp.swift' 'struct ThorChainExampleApp: App' 'struct ThorChainExampleApp: UIApplicationDelegate'
    expect_platform_mutant_rejected representable ui-type \
        'iOS Example/Sources/Views/DiagnosticsView.swift' 'struct DiagnosticsView: View' 'struct DiagnosticsView: UIViewRepresentable'
    expect_platform_mutant_rejected library-swiftui library-swiftui \
        Sources/ThorChainKit/Core/Kit.swift 'import Combine' $'import Combine\nimport SwiftUI'
    expect_platform_mutant_rejected missing-swiftui missing-swiftui \
        'iOS Example/Sources/ThorChainExampleApp.swift' 'import SwiftUI' 'import Foundation'
    expect_platform_mutant_rejected missing-app missing-app \
        'iOS Example/Sources/ThorChainExampleApp.swift' '@main' '// @main removed'
    expect_platform_mutant_rejected library-floor library-floor \
        Package.swift '.iOS(.v13)' '.iOS(.v14)'
    expect_platform_mutant_rejected example-floor example-floor \
        'iOS Example/iOS Example.xcodeproj/project.pbxproj' 'IPHONEOS_DEPLOYMENT_TARGET = 14.0;' 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;'
    expect_platform_mutant_rejected controller-path controller-path \
        'iOS Example/iOS Example.xcodeproj/project.pbxproj' '/* Begin PBXProject section */' $'/* MainController.swift */\n/* Begin PBXProject section */'
    expect_platform_mutant_rejected disconnected-publisher publisher-lastBlockHeightPublisher \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' 'lastBlockHeightPublisher' 'disconnectedHeightPublisher'
    expect_platform_mutant_rejected scalar-snapshot scalar-snapshot \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' 'private var cancellables = Set<AnyCancellable>()' $'private var cancellables = Set<AnyCancellable>()\n    private let launchHeight = runtime.kit.lastBlockHeight'
    expect_platform_mutant_rejected retained-cancellation retained-cancellation \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' '.store(in: &cancellables)' '.cancel()'
    expect_platform_mutant_rejected main-actor main-actor \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' '@MainActor' '// @MainActor removed'
    expect_platform_mutant_rejected main-hop main-hop \
        'iOS Example/Sources/Presentation/DiagnosticsViewModel.swift' '.receive(on: DispatchQueue.main)' '.map { $0 }'
    echo "PASS verify-s1-01-platform-mutants"
}

verify_package_topology() {
    local manifest
    manifest=$(mktemp)
    trap 'rm -f "$manifest"' RETURN

    cd "$repository_root"
    swift package dump-package > "$manifest" 2>/dev/null \
        || fail "verify-s1-01-package-topology" "Package.swift is unavailable or invalid"

    python3 - "$manifest" <<'PY' \
        || fail "verify-s1-01-package-topology" "unexpected product, target, or dependency topology"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    package = json.load(handle)

products = package["products"]
targets = package["targets"]
dependencies = package["dependencies"]

assert package["name"] == "ThorChainKit"
assert package["platforms"] == [
    {"options": [], "platformName": "ios", "version": "13.0"},
]
assert len(products) == 1
assert products[0]["name"] == "ThorChainKit"
assert products[0]["type"] == {"library": ["automatic"]}
assert products[0]["targets"] == ["ThorChainKit"]

assert [(target["name"], target["type"]) for target in targets] == [
    ("ThorChainKit", "regular"),
    ("ThorChainKitTests", "test"),
]
assert [target["dependencies"] for target in targets] == [
    [
        {"byName": ["BigInt", None]},
        {"product": ["HsCryptoKit", "HsCryptoKit.Swift", None, None]},
        {"product": ["secp256k1", "secp256k1.swift", None, None]},
    ],
    [{"byName": ["ThorChainKit", None]}],
]
assert [target["exclude"] for target in targets] == [[], ["Fixtures"]]

assert len(dependencies) == 3
dependency_map = {
    dependency["sourceControl"][0]["identity"]: dependency["sourceControl"][0]
    for dependency in dependencies
}
assert dependency_map["bigint"]["location"]["remote"] == [
    {"urlString": "https://github.com/attaswift/BigInt.git"}
]
assert dependency_map["bigint"]["requirement"] == {
    "range": [{"lowerBound": "5.0.0", "upperBound": "6.0.0"}]
}
assert dependency_map["hscryptokit.swift"]["location"]["remote"] == [
    {"urlString": "https://github.com/horizontalsystems/HsCryptoKit.Swift.git"}
]
assert dependency_map["hscryptokit.swift"]["requirement"] == {"exact": ["1.3.2"]}
assert dependency_map["secp256k1.swift"]["location"]["remote"] == [
    {"urlString": "https://github.com/GigaBitcoin/secp256k1.swift.git"}
]
assert dependency_map["secp256k1.swift"]["requirement"] == {"exact": ["0.10.0"]}
PY

    echo "PASS verify-s1-01-package-topology"
}

verify_default_bigint_resolution() {
    local graph
    graph=$(mktemp)
    trap 'rm -f "$graph"' RETURN

    [[ -f "$repository_root/Package.resolved" ]] \
        || fail "verify-s1-01-bigint-default" "Package.resolved is unavailable"

    cd "$repository_root"
    swift package show-dependencies --format json > "$graph"

    python3 - "$repository_root/Package.resolved" "$graph" <<'PY' \
        || fail "verify-s1-01-bigint-default" "BigInt is not locked and resolved at the approved default"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    lock = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    graph = json.load(handle)

pins = lock["pins"]
assert len(pins) == 5
pin_map = {pin["identity"]: pin for pin in pins}
expected_pins = {
    "bigint": ("https://github.com/attaswift/BigInt.git", "e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe", "5.7.0"),
    "hscryptokit.swift": ("https://github.com/horizontalsystems/HsCryptoKit.Swift.git", "7c11ad0e690cbb178a70f3b9d1116d0a37a51a41", "1.3.2"),
    "hsextensions.swift": ("https://github.com/horizontalsystems/HsExtensions.Swift.git", "0012014f98ae81ffb89b0d3a2e9c204559e1c278", "1.0.6"),
    "secp256k1.swift": ("https://github.com/GigaBitcoin/secp256k1.swift.git", "48fb20fce4ca3aad89180448a127d5bc16f0e44c", "0.10.0"),
    "swift-crypto": ("https://github.com/apple/swift-crypto.git", "60f13f60c4d093691934dc6cfdf5f508ada1f894", "2.6.0"),
}
assert set(pin_map) == set(expected_pins)
for identity, (location, revision, version) in expected_pins.items():
    assert pin_map[identity]["location"] == location
    assert pin_map[identity]["state"] == {"revision": revision, "version": version}

dependencies = graph["dependencies"]
assert len(dependencies) == 3
direct = {dependency["identity"]: dependency for dependency in dependencies}
assert direct["bigint"]["version"] == "5.7.0"
assert direct["bigint"]["url"] == "https://github.com/attaswift/BigInt.git"
assert direct["hscryptokit.swift"]["version"] == "1.3.2"
assert direct["hscryptokit.swift"]["url"] == "https://github.com/horizontalsystems/HsCryptoKit.Swift.git"
assert direct["secp256k1.swift"]["version"] == "0.10.0"
assert direct["secp256k1.swift"]["url"] == "https://github.com/GigaBitcoin/secp256k1.swift.git"
PY

    echo "PASS verify-s1-01-bigint-default"
}

verify_toolchain() {
    local xcode_version swift_version
    xcode_version=$(xcodebuild -version)
    swift_version=$(xcrun swift --version 2>&1)
    [[ "$xcode_version" == $'Xcode 26.3\nBuild version 17C529' ]] \
        || fail "verify-s1-01-toolchain" "expected Xcode 26.3 build 17C529"
    [[ "$swift_version" == *"Apple Swift version 6.2.4"* ]] \
        || fail "verify-s1-01-toolchain" "expected Apple Swift 6.2.4"
    echo "PASS verify-s1-01-toolchain"
}

verify_source_contract() {
    local expected_sources actual_sources imports
    expected_sources=$(mktemp)
    actual_sources=$(mktemp)
    imports=$(mktemp)
    trap 'rm -f "$expected_sources" "$actual_sources" "$imports"' RETURN

    cat > "$expected_sources" <<'EOF'
Sources/ThorChainKit/Address/AddressCodec.swift
Sources/ThorChainKit/Address/AddressError.swift
Sources/ThorChainKit/Address/Bech32Codec.swift
Sources/ThorChainKit/Address/BitConversion.swift
Sources/ThorChainKit/Core/Kit.swift
Sources/ThorChainKit/Core/KitConfigurationError.swift
Sources/ThorChainKit/Core/KitDependencies.swift
Sources/ThorChainKit/Core/KitFactory.swift
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
    cd "$repository_root"
    find Sources/ThorChainKit -type f -name '*.swift' | sort > "$actual_sources"
    cmp -s "$expected_sources" "$actual_sources" \
        || fail "verify-s1-01-source-closure" "unexpected production Swift source path"

    python3 - Sources/ThorChainKit > "$imports" <<'PY'
from pathlib import Path
import re
import sys

modules = set()
for path in Path(sys.argv[1]).rglob("*.swift"):
    for line in path.read_text().splitlines():
        match = re.fullmatch(r"import ([A-Za-z0-9_]+)", line)
        if match:
            modules.add(match.group(1))
print("\n".join(sorted(modules)))
PY
    [[ "$(<"$imports")" == $'BigInt\nCombine\nCryptoKit\nFoundation\nHsCryptoKit\nsecp256k1' ]] \
        || fail "verify-s1-01-imports" "imports differ from the system/BigInt allowlist"
    python3 - Sources/ThorChainKit <<'PY' \
        || fail "verify-s1-01-source-closure" "secret API or unchecked Sendable is present"
from pathlib import Path
import re
import sys

source_root = Path(sys.argv[1])
crypto_source = "\n".join(path.read_text() for path in (source_root / "Crypto").rglob("*.swift"))
assert re.search(r"\b(seed|privateKey)\b|@unchecked\s+Sendable", crypto_source) is None
PY
    echo "PASS verify-s1-01-source-closure"
    echo "PASS verify-s1-01-imports"
}

verify_public_symbols() {
    local actual fixture output_dir symbol_graph derived_data
    actual=$(mktemp)
    output_dir=$(mktemp -d)
    trap 'rm -f "$actual"; rm -rf "$output_dir"' RETURN
    fixture="$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt"

    require_simulator
    cd "$repository_root"
    derived_data=$(mktemp -d)
    xcodebuild -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$derived_data" \
        CODE_SIGNING_ALLOWED=NO build >/dev/null \
        || fail "verify-s1-01-public-symbols" "iOS Simulator package build failed"
    xcrun swift-symbolgraph-extract \
        -module-name ThorChainKit \
        -I "$derived_data/Build/Products/Debug-iphonesimulator" \
        -Xcc -fmodule-map-file="$derived_data/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/secp256k1_bindings.modulemap" \
        -Xcc -fmodule-map-file="$derived_data/Build/Intermediates.noindex/GeneratedModuleMaps-iphonesimulator/HsCryptoKitC.modulemap" \
        -target arm64-apple-ios13.0-simulator \
        -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
        -minimum-access-level public \
        -skip-synthesized-members \
        -omit-extension-block-symbols \
        -output-dir "$output_dir"
    symbol_graph="$output_dir/ThorChainKit.symbols.json"
    [[ -f "$symbol_graph" ]] \
        || fail "verify-s1-01-public-symbols" "ThorChainKit symbol graph is unavailable"
    python3 - "$symbol_graph" > "$actual" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    graph = json.load(handle)

lines = []
for symbol in graph["symbols"]:
    kind = symbol["kind"]["identifier"]
    path = ".".join(symbol["pathComponents"])
    declaration = "".join(
        fragment.get("spelling", "")
        for fragment in symbol.get("declarationFragments", [])
    )
    lines.append(f"{kind}\t{path}\t{declaration}")
print("\n".join(sorted(lines)))
PY
    python3 - "$fixture" "$actual" <<'PY' \
        || fail "verify-s1-01-public-symbols" "an S1-01 public declaration was removed or changed"
from pathlib import Path
import sys

baseline = set(Path(sys.argv[1]).read_text().splitlines())
actual = set(Path(sys.argv[2]).read_text().splitlines())
assert baseline <= actual
PY
    echo "PASS verify-s1-01-public-symbols"
}

verify_test_contract() {
    local tmp allowlist
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    allowlist="$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt"

    cd "$repository_root"
    python3 - Tests/ThorChainKitTests/PublicApiTests.swift <<'PY' \
        || fail "verify-s1-01-test-discovery" "authoritative tests contain a disabling construct"
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
assert re.search(r"XCTSkip|XCTExpectFailure|^\s*#if|@available", source, re.MULTILINE) is None
PY
    run_simulator_tests public-api PublicApiTests "$allowlist"
    echo "PASS verify-s1-01-test-discovery"
}

copy_syntax_audit_tree() {
    local destination=$1
    mkdir -p "$destination/Scripts" "$destination/Tests/ThorChainKitTests/Fixtures"
    cp -R "$repository_root/Sources" "$destination/Sources"
    cp "$repository_root/Scripts/verify-s1-01-factory.swift" "$destination/Scripts/"
    cp "$repository_root/Scripts/verify-s1-01-values.swift" "$destination/Scripts/"
    cp "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-factory-syntax.txt" \
        "$destination/Tests/ThorChainKitTests/Fixtures/"
    cp "$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-value-syntax.txt" \
        "$destination/Tests/ThorChainKitTests/Fixtures/"
}

expect_syntax_mutant_rejected() {
    local verifier=$1 label=$2 path=$3 needle=$4 replacement=$5 tmp file
    tmp=$(mktemp -d)
    copy_syntax_audit_tree "$tmp"
    file="$tmp/$path"
    python3 - "$file" "$needle" "$replacement" <<'PY' \
        || fail "$verifier-$label" "guarded transform did not apply exactly once"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old, new = sys.argv[2], sys.argv[3]
assert source.count(old) == 1
path.write_text(source.replace(old, new))
PY
    (cd "$tmp" && xcrun swiftc -frontend -dump-parse "$path" >/dev/null 2>&1) \
        || fail "$verifier-$label" "mutant is not valid parsed Swift"
    if (cd "$tmp" && xcrun swift "Scripts/$verifier.swift" \
        "Tests/ThorChainKitTests/Fixtures/$label" >/dev/null 2>&1); then
        fail "$verifier-$label" "mutant passed the positive syntax fixture"
    fi
}

verify_factory_syntax() {
    local fixture='S1-01-factory-syntax.txt'
    local insertion='        var namespaceInput = Data(walletId.utf8)'
    cd "$repository_root"
    xcrun swift Scripts/verify-s1-01-factory.swift \
        "Tests/ThorChainKitTests/Fixtures/$fixture"

    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = URLSession.shared\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = URLRequest(url: endpoints.families[0].cosmosRestURL)\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = try? Data(contentsOf: endpoints.families[0].cosmosRestURL)\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = FileManager.default\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = FileHandle(forUpdatingAtPath: walletId)\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = UserDefaults.standard\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        _ = sqlite3_open(walletId, nil)\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        Task {}\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = OperationQueue()\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        DispatchQueue.global().async {}\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in }\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift "$insertion" \
        $'        let _ = DispatchSource.makeTimerSource()\n        var namespaceInput = Data(walletId.utf8)'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift 'public extension Kit {' \
        $'typealias FactoryLifecycle = NoOpLifecycle\n\npublic extension Kit {'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift '    static func instance(' \
        $'    private static func makeLifecycle() -> NoOpLifecycle { NoOpLifecycle() }\n\n    static func instance('
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Core/KitFactory.swift 'KitDependencies(lifecycle: NoOpLifecycle())' \
        'KitDependencies(lifecycle: ExternalFactoryHelper.makeLifecycle())'
    expect_syntax_mutant_rejected verify-s1-01-factory "$fixture" \
        Sources/ThorChainKit/Models/Network.swift \
        '        environment.rawValue + "\0" + expectedChainId' \
        $'        ({ _ = try? Data(contentsOf: URL(string: "https://example.com")!); return environment.rawValue + "\\0" + expectedChainId })()'
    echo "PASS verify-s1-01-factory-mutants"
}

verify_value_syntax() {
    local fixture='S1-01-value-syntax.txt'
    cd "$repository_root"
    xcrun swift Scripts/verify-s1-01-values.swift \
        "Tests/ThorChainKitTests/Fixtures/$fixture"

    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Models/Address.swift \
        '        let decoded = try Bech32Codec.decode(raw)' \
        $'        _ = try? Data(contentsOf: URL(string: "https://example.com")!)\n        let decoded = try Bech32Codec.decode(raw)'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Models/Address.swift \
        '        let decoded = try Bech32Codec.decode(raw)' \
        $'        Task {}\n        let decoded = try Bech32Codec.decode(raw)'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift \
        '        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)' \
        $'        _ = try? Data(contentsOf: cosmosRestURL)\n        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift \
        '        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)' \
        $'        Task {}\n        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Models/Network.swift \
        '        expectedChainId: "thorchain-1",' \
        '        expectedChainId: ({ _ = try? Data(contentsOf: URL(string: "https://example.com")!); return "thorchain-1" })(),'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Models/Denom.swift \
        '    public static let rune = try! Denom(rawValue: "rune")' \
        '    public static let rune = { Task {}; return try! Denom(rawValue: "rune") }()'
    expect_syntax_mutant_rejected verify-s1-01-values "$fixture" \
        Sources/ThorChainKit/Models/EndpointConfiguration.swift \
        '        policy: EndpointPolicy = .default' \
        '        policy: EndpointPolicy = EndpointDefaults.policy()'
    echo "PASS verify-s1-01-value-mutants"
}

verify_strict_build() {
    local derived_data
    require_simulator
    cd "$repository_root"
    derived_data=$(mktemp -d)
    xcodebuild -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$derived_data" \
        SWIFT_VERSION=5 \
        SWIFT_STRICT_CONCURRENCY=complete \
        CODE_SIGNING_ALLOWED=NO build >/dev/null \
        || fail "verify-s1-01-strict-build" "Swift 5 complete-concurrency simulator build failed"
    echo "PASS verify-s1-01-strict-build"
}

verify_skip_canary() {
    local tmp allowlist test_file result_bundle
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    mkdir -p "$tmp/Scripts" "$tmp/Tests/ThorChainKitTests"
    cp "$repository_root/Package.swift" "$repository_root/Package.resolved" "$tmp/"
    cp -R "$repository_root/Sources" "$tmp/Sources"
    cp -R "$repository_root/Tests/ThorChainKitTests" "$tmp/Tests/"
    cp "$repository_root/Scripts/verify-s1-01-xunit.swift" "$tmp/Scripts/"
    test_file="$tmp/Tests/ThorChainKitTests/PublicApiTests.swift"
    python3 - "$test_file" <<'PY' \
        || fail "verify-s1-01-skip-canary" "guarded XCTSkip transform did not apply"
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "    func testNetworkConstants() throws {\n"
new = old + '        throw XCTSkip("S1-01 canary")\n'
assert source.count(old) == 1
path.write_text(source.replace(old, new))
PY
    allowlist="$tmp/Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt"
    require_simulator
    result_bundle="$tmp/public-api.xcresult"
    set +e
    (cd "$tmp" && xcodebuild \
        -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$tmp/DerivedData" \
        -resultBundlePath "$result_bundle" \
        -only-testing:ThorChainKitTests/PublicApiTests \
        CODE_SIGNING_ALLOWED=NO test > "$tmp/xcodebuild.log" 2>&1) \
        || true
    set -e
    rg -qi 'skip|skipped' "$tmp/xcodebuild.log" \
        || fail "verify-s1-01-skip-canary" "XCTSkip canary did not appear in simulator output"
    Scripts/verify-xcresult.sh verify-s1-01-skip-canary "$result_bundle" "$allowlist" reject \
        || fail "verify-s1-01-skip-canary" "XCTSkip canary was not rejected by xcresult"
    echo "PASS verify-s1-01-skip-canary"
}

verify_direct_scripts() {
    local script mode
    for script in \
        Scripts/verify-s1-01.sh \
        Scripts/verify-xcresult.sh \
        Scripts/verify-bigint-floor.sh \
        Scripts/test-s1-01-mutants.sh \
        Scripts/run-maestro.sh \
        Scripts/test-run-maestro.sh
    do
        [[ -x "$repository_root/$script" ]] \
            || fail "verify-s1-01-script-modes" "$script is not executable"
        [[ "$(head -n 1 "$repository_root/$script")" == '#!/usr/bin/env bash' ]] \
            || fail "verify-s1-01-script-modes" "$script has an invalid shebang"
        mode=$(cd "$repository_root" && git ls-files -s "$script" | awk '{print $1}')
        [[ "$mode" == 100755 ]] \
            || fail "verify-s1-01-script-modes" "$script Git mode is not 100755"
    done
    echo "PASS verify-s1-01-script-modes"
}

verify_public_consumer() {
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    require_simulator
    mkdir -p "$tmp/Sources/ThorChainKitConsumer"
    python3 - "$tmp/Package.swift" "$repository_root" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
root = sys.argv[2].replace('\\', '\\\\').replace('"', '\\"')
path.write_text(f'''// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ThorChainKitConsumer",
    platforms: [.iOS(.v13)],
    dependencies: [.package(name: "ThorChainKitLocal", path: "{root}")],
    targets: [
        .executableTarget(
            name: "ThorChainKitConsumer",
            dependencies: [.product(name: "ThorChainKit", package: "ThorChainKitLocal")]
        ),
    ]
)
''')
PY
    cat > "$tmp/Sources/ThorChainKitConsumer/main.swift" <<'SWIFT'
import Foundation
import ThorChainKit

let network = Network.mainnet
let family = try EndpointFamilyDescriptor(
    id: "fixture",
    cosmosRestURL: URL(string: "https://rest.example.com")!,
    cometBftURL: URL(string: "https://rpc.example.com")!
)
let endpoints = try EndpointConfiguration(families: [family])
let address = try Address(
    "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
    network: network
)
let kit = try Kit.instance(address: address, walletId: "consumer", endpoints: endpoints)
_ = (kit.network, kit.address, kit.accountState, kit.lastBlockHeight)
_ = (kit.syncState, kit.runeBalance.description, kit.accountExists)
_ = (kit.accountStatePublisher, kit.lastBlockHeightPublisher, kit.syncStatePublisher)
kit.start()
kit.refresh()
kit.stop()
SWIFT
    (cd "$tmp" && xcodebuild \
        -scheme ThorChainKitConsumer \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$tmp/DerivedData" \
        IPHONEOS_DEPLOYMENT_TARGET=13.0 \
        SWIFT_VERSION=5 \
        SWIFT_STRICT_CONCURRENCY=complete \
        SWIFT_SUPPRESS_WARNINGS=NO \
        CODE_SIGNING_ALLOWED=NO \
        build >/dev/null) \
        || fail "verify-s1-01-public-consumer" "public-only iOS 13 consumer failed"
    echo "PASS verify-s1-01-public-consumer"
}

verify_sanitized_gimle_report() {
    local report="$repository_root/docs/reports/gimle/THR-12-s1-01-gimle-reliability.md"
    [[ -f "$report" ]] \
        || fail "verify-s1-01-gimle-report" "reliability report is absent"
    python3 - "$report" <<'PY' \
        || fail "verify-s1-01-gimle-report" "report contains a machine-local path"
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
assert not any(value in source for value in ["/Users/", "/Users/Shared/", "/private/", "file://"])
PY
    echo "PASS verify-s1-01-gimle-report"
}

verify_example_workspace() {
    local workspace="$repository_root/iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata"
    [[ -f "$workspace" ]] \
        || fail "verify-s1-01-example-workspace" "workspace data is absent"
    python3 - "$workspace" <<'PY' \
        || fail "verify-s1-01-example-workspace" "workspace links are not exact"
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
locations = [node.attrib.get("location") for node in root.findall("FileRef")]
assert locations == ["container:iOS Example.xcodeproj", "group:.."]
PY
    echo "PASS verify-s1-01-example-workspace"
}

verify_ci_provenance() {
    python3 - "$repository_root/.github/workflows/ci.yml" <<'PY' \
        || fail "verify-s1-01-ci-provenance" "CI action or Maestro provenance differs"
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
required = [
    "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
    "actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9",
    "https://github.com/mobile-dev-inc/Maestro/releases/download/cli-2.6.1/maestro.zip",
    "3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b",
]
assert all(source.count(value) == 1 for value in required)
assert "actions/checkout@v" not in source
assert "actions/setup-java@v" not in source
PY
    echo "PASS verify-s1-01-ci-provenance"
}

if [[ ${1:-} == "--platform-only" && $# -eq 1 ]]; then
    verify_platform_boundary
    verify_platform_mutants
    exit 0
fi
[[ $# -eq 0 ]] || fail "verify-s1-01-arguments" "expected no arguments or --platform-only"

verify_package_topology
verify_default_bigint_resolution
verify_toolchain
verify_source_contract
verify_public_symbols
verify_test_contract
verify_skip_canary
verify_factory_syntax
verify_value_syntax
verify_direct_scripts
verify_strict_build
"$repository_root/Scripts/verify-bigint-floor.sh"
"$repository_root/Scripts/test-s1-01-mutants.sh"
verify_public_consumer
verify_example_workspace
verify_ci_provenance
verify_sanitized_gimle_report
