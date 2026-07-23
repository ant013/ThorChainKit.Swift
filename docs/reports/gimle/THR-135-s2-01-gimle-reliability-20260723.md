# THR-135 S2-01 Gimle Reliability Report

## Scope and phase

- Slice: S2-01 immutable send/quote domain and stable public errors.
- Run: `THR-135-s2-01-20260723-r2`.
- Current phase: `adversarial_review` after sanitized docs-only rework.
- Repository branch: `docs/THR-135-s2-01-formalization`.
- Integration base: `origin/main` at `937332b2e7020868abcac8681ddd664b6e4bad72`.
- Canonical architecture source preserved from `518835315a65996b9321665213adb0516503df65`.
- Trust: `RED` pending independent adversarial acceptance; validation has no structural errors.

## Evidence identity

The codebase-memory project was queried first as `Users-ant013-Data-AI-thorchain`. Current TronKit and EvmKit indexed commits matched their verified local trees. The authorized Unstoppable supporting consumer is the operator-local checkout `$UW_ROOT`, branch `local/THR-104-thorchain-lifecycle-v0.50`, at HEAD `8a63bfda028dd8543115b26dd777235a53304311`, with remote identity `horizontalsystems/unstoppable-wallet-ios`.

The UW working copy is intentionally dirty with local THR-104/THR-139 integration changes and one unrelated pre-existing MultiSwap test change. It was read-only evidence. Gimle's UW project mapping pointed at a different indexed checkout and commit; this is mapping defect `B-0001`, not delivery evidence.

## Fallbacks and selected family

- Accepted fallback: Serena activation of the exact target worktree and authorized UW checkout, followed by targeted `rg` verification.
- Selected analog family: TronKit primary ownership/boundary evidence; EvmKit signer and typed-error trust-boundary support; UW handler registration, local validation, and ten-second expiration as consumer evidence.
- Rejected counterexample: Vultisig raw transaction, raw key-shaped, and unbounded error-presentation fixtures.
- No raw transaction, private key, provider URL, credential, response body, or absolute operator path is part of the committed evidence.

## S2-01 decisions

- Immutable public values remain the Kit-owned, host-neutral ownership spine.
- Quote identity is opaque, one-use, generation-bound, and exactly ten seconds from the accepted coherent snapshot.
- Errors are finite, deterministic, `Sendable`, and sanitized; provider text stays internal.
- Verification is test-first and local-only. Durable journal, transport, protobuf, signing verification, Example UI, host integration, and S2-02+ remain out of scope.

## Artifact binding

- Spec, delta matrix, and test-plan digest: `1b1e8107674c7711c040fa5fea6328156e4454fbd38554490421b98c7dadf173`.
- Repository report is a sanitized summary of the external durable run; the external canonical state remains under the operator's Gimle audit root.
