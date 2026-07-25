#!/usr/bin/env python3
"""Fail-closed checks for the bounded S2-06 artifact directory."""
import hashlib
import json
import pathlib
import subprocess
import sys


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify-s2-06-artifacts.py <artifact-dir> <udid>")
    root = pathlib.Path(__file__).resolve().parents[1]
    artifact = pathlib.Path(sys.argv[1]).resolve()
    udid = sys.argv[2]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip():
        raise SystemExit("dirty tracked input")
    junit = artifact / "junit.xml"
    if not junit.is_file():
        raise SystemExit("missing JUnit")
    text = junit.read_text()
    if text.count("<testcase ") != 5 or any(f'{key}="{value}"' in text for key, value in (("failures", "1"), ("errors", "1"), ("skipped", "1"))):
        raise SystemExit("JUnit count or status is not exactly five passing cases")
    manifest = {"version": 1, "head": head, "udid": udid, "junit": digest(junit)}
    (artifact / "evidence-manifest.json").write_text(json.dumps(manifest, sort_keys=True) + "\n")
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
