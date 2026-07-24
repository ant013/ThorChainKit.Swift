#!/bin/zsh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
database="$(mktemp -u "/tmp/thorchainkit-s2-05-restart.XXXXXX.sqlite")"
trap 'rm -f "$database" "$database-shm" "$database-wal"' EXIT

cd "$root"
test "$(xcrun swift test --list-tests | rg -c 'SendJournalRestartTests[./]testSeedBroadcastingForRestart')" -eq 1
test "$(xcrun swift test --list-tests | rg -c 'SendJournalRestartTests[./]testSeparateProcessRecoversBroadcastingAsUnknown')" -eq 1
THR_S205_RESTART_DB="$database" xcrun swift test --filter SendJournalRestartTests/testSeedBroadcastingForRestart
THR_S205_RESTART_DB="$database" xcrun swift test --filter SendJournalRestartTests/testSeparateProcessRecoversBroadcastingAsUnknown
