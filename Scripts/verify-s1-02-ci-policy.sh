#!/bin/bash

set -euo pipefail

usage() {
  echo "usage: $0 steady-state --ref <40-char-sha>" >&2
  exit 64
}

mode=${1:-}
shift || true

ref=
while (($#)); do
  case "$1" in
    --ref)
      (($# >= 2)) || usage
      ref=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

[[ "$mode" == steady-state && -n "$ref" ]] || usage

python3 - "$ref" <<'PY'
import re
import subprocess
import sys

WORKFLOW_PATH = ".github/workflows/ci.yml"
SHA_RE = re.compile(r"[0-9a-f]{40}")

EXPECTED_WORKFLOW = r"""name: Build Only

on:
  workflow_dispatch:
    inputs:
      pr_number:
        description: Open same-repository pull request number
        required: true
        type: number
      expected_head_sha:
        description: Exact pull request head commit
        required: true
        type: string
      confirmation:
        description: Type FINAL_BUILD_ONLY
        required: true
        type: string

permissions:
  contents: read

concurrency:
  group: build-only-pr-${{ inputs.pr_number }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: macos-26
    timeout-minutes: 10
    env:
      DEVELOPER_DIR: /Applications/Xcode_26.3.app/Contents/Developer
    steps:
      - name: Preflight exact pull request head
        env:
          GH_TOKEN: ${{ github.token }}
          PR_NUMBER: ${{ inputs.pr_number }}
          EXPECTED_HEAD_SHA: ${{ inputs.expected_head_sha }}
          CONFIRMATION: ${{ inputs.confirmation }}
          EVENT_SHA: ${{ github.sha }}
          WORKFLOW_REF: ${{ github.workflow_ref }}
          WORKFLOW_SHA: ${{ github.workflow_sha }}
          DISPATCHED_REF: ${{ github.ref_name }}
          REPOSITORY: ${{ github.repository }}
        run: |
          set -euo pipefail
          [[ "$CONFIRMATION" == "FINAL_BUILD_ONLY" ]]
          [[ "$EXPECTED_HEAD_SHA" =~ ^[0-9a-f]{40}$ ]]
          [[ "$EVENT_SHA" == "$EXPECTED_HEAD_SHA" ]]
          [[ "$WORKFLOW_SHA" == "$EXPECTED_HEAD_SHA" ]]

          pull_request_json=$(gh api --method GET "repos/$REPOSITORY/pulls/$PR_NUMBER")
          jq -e \
            --arg repository "$REPOSITORY" \
            --arg dispatched_ref "$DISPATCHED_REF" \
            --arg expected_head_sha "$EXPECTED_HEAD_SHA" \
            '.state == "open"
              and .base.repo.full_name == $repository
              and .base.ref == "main"
              and .head.repo.full_name == $repository
              and .head.ref == $dispatched_ref
              and .head.sha == $expected_head_sha' \
            <<<"$pull_request_json" >/dev/null

          printf '%s\n' \
            "workflow_ref=$WORKFLOW_REF" \
            "workflow_sha=$WORKFLOW_SHA" \
            "event_sha=$EVENT_SHA" \
            "pr_head_sha=$EXPECTED_HEAD_SHA"
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
        with:
          ref: ${{ inputs.expected_head_sha }}
          fetch-depth: 1
          persist-credentials: false
      - name: Build Example
        env:
          EXPECTED_HEAD_SHA: ${{ inputs.expected_head_sha }}
        run: |
          set -euo pipefail
          [[ "$(git rev-parse HEAD)" == "$EXPECTED_HEAD_SHA" ]]
          xcodebuild \
            -workspace 'iOS Example/iOS Example.xcworkspace' \
            -scheme 'iOS Example' \
            -destination 'generic/platform=iOS Simulator' \
            CODE_SIGNING_ALLOWED=NO \
            build
"""

EXPECTED_DISPATCH = """on:
  workflow_dispatch:
    inputs:
      pr_number:
        description: Open same-repository pull request number
        required: true
        type: number
      expected_head_sha:
        description: Exact pull request head commit
        required: true
        type: string
      confirmation:
        description: Type FINAL_BUILD_ONLY
        required: true
        type: string

"""

EXPECTED_BUILD = r"""      - name: Build Example
        env:
          EXPECTED_HEAD_SHA: ${{ inputs.expected_head_sha }}
        run: |
          set -euo pipefail
          [[ "$(git rev-parse HEAD)" == "$EXPECTED_HEAD_SHA" ]]
          xcodebuild \
            -workspace 'iOS Example/iOS Example.xcworkspace' \
            -scheme 'iOS Example' \
            -destination 'generic/platform=iOS Simulator' \
            CODE_SIGNING_ALLOWED=NO \
            build
"""

FORBIDDEN = (
    (re.compile(r"(?im)(?:^|\s)(?:swift\s+)?test(?:\s|$)"), "test command"),
    (re.compile(r"(?i)-only-testing|\.xcresult\b"), "test result handling"),
    (re.compile(r"(?i)\bmutant\w*\b"), "mutant execution"),
    (re.compile(r"(?i)\bmaestro\b"), "Maestro"),
    (re.compile(r"(?i)setup-java|\bripgrep\b"), "tool provisioning"),
    (re.compile(r"(?i)\bxcrun\s+simctl\b|\b(?:udid|runtime)\b|\biPhone\s+\d"), "simulator device selection"),
    (re.compile(r"(?i)actions/(?:upload|download)-artifact"), "artifact transfer"),
    (re.compile(r"(?i)(?:^|\s)Scripts/"), "repository script execution"),
    (re.compile(r"(?i)\b(?:curl|wget|brew\s+install)\b"), "tool download"),
    (re.compile(r"(?i)\bfixture\b|\bsecret[- ]scan\w*\b"), "acceptance or scan execution"),
)


class PolicyFailure(Exception):
    pass


def fail(message):
    raise PolicyFailure(message)


def git(*args):
    result = subprocess.run(
        ["git", *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    if result.returncode != 0:
        fail(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def exact_commit(value):
    if not SHA_RE.fullmatch(value):
        fail("ref must be an exact 40-character lowercase commit SHA")
    resolved = git("rev-parse", "--verify", f"{value}^{{commit}}").strip()
    if resolved != value:
        fail(f"ref does not resolve exactly to {value}")
    return value


def workflow_at(commit):
    return git("show", f"{commit}:{WORKFLOW_PATH}")


def top_level_on_block(workflow):
    match = re.search(r"(?ms)^on:\n.*?(?=^[A-Za-z][A-Za-z0-9_-]*:)", workflow)
    if not match:
        fail("workflow has no top-level on block")
    return match.group(0)


def verify(workflow):
    if top_level_on_block(workflow) != EXPECTED_DISPATCH:
        fail("workflow must be manual-only with the approved dispatch inputs")
    if workflow.count("runs-on: macos") != 1:
        fail("workflow must contain exactly one hosted macOS job")
    job_names = re.findall(
        r"(?m)^  ([A-Za-z0-9_-]+):\n(?=    )",
        workflow.split("\njobs:\n", 1)[-1],
    )
    if job_names != ["build"]:
        fail("workflow must contain only the build job")
    if "  contents: read\n" not in workflow:
        fail("workflow must keep read-only repository permission")
    if "  group: build-only-pr-${{ inputs.pr_number }}\n" not in workflow:
        fail("workflow must cancel duplicate runs through the per-PR group")
    if "  cancel-in-progress: true\n" not in workflow:
        fail("workflow must cancel an older same-PR build")
    if workflow.count("    timeout-minutes: 10\n") != 1:
        fail("build job must have the ten-minute wall-clock timeout")
    if workflow.count(
        "      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5\n"
    ) != 1:
        fail("workflow must use the pinned checkout action exactly once")
    if "          ref: ${{ inputs.expected_head_sha }}\n" not in workflow:
        fail("checkout must use the exact expected head SHA")
    if "          fetch-depth: 1\n" not in workflow:
        fail("checkout must remain shallow")
    if "          persist-credentials: false\n" not in workflow:
        fail("checkout credentials must not persist")
    for assertion in (
        '[[ "$EVENT_SHA" == "$EXPECTED_HEAD_SHA" ]]',
        '[[ "$WORKFLOW_SHA" == "$EXPECTED_HEAD_SHA" ]]',
        '.head.sha == $expected_head_sha',
        '[[ "$(git rev-parse HEAD)" == "$EXPECTED_HEAD_SHA" ]]',
    ):
        if workflow.count(assertion) != 1:
            fail(f"exact-head assertion is missing or duplicated: {assertion}")
    if workflow.count("xcodebuild") != 1:
        fail("workflow must invoke xcodebuild exactly once")
    if workflow.count(EXPECTED_BUILD) != 1:
        fail("workflow must contain the exact generic Example build block")
    for pattern, label in FORBIDDEN:
        if pattern.search(workflow):
            fail(f"workflow contains forbidden {label}")
    if workflow != EXPECTED_WORKFLOW:
        fail("workflow differs from the approved build-only contract")


def changed_once(workflow, old, new):
    if workflow.count(old) != 1:
        fail(f"policy canary source is missing or duplicated: {old!r}")
    return workflow.replace(old, new, 1)


def expect_rejection(label, workflow):
    try:
        verify(workflow)
    except PolicyFailure:
        print(f"policy canary rejected: {label}")
        return
    fail(f"policy canary unexpectedly passed: {label}")


def run_policy_canaries():
    canaries = (
        (
            "automatic trigger",
            changed_once(EXPECTED_WORKFLOW, "  workflow_dispatch:\n", "  push:\n  workflow_dispatch:\n"),
        ),
        (
            "missing concurrency",
            changed_once(
                EXPECTED_WORKFLOW,
                "concurrency:\n  group: build-only-pr-${{ inputs.pr_number }}\n  cancel-in-progress: true\n\n",
                "",
            ),
        ),
        (
            "missing timeout",
            changed_once(EXPECTED_WORKFLOW, "    timeout-minutes: 10\n", ""),
        ),
        (
            "mutable checkout",
            changed_once(
                EXPECTED_WORKFLOW,
                "          ref: ${{ inputs.expected_head_sha }}\n",
                "          ref: ${{ github.ref }}\n",
            ),
        ),
        (
            "persisted checkout credentials",
            changed_once(
                EXPECTED_WORKFLOW,
                "          persist-credentials: false\n",
                "          persist-credentials: true\n",
            ),
        ),
        (
            "weakened exact-head preflight",
            changed_once(
                EXPECTED_WORKFLOW,
                '          [[ "$WORKFLOW_SHA" == "$EXPECTED_HEAD_SHA" ]]\n',
                "",
            ),
        ),
        (
            "second job",
            EXPECTED_WORKFLOW + "  duplicate:\n    runs-on: macos-26\n    steps: []\n",
        ),
        (
            "second build",
            changed_once(
                EXPECTED_WORKFLOW,
                "          xcodebuild \\\n",
                "          xcodebuild -version\n          xcodebuild \\\n",
            ),
        ),
        (
            "test action",
            changed_once(EXPECTED_WORKFLOW, "            build\n", "            test\n"),
        ),
        (
            "repository verifier",
            changed_once(
                EXPECTED_WORKFLOW,
                "          xcodebuild \\\n",
                "          Scripts/verify-s1-03.sh\n          xcodebuild \\\n",
            ),
        ),
        (
            "simulator device command",
            changed_once(
                EXPECTED_WORKFLOW,
                "          xcodebuild \\\n",
                "          xcrun simctl list devices\n          xcodebuild \\\n",
            ),
        ),
        (
            "tool installation",
            changed_once(
                EXPECTED_WORKFLOW,
                "      - name: Build Example\n",
                "      - uses: actions/setup-java@0123456789012345678901234567890123456789\n"
                "      - name: Build Example\n",
            ),
        ),
        (
            "artifact upload",
            EXPECTED_WORKFLOW
            + "      - uses: actions/upload-artifact@0123456789012345678901234567890123456789\n",
        ),
    )
    for label, workflow in canaries:
        expect_rejection(label, workflow)


try:
    commit = exact_commit(sys.argv[1])
    verify(workflow_at(commit))
    run_policy_canaries()
except PolicyFailure as error:
    print(f"FAIL build-only CI policy: {error}", file=sys.stderr)
    raise SystemExit(1)

print("PASS build-only CI policy")
PY
