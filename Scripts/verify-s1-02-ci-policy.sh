#!/bin/bash

set -euo pipefail

usage() {
  echo "usage: $0 bootstrap --base-ref <40-char-sha> --candidate-ref <40-char-sha>" >&2
  echo "       $0 steady-state --ref <40-char-sha>" >&2
  exit 64
}

mode=${1:-}
shift || true

base_ref=
candidate_ref=
ref=

while (($#)); do
  case "$1" in
    --base-ref)
      (($# >= 2)) || usage
      base_ref=$2
      shift 2
      ;;
    --candidate-ref)
      (($# >= 2)) || usage
      candidate_ref=$2
      shift 2
      ;;
    --ref)
      (($# >= 2)) || usage
      ref=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

case "$mode" in
  bootstrap)
    [[ -n "$base_ref" && -n "$candidate_ref" && -z "$ref" ]] || usage
    ;;
  steady-state)
    [[ -z "$base_ref" && -z "$candidate_ref" && -n "$ref" ]] || usage
    ;;
  *) usage ;;
esac

python3 - "$mode" "$base_ref" "$candidate_ref" "$ref" <<'PY'
import re
import subprocess
import sys

WORKFLOW_PATH = ".github/workflows/ci.yml"
VERIFIER_PATH = "Scripts/verify-s1-02-ci-policy.sh"
SHA_RE = re.compile(r"[0-9a-f]{40}")

DISPATCH_BLOCK = """on:
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
        description: Type FINAL_S1_02_GATE
        required: true
        type: string

"""

BASE_CHECKOUT = "      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5\n"
DISPATCH_PREFLIGHT = r"""      - name: Preflight exact pull request head
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
          [[ "$CONFIRMATION" == "FINAL_S1_02_GATE" ]]
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
      - name: Verify exact checkout
        env:
          EXPECTED_HEAD_SHA: ${{ inputs.expected_head_sha }}
        run: |
          set -euo pipefail
          [[ "$(git rev-parse HEAD)" == "$EXPECTED_HEAD_SHA" ]]
          printf '%s\n' "checkout_sha=$EXPECTED_HEAD_SHA"
"""


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


def exact_commit(value, label):
    if not SHA_RE.fullmatch(value):
        fail(f"{label} must be an exact 40-character lowercase commit SHA")
    resolved = git("rev-parse", "--verify", f"{value}^{{commit}}").strip()
    if resolved != value:
        fail(f"{label} does not resolve exactly to {value}")
    return value


def workflow_at(commit):
    return git("show", f"{commit}:{WORKFLOW_PATH}")


def top_level_on_block(workflow):
    match = re.search(r"(?ms)^on:\n.*?(?=^[A-Za-z][A-Za-z0-9_-]*:)", workflow)
    if not match:
        fail("workflow has no top-level on block")
    return match.group(0)


def verify_dispatch_policy(workflow):
    if top_level_on_block(workflow) != DISPATCH_BLOCK:
        fail("workflow trigger and required dispatch inputs do not match the policy")
    if workflow.count(DISPATCH_PREFLIGHT) != 1:
        fail("exact workflow/event/PR/checkout SHA preflight is missing or duplicated")
    if workflow.count("runs-on: macos") != 1:
        fail("workflow must contain exactly one hosted macOS job")
    top_level_jobs = re.findall(r"(?m)^  ([A-Za-z0-9_-]+):\n(?=    )", workflow.split("\njobs:\n", 1)[-1])
    if len(top_level_jobs) != 1:
        fail("workflow must contain exactly one job")


def expected_bootstrap_workflow(base_workflow):
    base_on = top_level_on_block(base_workflow)
    if "workflow_dispatch:" in base_on:
        fail("base workflow already contains workflow_dispatch")
    if base_workflow.count(BASE_CHECKOUT) != 1:
        fail("base workflow must contain the exact pinned checkout step once")
    without_old_trigger = base_workflow.replace(base_on, DISPATCH_BLOCK, 1)
    return without_old_trigger.replace(BASE_CHECKOUT, DISPATCH_PREFLIGHT, 1)


def verify_bootstrap(base_workflow, candidate_workflow, changed_paths):
    expected_paths = sorted([WORKFLOW_PATH, VERIFIER_PATH])
    if sorted(changed_paths) != expected_paths:
        fail("bootstrap must change exactly the workflow and policy verifier paths")
    expected_workflow = expected_bootstrap_workflow(base_workflow)
    if candidate_workflow != expected_workflow:
        fail("candidate contains trigger-unrelated S1-01 workflow drift")
    verify_dispatch_policy(candidate_workflow)


def expect_mutant_failure(name, operation):
    try:
        operation()
    except PolicyFailure:
        print(f"mutant rejected: {name}")
        return
    fail(f"mutant unexpectedly passed: {name}")


def trigger_mutant(workflow, trigger):
    mutated_on = DISPATCH_BLOCK + f"  {trigger}:\n"
    return workflow.replace(DISPATCH_BLOCK, mutated_on, 1)


def run_policy_mutants(workflow):
    for trigger in (
        "pull_request",
        "pull_request_target",
        "push",
        "schedule",
        "merge_group",
    ):
        expect_mutant_failure(
            f"automatic trigger {trigger}",
            lambda trigger=trigger: verify_dispatch_policy(trigger_mutant(workflow, trigger)),
        )

    expected_input = """      expected_head_sha:
        description: Exact pull request head commit
        required: true
        type: string
"""
    expect_mutant_failure(
        "missing dispatch input",
        lambda: verify_dispatch_policy(workflow.replace(expected_input, "", 1)),
    )
    expect_mutant_failure(
        "mutable checkout",
        lambda: verify_dispatch_policy(
            workflow.replace(
                "ref: ${{ inputs.expected_head_sha }}",
                "ref: ${{ github.ref }}",
                1,
            )
        ),
    )
    expect_mutant_failure(
        "mismatched pull request head",
        lambda: verify_dispatch_policy(
            workflow.replace(
                ".head.sha == $expected_head_sha",
                ".base.sha == $expected_head_sha",
                1,
            )
        ),
    )
    expect_mutant_failure(
        "stale default workflow definition",
        lambda: verify_dispatch_policy(
            workflow.replace(
                '[[ "$WORKFLOW_SHA" == "$EXPECTED_HEAD_SHA" ]]',
                '[[ "$EVENT_SHA" == "$EXPECTED_HEAD_SHA" ]]',
                1,
            )
        ),
    )
    duplicate_job = """
  duplicate-main-suite:
    runs-on: macos-26
    steps:
      - run: Scripts/verify-s1-01.sh
"""
    expect_mutant_failure(
        "duplicate main suite",
        lambda: verify_dispatch_policy(workflow + duplicate_job),
    )


def run_bootstrap_mutants(base_workflow, candidate_workflow, changed_paths):
    expect_mutant_failure(
        "third changed path",
        lambda: verify_bootstrap(
            base_workflow,
            candidate_workflow,
            changed_paths + ["README.md"],
        ),
    )
    expect_mutant_failure(
        "trigger-unrelated job command drift",
        lambda: verify_bootstrap(
            base_workflow,
            candidate_workflow.replace(
                "run: Scripts/verify-s1-01.sh",
                "run: Scripts/verify-s1-01.sh --mutant",
                1,
            ),
            changed_paths,
        ),
    )
    run_policy_mutants(candidate_workflow)


mode, base_ref, candidate_ref, ref = sys.argv[1:]
try:
    if mode == "bootstrap":
        base = exact_commit(base_ref, "base ref")
        candidate = exact_commit(candidate_ref, "candidate ref")
        if base == candidate:
            fail("base and candidate commits must differ")
        if git("merge-base", base, candidate).strip() != base:
            fail("candidate must descend directly from the supplied base history")
        changed_paths = git("diff", "--name-only", base, candidate).splitlines()
        base_workflow = workflow_at(base)
        candidate_workflow = workflow_at(candidate)
        verify_bootstrap(base_workflow, candidate_workflow, changed_paths)
        run_bootstrap_mutants(base_workflow, candidate_workflow, changed_paths)
        print(f"bootstrap policy verified: base={base} candidate={candidate}")
    else:
        commit = exact_commit(ref, "ref")
        workflow = workflow_at(commit)
        verify_dispatch_policy(workflow)
        run_policy_mutants(workflow)
        print(f"steady-state policy verified: ref={commit}")
except PolicyFailure as error:
    print(f"S1-02 CI policy verification failed: {error}", file=sys.stderr)
    sys.exit(1)
PY
