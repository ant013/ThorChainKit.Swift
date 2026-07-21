#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repository_root"

fail() {
    echo "FAIL verify-s1-04-live: $1" >&2
    exit 1
}

[[ ${THORCHAIN_S1_04_LIVE:-} == 1 ]] \
    || fail "UNRUN: THORCHAIN_S1_04_LIVE=1 is required"

required_variables=(
    THORCHAIN_S1_04_EXPECTED_HEAD
    THORCHAIN_S1_04_FAMILY_ID
    THORCHAIN_S1_04_COSMOS_URL
    THORCHAIN_S1_04_COMET_URL
    THORCHAIN_S1_04_EXISTING_ADDRESS
    THORCHAIN_S1_04_ABSENT_ADDRESS
    THORCHAIN_SIMULATOR_UDID
)
for variable in "${required_variables[@]}"; do
    [[ -n ${!variable:-} ]] || fail "UNRUN: $variable is required"
done

expected_head=$THORCHAIN_S1_04_EXPECTED_HEAD
simulator_udid=$THORCHAIN_SIMULATOR_UDID
[[ "$expected_head" =~ ^[0-9a-f]{40}$ ]] || fail "expected head must be a 40-character SHA"
[[ "$simulator_udid" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
    || fail "THORCHAIN_SIMULATOR_UDID must contain one UUID"
[[ "$(git rev-parse HEAD)" == "$expected_head" ]] || fail "HEAD is not the expected head"
[[ -z "$(git status --porcelain)" ]] || fail "implementation HEAD must be clean"

python3 - <<'PY' || fail "public live inputs are malformed or contain credentials"
import os
import re
from urllib.parse import urlsplit

family = os.environ["THORCHAIN_S1_04_FAMILY_ID"]
assert re.fullmatch(r"[A-Za-z0-9._-]{1,64}", family)
for name in ["THORCHAIN_S1_04_COSMOS_URL", "THORCHAIN_S1_04_COMET_URL"]:
    value = urlsplit(os.environ[name])
    assert value.scheme == "https"
    assert value.hostname
    assert value.username is None and value.password is None
    assert not value.query and not value.fragment
for name in ["THORCHAIN_S1_04_EXISTING_ADDRESS", "THORCHAIN_S1_04_ABSENT_ADDRESS"]:
    assert re.fullmatch(r"thor1[023456789acdefghjklmnpqrstuvwxyz]{38}", os.environ[name])
assert os.environ["THORCHAIN_S1_04_EXISTING_ADDRESS"] != os.environ["THORCHAIN_S1_04_ABSENT_ADDRESS"]
PY

device_list=$(xcrun simctl list devices available -j)
python3 - "$simulator_udid" "$device_list" <<'PY' \
    || fail "the configured simulator is unavailable"
import json
import sys

udid = sys.argv[1].lower()
devices = json.loads(sys.argv[2])["devices"]
matches = [
    device
    for runtime in devices.values()
    for device in runtime
    if device.get("isAvailable") and device.get("udid", "").lower() == udid
]
assert len(matches) == 1
assert matches[0].get("state") in {"Shutdown", "Booted"}
PY

output_dir="$repository_root/build/s1-04-live/$expected_head"
evidence="$output_dir/evidence.json"
result_bundle="$output_dir/ThorChainKitLiveTests.xcresult"
derived_data="$output_dir/DerivedData"
allowlist="$repository_root/Tests/ThorChainKitLiveTests/Fixtures/S1-04-live-tests.txt"
[[ -f "$allowlist" && -s "$allowlist" ]] || fail "live test allowlist is unavailable"
[[ ! -e "$output_dir" ]] || fail "live evidence output already exists"
mkdir -p "$output_dir"

THORCHAIN_S1_04_EVIDENCE_PATH="$evidence" \
xcodebuild \
    -scheme ThorChainKit \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -derivedDataPath "$derived_data" \
    -resultBundlePath "$result_bundle" \
    -only-testing:ThorChainKitLiveTests \
    SWIFT_VERSION=5 \
    SWIFT_STRICT_CONCURRENCY=complete \
    SWIFT_SUPPRESS_WARNINGS=NO \
    CODE_SIGNING_ALLOWED=NO \
    test || fail "live test command failed"

Scripts/verify-xcresult.sh verify-s1-04-live "$result_bundle" "$allowlist"
[[ -f "$evidence" && ! -L "$evidence" ]] || fail "live evidence JSON is unavailable"
python3 - "$evidence" "$expected_head" "$THORCHAIN_S1_04_FAMILY_ID" <<'PY' \
    || fail "live evidence schema or values differ"
from datetime import datetime
import json
from pathlib import Path
import re
import sys

path, expected_head, expected_family = sys.argv[1:]
data = json.loads(Path(path).read_text())
assert data["schemaVersion"] == 1
assert data["head"] == expected_head
assert data["familyId"] == expected_family
assert data["chainId"] == "thorchain-1"
datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
for field in ["cosmosHeight", "cometHeight", "acceptedHeight"]:
    assert isinstance(data[field], int) and data[field] > 0
assert data["acceptedHeight"] == data["cosmosHeight"]
assert abs(data["cosmosHeight"] - data["cometHeight"]) <= 5
existing = data["existing"]
assert existing["class"] == "existing" and existing["accountExists"] is True
assert re.fullmatch(r"0|[1-9][0-9]*", existing["rawRuneAmount"])
assert existing["rawRuneAmount"] == existing["implementationRuneAmount"]
absent = data["absent"]
assert absent == {"class": "absent", "accountExists": False, "balanceCount": 0}
serialized = json.dumps(data, sort_keys=True)
assert not re.search(r"(?i)(url|address|mnemonic|seed phrase|private key|api.?key|bearer)", serialized)
PY

echo "PASS verify-s1-04-live head=$expected_head evidence=build/s1-04-live/$expected_head/evidence.json"
