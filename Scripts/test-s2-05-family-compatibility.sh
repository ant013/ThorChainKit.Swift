#!/bin/zsh
set -euo pipefail

if (( $# != 1 )) || [[ "$1" != "--fixture-only" ]]; then
    print -u2 "usage: $0 --fixture-only"
    exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
test "$(xcrun swift test --list-tests | rg -c 'BroadcastRetryTests[./]testUnapprovedProductionFamilyIsUnavailableWithoutIO')" -eq 1
xcrun swift test --filter BroadcastRetryTests/testUnapprovedProductionFamilyIsUnavailableWithoutIO
