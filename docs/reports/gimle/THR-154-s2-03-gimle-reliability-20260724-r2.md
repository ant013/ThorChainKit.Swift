# THR-154 S2-03 Gimle Reliability Report — Corrected Revision

**Issue:** `4c7cc223-1102-467f-993f-777d11108643` (`THR-154`)

**Run state:** `audit/runs/THR-154-s2-03-correction-20260724/state.json`

**Repository:** clean worktree `/Users/ant013/Data/AI/.worktrees/thorchain/s2-03-direct-sign`

**Branch/head:** `docs/THR-154-s2-03-direct-sign` at
`754fcc831b3d26e2812630e06b0ffdf05e5c228b` (`origin/main`)

## Result

Gimle trust is **RED**. The target repository is not registered in Palace's
project or git-mount inventory, and the exact project overview returns
`unknown_project`. The native runtime identifies as `native-dev`, but no
target indexed commit can be resolved. Serena is also unavailable in the
active tool environment.

This does not block the documentation-only correction: the analog family and
all load-bearing claims are independently verified with the codebase-memory
target index, exact pinned Git heads, and targeted `rg`. The Gimle failures are
retained as evidence and are not treated as successful discovery.

## Bounded evidence

| Fact | Current-tree basis | Decision |
|---|---|---|
| THOR assembly and signature verification | Vultisig `THORChainHelper`, head `d3123dbe` | Primary analog |
| Local exact-byte/hash ownership | EvmKit `TransactionBuilder`, head `be028631` | Supporting analog |
| SwiftProtobuf generation shape | TronKit generated source and `Package.swift`, head `aa691bcd` | Supporting analog |
| 20M gas helper | Vultisig `getFee`, lines 393–399 | Rejected counterexample |
| Wire/golden contract | Canonical S2-03 spec at corrected head | Authoritative product contract |

The critical slice has one coherent primary, two independent supporting facts,
an explicit composition waiver because S2-04 owns host composition, and a
dispositioned counterexample. No broad rediscovery was repeated.

## Defects and fallbacks

| ID | Classification | Impact | Workaround |
|---|---|---|---|
| `GIM-THR154-MAP` | mapping bug, high, confirmed | No target Gimle discovery or freshness metadata | Codebase-memory, exact Git, and targeted `rg`; retain RED trust |
| `GIM-THR154-HEALTH-MAP` | mapping bug, high, confirmed | Palace health has no ThorChainKit mount | Same independent fallback |
| `GIM-THR154-ROUTING` | mapping bug, high, confirmed | Native code routing has no ThorChainKit project | Same independent fallback |
| `ENV-THR154-SERENA` | environment drift, medium, confirmed | Serena verification unavailable | Do not claim Serena evidence; use Git/`rg` |

The earlier formalization checkpoint is preserved as superseded evidence; it
was bound to the dirty THR-104 worktree and contained the issue-ID typo
`4c7c223-...`. It was not deleted or reused as the corrected checkpoint.

## Verification policy

All builds, tests, mutants, simulator checks, Maestro checks, and other
verification run locally on the MacBook. GitHub Actions remains disabled and
is not an acceptance or merge gate. No hosted workflow was enabled or
dispatched in this correction.
