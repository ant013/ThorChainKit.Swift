# Paperclip Unstoppable roadmap walker — evidence-based analysis

## Conclusion

The Unstoppable team operated two related but independent state machines:

1. **Outer walker** managed only roadmap ordering: it checked `main`, selected the first unfinished slice, created exactly one child issue, and blocked the parent on that child.
2. **Inner delivery loop** took one child through spec → adversarial review → plan → implementation → code review → QA → CTO merge.

The main idea to preserve is not merely seven role transitions, but the strict linkage of three sources of truth:

| Area | Source of truth |
|---|---|
| which slice is next | `ROADMAP.md` on the current integration branch |
| who is currently authorized to act | Paperclip issue, current `status`, `assigneeAgentId`, execution lock, and latest comments |
| whether the slice has actually shipped | merged PR and status marker already on the integration branch |

This model should be carried over to ThorChain, but the identified violations must not be: the incorrect CEO role, roadmap-only PR, merge before QA, `PR #TBD`, stale-wake reopen, and internal approval under the old `analog-driven-development` instead of the current `analog-driven-change` + `gimle-evidence`.

## Source data

The analysis was performed on 2026-07-17 without running or modifying the local Paperclip instance.

### Paperclip

- Company: `dfc662ee-513f-42f7-9f46-23f07e0a98d0` (`UNS`).
- Latest SQL snapshot: Paperclip backup artifact `instances/default/data/backups/paperclip-20260618-202325.sql.gz`, SHA-256 `df229fd0c9f43dfba498de14f1d240b2dca0931842839216b93e4eb1eff3e426`.
- Run logs: Paperclip artifact `instances/default/data/run-logs/dfc662ee-513f-42f7-9f46-23f07e0a98d0`, 194 NDJSON total:
  - CEO — 21;
  - CTO — 60;
  - CodeReviewer — 50;
  - SwiftEngineer — 45;
  - QAEngineer — 18.
- Materialized role bundles: Paperclip artifact `instances/default/companies/dfc662ee-513f-42f7-9f46-23f07e0a98d0/agents`.

### Result repository

- Repository source: `ant013/multi-swap-ios`, `HEAD=dce5b5f2f7d1b0dfc0c84fb8df74e8e143edb6a3`, clean `main`.
- Roadmap source anchor: `ant013/multi-swap-ios@dce5b5f2:ROADMAP.md:38`, SHA-256 `ac6d0ffa696fb8762a00d904def7c1549a7bc3410e984f63b30d5d8e92b78187`.
- Slice artifact source paths: `ant013/multi-swap-ios@dce5b5f2:docs/specs` and `ant013/multi-swap-ios@dce5b5f2:docs/plans`.
- GitHub: 13 merged PRs; PR #1–#4 and #6–#13 relate to slice delivery, while PR #5 was a separate roadmap correction.

`multi-swap-ios` is absent from the current codebase-memory index. Therefore, the Git/PR/ROADMAP conclusions were verified directly in the exact local tree and through GitHub CLI. This is a deliberate local fallback, not a Gimle semantic-search result.

## Actual issue model

### Parent walker

Parent `[UNS-7] MultiSwap Roadmap Walker` contained no implementation of its own. Its sole responsibility was to advance the roadmap.

Stable state while one slice was being worked on:

```text
parent.status = blocked
parent.blockedByIssueIds = [activeChild.id]
activeChild.parentId = parent.id
activeChild.status = todo | in_progress | blocked
active children count = 1
```

When the child moved to `done`, Paperclip removed the blocker and woke the parent. The walker rechecked `origin/main`, confirmed that the status marker was already merged, and only then created the next child.

This is not cosmetic. Three early runs left the parent `in_progress` without a formal disposition. Paperclip recorded `successful_run_missing_state`, then `issue.successful_run_handoff_escalated`, and assigned recovery to the owner. After switching to `blockedByIssueIds=[child]`, progression became stable.

### Child issue

A roadmap child:

- belonged to the same Paperclip project/workspace;
- had the walker issue as its `parentId`;
- was created in `todo` and assigned to the CTO;
- contained the slice goal, deliverables, acceptance, gate, and status-marker requirement;
- moved to `in_progress` after checkout;
- usually remained `in_progress` between phases, with only the assignee changing;
- became `blocked` only for a real architectural/tooling obstacle;
- was closed as `done` after delivery, not merely after code was written.

Side issues did not substitute for the roadmap. For example, `UNS-16` was a child of `UNS-15`, not of the walker; it could be deferred or closed separately by an architectural decision without creating a second active roadmap slice.

## Outer walker: reconstructed algorithm

The observed behavior and the Walker Rule at source anchor `ant013/multi-swap-ios@dce5b5f2:ROADMAP.md:38` yield the following algorithm.

1. On every wake, read `PAPERCLIP_TASK_ID` and retrieve the parent from the API again.
2. Exit immediately if the parent is closed, cancelled, or assigned to another agent without a fresh explicit handoff.
3. If an unfinished child exists, create nothing. Ensure that the parent is formally `blocked` by exactly that child, then stop.
4. Update the integration branch in fast-forward mode only and read the roadmap from the current `origin/<integration>`.
5. Traverse slice headings from top to bottom. Inspect the next three lines for each heading.
6. Skip a slice only when `**Status:** ✅` is present.
7. The first heading without a marker is the only permissible next child.
8. Create a child with `parentId=walker.id`, the same project/workspace, `status=todo`, `assignee=CTO`, and the Goal/Deliverables/Acceptance/Gate text from the roadmap.
9. Leave a comment on the parent about the selected slice, then set `status=blocked` and `blockedByIssueIds=[child.id]`.
10. Stop the run. Do not perform phase 1 within the parent run.
11. After the child closes, check the integration branch again. A “merged” comment in Paperclip is insufficient: the marker must be physically present in the merged roadmap.
12. If no unfinished headings remain, close the walker as `done` with a terminal summary.

### Operator stop/resume

Twice, the operator stopped the walker after a slice was already active: after MS.8 and MS.10. The correct semantics were:

- the current child completes the cycle;
- no new child is created;
- the parent is closed with an explicit `operator stop after <slice>`;
- resume requires a new explicit operator event and rescanning the current roadmap.

Stopping must not cancel an in-flight child or leave the parent in an indeterminate `in_progress` state.

## Inner loop: seven phases

| Phase | Owner | Required result | Next owner |
|---|---|---|---|
| 1 | CTO | fresh feature branch from integration; detailed spec committed + pushed | CodeReviewer |
| 2 | CodeReviewer | adversarial spec review; architecture/security/UX findings; approval or blockers | CTO |
| 3 | CTO | implementation plan addressing every finding; files/tests/commands/stop conditions | SwiftEngineer |
| 4 | SwiftEngineer | TDD implementation, local verification, pushed PR; status marker on the same branch | CodeReviewer |
| 5 | CodeReviewer | review of the actual PR head; diff-to-plan; build/lint/format/tests; approval or return with blocker | QAEngineer or SwiftEngineer |
| 6 | QAEngineer | independent smoke/acceptance verification on the same PR head with actual output | CTO |
| 7 | CTO | repeat verification of head + CR + QA; squash merge; marker on integration; child `done` | parent walker wake |

### Return loops

The loop was not a linear pipeline, but a finite-state machine with permitted returns:

- spec `CHANGES REQUIRED`: Reviewer → CTO, then repeat phase 2;
- implementation blocker: Engineer → CTO; after a ruling, CTO → Engineer;
- code blocker: Reviewer → Engineer; after the fix, Engineer → Reviewer;
- change to a load-bearing decision after implementation begins: CTO ruling → mandatory Reviewer re-ratification → Engineer;
- QA failure: QA → Engineer or CTO depending on defect type, followed by repeated review and QA.

A successful re-review example is `UNS-15`: phase 5 found a blocker, the Engineer fixed it, the Reviewer repeated phase 5, followed by QA and CTO merge. A more complex example is `UNS-21`: an implementation blocker prompted a CTO reversal and separate Reviewer re-ratification before implementation continued.

## Atomic handoff contract

The materialized instructions contain a useful operational protocol at Paperclip artifact anchor `instances/default/companies/dfc662ee-513f-42f7-9f46-23f07e0a98d0/agents/404e012b-f162-4bf0-b361-780e1cd629ec/instructions/AGENTS.md:59`.

### On every wake

1. Read `TASK` and `WAKE_REASON`.
2. Read the issue from the API again; CLI memory is not authoritative.
3. Check the current status, assignee, execution lock, and freshness of the handoff comment.
4. Do not resume a closed stale task or one owned by someone else.
5. If there is no authorized work, perform an idle exit without reading Git “just in case.”

### Interphase handoff

Normalized safe order:

1. Complete and push the artifacts for the current phase.
2. `POST /api/issues/{id}/comments` with evidence and a formal mention of the next role.
3. The final line of the comment is `[@Role](agent://<uuid>?i=<icon>) your turn.` — no text follows it.
4. `PATCH /api/issues/{id}`: next `assigneeAgentId`, usually `status=in_progress`.
5. One read-only check of the response/GET confirms assignee/status; no polling or continued work.
6. STOP.

The comment must precede PATCH. In the old API, attempting to write a comment after transferring ownership could return 409 and leave the new owner without context.

### Locks and blockers

- HTTP 409 indicates an execution-lock conflict, not permission to repeat PATCH.
- First read `executionAgentNameKey`; the holder releases the lock through issue release, or ownership returns to the holder to complete the operation.
- Direct SQL updates are prohibited.
- A real blocker is recorded as `status=blocked` with an exact comment: what was required, what was checked, and what decision is needed.
- A blocked role does not perform another role's work or create a “preparatory” task merely to remain active.

## Roadmap marker contract

The old parser considered a slice complete if it found `**Status:** ✅` within the three lines after the heading. This is insufficient validation for ThorChain, so the selection rule is preserved while the marker content is strengthened:

```markdown
### S1.01 Package Public API
**Status:** ✅ Implemented — PR #42 — merge `abc1234` — 2026-07-17
```

Mandatory rules:

- real PR number, no `#TBD`;
- merge commit, not an intermediate implementation commit;
- marker is added in the feature PR for the same slice;
- roadmap-only PR is prohibited;
- marker is verified after merge on the integration branch;
- heading/marker format is checked by a separate deterministic lint.

## What the live history establishes

### Completed roadmap children

| Issue | Slice | PR | Seven-phase cycle |
|---|---|---:|---|
| UNS-8 | MS.0 Architecture | [#1](https://github.com/ant013/multi-swap-ios/pull/1) | complete |
| UNS-9 | MS.1 Feasibility | [#2](https://github.com/ant013/multi-swap-ios/pull/2) | complete |
| UNS-10 | MS.2 Target/Core boot | [#3](https://github.com/ant013/multi-swap-ios/pull/3) | complete |
| UNS-11 | MS.3 API/AST gate | [#4](https://github.com/ant013/multi-swap-ios/pull/4) | complete |
| UNS-13 | MS.4 CI workflow | [#6](https://github.com/ant013/multi-swap-ios/pull/6) | incomplete, operator/manual completion |
| UNS-14 | MS.5 Shell | [#7](https://github.com/ant013/multi-swap-ios/pull/7) | violated: CR merged after phase 5 |
| UNS-15 | MS.6 Rates | [#8](https://github.com/ant013/multi-swap-ios/pull/8) | complete, with re-review |
| UNS-17 | MS.7 Route policy | [#9](https://github.com/ant013/multi-swap-ios/pull/9) | violated: CR merged; QA/CTO skipped |
| UNS-18 | MS.8 Address input | [#10](https://github.com/ant013/multi-swap-ios/pull/10) | complete, with CTO unblock |
| UNS-19 | MS.9 Deposit resolver | [#11](https://github.com/ant013/multi-swap-ios/pull/11) | violated: CR merged after phase 5 |
| UNS-20 | MS.10 Deposit QR | [#12](https://github.com/ant013/multi-swap-ios/pull/12) | complete |
| UNS-21 | MS.UI correction | [#13](https://github.com/ant013/multi-swap-ios/pull/13) | complete, with re-ratification |

Total: 8 of 12 children completed all seven phases; 4 had process deviations. The presence of a merged PR does not make those deviations the desired protocol.

### Positive properties

- Deterministic order based on the committed roadmap.
- Exactly one active roadmap slice.
- The spec exists before the plan; the plan incorporates independent criticism.
- One issue preserves the complete history of decisions and returns.
- Reviewer and QA provide separate evidence.
- A stop directive finishes the current slice but does not start a new one.
- The feature PR usually contains the spec, plan, code, tests, and status marker together.

## Defects that must not be copied

1. **Incorrect CEO composition.** The CEO bundle contains the CTO heading and responsibilities; it differs from the CTO bundle in virtually nothing except `Runtime agent=UnstoppableCEO`. This explains the observed conflation of outer orchestration and CTO authority. In ThorChain, the CEO must be a separate outer-walker owner and the CTO the inner technical owner.
2. **Missing parent disposition.** Leaving the walker `in_progress` after child creation triggered recovery. The parent must be blocked by the child.
3. **Roadmap-only PR #5.** MS.2 and MS.3 were marked by a separate PR after implementation even though the roadmap rule prohibited this.
4. **Premature merge.** In UNS-14, UNS-17, and UNS-19, the CodeReviewer merged the PR or closed the issue before independent QA/CTO phase 7.
5. **Stale reopen.** After UNS-17 closed, a deferred-comment wake moved the issue back to `todo`; manual closure was required.
6. **Misleading marker.** MS.7 remained at `PR #TBD`, although the actual PR was #9.
7. **STOP/verify instruction conflict.** One section required stopping immediately after PATCH, while another required a GET. The new contract allows exactly one read-only verification and prohibits further work/polling.
8. **Old approval protocol.** `analog-driven-development` treated CR+CTO as internal design approval. The current ThorChain process uses `analog-driven-change` + `gimle-evidence` and requires explicit Board/user approval before implementation unless the user has already approved the specific design package in an acceptable form.
9. **Local CI directive embedded in roles.** For ThorChain, verification policy must belong to the repo/roadmap slice, not be copied from MultiSwap, where GitHub Actions were disabled because of macOS minutes.

## ThorChain decision

The cleaned model is carried over:

- **ThorChainCEO** owns only the parent walker, operator stop/resume, and portfolio visibility.
- **ThorChainCTO** owns child phases 1, 3, and 7, but does not select a second slice in parallel.
- **ThorChainCodeReviewer**, **ThorChainSwiftEngineer**, and **ThorChainQAEngineer** retain independent phases.
- One parent walker serves `ThorChainKit.Swift` and a single integration branch.
- Slice headings have stable IDs `S1.01`, `S1.02`, …; each links to a separate detailed spec.
- Every child verifies the kit and its `iOS Example`; Maestro applies only to the Example app, not to Unstoppable.
- Host-integration slices use Unstoppable adapter/AppTests acceptance, but do not add Maestro there.
- The new Gimle evidence/design approval gate applies before implementation.
- No roadmap issue is created before separate approval of the Paperclip/ThorChain assembly spec.

The normative version without historical noise is stored in [`paperclip-thorchain-roadmap-walker-contract.md`](paperclip-thorchain-roadmap-walker-contract.md).

## Preservation gate before deleting the old Paperclip product

The old Paperclip product/roadmap/issues/workspaces must not be deleted until all of the following are true:

- this report and the ThorChain contract exist outside the Paperclip data directory;
- the latest SQL snapshot and its SHA-256 are recorded;
- 194 run logs and five materialized role bundles are included in the backup/export manifest;
- `multi-swap-ios` Git history and GitHub PRs remain untouched;
- the ThorChain spec explicitly includes the outer state machine, inner state machine, atomic handoff, and listed defect guards;
- rollback describes restoring the old company from the snapshot or saved export;
- the user has approved the new assembly spec before destructive cleanup.

No deletion had been performed as of this report.
