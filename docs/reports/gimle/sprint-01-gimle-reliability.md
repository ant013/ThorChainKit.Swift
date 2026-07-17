# Gimle reliability report — Sprint 1 design

## Conclusion

**Trust: RED.** Gimle was used only for discovery. The architectural decisions are based on Serena/`rg` verification of the exact local trees mapped by Gimle and on the pinned Vultisig clone.

RED does not mean that the design is unsubstantiated. It means that Gimle cannot independently confirm the currentness and completeness of the selected analogs.

## Post-fix verification — PR #508

The live verification was repeated after the merge/deployment on July 17, 2026. Result: **five of the seven original defects have been fixed; Trust remains RED**, because `SEMANTIC-ROW-FRESHNESS` has not been fixed and `SEMANTIC-UNDERFILL` remains reproducible.

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
| `SEMANTIC-ROW-FRESHNESS` | **OPEN, claimed fix not reproduced** | 12 rows checked with `include_context=false/true` have `indexed_commit=null`, `commits_behind_head=null`, `stale=null` |
| `SEMANTIC-UNDERFILL` | **OPEN** | multi-project query: `returned=0`, `scope_excluded_count=42`, `total=74997`, `has_more=true`, `next_offset=null` |

### Additional results

- `tron-kit`, `eip20-kit`, and `uniswap-kit` now have absolute, existing `repo_path` values; all three have `identity_check=ok` in the project overview.
- The backfill is not NULL-free: `12/18` project rows still have `indexed_commit=null`; `uniswap-kit` correctly returns `freshness_state=unknown` and `indexed_commit_unpopulated_reingest_required`.
- The cause of row freshness was found in the deployed source: `semantic_search` passes the per-hit `_commit_sha` to `_load_freshness` instead of the authoritative `Project.indexed_commit`. This preserves the load-bearing defect and necessarily keeps Trust `RED`.
- The team's proposed cause of underfill was confirmed: after `_filter_by_scope`, the response still builds `expected_rows` and `pagination_envelope(total=total_candidates)` from the pre-filter total.
- The built-in Codex Palace connector hung without a payload after restart. A fresh direct Streamable HTTP MCP session to the same server works; this is a separate connector/session drift, not a failure of the live Palace server.

## Context loading

- `codebase-memory` was called first, but the exact local project is available only for EvmKit/MarketKit.
- Its UW project points to a different clone and was not used as load-bearing evidence.
- Serena was used for the registered exact projects.
- Where activation could have created metadata in a read-only source tree, targeted `rg`/`git` was used.

## Confirmed defects

| ID | Severity | Defect | Impact | Workaround |
|---|---|---|---|---|
| GIM-RUNTIME-ID | low | runtime reports `git_sha=native-dev` | the Gimle build cannot be tied to a source commit | defensive contract handling |
| GIM-UW-LAG | high | overview claims lag 4, while the mapped worktree is actually 8 commits ahead of the index | recent host wiring may be missing | verify all of UW in exact tree `5b06860e` |
| GIM-EVM-LAG | medium | EvmKit index is 3 commits behind | new consumer-owned syncer composition is not visible | exact tree `be028631` |
| GIM-TRON-FRESHNESS | high, forces RED | overview reports lag 0, while the mapped tree is 2 commits newer | primary analog is incorrectly marked current | exact tree `aa691bcd` |
| GIM-HDWALLET-MAPPING | high, forces RED | indexed commit is absent from the mapped repo despite lag 0 | derivation cannot be substantiated through Gimle | local tree + authoritative vectors |
| GIM-SEMANTIC-ROW-FRESHNESS | high, forces RED | semantic rows have null commit/lag, but `stale=false` | row currentness cannot be substantiated | discovery-only + Serena/rg |
| GIM-SEMANTIC-UNDERFILL | medium | scoped query returns 0/few rows while `has_more=true` | absence claims cannot be made | bounded graph/text/local searches |
| GIM-EXAMPLE-DISCOVERY | medium | bounded semantic search does not find the existing TronKit/EvmKit Example apps | one could incorrectly conclude that the runnable harness is absent | inspect current Xcode targets/workspaces + Serena/rg |

Additionally, the subagent confirmed the false-success envelope `phase2_required`, dependency/legacy path pollution, and discrepancies between project-list and overview commits. These observations were not used as load-bearing facts, but should be fixed in Gimle.

## Accepted evidence policy

- Semantic rows with a warning were not tied to `MATCH` claims.
- 24 latest claims were accepted as independent current-tree `MATCH`; a separate Gimle Example-coverage claim remains unaccepted as `PARTIAL`.
- A primary, supporting, and rejected counterexample is recorded for each of the 7 slices.
- High-risk slices have at least two independent accepted facts and an explicit lifecycle/trust counterexample.
- The analog family gate passed in `verified` mode; trust intentionally remains `RED`.

## Source integrity

- No files were created/committed/pushed in Unstoppable Wallet.
- The mistakenly created local feature branch was deleted; the worktree was returned to its original branch.
- Existing user-owned dirty/untracked files were not changed.
- The Vultisig clone remained at the pinned commit and clean.

## Durable audit

Design run state: Gimle skills audit artifact `audit/runs/thorchainkit-sprint1-design-20260717/state.json`.

Post-fix verification run: Gimle skills audit artifact `audit/runs/thorchainkit-gimle-postfix-20260717/state.json`.
