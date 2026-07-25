#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
python3 - "$root/Scripts/sprint-02-flow-manifest.json" "$root/.maestro/sprint-02" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
flows = manifest["flows"]
expected = {"send-quote-review", "send-checktx-accepted", "send-unknown", "send-retry", "send-restart-pending"}
assert len(flows) == 5 and {item["flow"] for item in flows} == expected
for item in flows:
    assert item["actions"] and item["assertions"]
    assert (pathlib.Path(sys.argv[2]) / f'{item["flow"]}.yaml').is_file()
print("Maestro manifest contract OK")
PY
