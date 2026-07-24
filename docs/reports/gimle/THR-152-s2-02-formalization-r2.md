# SUPERSEDED/REJECTED — THR-152 S2-02 Formalization r2

This report is historical evidence only. Revision 2 was rejected by the
approval gate; revision 4 in `THR-152-s2-02-formalization-r3.md` is the current
formalization authority.

## Run binding

- Run: `THR-152-s2-02-20260724-r2`
- Worktree: dedicated clean S2-02 checkout (operator path intentionally omitted)
- Branch: `docs/THR-152-s2-02-formalization`
- HEAD: `db6c1d667c61f9778ec2605c0a60ac3be5f02227`
- Worktree status: clean at preflight
- Discovery: `0/2`; closure: `0/5`
- Primary spec SHA-256: `e1810db3c3516f072dcd500fe4082574e460f30353cc8ac120cf8b29b112ed9a`
- Architecture revision: commit `518835315a65996b9321665213adb0516503df65`

## Trust

**YELLOW — safe current-tree fallback; target-bound Gimle evidence unavailable.**

Palace health was reachable, but returned runtime label `native-dev`, a Gimle-serving checkout, and a serving SHA rather than the ThorChainKit worktree. The registered Palace project list contains no ThorChainKit project. These are recorded as `B-0001` environment drift and `B-0002` target coverage/mapping gap. Codebase-memory also returned no current `SendQuote`/`SendPreflight` results while Serena and `rg` located current symbols; this is `B-0003` and was not used as authority for send-domain claims.

## Independent evidence

- `F-001`: `EndpointLease` carries family, chain identity, read height, Comet reference height, and pool generation — `Sources/ThorChainKit/Network/EndpointLease.swift:3-8`.
- `F-002`: `EndpointPool` leases families, validates generation, and reset-cancels waiters — `Sources/ThorChainKit/Network/EndpointPool.swift:30-84`.
- `F-003`: `ReadOperationCoordinator` provides account/balance child operations, cancellation, stale-lease rejection, and retry, but its structured task-group drain is rejected for non-cooperative send liveness — `Sources/ThorChainKit/Network/ReadOperationCoordinator.swift:37-149`.
- `F-004`: `LiveThorNodeClient` binds account/balance requests to lease height and rejects bad response proof — `Sources/ThorChainKit/Network/LiveThorNodeClient.swift:21-138`.
- `F-005`: `SendQuote` is immutable and checks canonical authority projection — `Sources/ThorChainKit/Send/Domain/SendQuote.swift:31-116`.
- `F-006`: `SendRuntime` owns generation admission/invalidation while quote/send remain unavailable placeholders — `Sources/ThorChainKit/Send/Internal/SendRuntime.swift:35-79`.
- `F-007`: EvmKit's `NonceProvider` takes the maximum successful provider value — `EvmKit.Swift/Sources/EvmKit/Api/Core/NonceProvider.swift:1-26` in the verified external checkout; rejected as a coherence counterexample.

All kept analogs were independently checked with Serena and targeted `rg`/Git reads in their exact checkouts. No implementation code was changed during evidence or formalization.

## Defects and workarounds

| ID | Classification | Impact | Workaround |
|---|---|---|---|
| B-0001 | environment drift | Gimle runtime identity is not target-bound | Treat Gimle as non-authoritative; use Serena/current-tree evidence. |
| B-0002 | coverage gap | Palace has no ThorChainKit registered project | Preserve unresolved target mapping; do not infer freshness. |
| B-0003 | coverage gap | Codebase-memory omits current send symbols | Use exact-worktree Serena, `rg`, and Git reads. |

## Remaining formalization gate

Adversarial review revision 1 found critical/high gaps in implementation ownership seams, query-codec boundary, exact-family H1/H2 refresh, common height, H0 attempt/deadline ownership, digest definition, artifact binding, and test/live evidence. Security review additionally required strict proof envelopes, an explicit trusted-provider boundary, memo-policy validation, and orphan caps. Revision 2 resolves those IDs; all latest decision records are `ACCEPT`. Explicit user approval of this exact revision is still required before implementation.

## Revision-2 resolutions

- `D-001`/`D-002`: the spec now names the minimum runtime/store/composition seams and query-only Cosmos/ABCI codecs; transaction/signing codecs remain S2-03 scope.
- `D-003`/`D-004`/`D-005`: manifests bind exact normalized endpoints and revision; `refreshLease(family:minimumHeight:)` is required; each round uses the highest common proven height bounded by both lease role heights.
- `D-006`/`D-007`: H0 carries attempt/family/route identity with injected deadline/lifecycle races and orphan caps; the structured task-group drain is explicitly rejected as the liveness spine.
- `D-008`: the digest is versioned SHA-256 over length-prefixed canonical bytes with a fixed vector and complete identity/proof fields.
- `D-009`/`D-010`/`D-011`: the plan binds the current artifact hash, maps each criterion to named tests, rejects zero-test filters, and defines live/fixture capture IDs plus PASS/FAIL/UNRUN semantics.

The security lane returned these additional resolved constraints: strict success envelopes and duplicate-key/body bounds, trusted-provider (not cryptographic state-proof) scope, positive memo policy, interleaved late-family tests, and family/global orphan accounting. The architecture and verification lanes returned; the security lane returned after the bounded final poll. No files were modified by review workers.
