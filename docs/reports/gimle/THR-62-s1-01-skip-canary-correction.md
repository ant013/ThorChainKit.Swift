# THR-62 S1-01 skip-canary correction

## Goal and scope

Make the inherited S1-01 skip canary produce a truthful Xcode result bundle on
the pinned Xcode 26.3 simulator. The only implementation delta is the injected
test statement in `Scripts/verify-s1-01.sh`; S1-03 product behavior, allowlists,
result parsing, and fail-closed checks remain unchanged.

The prior `throw XCTSkip(...)` transform causes Xcode 26.3 to diagnose the
following assertions as unreachable code. That build failure produces an
`unknown` result bundle with zero test nodes, so it cannot prove skip handling.
`try XCTSkipIf(true, ...)` still executes XCTest's skip path while allowing the
method body to compile and the result bundle to credit exactly one skipped test.

## Acceptance criteria

- normal approved-head S1-01 run: 18 allowlisted tests, all `Passed`;
- injected canary: 18 allowlisted tests, 17 `Passed`, exactly one `Skipped`;
- missing, malformed, wrong-count, wrong-name, failed, or non-canary bundles
  remain rejected by the existing `verify-xcresult.sh` contract;
- no S1-03 product source changes.

## Verification evidence

The exact approved head `336516436daacd52acc113869dd627e85802d94a` was run in an
isolated Xcode 26.3.1/iOS 26.3.1 simulator tree. The old transform produced:
`result=unknown`, `totalTestCount=0`, and `testNodes=[]`, reproducing QA's
`expected 18, observed 0` failure. With the corrected transform, the result
summary reported `result=Passed`, `totalTestCount=18`, `passedTests=17`,
`skippedTests=1`; the result tree contained one `Skipped` allowlisted case.
The approved-head verifier printed `PASS verify-s1-01-skip-canary`.

Using a real temporary Git worktree at the same approved head (rather than a
source archive), the complete `Scripts/verify-s1-01.sh` exited 0. Its expected
mutation harness failures were observed and credited, including the namespace
mutant, and it printed the final `PASS verify-s1-01-gimle-report` gate.

`git diff --check` passed. The full verifier on the production base `7fd9663`
also reaches its pre-existing S1-01 source-closure mismatch before the canary;
that unrelated baseline failure is not changed here. Independent CR/QA should
rerun `Scripts/verify-s1-01.sh` after applying this one-line correction to the
approved S1-03 head.

## Gimle reliability

Codebase-memory located the inherited `verify_skip_canary` symbol, and Serena
identified the existing result/status parser family. Palace memory is healthy,
but `Users-ant013-Data-AI-thorchain` is not registered (`unknown_project`), so
Gimle trust is `RED` for this run. Current-tree `rg`, Git, and pinned simulator
evidence are the decision authority; no Gimle-only claim was accepted.
