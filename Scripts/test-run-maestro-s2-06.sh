#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
flow="$root/.maestro/sprint-02/send-checktx-accepted.yaml"

[[ -f "$flow" ]] || { echo "S2-06 accepted-send flow is missing" >&2; exit 1; }
bash -n "$root/Scripts/run-maestro.sh" "$root/Scripts/run-maestro-s2-06.sh"
rg -q '^name: send-checktx-accepted$' "$flow"
rg -q 'id: send\.confirm\.button' "$flow"
rg -q 'CheckTx accepted — not confirmed' "$flow"
[[ "$(find "$root/.maestro/sprint-02" -maxdepth 1 -type f -name '*.yaml' | wc -l | tr -d ' ')" == "1" ]] \
    || { echo "S2-06 must contain exactly one Maestro flow" >&2; exit 1; }

echo "S2-06 single-flow contract OK"
