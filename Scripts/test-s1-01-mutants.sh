#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

swift_flags=(
    -Xcc -nostdinc
    -Xcc -isystem
    -Xcc "$(xcrun clang -print-resource-dir)/include"
    -Xcc -isystem
    -Xcc "$(xcrun --sdk macosx --show-sdk-path)/usr/include"
    -Xcc -iframework
    -Xcc "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks"
)

lifecycle_test="ThorChainKitTests.PublicApiTests/testLifecycleSerializesIdempotentStartStopAndRunningRefresh"
namespace_test="ThorChainKitTests.PublicApiTests/testPersistenceNamespaceIsDeterministicInternalAndAbsentFromErrors"

swift test --package-path "$repository_root" --filter "$lifecycle_test" "${swift_flags[@]}"
swift test --package-path "$repository_root" --filter "$namespace_test" "${swift_flags[@]}"

copy_package() {
    local destination=$1
    mkdir -p "$destination"
    rsync -a --exclude .build --exclude .git "$repository_root/" "$destination/"
}

require_mutant_failure() {
    local package_path=$1
    local test_name=$2
    local label=$3
    local log="$temporary_root/$label.log"

    if swift test --package-path "$package_path" --filter "$test_name" "${swift_flags[@]}" > "$log" 2>&1; then
        echo "FAIL $label: mutant passed" >&2
        exit 1
    fi
    grep -q "Test Case .* failed" "$log" || {
        echo "FAIL $label: mutant did not reach the target assertion" >&2
        exit 1
    }
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
