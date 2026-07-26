#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
validator="$root/Scripts/validate-s2-06-manifest.py"
python3 "$validator" "$root/Scripts/sprint-02-flow-manifest.json" "$root/.maestro/sprint-02"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp "$root/Scripts/sprint-02-flow-manifest.json" "$tmp/manifest.json"
cp -R "$root/.maestro/sprint-02" "$tmp/flows"
jq '.flows[0].assertions = []' "$tmp/manifest.json" > "$tmp/mutated.json"
if python3 "$validator" "$tmp/mutated.json" "$tmp/flows" >/dev/null 2>&1; then
    echo "manifest negative mutation unexpectedly passed" >&2
    exit 1
fi
jq '.flows[1].actions[5] = "skip confirmation"' "$tmp/manifest.json" > "$tmp/mutated-actions.json"
if python3 "$validator" "$tmp/mutated-actions.json" "$tmp/flows" >/dev/null 2>&1; then
    echo "manifest action mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/lifecycle-flows"
perl -0pi -e 's/- tapOn:\n    id: lifecycle-start\n//' "$tmp/lifecycle-flows/send-checktx-accepted.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/lifecycle-flows" >/dev/null 2>&1; then
    echo "lifecycle-start removal mutation unexpectedly passed" >&2
    exit 1
fi
perl -0pi -e 's/^.*send\.result\.local-hash.*\n//mg' "$tmp/flows/send-checktx-accepted.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/flows" >/dev/null 2>&1; then
    echo "YAML negative mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/confirm-flows"
perl -0pi -e 's/(- tapOn:\n    id:) send\.confirm\.button/$1 send.confirm.missing/' "$tmp/confirm-flows/send-checktx-accepted.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/confirm-flows" >/dev/null 2>&1; then
    echo "Confirm-action negative mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/expiry-flows"
perl -0pi -e 's/    enabled: true\n//' "$tmp/expiry-flows/send-quote-review.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/expiry-flows" >/dev/null 2>&1; then
    echo "pre-expiry enabled-removal mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/expiry-true-flows"
perl -0pi -e 's/    enabled: true/    enabled: false/' "$tmp/expiry-true-flows/send-quote-review.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/expiry-true-flows" >/dev/null 2>&1; then
    echo "pre-expiry enabled-inversion mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/expiry-false-flows"
perl -0pi -e 's/    enabled: false/    enabled: true/' "$tmp/expiry-false-flows/send-quote-review.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/expiry-false-flows" >/dev/null 2>&1; then
    echo "expiry disabled-state inversion mutation unexpectedly passed" >&2
    exit 1
fi
cp -R "$root/.maestro/sprint-02" "$tmp/scenario-flows"
perl -0pi -e 's/("--example-scenario":\s*")send-checktx-accepted("\s*)/$1send-unknown$2/' "$tmp/scenario-flows/send-checktx-accepted.yaml"
if python3 "$validator" "$tmp/manifest.json" "$tmp/scenario-flows" >/dev/null 2>&1; then
    echo "scenario binding negative mutation unexpectedly passed" >&2
    exit 1
fi
rg -q 'parts\.count == 1 \|\| !fraction\.isEmpty' "$root/iOS Example/Sources/Send/SendAmountInput.swift"
rg -q 'Mnemonic\.validate\(words: secret\.words\)' "$root/iOS Example/Sources/Signing/LiveSendSession.swift"
rg -q 'attributes\[\.type\].*\.typeRegular' "$root/iOS Example/LiveSupport/LiveSecretLoader.swift"
rg -q 'FixtureTranscript\(expected: scenario\.expectedRequests\)' "$root/iOS Example/Sources/Core/ExampleRuntime.swift"
rg -q 'acceptedBytes' "$root/iOS Example/Sources/Signing/FixtureTransport.swift"
rg -q 'scenario\.id == \.unknown \|\| scenario\.id == \.retry' "$root/iOS Example/Sources/Signing/FixtureTransport.swift"
rg -q 'guard raw == scenario\.expectedSignedBytes else' "$root/iOS Example/Sources/Signing/FixtureTransport.swift"
python3 - "$root/iOS Example/Sources/Signing/FixtureTransport.swift" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
guard = "guard raw == scenario.expectedSignedBytes else { throw URLError(.cannotParseResponse) }"

def validate(value: str) -> None:
    if guard not in value:
        raise AssertionError("signed-byte acceptance guard is missing")

validate(source)
mutant = source.replace(guard, "guard raw != scenario.expectedSignedBytes else { throw URLError(.cannotParseResponse) }", 1)
try:
    validate(mutant)
except AssertionError:
    print("signed-byte negative mutation rejected")
else:
    raise SystemExit("signed-byte negative mutation unexpectedly passed")
PY
python3 - "$root/iOS Example/Sources/Signing/FixtureTransport.swift" <<'PY'
import base64
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
values = dict(re.findall(
    r'private static let (\w+Response) = Data\(base64Encoded: "([^"]+)"\)!',
    source,
))
expected_names = {"senderAccountResponse", "recipientAccountResponse", "networkResponse"}
if set(values) != expected_names:
    raise SystemExit("fixture response matrix is incomplete")

def validate(value: str) -> None:
    if "guard query.count == 3" not in value:
        raise AssertionError("ABCI query cardinality guard is missing")
    if "private func cometEnvelope(_ value: Data) -> Data" not in value:
        raise AssertionError("Comet envelope helper is missing")
    match = re.search(r'return Data\(#"(?P<wire>.*?)"#\.utf8\)', value)
    if match is None:
        raise AssertionError("Comet envelope wire template is missing")
    template = match.group("wire")
    for name, encoded in values.items():
        if f"cometEnvelope(Self.{name})" not in value:
            raise AssertionError(f"{name} is not enveloped")
        envelope = {
            "jsonrpc": "2.0",
            "id": 1,
            "result": {"response": {"code": 0, "height": "12345678", "value": encoded}},
        }
        wire = template.replace(r'\#(encoded)', encoded)
        if json.loads(wire) != envelope:
            raise AssertionError("invalid Comet envelope contract")
        base64.b64decode(encoded, validate=True)

validate(source)
mutant = source.replace(
    'cometEnvelope(Self.networkResponse)',
    'Self.networkResponse',
    1,
)
try:
    validate(mutant)
except AssertionError:
    print("fixture behavioral envelope negative mutation rejected")
else:
    raise SystemExit("fixture raw-envelope mutation unexpectedly passed")
PY
rg -q 'isQuoteExpired' "$root/iOS Example/Sources/Send/SendViewModel.swift"
rg -q 'value: model\.dataSource' "$root/iOS Example/Sources/Views/DiagnosticsView.swift"
rg -q 'artifactDigests' "$root/Scripts/verify-s2-06-artifacts.py"
rg -q 'maestro hierarchy' "$root/Scripts/run-maestro-s2-06.sh"
rg -q 'scan-s2-06-ocr.swift' "$root/Scripts/run-maestro-s2-06.sh"
echo "S2-06 manifest negative mutations rejected"
