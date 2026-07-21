#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
canary_udid='12345678-1234-1234-1234-123456789ABC'

fail() {
    echo "FAIL test-run-maestro: $1" >&2
    exit 1
}

copy_fixture_repo() {
    local destination=$1
    mkdir -p "$destination/Scripts" "$destination/.maestro" "$destination/.github/workflows"
    cp "$repository_root/Scripts/run-maestro.sh" "$destination/Scripts/"
    cp "$repository_root/Scripts/scan-s1-01-artifacts.swift" "$destination/Scripts/"
    cp -R "$repository_root/.maestro/flows" "$destination/.maestro/flows"
    cp "$repository_root/.maestro/config.yaml" "$destination/.maestro/"
    cp "$repository_root/.github/workflows/ci.yml" "$destination/.github/workflows/"
    cp -R "$repository_root/iOS Example" "$destination/iOS Example"
    (
        cd "$destination"
        git init -q
        git add -f Scripts .maestro .github 'iOS Example'
        git -c user.name=Canary -c user.email=canary.invalid commit -qm fixture
    )
    make_shims "$destination"
}

make_shims() {
    local destination=$1
    mkdir -p "$destination/shims"
    cat > "$destination/shims/java" <<'SH'
#!/usr/bin/env bash
if [[ ${SHIM_JAVA_VERSION:-good} == good ]]; then
    echo 'openjdk version "17.0.19"' >&2
    echo 'OpenJDK Runtime Environment Temurin-17.0.19+10' >&2
else
    echo 'openjdk version "21.0.1"' >&2
fi
SH
    cat > "$destination/shims/xcrun" <<'SH'
#!/usr/bin/env bash
echo "xcrun $*" >> "$SHIM_LOG"
if [[ $1 == simctl ]]; then
    if [[ $2 == list ]]; then
        printf '{"devices":{"runtime":[{"udid":"%s","isAvailable":true,"state":"Shutdown"}]}}\n' "$SHIM_UDID"
    fi
    exit 0
fi
exec /usr/bin/xcrun "$@"
SH
    cat > "$destination/shims/xcodebuild" <<'SH'
#!/usr/bin/env bash
echo "xcodebuild $*" >> "$SHIM_LOG"
[[ " $* " == *"id=$SHIM_UDID"* ]] || exit 41
derived=''
while (($#)); do
    if [[ $1 == -derivedDataPath ]]; then
        derived=$2
        shift 2
    else
        shift
    fi
done
[[ $derived == /* ]] || exit 42
mkdir -p "$derived/Build/Products/Debug-iphonesimulator/iOS Example.app"
SH
    cat > "$destination/shims/maestro" <<'SH'
#!/usr/bin/env bash
echo "maestro $*" >> "$SHIM_LOG"
if [[ ${1:-} == --version ]]; then
    [[ -n ${MAESTRO_CLI_NO_ANALYTICS:-} ]] || echo 'Anonymous analytics enabled.'
    [[ ${SHIM_MAESTRO_VERSION:-good} == good ]] && echo '2.6.1' || echo '2.6.0'
    exit 0
fi
[[ " $* " == *" --device $SHIM_UDID "* ]] || exit 51
output=''
artifacts=''
debug=''
while (($#)); do
    case $1 in
        --output) output=$2; shift 2 ;;
        --test-output-dir) artifacts=$2; shift 2 ;;
        --debug-output) debug=$2; shift 2 ;;
        *) shift ;;
    esac
done
[[ $output == /* && $artifacts == /* && $debug == /* ]] || exit 52
mkdir -p "$artifacts" "$debug"
if [[ ${SHIM_BAD_JUNIT:-0} == 1 ]]; then
    printf '<testsuites><testsuite tests="0" failures="0" errors="0" skipped="0"/></testsuites>\n' > "$output"
else
    printf '<testsuites><testsuite tests="1" failures="0" errors="0" skipped="0"><testcase name="foundation"/></testsuite></testsuites>\n' > "$output"
fi
printf 'safe debug output\n' > "$debug/maestro.log"
base64 -D > "$artifacts/foundation-success.png" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=
PNG
/usr/bin/sips -z 100 100 "$artifacts/foundation-success.png" >/dev/null
SH
    chmod +x "$destination/shims/java" "$destination/shims/xcrun" \
        "$destination/shims/xcodebuild" "$destination/shims/maestro"
}

run_fixture() {
    local fixture=$1 slice=$2
    SHIM_LOG="$fixture/commands.log" \
    SHIM_UDID="$canary_udid" \
    PATH="$fixture/shims:$PATH" \
    THORCHAIN_SIMULATOR_UDID="$canary_udid" \
        "$fixture/Scripts/run-maestro.sh" "$slice" >/dev/null
}

verify_provenance() {
    python3 - "$1" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
required = [
    "name: Build Only",
    "workflow_dispatch:",
    "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5",
    "- name: Build Example",
    "-destination 'generic/platform=iOS Simulator'",
]
assert all(source.count(value) == 1 for value in required)
for forbidden in [
    "actions/setup-java@",
    "mobile-dev-inc/Maestro",
    "maestro test",
    "simctl",
    "swift test",
    "xcodebuild test",
    "test-run-maestro.sh",
    "run-maestro.sh",
]:
    assert forbidden not in source
PY
}

expect_runner_failure() {
    local label=$1 fixture=$2
    shift 2
    if env \
        SHIM_LOG="$fixture/commands.log" \
        SHIM_UDID="$canary_udid" \
        PATH="$fixture/shims:$PATH" \
        THORCHAIN_SIMULATOR_UDID="$canary_udid" \
        "$@" "$fixture/Scripts/run-maestro.sh" s1-01 >/dev/null 2>&1
    then
        fail "$label was accepted"
    fi
    echo "PASS $label"
}

happy="$test_root/happy-s1-01"
copy_fixture_repo "$happy"
verify_provenance "$happy/.github/workflows/ci.yml"
run_fixture "$happy" s1-01
python3 - "$happy/commands.log" "$canary_udid" "$happy" '.maestro/flows/00-launch-foundation.yaml' <<'PY' \
    || fail "shim argv audit failed"
import sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
udid, root, flow = sys.argv[2], sys.argv[3], sys.argv[4]
required = ["simctl boot ", "simctl bootstatus ", "xcodebuild ", "simctl install ", "simctl launch ", "maestro --device "]
for prefix in required:
    matches = [line for line in lines if prefix in line]
    assert len(matches) == 1, (prefix, matches)
    assert matches[0].count(udid) == 1, matches[0]
for line in lines:
    if "--output" in line or "-derivedDataPath" in line:
        assert root in line, line
maestro = next(line for line in lines if line.startswith("maestro --device "))
assert maestro.endswith(" " + flow), maestro
PY
echo "PASS run-maestro-shim-s1-01"

happy="$test_root/happy-s1-02"
copy_fixture_repo "$happy"
run_fixture "$happy" s1-02
python3 - "$happy/commands.log" <<'PY' \
    || fail "S1-02 exact flow argv audit failed"
import sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
maestro = next(line for line in lines if line.startswith("maestro --device "))
assert maestro.endswith(" .maestro/flows/01-endpoint-policy.yaml"), maestro
assert "00-launch-foundation.yaml" not in maestro
PY
echo "PASS run-maestro-shim-s1-02"

happy="$test_root/happy-s1-03"
copy_fixture_repo "$happy"
run_fixture "$happy" s1-03
python3 - "$happy/commands.log" <<'PY' \
    || fail "S1-03 exact flow argv audit failed"
import sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
maestro = next(line for line in lines if line.startswith("maestro --device "))
assert maestro.endswith(" .maestro/flows/02-address-codec.yaml"), maestro
assert "00-launch-foundation.yaml" not in maestro
assert "01-endpoint-policy.yaml" not in maestro
PY
echo "PASS run-maestro-shim-s1-03"

happy="$test_root/happy-s1-04"
copy_fixture_repo "$happy"
run_fixture "$happy" s1-04
python3 - "$happy/commands.log" <<'PY' \
    || fail "S1-04 exact flow argv audit failed"
import sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
maestro = next(line for line in lines if line.startswith("maestro --device "))
assert maestro.endswith(" .maestro/flows/03-account-read-fixture.yaml"), maestro
for earlier in [
    "00-launch-foundation.yaml",
    "01-endpoint-policy.yaml",
    "02-address-codec.yaml",
]:
    assert earlier not in maestro
PY
echo "PASS run-maestro-shim-s1-04"

fixture="$test_root/wrong-s1-04-mapping"
copy_fixture_repo "$fixture"
mutated="$fixture/Scripts/run-maestro.sh"
python3 - "$mutated" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "s1-04) flow_path=.maestro/flows/03-account-read-fixture.yaml ;;"
assert source.count(old) == 1
path.write_text(source.replace(old, "s1-04) flow_path=.maestro/flows/02-address-codec.yaml ;;"))
PY
if run_fixture "$fixture" s1-04 >/dev/null 2>&1; then
    maestro_line=$(rg '^maestro --device ' "$fixture/commands.log")
    [[ "$maestro_line" != *'03-account-read-fixture.yaml' ]] \
        || fail "wrong S1-04 mapping canary did not mutate the selected flow"
else
    fail "wrong S1-04 mapping canary did not reach the shim audit"
fi
echo "PASS wrong-s1-04-mapping"

fixture="$test_root/missing-slice"
copy_fixture_repo "$fixture"
if SHIM_LOG="$fixture/commands.log" SHIM_UDID="$canary_udid" PATH="$fixture/shims:$PATH" \
    THORCHAIN_SIMULATOR_UDID="$canary_udid" "$fixture/Scripts/run-maestro.sh" >/dev/null 2>&1; then
    fail "missing slice was accepted"
fi
echo "PASS missing-slice"

for bad_slice in '.maestro/flows/00-launch-foundation.yaml' unknown; do
    fixture="$test_root/bad-slice-${bad_slice##*/}"
    copy_fixture_repo "$fixture"
    if SHIM_LOG="$fixture/commands.log" SHIM_UDID="$canary_udid" PATH="$fixture/shims:$PATH" \
        THORCHAIN_SIMULATOR_UDID="$canary_udid" "$fixture/Scripts/run-maestro.sh" "$bad_slice" >/dev/null 2>&1; then
        fail "raw or unknown slice was accepted"
    fi
done
echo "PASS invalid-slice"

fixture="$test_root/extra-slice"
copy_fixture_repo "$fixture"
if SHIM_LOG="$fixture/commands.log" SHIM_UDID="$canary_udid" PATH="$fixture/shims:$PATH" \
    THORCHAIN_SIMULATOR_UDID="$canary_udid" "$fixture/Scripts/run-maestro.sh" s1-01 extra >/dev/null 2>&1; then
    fail "extra slice argument was accepted"
fi
echo "PASS extra-slice"

fixture="$test_root/action-provenance"
copy_fixture_repo "$fixture"
python3 - "$fixture/.github/workflows/ci.yml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5"
assert source.count(old) == 1
path.write_text(source.replace(old, "actions/checkout@v4"))
PY
if verify_provenance "$fixture/.github/workflows/ci.yml" 2>/dev/null; then
    fail "changed action provenance was accepted"
fi
echo "PASS action-provenance"

fixture="$test_root/build-only-provenance"
copy_fixture_repo "$fixture"
python3 - "$fixture/.github/workflows/ci.yml" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "-destination 'generic/platform=iOS Simulator'"
assert source.count(old) == 1
path.write_text(source.replace(old, "-destination 'platform=iOS Simulator,name=iPhone 17 Pro'"))
PY
if verify_provenance "$fixture/.github/workflows/ci.yml" 2>/dev/null; then
    fail "changed build-only provenance was accepted"
fi
echo "PASS build-only-provenance"

fixture="$test_root/wrong-maestro"
copy_fixture_repo "$fixture"
expect_runner_failure wrong-maestro "$fixture" SHIM_MAESTRO_VERSION=bad

fixture="$test_root/wrong-java"
copy_fixture_repo "$fixture"
expect_runner_failure wrong-java "$fixture" SHIM_JAVA_VERSION=bad

fixture="$test_root/wrong-udid"
copy_fixture_repo "$fixture"
if SHIM_LOG="$fixture/commands.log" SHIM_UDID="$canary_udid" PATH="$fixture/shims:$PATH" \
    THORCHAIN_SIMULATOR_UDID='AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA' \
    "$fixture/Scripts/run-maestro.sh" >/dev/null 2>&1; then
    fail "unavailable UDID was accepted"
fi
echo "PASS wrong-udid"

fixture="$test_root/bad-junit"
copy_fixture_repo "$fixture"
expect_runner_failure bad-junit "$fixture" SHIM_BAD_JUNIT=1

fixture="$test_root/bad-manifest"
copy_fixture_repo "$fixture"
cp "$fixture/.maestro/flows/00-launch-foundation.yaml" "$fixture/.maestro/flows/extra.yaml"
expect_runner_failure bad-manifest "$fixture" env

fixture="$test_root/symlink-output"
copy_fixture_repo "$fixture"
mkdir -p "$fixture/build" "$fixture/outside"
ln -s "$fixture/outside" "$fixture/build/s1-01-maestro-results"
expect_runner_failure symlink-output "$fixture" env

mutate_runner() {
    local fixture=$1 old=$2 new=$3
    python3 - "$fixture/Scripts/run-maestro.sh" "$old" "$new" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
assert source.count(sys.argv[2]) == 1
path.write_text(source.replace(sys.argv[2], sys.argv[3]))
PY
}

fixture="$test_root/relative-output"
copy_fixture_repo "$fixture"
mutate_runner "$fixture" 'results_root="$repository_root/build/$slice-maestro-results"' 'results_root="build/$slice-maestro-results"'
expect_runner_failure relative-output "$fixture" env

fixture="$test_root/sibling-output"
copy_fixture_repo "$fixture"
mutate_runner "$fixture" 'results_root="$repository_root/build/$slice-maestro-results"' 'results_root="${repository_root}-escape"'
expect_runner_failure sibling-output "$fixture" env

fixture="$test_root/substituted-udid"
copy_fixture_repo "$fixture"
mutate_runner "$fixture" '-destination "platform=iOS Simulator,id=$udid"' '-destination "platform=iOS Simulator,id=AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"'
expect_runner_failure substituted-udid "$fixture" env

cat > "$test_root/render.swift" <<'SWIFT'
import AppKit
import Foundation

let output = CommandLine.arguments[1]
let text = CommandLine.arguments[2]
let size = NSSize(width: 1800, height: 320)
let image = NSImage(size: size)
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
(text as NSString).draw(
    at: NSPoint(x: 30, y: 120),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 64),
        .foregroundColor: NSColor.black,
    ]
)
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
SWIFT

clang_resource=$(xcrun clang -print-resource-dir)
sdk=$(xcrun --sdk macosx --show-sdk-path)
swift_flags=(
    -Xcc -nostdinc
    -Xcc -isystem -Xcc "$clang_resource/include"
    -Xcc -isystem -Xcc "$sdk/usr/include"
    -Xcc -iframework -Xcc "$sdk/System/Library/Frameworks"
)

make_scanner_fixture() {
    local fixture=$1
    mkdir -p "$fixture/Scripts" "$fixture/artifacts"
    cp "$repository_root/Scripts/scan-s1-01-artifacts.swift" "$fixture/Scripts/"
    printf 'safe tracked input\n' > "$fixture/safe.txt"
    printf 'safe.txt\n' > "$fixture/artifacts/tracked.txt"
    xcrun swift "${swift_flags[@]}" "$test_root/render.swift" \
        "$fixture/artifacts/safe.png" 'SAFE FIXTURE'
}

run_scanner() {
    local fixture=$1 artifact=${2:-$1/artifacts}
    xcrun swift "${swift_flags[@]}" "$fixture/Scripts/scan-s1-01-artifacts.swift" \
        "$fixture" "$artifact" "$fixture/artifacts/tracked.txt" >/dev/null
}

scanner="$test_root/scanner-positive"
make_scanner_fixture "$scanner"
run_scanner "$scanner"
echo "PASS scanner-positive"

scanner="$test_root/scanner-secret-second"
make_scanner_fixture "$scanner"
secret_text='private'' key: canary12345678'
xcrun swift "${swift_flags[@]}" "$test_root/render.swift" \
    "$scanner/artifacts/z-secret.png" "$secret_text"
if run_scanner "$scanner" 2>/dev/null; then fail "secret second PNG was accepted"; fi
echo "PASS scanner-secret-second"

scanner="$test_root/scanner-namespace"
make_scanner_fixture "$scanner"
namespace_text='namespace: e2df225b7a00d471b1b09ec2d3344df''89a11e9cfe116c05f5290683480623015'
xcrun swift "${swift_flags[@]}" "$test_root/render.swift" \
    "$scanner/artifacts/namespace.png" "$namespace_text"
if run_scanner "$scanner" 2>/dev/null; then fail "namespace PNG was accepted"; fi
echo "PASS scanner-namespace"

scanner="$test_root/scanner-malformed"
make_scanner_fixture "$scanner"
printf 'not a png\n' > "$scanner/artifacts/bad.png"
if run_scanner "$scanner" 2>/dev/null; then fail "malformed PNG was accepted"; fi
echo "PASS scanner-malformed"

scanner="$test_root/scanner-raw-secret"
make_scanner_fixture "$scanner"
raw_secret='api'' key: canary12345678'
printf '%s\n' "$raw_secret" > "$scanner/artifacts/commands.json"
if run_scanner "$scanner" 2>/dev/null; then fail "raw secret was accepted"; fi
echo "PASS scanner-raw-secret"

scanner="$test_root/scanner-inner-symlink"
make_scanner_fixture "$scanner"
printf 'outside\n' > "$scanner/outside.txt"
ln -s "$scanner/outside.txt" "$scanner/artifacts/escape.txt"
if run_scanner "$scanner" 2>/dev/null; then fail "inner symlink was accepted"; fi
echo "PASS scanner-inner-symlink"

scanner="$test_root/scanner-root-symlink"
make_scanner_fixture "$scanner"
mv "$scanner/artifacts" "$scanner/real-artifacts"
ln -s "$scanner/real-artifacts" "$scanner/artifacts"
if run_scanner "$scanner" 2>/dev/null; then fail "symlinked root was accepted"; fi
echo "PASS scanner-root-symlink"

scanner="$test_root/scanner-sibling"
make_scanner_fixture "$scanner"
mkdir -p "${scanner}-escape"
if run_scanner "$scanner" "${scanner}-escape" 2>/dev/null; then fail "sibling root was accepted"; fi
echo "PASS scanner-sibling"

scanner="$test_root/scanner-unreadable"
make_scanner_fixture "$scanner"
printf 'unreadable\n' > "$scanner/artifacts/unreadable.txt"
chmod 000 "$scanner/artifacts/unreadable.txt"
if run_scanner "$scanner" 2>/dev/null; then fail "unreadable artifact was accepted"; fi
echo "PASS scanner-unreadable"

scanner="$test_root/scanner-count"
make_scanner_fixture "$scanner"
python3 - "$scanner/Scripts/scan-s1-01-artifacts.swift" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "    processedPNGCount += 1"
assert source.count(old) == 1
path.write_text(source.replace(old, "    processedPNGCount += 0"))
PY
if run_scanner "$scanner" 2>/dev/null; then fail "processed-count mutant was accepted"; fi
echo "PASS scanner-count"

echo "PASS test-run-maestro"
