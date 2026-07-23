# THR-135 S2-01 Gimle Reliability Report

## Scope and phase

- Slice: S2-01 immutable send/quote domain and stable public errors.
- Run: `THR-135-s2-01-20260723-r3`.
- Current phase: `adversarial_review` after discovery-1 docs-only rework.
- Repository branch: `docs/THR-135-s2-01-formalization`.
- Integration base: `origin/main` at `937332b2e7020868abcac8681ddd664b6e4bad72`.
- Canonical architecture source preserved from `518835315a65996b9321665213adb0516503df65`.
- Trust: `RED` pending independent adversarial acceptance; validation has no structural errors.

## Evidence identity

The codebase-memory project was queried first as `Users-ant013-Data-AI-thorchain`. Current TronKit and EvmKit indexed commits matched their verified local trees. The authorized Unstoppable supporting consumer is the operator-local checkout `$UW_ROOT`, branch `local/THR-104-thorchain-lifecycle-v0.50`, at HEAD `8a63bfda028dd8543115b26dd777235a53304311`, with remote identity `horizontalsystems/unstoppable-wallet-ios`.

The UW working copy is intentionally dirty with local THR-104/THR-139 integration changes and one unrelated pre-existing MultiSwap test change. It was read-only evidence. Gimle's UW project mapping pointed at a different indexed checkout and commit; this is mapping defect `B-0001`, not delivery evidence.

## Fallbacks and selected family

- Accepted fallback: Serena activation of the exact target worktree and authorized UW checkout, followed by targeted `rg` verification.
- Selected analog family: UW `EvmSendHandler`/`TronSendHandler` is the single S2-01 primary for review→send separation, typed validation, and ten-second expiration; `SendHandlerFactory` is supporting composition evidence; TronKit supplies supporting standalone-Kit lifecycle/ownership evidence; EvmKit supplies signer and typed-error trust-boundary support.
- Rejected counterexample: Vultisig raw transaction, raw key-shaped, and unbounded error-presentation fixtures.
- No raw transaction, private key, provider URL, credential, response body, or absolute operator path is part of the committed evidence.

## S2-01 decisions

- Immutable public values remain the Kit-owned, host-neutral ownership spine, while the UW handler family is the coherent behavioral analog.
- Active deferred facade calls fail closed as `operationUnavailable`; inactive lifecycle admission still returns `kitNotStarted`; pending is empty and `.degraded` until S2-05.
- Quote identity is opaque, one-use, generation-bound, and exactly ten seconds from the accepted coherent snapshot.
- Errors are finite, deterministic, `Sendable`, and sanitized; provider text and raw codespace stay internal, while public codespace is a fixed category allowlist; debug and reflection use explicit redacted mirrors.
- The composition seam is `Kit` → `KitDependencies`/`KitFactory` → `LifecycleCommandBridge` → `LifecycleGate` with one stored `SendRuntime` dependency.
- Verification is test-first and local-only. Durable journal, transport, protobuf, signing verification, Example UI, host integration, and S2-02+ remain out of scope.

## Artifact binding

- Spec/delta-matrix/test-plan digest: `639e8da5bbb329ff07e1c7ab4d9b59886afdf3e87e54ddff1474b8d90d937d21`.
- Implementation-plan digest: `d6590930f8797ccf49622d10bf6a9274315bb00cee93f3cf546f25c899d9ab4e`.
- Analog-family digest: `7279cec526c0cd6a2b67407049080de263eddb2680077abb6083c8493eac626d`.
- Consolidated-test-plan digest: `efb853fd65011a24331606434794d0c59cc9d7d62c1490da0c2f7e22a4a0a0c6`.
- Committed evidence manifest digest: `e2325dacc2fe6075554e8916ecebb23fe77cf61eee8e5c6695caff6ec76a8bdc`.
- The repository report and manifest are the immutable sanitized evidence
  binding for this revision; no mutable external audit root is required to
  reconstruct the selected claims, candidate IDs, decision IDs, or artifact
  hashes.
