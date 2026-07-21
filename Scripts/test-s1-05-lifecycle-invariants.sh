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
xctestrun=$(find "$temporary_root/shared-derived" -name '*.xctestrun' -print -quit)
[[ -n "$xctestrun" ]] || { echo "FAIL lifecycle missing xctestrun" >&2; exit 1; }

run_probe() {
    local name=$1 selector=$2 marker=$3
    local log="$temporary_root/$name.log"
    local pid watchdog_pid monitor_pid status marker_count unexpected_count
    local timeout_flag="$temporary_root/$name.timeout"
    rm -f "$timeout_flag"

    xcodebuild test-without-building \
        -xctestrun "$xctestrun" \
        -destination "$destination" \
        -collect-test-diagnostics never \
        -only-testing:"ThorChainKitTests/LifecycleInvariantProbeTests/$selector" \
        SWIFT_SUPPRESS_WARNINGS=NO \
        >"$log" 2>&1 &
    pid=$!

    (
        sleep 20
        if kill -0 "$pid" 2>/dev/null; then
            : >"$timeout_flag"
            kill -TERM "$pid" 2>/dev/null || true
        fi
    ) &
    watchdog_pid=$!

    (
        while ! rg -q 'S105_INVARIANT_[A-Z_]+' "$log" 2>/dev/null; do
            sleep 0.05
        done
        kill -TERM "$pid" 2>/dev/null || true
    ) &
    monitor_pid=$!

    if wait "$pid"; then status=0; else status=$?; fi
    kill -TERM "$watchdog_pid" 2>/dev/null || true
    kill -TERM "$monitor_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
    if [[ -e "$timeout_flag" ]]; then
        tail -40 "$log" >&2 || true
        echo "FAIL $name timed out" >&2
        exit 1
    fi
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
