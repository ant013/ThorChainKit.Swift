# THR-135 S2-01 Gimle Reliability Report

## Scope and phase

- Slice: S2-01 immutable send/quote domain and stable public errors.
- Run: `THR-135-s2-01-20260723-r4`.
- Current phase: `adversarial_review` after supervisor exact-head corrections.
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
- Active deferred facade calls with valid local input fail closed as `operationUnavailable`; invalid local input returns its stable validation error; inactive lifecycle admission still returns `kitNotStarted`; pending is empty and `.degraded` until S2-05.
- Quote identity is opaque, one-use, generation-bound, and exactly ten seconds from the accepted coherent snapshot; its private namespace/generation/deadline envelope is checked before active/consumed state, with eight bounded secure-random attempts.
- Errors are finite, deterministic, `Sendable`, and sanitized; provider text and raw codespace stay internal, while public codespace is a fixed category allowlist; debug and reflection use explicit redacted mirrors.
- The composition seam is `Kit` → `KitDependencies`/`KitFactory` → `LifecycleCommandBridge` → `LifecycleGate` with one stored `SendRuntime` dependency.
- Verification is test-first and local-only. Durable journal, transport, protobuf, signing verification, Example UI, host integration, and S2-02+ remain out of scope.

## Artifact binding

- Spec/delta-matrix/test-plan digest: `9f8cb01934980b3c2e4907e5905fd63d72d01dc89bf5e12012f58a1b6232b5bc`.
- Implementation-plan digest: `2c5d0f1a5367d3f475e4f0b639462d5fdaea88ba5ba0550f255b860a6866fe89`.
- Analog-family digest: `7279cec526c0cd6a2b67407049080de263eddb2680077abb6083c8493eac626d`.
- Consolidated-test-plan digest: `efb853fd65011a24331606434794d0c59cc9d7d62c1490da0c2f7e22a4a0a0c6`.
- Committed evidence manifest digest: `c9670f23dbaefe3411db5f2e844a5bfa4f85d4ec3395ac02212f4488a2f4a70d` (`THR-135-s2-01-evidence-r4.json`).
- The repository report and manifest are the immutable sanitized evidence
  binding for this revision; no mutable external audit root is required to
  reconstruct the selected claims, candidate IDs, decision IDs, or artifact
  hashes.
- The historical host-local `F-S201-ERROR-GRAPH-COMPILE` probe is quarantined
  and omitted from the load-bearing manifest; the implementation head must
  supply the committed deployment-floor/import and concurrency harnesses.
