# ThorChain Paperclip roadmap walker — normative contract

This document is the cleaned, portable model. Historical evidence and deviations are in [`paperclip-unstoppable-roadmap-walker-analysis.md`](paperclip-unstoppable-roadmap-walker-analysis.md).

## 1. Roles

| Role | Permitted responsibility |
|---|---|
| ThorChainCEO | parent walker, selection of the next slice, stop/resume, portfolio status |
| ThorChainCTO | child spec, post-review plan, architecture rulings, final merge |
| ThorChainCodeReviewer | adversarial spec review and independent code review |
| ThorChainSwiftEngineer | TDD implementation and PR |
| ThorChainQAEngineer | independent acceptance/smoke evidence |

The CEO does not write the spec/plan/code or merge a child PR. The CTO does not create the next roadmap child until the current one is complete.

## 2. Outer-walker invariants

1. The integration branch and exact roadmap path are recorded in project bindings.
2. At most one unfinished child with `parentId=walker.id` exists at a time.
3. During child delivery, the parent has `status=blocked` and `blockedByIssueIds=[child.id]`.
4. The next child is determined solely by scanning the current roadmap from top to bottom.
5. A slice is considered complete only when it has a status marker on the integration branch after merge.
6. The parent is never used as an implementation worktree/issue.
7. The parent run ends immediately after child creation and formal blocking.

## 3. Selection algorithm

```text
read live parent issue
guard status + assignee + wake reason
if active child exists:
    ensure parent blockedBy == [child]
    stop

fetch integration branch
read roadmap from origin/integration
for heading in document order:
    if valid Status ✅ marker is within next 3 lines:
        continue
    next_slice = heading
    break

if no next_slice:
    close parent done with terminal summary
    stop

create exactly one child assigned to CTO
comment selection evidence on parent
set parent blockedBy=[child], status=blocked
verify once
stop
```

## 4. Child template

Every child contains:

- stable slice ID and exact roadmap heading;
- goal and non-goals;
- linked detailed-spec path;
- deliverables;
- acceptance criteria;
- deterministic verification commands;
- opt-in live verification, where applicable;
- Example app/Maestro surface, where applicable;
- Unstoppable adapter/AppTests surface, where applicable;
- Gimle/Serena/current-tree evidence requirements;
- requirement to add the exact status marker in the same feature PR;
- parent walker ID, project/workspace, and integration branch.

## 5. Child state machine

```text
todo/CTO
  -> in_progress/CTO              phase 1 spec
  -> in_progress/CodeReviewer     phase 2 spec review
  -> in_progress/CTO              phase 3 plan/rulings
  -> approval_wait/Board          explicit analog-driven-change approval gate
  -> in_progress/SwiftEngineer    phase 4 implementation + PR
  -> in_progress/CodeReviewer     phase 5 code review
  -> in_progress/QAEngineer       phase 6 acceptance
  -> in_progress/CTO              phase 7 merge
  -> done/CTO
```

If Paperclip does not support a separate `approval_wait`, the issue remains `blocked` with a machine-readable approval blocker and the assignee specified by the assembly spec. Waiting for approval must not be disguised as `in_progress`.

Permitted returns:

- Reviewer → CTO for spec changes;
- CTO → Reviewer for spec re-review;
- Engineer → CTO for an architectural blocker;
- Reviewer → Engineer for code changes;
- QA → Engineer/CTO for failed acceptance;
- load-bearing ruling after approval → Reviewer and renewed Board/user approval if the design changed materially.

## 6. Approval gate

Before implementation, the following must exist and be pushed:

1. approved component analog family;
2. Gimle evidence report with Serena/`rg` current-tree verification;
3. detailed slice spec;
4. adversarial review disposition;
5. CTO implementation plan;
6. explicit Board/user approval satisfying the current `analog-driven-change` protocol.

The old rule that “CR + CTO automatically replace the user” is not carried over.

## 7. Atomic handoff

```text
push phase artifacts
POST evidence comment ending in formal "your turn."
PATCH assignee + status
one read-only verification
STOP
```

Rules:

- POST always precedes PATCH;
- the mention uses the UUID of the current ThorChain company, not the old team;
- the comment ends with a formal mention and `your turn.`;
- polling, a new checkout, and continued work are prohibited after handoff;
- a non-2xx POST prohibits PATCH: blocker/escalation first;
- 409 requires resolving the execution lock; direct SQL is prohibited;
- a stale wake never resumes a closed issue or one owned by someone else.

## 8. Merge gate

The CTO merge is permitted only when all of the following are true:

- PR head matches the head verified by the Reviewer;
- latest Reviewer result is APPROVE and includes commands/results;
- latest QA result is PASS on the same head;
- required CI/local checks have completed according to the slice spec;
- no approval/blocker remains open;
- the status marker contains the actual PR and will be merged by that PR;
- merge is performed using squash without co-author trailers;
- after merge, the marker is verified on the integration branch;
- only then is the child moved to `done`.

The Reviewer and QA do not merge or close the child.

## 9. Status marker

Canonical form:

```markdown
### S1.01 Package Public API
**Status:** ✅ Implemented — PR #42 — merge `abc1234` — 2026-07-17
```

Prohibited:

- `PR #TBD`;
- roadmap-only PR;
- direct-push marker on the integration branch;
- marker before acceptance;
- link to the implementation commit instead of the merge commit;
- manually closing a child without a marker on the integration branch.

## 10. Stop/resume

- Stop does not cancel an active child unless the operator explicitly instructs otherwise.
- After the current child is complete, the parent is closed with terminal reason `operator_stop_after=<slice>`.
- A new child is prohibited after stop.
- Resume is a separate explicit operator event; the walker fetches the branch again and rescans the roadmap.
- Old session memory does not determine the resume position.

## 11. Defect guards

- `active_child_count <= 1`.
- A parent without `done/cancelled` always has either an active-child blocker or is performing a short selection run.
- Handoff does not leave the issue assigned to the role that completed the phase.
- Deferred comments cannot reopen a `done` issue without explicit operator action.
- Reviewer/QA API permissions do not permit merge/close.
- The CEO bundle has its own role, not a copy of the CTO role craft.
- Roadmap lint checks the heading, marker, real PR number, and absence of duplicates.
- The watchdog reports a violation, but is not the normal handoff mechanism.

## 12. ThorChain acceptance boundary

- Package slices are verified with unit/integration tests and `iOS Example`.
- Maestro runs only in the `ThorChainKit.Swift` Example app.
- Live network gates are opt-in and cannot be replaced by a fixture-green result.
- Unstoppable integration is verified with adapter contract/AppTests/manual acceptance; Maestro is not added there.
- Every live result records the network, endpoint family, block height or tx ID, and observed outcome.

## 13. Activation gate

The walker must not be started until:

- private `ant013/ThorChainKit.Swift` has been created and bound;
- English `ROADMAP.md` and slice specs have been approved;
- five-agent bundles have passed identity/model/path validation;
- all agents use the `codex_local` model `gpt-5.6-sol`;
- backup/rollback of the old Paperclip product has been confirmed;
- the assembly spec has been committed/pushed and explicitly approved by the user.
