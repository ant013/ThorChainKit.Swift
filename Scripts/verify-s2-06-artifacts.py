#!/usr/bin/env python3
"""Fail-closed provenance, UI-tree, screenshot, and canary checks for S2-06."""
import hashlib
import json
import pathlib
import subprocess
import sys

SENSITIVE = ("mnemonic", "seed phrase", "private key", "signature", "account sequence", "credential", "secret")
REQUIRED = {"junit.xml", "build-settings.json", "ui-tree.json", "screenshots/ocr-self-test.json"}


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(message)


def tracked_inputs(root: pathlib.Path) -> dict[str, str]:
    names = subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines()
    return {
        name: digest(root / name)
        for name in names
        if name.startswith(("iOS Example/", ".maestro/", "Scripts/"))
        and not name.endswith((".sqlite", ".env"))
    }


def scan_bytes(root: pathlib.Path) -> None:
    for path in root.rglob("*"):
        if not path.is_file() or path.name == "evidence-manifest.json":
            continue
        data = path.read_bytes()
        lowered = data.lower()
        if any(token.encode() in lowered for token in SENSITIVE):
            fail(f"sensitive canary in artifact: {path.relative_to(root)}")


def verify_ui_tree(path: pathlib.Path) -> None:
    payload = json.loads(path.read_text())
    nodes = payload.get("nodes")
    if not isinstance(nodes, list) or not nodes:
        fail("runtime UI tree is missing or empty")
    required_ids = {"send.mode-badge", "send.recipient.input", "send.amount.input", "send.confirm.button"}
    seen = {node.get("identifier") for node in nodes if isinstance(node, dict)}
    if not required_ids <= seen:
        fail("runtime UI tree is missing required identifiers")
    for node in nodes:
        if not isinstance(node, dict):
            fail("runtime UI tree contains an invalid node")
        values = json.dumps(node, sort_keys=True).lower()
        if any(token in values for token in SENSITIVE):
            fail("runtime UI tree contains a sensitive value")


def verify_junit(path: pathlib.Path) -> None:
    text = path.read_text()
    if text.count("<testcase ") != 5:
        fail("JUnit must contain exactly five test cases")
    for key in ("failures", "errors", "skipped"):
        if f'{key}="0"' not in text:
            fail(f"JUnit {key} is not zero")


def main() -> int:
    if len(sys.argv) != 3:
        fail("usage: verify-s2-06-artifacts.py <artifact-dir> <udid>")
    root = pathlib.Path(__file__).resolve().parents[1]
    artifact = pathlib.Path(sys.argv[1]).resolve()
    udid = sys.argv[2]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    if artifact.name != pathlib.Path(udid).name:
        fail("artifact directory is not UDID-scoped")
    if artifact.parent.name != head:
        fail("artifact directory is not HEAD-scoped")
    if subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=root, text=True).strip():
        fail("tracked input is dirty")
    if not artifact.is_dir():
        fail("artifact directory is missing")
    actual = {str(path.relative_to(artifact)) for path in artifact.rglob("*") if path.is_file()}
    missing = REQUIRED - actual
    if missing:
        fail(f"missing required artifacts: {sorted(missing)}")
    allowed = REQUIRED | {"evidence-manifest.json"} | {
        name for name in actual if name.startswith("screenshots/")
    }
    if actual - allowed:
        fail(f"unexpected artifact files: {sorted(actual - allowed)}")
    verify_junit(artifact / "junit.xml")
    verify_ui_tree(artifact / "ui-tree.json")
    ocr = json.loads((artifact / "screenshots/ocr-self-test.json").read_text())
    if ocr.get("images", 0) <= 0 or not ocr.get("visionInitialized") or not ocr.get("readable") or ocr.get("canariesMissed"):
        fail("Vision/OCR screenshot self-test did not pass")
    if not any(path.suffix.lower() in {".png", ".jpg", ".jpeg"} for path in (artifact / "screenshots").rglob("*")):
        fail("screenshot evidence is missing")
    settings = json.loads((artifact / "build-settings.json").read_text())
    if settings.get("scheme") != "ThorChainExampleFixture" or settings.get("configuration") != "Debug" or settings.get("udid") != udid:
        fail("build scheme/configuration/UDID is not exact")
    executable = pathlib.Path(settings.get("resolvedExecutable", ""))
    if not executable.is_file():
        fail("resolved executable is missing")
    inputs = tracked_inputs(root)
    manifest_path = artifact / "evidence-manifest.json"
    if manifest_path.exists():
        prior = json.loads(manifest_path.read_text())
        if prior.get("head") != head or prior.get("udid") != udid or prior.get("trackedInputs") != inputs:
            fail("artifact provenance is missing, wrong-head, or tampered")
        current_digests = {
            name: digest(artifact / name)
            for name in sorted(actual)
            if name != "evidence-manifest.json"
        }
        if prior.get("artifactDigests") != current_digests:
            fail("artifact content was tampered after provenance capture")
    scan_bytes(artifact)
    manifest = {
        "version": 2,
        "head": head,
        "udid": udid,
        "scheme": settings["scheme"],
        "configuration": settings["configuration"],
        "resolvedExecutable": str(executable),
        "artifactDigests": {name: digest(artifact / name) for name in sorted(actual) if name != "evidence-manifest.json"},
        "trackedInputs": inputs,
    }
    manifest_path.write_text(json.dumps(manifest, sort_keys=True) + "\n")
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
