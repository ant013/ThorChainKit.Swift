#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)

fail() {
    echo "FAIL $1: $2" >&2
    exit 1
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
    {"options": [], "platformName": "macos", "version": "10.15"},
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
    [{"byName": ["BigInt", None]}],
    [{"byName": ["ThorChainKit", None]}],
]
assert [target["exclude"] for target in targets] == [[], ["Fixtures"]]

assert len(dependencies) == 1
dependency = dependencies[0]["sourceControl"][0]
assert dependency["identity"] == "bigint"
assert dependency["location"]["remote"] == [
    {"urlString": "https://github.com/attaswift/BigInt.git"}
]
assert dependency["requirement"] == {
    "range": [{"lowerBound": "5.0.0", "upperBound": "6.0.0"}]
}
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
assert len(pins) == 1
pin = pins[0]
assert pin["identity"] == "bigint"
assert pin["location"] == "https://github.com/attaswift/BigInt.git"
assert pin["state"] == {
    "revision": "e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe",
    "version": "5.7.0",
}

dependencies = graph["dependencies"]
assert len(dependencies) == 1
dependency = dependencies[0]
assert dependency["identity"] == "bigint"
assert dependency["version"] == "5.7.0"
assert dependency["url"] == "https://github.com/attaswift/BigInt.git"
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
Sources/ThorChainKit/Address/AddressError.swift
Sources/ThorChainKit/Address/Bech32Codec.swift
Sources/ThorChainKit/Address/BitConversion.swift
Sources/ThorChainKit/Core/Kit.swift
Sources/ThorChainKit/Core/KitConfigurationError.swift
Sources/ThorChainKit/Core/KitDependencies.swift
Sources/ThorChainKit/Core/KitFactory.swift
Sources/ThorChainKit/Models/AccountState.swift
Sources/ThorChainKit/Models/Address.swift
Sources/ThorChainKit/Models/Denom.swift
Sources/ThorChainKit/Models/EndpointConfiguration.swift
Sources/ThorChainKit/Models/Network.swift
Sources/ThorChainKit/Models/SyncError.swift
Sources/ThorChainKit/Models/SyncState.swift
Sources/ThorChainKit/Network/EndpointFamilyDescriptor.swift
Sources/ThorChainKit/Network/EndpointPolicy.swift
Sources/ThorChainKit/ThorChainKit.swift
EOF
    cd "$repository_root"
    find Sources/ThorChainKit -type f -name '*.swift' | sort > "$actual_sources"
    cmp -s "$expected_sources" "$actual_sources" \
        || fail "verify-s1-01-source-closure" "unexpected production Swift source path"

    rg '^import ' Sources/ThorChainKit \
        | sed -E 's/^.*:import ([A-Za-z0-9_]+).*$/\1/' \
        | sort -u > "$imports"
    [[ "$(<"$imports")" == $'BigInt\nCombine\nCryptoKit\nFoundation' ]] \
        || fail "verify-s1-01-imports" "imports differ from the system/BigInt allowlist"
    if rg -n '\b(seed|privateKey)\b|@unchecked[[:space:]]+Sendable' Sources/ThorChainKit >/dev/null; then
        fail "verify-s1-01-source-closure" "secret API or unchecked Sendable is present"
    fi
    echo "PASS verify-s1-01-source-closure"
    echo "PASS verify-s1-01-imports"
}

verify_public_symbols() {
    local actual fixture symbol_graph
    actual=$(mktemp)
    trap 'rm -f "$actual"' RETURN
    fixture="$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt"

    cd "$repository_root"
    swift package dump-symbol-graph \
        --minimum-access-level public \
        --skip-synthesized-members >/dev/null
    symbol_graph=$(find .build -path '*/symbolgraph/ThorChainKit.symbols.json' -print)
    [[ $(printf '%s\n' "$symbol_graph" | sed '/^$/d' | wc -l | tr -d ' ') == 1 ]] \
        || fail "verify-s1-01-public-symbols" "expected one ThorChainKit symbol graph"
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
    cmp -s "$fixture" "$actual" \
        || fail "verify-s1-01-public-symbols" "public declarations differ from the fixture"
    echo "PASS verify-s1-01-public-symbols"
}

verify_test_contract() {
    local tmp allowlist discovered command_text
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN
    allowlist="$repository_root/Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt"

    cd "$repository_root"
    swift test list --enable-xctest --disable-swift-testing > "$tmp/discovered.txt"
    cmp -s "$allowlist" "$tmp/discovered.txt" \
        || fail "verify-s1-01-test-discovery" "discovered tests differ from the 18-case allowlist"
    if rg -n 'XCTSkip|XCTExpectFailure|^[[:space:]]*#if|@available' \
        Tests/ThorChainKitTests/PublicApiTests.swift >/dev/null; then
        fail "verify-s1-01-test-discovery" "authoritative tests contain a disabling construct"
    fi
    command_text='swift test --enable-xctest --disable-swift-testing --parallel --num-workers 1 --filter ThorChainKitTests.PublicApiTests --xunit-output'
    [[ "$command_text" != *"--skip"* ]] \
        || fail "verify-s1-01-test-discovery" "test command contains --skip"
    echo "PASS verify-s1-01-test-discovery"

    set -o pipefail
    swift test \
        --enable-xctest \
        --disable-swift-testing \
        --parallel \
        --num-workers 1 \
        --filter ThorChainKitTests.PublicApiTests \
        --xunit-output "$tmp/public-api.xml" \
        --verbose 2>&1 | tee "$tmp/public-api.log" >/dev/null \
        || fail "verify-s1-01-test-execution" "the XCTest process failed"
    xcrun swift Scripts/verify-s1-01-xunit.swift \
        "$tmp/public-api.xml" \
        "$tmp/public-api.log" \
        "$allowlist" \
        || fail "verify-s1-01-test-execution" "xUnit/transcript validation failed"
    echo "PASS verify-s1-01-test-execution"
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
    cd "$repository_root"
    swift build \
        -Xswiftc -swift-version \
        -Xswiftc 5 \
        -Xswiftc -strict-concurrency=complete \
        -Xswiftc -warnings-as-errors \
        || fail "verify-s1-01-strict-build" "Swift 5 complete-concurrency build failed"
    echo "PASS verify-s1-01-strict-build"
}

verify_skip_canary() {
    local tmp allowlist test_file clang_resource sdk
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
    clang_resource=$(xcrun clang -print-resource-dir)
    sdk=$(xcrun --sdk macosx --show-sdk-path)
    (cd "$tmp" && swift test \
        --enable-xctest \
        --disable-swift-testing \
        --parallel \
        --num-workers 1 \
        --filter ThorChainKitTests.PublicApiTests \
        --xunit-output "$tmp/public-api.xml" \
        -Xcc -nostdinc \
        -Xcc -isystem -Xcc "$clang_resource/include" \
        -Xcc -isystem -Xcc "$sdk/usr/include" \
        -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks" \
        --verbose 2>&1 | tee "$tmp/public-api.log" >/dev/null) \
        || fail "verify-s1-01-skip-canary" "XCTSkip canary process did not reach status validation"
    if (cd "$tmp" && xcrun swift Scripts/verify-s1-01-xunit.swift \
        "$tmp/public-api.xml" "$tmp/public-api.log" "$allowlist" >/dev/null 2>&1); then
        fail "verify-s1-01-skip-canary" "XCTSkip canary passed transcript validation"
    fi
    echo "PASS verify-s1-01-skip-canary"
}

verify_direct_scripts() {
    local script mode
    for script in \
        Scripts/verify-s1-01.sh \
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
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath "$tmp/DerivedData" \
        IPHONEOS_DEPLOYMENT_TARGET=13.0 \
        SWIFT_VERSION=5 \
        SWIFT_STRICT_CONCURRENCY=complete \
        SWIFT_SUPPRESS_WARNINGS=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        CODE_SIGNING_ALLOWED=NO \
        build >/dev/null) \
        || fail "verify-s1-01-public-consumer" "public-only iOS 13 consumer failed"
    echo "PASS verify-s1-01-public-consumer"
}

verify_sanitized_gimle_report() {
    local report="$repository_root/docs/reports/gimle/THR-12-s1-01-gimle-reliability.md"
    [[ -f "$report" ]] \
        || fail "verify-s1-01-gimle-report" "reliability report is absent"
    if rg -n '/Users/|/Users/Shared/|/private/|file://' "$report" >/dev/null; then
        fail "verify-s1-01-gimle-report" "report contains a machine-local path"
    fi
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
