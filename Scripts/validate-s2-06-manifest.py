#!/usr/bin/env python3
"""Validate the semantic S2-06 five-flow contract and its committed YAML."""
import json
import pathlib
import re
import sys

EXPECTED = {
    "send-quote-review": {
        "actions": [
            ("launch send-quote-review", ["launchApp:", '"--example-scenario": "send-quote-review"']),
            ("enter amount", ["- tapOn:\n    id: send.amount.input", 'inputText: "1.25"']),
            ("enter memo", ["- tapOn:\n    id: send.memo.input", 'inputText: "fixture memo"']),
            ("quote", ["- tapOn:\n    id: send.quote.button"]),
            ("advance exact deadline", ["- tapOn:\n    id: send.fixture.advance-to-expiry"]),
        ],
        "assertions": [
            ("review recipient", ["- assertVisible:\n    id: send.review.recipient"]),
            ("review amount", ["- assertVisible:\n    id: send.review.amount"]),
            ("review memo", ["- assertVisible:\n    id: send.review.memo"]),
            ("review native fee", ["- assertVisible:\n    id: send.review.native-fee"]),
            ("review total", ["- assertVisible:\n    id: send.review.total"]),
            ("review height", ["- assertVisible:\n    id: send.review.height"]),
            ("absolute expiry", ["- assertVisible:\n    id: send.review.expiry"]),
            ("expiry disables confirm", ["- assertNotEnabled:\n    id: send.confirm.button"]),
            ("zero signer calls", ["- assertVisible:\n    id: send.fixture.signer-call-count\n    text: \"0\""]),
        ],
    },
    "send-checktx-accepted": {
        "actions": [
            ("launch send-checktx-accepted", ["launchApp:", '"--example-scenario": "send-checktx-accepted"']),
            ("quote", ["- tapOn:\n    id: send.quote.button"]),
            ("confirm", ["- tapOn:\n    id: send.confirm.button"]),
        ],
        "assertions": [
            ("CheckTx accepted — not confirmed", ['- assertVisible:\n    text: "CheckTx accepted — not confirmed"']),
            ("local hash", ["- assertVisible:\n    id: send.result.local-hash"]),
        ],
    },
    "send-unknown": {
        "actions": [
            ("launch send-unknown", ["launchApp:", '"--example-scenario": "send-unknown"']),
            ("quote", ["- tapOn:\n    id: send.quote.button"]),
            ("confirm", ["- tapOn:\n    id: send.confirm.button"]),
        ],
        "assertions": [
            ("Unknown — retry available", ['- assertVisible:\n    text: "Unknown — retry available"']),
            ("canonical local hash", ["- assertVisible:\n    id: send.result.local-hash"]),
            ("retry available", ["- assertVisible:\n    id: send.retry.button"]),
        ],
    },
    "send-retry": {
        "actions": [
            ("launch send-retry", ["launchApp:", '"--example-scenario": "send-retry"']),
            ("restore unknown pending", ["- tapOn:\n    id: send.confirm.button"]),
            ("acknowledge current fee", ["- tapOn:\n    id: send.retry.button"]),
            ("retry", ["- tapOn:\n    id: send.retry.button"]),
        ],
        "assertions": [
            ("same hash", ["- assertVisible:\n    id: send.retry.hash-unchanged\n    text: \"true\""]),
            ("same signer count", ["- assertVisible:\n    id: send.retry.signer-count-unchanged\n    text: \"true\""]),
            ("previous native fee", ["- assertVisible:\n    id: send.retry.previous-fee"]),
            ("current native fee", ["- assertVisible:\n    id: send.retry.current-fee"]),
            ("exact current-fee acknowledgement", ["- assertVisible:\n    id: send.retry.response"]),
            ("sdk/19", ["- assertVisible:\n    id: send.retry.response", 'text: "sdk/19"']),
            ("signer count unchanged", ["- assertVisible:\n    id: send.fixture.signer-call-count\n    text: \"1\""]),
        ],
    },
    "send-restart-pending": {
        "actions": [
            ("launch send-restart-pending", ["launchApp:", '"--example-scenario": "send-restart-pending"']),
            ("create pending", ["- tapOn:\n    id: send.confirm.button"]),
            ("relaunch same namespace", ["- launchApp\n- assertVisible:"]),
        ],
        "assertions": [
            ("pending before relaunch", ["- assertVisible:\n    id: send.pending.list"]),
            ("pending after relaunch", ["- assertVisible:\n    id: send.pending.list"]),
            ("same namespace", ["- assertVisible:\n    id: send.pending.namespace"]),
            ("empty versus unavailable", ["- assertVisible:\n    text: \"thor-example/fixture/send-restart-pending\""]),
        ],
    },
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
        contract = EXPECTED[name]
        for kind in ("actions", "assertions"):
            expected = contract[kind]
            labels = [label for label, _ in expected]
            if item.get(kind) != labels:
                fail(f"{name}: manifest {kind} do not match the approved matrix")
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
        for kind in ("actions", "assertions"):
            for label, needles in contract[kind]:
                if not all(needle in text for needle in needles):
                    fail(f"{name}: missing {kind[:-1]} {label}")
        pending_assertion = "- assertVisible:\n    id: send.pending.list"
        if name == "send-restart-pending" and text.count(pending_assertion) < 2:
            fail(f"{name}: pending list must be asserted before and after relaunch")
    print("S2-06 semantic manifest contract OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
