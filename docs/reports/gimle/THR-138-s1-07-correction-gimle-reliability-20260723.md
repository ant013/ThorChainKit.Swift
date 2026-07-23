# THR-138 Gimle reliability report

- Task: THR-138
- Workflow/phase: `analog_change` / design
- Repository branch: `docs/s1-07-unstoppable-rune-surface-v050`
- Repository head: `b57829a48cfbb8bd189154972d20056a126d455e`
- Canonical state: `audit/runs/THR-138-s1-07-correction-20260723/state.json`
- Trust: **RED for Gimle/Palace evidence; current-tree and live fallbacks are usable**

## Evidence used

Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried first and
reported ready. Its graph located the ThorChainKit account reader and the
existing absence regression test. Serena was then activated on the exact
assigned ThorChainKit worktree, and targeted current-tree reads independently
verified the selected symbols and line ranges.

The live Liquify REST request was read-only and returned HTTP 404, code `5`,
empty details, the short address-specific message, and a current Cosmos height
header. This is the load-bearing provider observation for the design.

## Gimle/Palace calls

The Palace runtime was reachable at `native-dev` with no server integrity
warnings. Memory health was reachable and listed the registered projects. The
`uw-ios-app` overview resolved to the canonical Unstoppable project at indexed
commit `8a63bfda028dd8543115b26dd777235a53304311`, not the exact local v0.50
checkout used by this issue. Palace code searches for `Liquify`,
`ThorChainKitManager`, and `account not found` therefore returned zero rows.

This is recorded as `GIMLE-THR138-001` in the machine state. It forces RED
trust for Palace-backed UW claims. The workaround is independent Serena,
targeted `rg`, Git status/diff reads, and the direct Liquify request against the
exact local checkout. No Palace result influenced the selected implementation
delta.

## Selected analog and conclusion

The primary current-tree spine is `LiveThorNodeClient.account` plus its
`isExactAbsence` predicate. The existing `AbsenceEnvelope`, account regression
test, and exact UW adapter consumer supply supporting contract, test, and
consumer evidence. `LiveThorNodeClient.balances` is a rejected counterexample:
its non-2xx behavior must remain unchanged. Composition is explicitly waived
because the correction adds no factory or registration behavior.

The verified design is to preserve code `5`, empty details, and exact
address-specific semantics while admitting both the existing long message and
the observed short message. Generic, malformed, foreign-address, non-404, and
balance-operation errors remain fail-closed.

## Limitations

- No Gimle index exists for the ThorChainKit repository in Palace, so
  codebase-memory and current-tree evidence remain authoritative for kit
  symbols.
- The exact UW checkout contains pre-existing uncommitted S1-06/S1-07 changes;
  no files there were modified during this design phase.
- Local app build/live-smoke after implementation is intentionally unrun until
  the written design receives explicit approval.
