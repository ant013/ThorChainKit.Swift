#!/usr/bin/env python3
"""Emit a digest-only manifest for one local verification input root."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def git(root: Path, *args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(root), *args],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout


def file_membership(root: Path) -> list[str]:
    paths = git(root, "ls-files", "-c", "-o", "--exclude-standard", "-z")
    return sorted(
        set(paths.decode("utf-8").split("\0")[:-1]),
        key=lambda path: path.encode("utf-8"),
    )


def file_record(root: Path, relative_path: str) -> dict[str, object]:
    path = root / relative_path
    if path.is_symlink():
        raise ValueError(f"symlink rejected: {relative_path}")
    if not path.exists():
        return {
            "path": relative_path,
            "state": "deleted",
            "size": 0,
            "sha256": hashlib.sha256(b"").hexdigest(),
        }
    if not path.is_file():
        raise ValueError(f"non-file path: {relative_path}")
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            size += len(chunk)
            digest.update(chunk)
    return {
        "path": relative_path,
        "state": "present",
        "size": size,
        "sha256": digest.hexdigest(),
    }


def capture(root: Path, root_label: str) -> dict[str, object]:
    if not root.is_dir():
        raise ValueError(f"root is not a directory: {root_label}")
    head = git(root, "rev-parse", "HEAD").decode("ascii").strip()
    status = git(root, "status", "--porcelain=v1", "--untracked-files=all", "-z")
    return {
        "schemaVersion": 1,
        "rootLabel": root_label,
        "head": head,
        "statusSha256": hashlib.sha256(status).hexdigest(),
        "files": [file_record(root, path) for path in file_membership(root)],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root-label", required=True)
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()
    result = capture(args.root.resolve(), args.root_label)
    print(json.dumps(result, ensure_ascii=True, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
