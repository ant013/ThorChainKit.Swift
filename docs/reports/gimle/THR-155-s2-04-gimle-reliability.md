# THR-155 S2-04 Gimle reliability report

- Task: `THR-155`
- Slice: `S2-04 External Signer and Per-Account Coordinator`
- Pinned architecture head: `518835315a65996b9321665213adb0516503df65`
- Trust: **RED fallback**

## Substrate

`codebase-memory` project `Users-ant013-Data-AI-thorchain` is ready with
2,890 nodes and 4,056 edges. The target repository is not registered in the
available Palace/Gimle project list, so no target Gimle freshness or runtime
identity can be established. No Serena tool is available in this session.

These are recorded environment limitations, not evidence that the selected
analogs are absent. They force RED Gimle trust for this run; independently
verified current-tree evidence remains usable for the bounded design.

## Independently verified analog evidence

| Fact | Current-tree evidence | Verdict |
|---|---|---|
| Host owns signer capability at the wallet boundary | Unstoppable `TronKitWrapper` stores an owned optional signer and calls kit send only through the wrapper at `packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:140-166`. | MATCH |
| THOR signing verifies against the expected public key | Vultisig `THORChainHelper.getSignedTransaction` constructs the expected secp256k1 key and rejects failed verification at `VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:186-205`. | MATCH |
| Compact secp256k1 output is an available supporting shape | HsCryptoKit `Crypto.sign(data:privateKey:compact:)` normalizes and exposes compact signing at `Sources/HsCryptoKit/Crypto.swift:109-124`. | MATCH |
| Seed/private-key-owned signer is unsafe for this boundary | EvmKit `Signer` stores concrete signing objects and exposes `instance(seed:)` and `instance(privateKey:)` at `Sources/EvmKit/Core/Signer/Signer.swift:1-67`. | REJECTED COUNTEREXAMPLE |

## Fallback and limitations

The selected facts were verified with exact current checkout paths, Git heads,
targeted `rg`, and narrow reads. Because Gimle target mapping and Serena are
unavailable, this report does not claim Gimle-backed freshness or GREEN trust.
The pinned Sprint 2 report remains the architecture-level review record; this
slice report narrows the evidence to S2-04 and preserves the fallback defect.
