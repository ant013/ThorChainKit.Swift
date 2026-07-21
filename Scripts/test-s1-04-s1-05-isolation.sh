#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
primary_lock_hash=$(shasum -a 256 Package.resolved | awk '{print $1}')
temporary_root=$(mktemp -d)
trap 'find "$temporary_root" -depth -delete' EXIT
shared_packages="$temporary_root/packages"

copy_package() {
    local destination=$1
    mkdir -p "$destination"
    cp Package.swift Package.resolved "$destination/"
    mkdir -p "$destination/Sources" "$destination/Tests"
    rsync -a Sources/ThorChainKit/ "$destination/Sources/ThorChainKit/" >/dev/null
    rsync -a Tests/ThorChainKitTests/ "$destination/Tests/ThorChainKitTests/" >/dev/null
    rsync -a Tests/ThorChainKitLiveTests/ "$destination/Tests/ThorChainKitLiveTests/" >/dev/null
}

build() {
    local directory=$1 derived=$2
    (cd "$directory" && xcodebuild build \
        -scheme ThorChainKit \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$derived" \
        -clonedSourcePackagesDirPath "$shared_packages" \
        SWIFT_VERSION=5 \
        SWIFT_STRICT_CONCURRENCY=complete \
        SWIFT_SUPPRESS_WARNINGS=NO)
}

baseline="$temporary_root/baseline"
copy_package "$baseline"
build "$baseline" "$temporary_root/baseline-derived"
THORCHAIN_SIMULATOR_UDID='0A88BC07-1DF9-490A-BCAF-6FA2165F6B17' \
    "$root/Scripts/verify-bigint-floor.sh" >/dev/null

"$root/Scripts/test-s1-05-dependency-floor.sh" >/dev/null

mutate_and_reject() {
    local name=$1
    shift
    local directory="$temporary_root/$name" log="$temporary_root/$name.log"
    copy_package "$directory"
    python3 - "$directory" "$@" <<'PY'
from pathlib import Path
import sys

directory, *arguments = sys.argv[1:]
if len(arguments) % 3:
    raise SystemExit("mutant arguments must be path/old/new triples")
for index in range(0, len(arguments), 3):
    path = Path(directory, arguments[index])
    old, new = arguments[index + 1:index + 3]
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit(f"expected exactly one anchor in {path}")
    path.write_text(source.replace(old, new, 1))
PY
    if build "$directory" "$temporary_root/$name-derived" >"$log" 2>&1; then
        echo "FAIL $name unexpectedly compiled" >&2
        exit 1
    fi
    rg -i -q 'non-sendable|not sendable|task-isolated|sending .* risks' "$log" \
        || { echo "FAIL $name did not report a non-Sendable isolation diagnostic" >&2; exit 1; }
}

mutate_and_reject \
    account-reading-protocol \
    Sources/ThorChainKit/Network/AccountReadTransport.swift \
    'func read(address: Address) async throws -> AccountReadTransport' \
    'func read(address: Address) async throws -> AccountState' \
    Sources/ThorChainKit/Network/ReadOperationCoordinator.swift \
    'func read(address: Address) async throws -> AccountReadTransport' \
    'func read(address: Address) async throws -> AccountState'

mutate_and_reject \
    storage-record-boundary \
    Sources/ThorChainKit/Storage/AccountStateStorage.swift \
    'func load(key: StorageKey) async throws -> StorageRecord?' \
    'func load(key: StorageKey) async throws -> AccountState?' \
    Sources/ThorChainKit/Storage/AccountStateStorage.swift \
    'func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool' \
    'func saveIfCurrent(_ record: AccountState, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool' \
    Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift \
    'func load(key: StorageKey) async throws -> StorageRecord?' \
    'func load(key: StorageKey) async throws -> AccountState?' \
    Sources/ThorChainKit/Storage/GrdbAccountStateStorage.swift \
    'func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool' \
    'func saveIfCurrent(_ record: AccountState, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool'

[[ "$primary_lock_hash" == "$(shasum -a 256 Package.resolved | awk '{print $1}')" ]] || {
    echo "FAIL isolation changed the primary Package.resolved" >&2
    exit 1
}

echo "PASS S1-05 isolation baseline and exact compiler mutants"
