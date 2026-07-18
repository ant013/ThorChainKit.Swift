# Gimle reliability report — Sprint 1 design

## Conclusion

**Current Trust: YELLOW (rechecked July 18, 2026).** The two remaining
RED blockers from the July 17 check have been fixed: semantic rows now carry
authoritative project freshness, and the multi-project pagination envelope is
computed from the post-filter result set. Gimle may again be used for bounded
discovery and freshness evidence, with the standing Serena/targeted-`rg`
verification required by the evidence policy.

YELLOW is retained for two operational limitations that do not invalidate the
refreshed indexes: an MCP client session opened before a Palace restart does not
reconnect automatically, and the open-schema `search_code` passthrough cannot
prove that guessed `limit`/`file_pattern` arguments were enforced. The typed
`semantic_search` endpoint is bounded and is the accepted discovery path.

## July 18 final recheck

- A newly established MCP session returned `palace.health.status` in about
  0.2 seconds: Neo4j reachable, runtime commit `0e9cf57c`, clean serving tree,
  and no project-integrity warnings. Older Codex sessions continued to hang
  because the Palace restart invalidated their StreamableHTTP session. This is
  client-session drift, not a Palace outage.
- `tron-kit` now maps to
  `<gimle-source-root>/HorizontalSystems/TronKit.Swift` at
  `aa691bcd`; `indexed_commit`, `tree_head`, `dominant_symbol_commit`, and the
  exact local `origin/master` ref all agree. The overview reports
  `current_local_tree`, zero lag, `identity_check=ok`, 58,864 symbols, 839 files,
  and two modules.
- `uw-ios-app` now maps to
  `<gimle-source-root>/HorizontalSystems/unstoppable-wallet-ios` at
  `8a63bfda`; `indexed_commit`, `tree_head`, `dominant_symbol_commit`, and the
  exact local `origin/version/0.50` ref all agree. The completed ingest reports
  `current_local_tree`, zero lag, `identity_check=ok`, 250,199 symbols, 28,460
  files, and four modules.
- Bounded semantic searches for the Sprint 2 send path returned per-result
  `indexed_commit`, `commits_behind_head=0`, `stale=false`, and
  `freshness_state=current_local_tree`. TronKit results were independently
  confirmed in `TransactionSender.swift`, `TransactionManager.swift`, and
  `Kit.swift` with Serena and targeted `rg`; Unstoppable results were confirmed
  in `Core/Protocols.swift` and `SendNew/EvmSendHandler.swift` with targeted
  `rg` after Serena timed out on the newly indexed large app tree.
- The old underfill reproduction now returns `returned=1`, `total=1`,
  `has_more=false`, `next_offset=null`, `truncated=false`, and no warnings. The
  separate `scope_excluded_count=37` remains visible. The original impossible
  `returned=0`/`has_more=true` envelope is therefore fixed; low recall for a
  particular query remains a search-quality concern, not pagination corruption.

## Post-fix verification — PR #508

The first live verification was repeated after the merge/deployment on July 17,
2026. At that time five of seven defects were fixed and Trust remained RED. The
July 18 final recheck above supersedes that intermediate verdict: **all seven
original defects are now fixed and current Trust is YELLOW**.

### Merge and deployment

- GitHub confirms PR `#508` as `MERGED` into `develop` at `2026-07-17T11:20:17Z`, merge commit `b56232d5`; the required `test`, `lint`, `typecheck`, and `docker-build` checks are green.
- The live process is running from detached checkout `b6b0cabc` with a dirty hot patch. Nine production files are byte-equivalent to the merge commit; `runtime_identity.py` and `backfill_indexed_commit.py` also have the exact SHA-256 hashes of the merged versions.
- `project_analyze.py` contains the F2 project-indexed-commit writer/reader and the `ExtractorBaseline` source. Two diff hunks remain when compared with the merge commit, so the literal claim of “exactly four anchor patches” is not confirmed by this method; the functional F2 anchors are present.
- The PR test files were not copied into the live dirty checkout; merged CI verifies them. Live behavior was verified separately with real MCP payloads.

### Status of the original defects

| Defect | Status after PR #508 | Live evidence |
|---|---|---|
| `RUNTIME-ID` | **FIXED** | `git_sha=b6b0cabc`, `git_sha_source=resolved`, `git_sha_label=native-dev`, `git_dirty=true`, warnings empty |
| `UW-LAG` | **FIXED for the declared mapped tree** | `indexed_commit=tree_head=1eeed4e9`, `identity_check=ok`, `current_local_tree`; separate dev checkout `5b06860e` is not conflated with the mapping |
| `EVM-LAG` | **FIXED** | authoritative `indexed_commit=be028631`; `dominant_symbol_commit=27f125be` is diagnostic only; lag 0 to the exact mapped HEAD |
| `TRON-FRESHNESS` | **FIXED for the declared mapped tree** | repo path exists, `indexed_commit=tree_head=f8ce0c00`, `identity_check=ok`; separate dev checkout `aa691bcd` is explicitly different |
| `HDWALLET-MAPPING` | **FIXED** | mapped path/HEAD/indexed commit agree on `1bc214b2`; the commit exists |
| `SEMANTIC-ROW-FRESHNESS` | **FIXED on July 18** | bounded TronKit and UW rows carry the authoritative commit and current-tree freshness fields |
| `SEMANTIC-UNDERFILL` | **FIXED on July 18** | regression query returns a coherent post-filter envelope: `1/1`, terminal page, no warning |

### Additional results from the July 17 intermediate check

- `tron-kit`, `eip20-kit`, and `uniswap-kit` now have absolute, existing `repo_path` values; all three have `identity_check=ok` in the project overview.
- At that point the backfill was not NULL-free: `12/18` project rows still had
  `indexed_commit=null`; `uniswap-kit` correctly returned
  `freshness_state=unknown` and
  `indexed_commit_unpopulated_reingest_required`. The July 18 conclusion is
  scoped to the reverified `tron-kit` and `uw-ios-app` projects; it does not
  assert freshness for every registered project.
- The then-deployed semantic code passed per-hit `_commit_sha` to
  `_load_freshness` instead of the authoritative `Project.indexed_commit`.
  July 18 response evidence confirms that this result-level defect is now
  corrected for the two reverified projects.
- The proposed underfill cause was confirmed in the intermediate deployment:
  pagination used the pre-filter total. The July 18 regression proves the
  response now exposes a coherent post-filter total and terminal state.
- The built-in Codex Palace connector hung without a payload after restart. A fresh direct Streamable HTTP MCP session to the same server works; this is a separate connector/session drift, not a failure of the live Palace server.

## Context loading

- `codebase-memory` was called first, but the exact local project is available only for EvmKit/MarketKit.
- Its UW project points to a different clone and was not used as load-bearing evidence.
- Serena was used for the registered exact projects.
- Where activation could have created metadata in a read-only source tree, targeted `rg`/`git` was used.

## Historical defect catalogue

| ID | Severity | Defect | Impact | Workaround |
|---|---|---|---|---|
| GIM-RUNTIME-ID | low | runtime reports `git_sha=native-dev` | the Gimle build cannot be tied to a source commit | defensive contract handling |
| GIM-UW-LAG | high | overview claims lag 4, while the mapped worktree is actually 8 commits ahead of the index | recent host wiring may be missing | verify all of UW in exact tree `5b06860e` |
| GIM-EVM-LAG | medium | EvmKit index is 3 commits behind | new consumer-owned syncer composition is not visible | exact tree `be028631` |
| GIM-TRON-FRESHNESS | high, forces RED | overview reports lag 0, while the mapped tree is 2 commits newer | primary analog is incorrectly marked current | exact tree `aa691bcd` |
| GIM-HDWALLET-MAPPING | high, forces RED | indexed commit is absent from the mapped repo despite lag 0 | derivation cannot be substantiated through Gimle | local tree + authoritative vectors |
| GIM-SEMANTIC-ROW-FRESHNESS | high, formerly forced RED; **fixed July 18** | semantic rows had null commit/lag, but `stale=false` | row currentness could not be substantiated | fixed response + continuing Serena/rg verification |
| GIM-SEMANTIC-UNDERFILL | medium; **fixed July 18** | scoped query returned 0/few rows while `has_more=true` | absence claims could not be made | coherent post-filter envelope now verified |
| GIM-EXAMPLE-DISCOVERY | medium | bounded semantic search does not find the existing TronKit/EvmKit Example apps | one could incorrectly conclude that the runnable harness is absent | inspect current Xcode targets/workspaces + Serena/rg |

Additionally, the subagent confirmed the false-success envelope `phase2_required`, dependency/legacy path pollution, and discrepancies between project-list and overview commits. These observations were not used as load-bearing facts, but should be fixed in Gimle.

## Accepted evidence policy

- Semantic rows with a warning were not tied to `MATCH` claims.
- 24 latest claims were accepted as independent current-tree `MATCH`; a separate Gimle Example-coverage claim remains unaccepted as `PARTIAL`.
- A primary, supporting, and rejected counterexample is recorded for each of the 7 slices.
- High-risk slices have at least two independent accepted facts and an explicit lifecycle/trust counterexample.
- The analog family gate passed in `verified` mode. Design-time Trust was
  intentionally RED; the July 18 operational recheck raises current Trust to
  YELLOW without weakening the independent-verification requirement.

## Source integrity

- No files were created/committed/pushed in Unstoppable Wallet.
- The mistakenly created local feature branch was deleted; the worktree was returned to its original branch.
- Existing user-owned dirty/untracked files were not changed.
- The Vultisig clone remained at the pinned commit and clean.

## Durable audit

Design run state: Gimle skills audit artifact `audit/runs/thorchainkit-sprint1-design-20260717/state.json`.

Post-fix verification run: Gimle skills audit artifact `audit/runs/thorchainkit-gimle-postfix-20260717/state.json`.
