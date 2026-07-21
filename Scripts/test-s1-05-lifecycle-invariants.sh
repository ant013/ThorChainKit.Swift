#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
destination='id=0A88BC07-1DF9-490A-BCAF-6FA2165F6B17'
temporary_root=$(mktemp -d)
trap 'find "$temporary_root" -depth -delete' EXIT

if ! xcodebuild build-for-testing \
    -scheme ThorChainKit \
    -destination "$destination" \
    -derivedDataPath "$temporary_root/shared-derived" \
    SWIFT_VERSION=5 \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO \
    >"$temporary_root/baseline.log" 2>&1; then
    tail -80 "$temporary_root/baseline.log" >&2 || true
    echo "FAIL lifecycle baseline build" >&2
    exit 1
fi

run_probe() {
    local name=$1 selector=$2 marker=$3
    local log="$temporary_root/$name.log"
    local result="$temporary_root/$name.xcresult"
    local pid status elapsed marker_count unexpected_count
    local started=$(date +%s)

    xcodebuild test-without-building \
        -scheme ThorChainKit \
        -destination "$destination" \
        -derivedDataPath "$temporary_root/shared-derived" \
        -resultBundlePath "$result" \
        -collect-test-diagnostics never \
        -only-testing:"ThorChainKitTests/LifecycleInvariantProbeTests/$selector" \
        SWIFT_SUPPRESS_WARNINGS=NO \
        >"$log" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        elapsed=$(( $(date +%s) - started ))
        if (( elapsed >= 20 )); then
            kill -TERM "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            tail -40 "$log" >&2 || true
            echo "FAIL $name timed out" >&2
            exit 1
        fi
        sleep 0.1
    done
    if wait "$pid"; then status=0; else status=$?; fi
    (( status != 0 )) || { tail -40 "$log" >&2 || true; echo "FAIL $name exited zero" >&2; exit 1; }

    marker_count=$(rg -o "$marker" "$log" | wc -l | tr -d ' ' || true)
    unexpected_count=$(rg -o 'S105_INVARIANT_[A-Z_]+' "$log" | rg -v -F "$marker" | wc -l | tr -d ' ' || true)
    unexpected_count=${unexpected_count:-0}
    [[ "$marker_count" == 1 ]] || { tail -40 "$log" >&2 || true; echo "FAIL $name marker count=$marker_count" >&2; exit 1; }
    [[ "$unexpected_count" == 0 ]] || { tail -40 "$log" >&2 || true; echo "FAIL $name emitted an unexpected invariant marker" >&2; exit 1; }
    echo "PASS $name $marker"
}

run_probe duplicate-start testDuplicateStart S105_INVARIANT_DUPLICATE_START
run_probe stopped-refresh testStoppedRefresh S105_INVARIANT_STOPPED_REFRESH
run_probe duplicate-stop testDuplicateStop S105_INVARIANT_DUPLICATE_STOP

echo "PASS S1-05 lifecycle invariant protocol"
