#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
temporary_root=$(mktemp -d)
trap 'rm -rf "$temporary_root"' EXIT

expect_failure() {
    local label=$1
    local file=$2
    local needle=$3
    local replacement=$4
    local copy="$temporary_root/$label"
    mkdir -p "$copy/Sources" "$copy/Tests" "$copy/iOS Example" "$copy/Scripts" "$copy/.github/workflows" "$copy/.maestro"
    cp -R "$repository_root/Sources/ThorChainKit" "$copy/Sources/"
    cp -R "$repository_root/Tests/ThorChainKitTests" "$copy/Tests/"
    cp -R "$repository_root/Tests/ThorChainKitLiveTests" "$copy/Tests/"
    cp -R "$repository_root/iOS Example/Sources" "$copy/iOS Example/"
    cp "$repository_root/Package.swift" "$copy/"
    cp "$repository_root/Scripts/verify-s1-02-ci-policy.sh" "$repository_root/Scripts/verify-s1-03.sh" \
        "$repository_root/Scripts/verify-bigint-floor.sh" "$repository_root/Scripts/verify-s1-04.sh" \
        "$repository_root/Scripts/run-maestro.sh" "$copy/Scripts/"
    cp "$repository_root/.github/workflows/ci.yml" "$copy/.github/workflows/"
    cp "$repository_root/.maestro/config.yaml" "$repository_root/.maestro/flows/03-account-read-fixture.yaml" \
        "$copy/.maestro/"
    git -C "$copy" init -q
    git -C "$copy" add -f .
    git -C "$copy" -c user.name=mutant -c user.email=mutant@example.invalid commit -qm fixture
    python3 - "$copy/$file" "$needle" "$replacement" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
needle, replacement = sys.argv[2:]
assert source.count(needle) == 1
path.write_text(source.replace(needle, replacement))
PY
    if (cd "$copy" && Scripts/verify-s1-04.sh --source-only >/dev/null 2>&1); then
        echo "FAIL test-s1-04-mutants: $label was accepted" >&2
        exit 1
    fi
    echo "PASS $label"
}

expect_failure shared-transport \
    Sources/ThorChainKit/Network/HTTPTransporting.swift \
    'protocol HTTPTransporting: Sendable' \
    'protocol HttpTransport: Sendable'
expect_failure total-pagination \
    Sources/ThorChainKit/Network/LiveThorNodeClient.swift \
    'private let maximumBalancePageCount: Int' \
    'private let maximumBalancePageCount: Int\n    // pagination.total'
expect_failure unchecked-transport \
    Sources/ThorChainKit/Network/AccountReadTransport.swift \
    'struct AccountTransport: Equatable, Sendable' \
    'struct AccountTransport: Equatable, @unchecked Sendable'
