#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT
simulator_udid=${THORCHAIN_SIMULATOR_UDID:-}
[[ "$simulator_udid" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
    echo "FAIL test-s1-01-mutants: THORCHAIN_SIMULATOR_UDID must contain one UUID" >&2
    exit 1
}

lifecycle_test="ThorChainKitTests.PublicApiTests/testLifecycleSerializesIdempotentStartStopAndRunningRefresh"
namespace_test="ThorChainKitTests.PublicApiTests/testPersistenceNamespaceIsDeterministicInternalAndAbsentFromErrors"

run_test() {
    local label=$1 package_path=$2 test_name=$3 expect_failure=${4:-false}
    local selector="${test_name%%.*}/${test_name#*.}"
    [[ "$selector" != *'\\'* && "$selector" == */* ]] || {
        echo "FAIL $label: invalid simulator test selector: $selector" >&2
        exit 1
    }
    local result_bundle="$temporary_root/$label.xcresult"
    local allowlist="$temporary_root/$label-tests.txt"
    printf '%s\n' "$test_name" > "$allowlist"
    if (cd "$package_path" && xcodebuild -scheme ThorChainKit \
        -destination "platform=iOS Simulator,id=${simulator_udid}" \
        -derivedDataPath "$temporary_root/$label-derived-data" \
        -resultBundlePath "$result_bundle" \
        SWIFT_SUPPRESS_WARNINGS=NO \
        "-only-testing:$selector" \
        CODE_SIGNING_ALLOWED=NO test); then
        [[ "$expect_failure" == true ]] \
            || "$repository_root/Scripts/verify-xcresult.sh" "$label" "$result_bundle" "$allowlist"
    else
        [[ "$expect_failure" == true ]] \
            || { echo "FAIL $label: simulator test command failed" >&2; exit 1; }
    fi
    if [[ "$expect_failure" == true ]]; then
        "$repository_root/Scripts/verify-xcresult.sh" "$label" "$result_bundle" "$allowlist" true
    fi
}

run_test s1-01-lifecycle "$repository_root" "$lifecycle_test"
run_test s1-01-namespace "$repository_root" "$namespace_test"

copy_package() {
    local destination=$1
    mkdir -p "$destination"
    rsync -a --exclude .build --exclude .git "$repository_root/" "$destination/"
}

require_mutant_failure() {
    local package_path=$1
    local test_name=$2
    local label=$3
    run_test "$label" "$package_path" "$test_name" true
    echo "PASS $label"
}

deferred_copy="$temporary_root/deferred"
copy_package "$deferred_copy"
python3 - "$deferred_copy/Sources/ThorChainKit/Core/Kit.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = '''        if isOnFacadeDispatcher {
            let shouldDrain = pendingLifecycleCommands.isEmpty
            enqueueLifecycleCommand(kind)
            if shouldDrain && !pendingLifecycleCommands.isEmpty {
                drainPendingLifecycleCommands()
            }
            return
        }
'''
new = '''        if isOnFacadeDispatcher {
            facadeDispatcher.async {
                let shouldDrain = self.pendingLifecycleCommands.isEmpty
                self.enqueueLifecycleCommand(kind)
                if shouldDrain && !self.pendingLifecycleCommands.isEmpty {
                    self.drainPendingLifecycleCommands()
                }
            }
            return
        }
'''
if source.count(old) != 1:
    raise SystemExit("deferred mutation guard did not match exactly once")
path.write_text(source.replace(old, new), encoding="utf-8")
PY
require_mutant_failure "$deferred_copy" "$lifecycle_test" "s1-01-deferred-reentry-mutant"

separator_copy="$temporary_root/separator"
copy_package "$separator_copy"
python3 - "$separator_copy/Sources/ThorChainKit/Core/KitFactory.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = "        namespaceInput.append(0)\n"
if source.count(old) != 1:
    raise SystemExit("separator mutation guard did not match exactly once")
path.write_text(source.replace(old, ""), encoding="utf-8")
PY
require_mutant_failure "$separator_copy" "$namespace_test" "s1-01-namespace-separator-mutant"

order_copy="$temporary_root/order"
copy_package "$order_copy"
python3 - "$order_copy/Sources/ThorChainKit/Core/KitFactory.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
old = "        namespaceInput.append(contentsOf: address.network.persistenceKey.utf8)\n"
new = "        namespaceInput = Data(address.network.persistenceKey.utf8) + namespaceInput\n"
if source.count(old) != 1:
    raise SystemExit("order mutation guard did not match exactly once")
path.write_text(source.replace(old, new), encoding="utf-8")
PY
require_mutant_failure "$order_copy" "$namespace_test" "s1-01-namespace-order-mutant"

echo "PASS test-s1-01-mutants"
