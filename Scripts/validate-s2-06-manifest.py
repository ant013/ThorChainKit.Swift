#!/usr/bin/env python3
"""Validate the semantic S2-06 five-flow contract and its committed YAML."""
import json
import pathlib
import re
import sys

EXPECTED = {
    "send-quote-review": ["send.review.recipient", "send.review.amount", "send.review.expiry"],
    "send-checktx-accepted": ["CheckTx accepted", "send.result.local-hash"],
    "send-unknown": ["Unknown", "send.result.local-hash", "send.retry.button"],
    "send-retry": ["send.retry.previous-fee", "send.retry.current-fee", "send.retry.response", "send.fixture.signer-call-count"],
    "send-restart-pending": ["send.pending.list", "send.pending.namespace"],
}

def fail(message: str) -> None:
    raise SystemExit(message)

def main() -> int:
    if len(sys.argv) != 3:
        fail("usage: validate-s2-06-manifest.py <manifest> <flow-dir>")
    manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
    flow_dir = pathlib.Path(sys.argv[2])
    flows = manifest.get("flows")
    expected_names = list(EXPECTED)
    if manifest.get("version") != 1 or not isinstance(flows, list):
        fail("invalid manifest version or flows")
    if [item.get("flow") for item in flows] != expected_names:
        fail("manifest must contain the five flows in committed order")
    for item in flows:
        name = item["flow"]
        if item.get("scenarioArgument") != f"--example-scenario={name}":
            fail(f"{name}: scenario argument is not bound to flow")
        if not item.get("actions") or not item.get("assertions"):
            fail(f"{name}: action/assertion matrix is empty")
        text_path = flow_dir / f"{name}.yaml"
        if not text_path.is_file():
            fail(f"{name}: YAML is missing")
        text = text_path.read_text()
        scenario_arguments = re.findall(
            r'["\']?--example-scenario["\']?\s*:\s*["\']([^"\']+)["\']',
            text,
        )
        if "launchApp:" not in text or scenario_arguments != [name]:
            fail(f"{name}: YAML is not scenario-bound")
        for required in EXPECTED[name]:
            if required not in text:
                fail(f"{name}: missing required assertion {required}")
    print("S2-06 semantic manifest contract OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
