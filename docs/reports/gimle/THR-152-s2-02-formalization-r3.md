# THR-152 S2-02 Formalization — Gimle Reliability and Evidence

## Run binding

- Run: `THR-152-s2-02-20260724-r2`
- Design revision: `4`
- Previous rejected docs head: `a55b47fb3b9f64f2d370f935bd5577c895a6c75b`
- Branch: `docs/THR-152-s2-02-formalization`
- Discovery: `2/2` frozen; closure: `1/5`
- Architecture revision: commit `518835315a65996b9321665213adb0516503df65`
- Canonical architecture bundle digest: `a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc`
- Primary spec SHA-256: `7c8a348905707aa4446d7f536140ae49168855cf1f76b0c42faf375337bde414`

No implementation files changed. Revision 4 is a targeted formalization
correction after the revision-2 approval rejection; it does not expand
discovery or implementation scope.

## Trust

**YELLOW — safe current-tree fallback; target-bound Gimle evidence unavailable.**

Palace health was reachable, but returned runtime label `native-dev`, a
Gimle-serving checkout, and a serving SHA rather than the ThorChainKit
worktree. The registered Palace project list contains no ThorChainKit project.
These remain `B-0001` environment drift and `B-0002` target coverage/mapping
gap. Codebase-memory returned only a current `EndpointLease` test symbol for
the requested send vocabulary; Serena and targeted `rg` remain the authority
for exact current-tree claims, and the incomplete graph result is `B-0003`.

## Independent current-tree evidence

- `F-001`: THR-139 requires exactly three native RUNE families —
  `rorcual-mainnet`, `ibs-mainnet`, and `keplr-mainnet` — and explicitly
  excludes Liquify from native RUNE —
  `docs/specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md:70-112`.
- `F-002`: THR-139 defines exactly six role-bound normalized endpoint records,
  including the shared IBS host with distinct `/api` and `/rpc` base paths —
  `docs/specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md:90-112`.
- `F-003`: THR-139's three fixed S1-04 live invocations bind each family to
  its exact REST/Comet pair — `docs/specs/sprint-01-foundation/THR-139-resilient-rune-provider-pool.md:496-529`.
- `F-004`: current `EndpointLease` carries family, chain identity, read height,
  Comet reference height, and pool generation —
  `Sources/ThorChainKit/Network/EndpointLease.swift:3-8`.
- `F-005`: current `EndpointPool` leases families, validates generation, and
  reset-cancels waiters — `Sources/ThorChainKit/Network/EndpointPool.swift:30-84`.
- `F-006`: current `LiveThorNodeClient` binds account/balance requests to lease
  height and rejects bad response proof —
  `Sources/ThorChainKit/Network/LiveThorNodeClient.swift:21-138`.

## D-012 — exact native family and proof gate

**Outcome: ACCEPT for revision 4 after targeted closure correction.** S2-02's manifest
registry is exactly the THR-139 three-family registry and all six role-bound
records. Liquify is retained only as rejected counterevidence; it is not a
native-RUNE or send family.

The current proof status is deliberately explicit:

| Family | Complete S2-02 route/proof matrix | Send status |
|---|---|---|
| `rorcual-mainnet` | `UNRUN` | read-only |
| `ibs-mainnet` | `UNRUN` | read-only |
| `keplr-mainnet` | `UNRUN` | read-only |

`PASS` is reserved for a redacted fixture/live capture covering every required
route, its one approved proof mode, the exact family and six-record manifest,
schema revision, and implementation head. `FAIL` and `UNRUN` remain
read-only. S1-04 account/height compatibility and query-only REST cannot
promote a family to send-capable.

Revision 4 also scopes height headers only to `RESTHeaderProof`; `BodyHeightProof`
uses only its authoritative body field; and query-only protobuf dependency,
generated-source inputs, tool versions/checksums, and regeneration command are
bound in the spec's deterministic provenance contract. Transaction/signing
codecs remain S2-03, and S2-05 retry/lookup implementation ownership is
removed from this slice.

## Review path and limitations

The bounded worker review path was timeboxed by the supervisor; delayed workers
were not awaited again. The CTO synthesis uses the already independently
verified exact anchors above. Discovery is frozen at `2/2`; closure `1/5`
rechecked only the frozen IDs plus direct changed-line regressions. No new
discovery was opened.

The prior r2 report is explicitly superseded/rejected and is not current
authority.

Gimle defects and workarounds remain:

| ID | Classification | Impact | Workaround |
|---|---|---|---|
| B-0001 | environment drift | Gimle runtime identity is not target-bound | Treat Gimle as non-authoritative; use current-tree evidence. |
| B-0002 | coverage gap | Palace has no ThorChainKit registered project | Do not infer freshness or family proof from Palace. |
| B-0003 | coverage gap | Codebase-memory underfilled current send vocabulary | Use Serena, targeted `rg`, and Git reads. |

Explicit user approval of the exact pushed revision-4 spec/plan remains
required before implementation.
