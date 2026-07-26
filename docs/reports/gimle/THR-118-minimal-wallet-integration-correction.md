# Gimle Evidence Report — THR-118 Minimal Wallet Integration Correction

## Repository identity

- Target checkout: adjacent local `unstoppable-wallet-ios-THR-104-v0.50`
- Origin identity: `horizontalsystems/unstoppable-wallet-ios`
- Local branch: `local/THR-104-thorchain-lifecycle-v0.50`
- Target HEAD: `8a63bfda028dd8543115b26dd777235a53304311`
- Merge-base with `origin/version/0.50`:
  `8a63bfda028dd8543115b26dd777235a53304311`
- Working copy: dirty with the existing local native-RUNE integration.

## Evidence result

The indexed upstream Unstoppable project and exact local Serena/`rg` evidence
agree that v0.50 uses direct `MarketKit.Kit` ownership, ordinary `[Wallet]`
publication, normal wallet rows, and resolved-wallet deletion. The local
`WalletQuerying`, `UnavailableWallet`, technical unavailable-row UI, retry, and
identity-keyed delete are uncommitted additions rather than established wallet
conventions.

ThorChainKit has no dependency on that host recovery model. The selected analog
family therefore keeps the proven v0.50 host lifecycle and preserves only the
real kit integration seams.

MarketKit `3.6.12` already has the `thorchain` coin and blockchain dump rows.
The local metadata branch adds one native token relation with coin UID
`thorchain`, blockchain UID `thorchain`, type `native`, and 8 decimals, plus the
matching `BlockchainType.thorChain` mapping and focused test. This is normal
metadata discovery, not a recovery abstraction.

## Gimle reliability

Gimle/Palace health timed out after 300 seconds during this correction. The
indexed codebase-memory service also listed the ThorChain project but rejected
an immediate lookup as “project not found or not indexed.” Neither result was
used as load-bearing evidence. Exact filesystem identity, current-tree Serena,
targeted Git/`rg`, and the indexed upstream Unstoppable source are the decision
basis. Trust remains RED for Gimle-backed claims.

## Adversarial review

Decision: ACCEPT.

- Removing only the three visible declarations would leave dead recovery state;
  the coherent minimum is removal of their full propagation contour.
- The correction must not remove normal resolved-wallet deletion.
- The correction must not remove actual ThorChainKit integration or exact
  native-RUNE construction checks.
- Preserving upstream behavior can retain existing generic failure semantics;
  the operator explicitly rejects a new recovery subsystem without a reproduced
  product requirement.
- No remote Unstoppable action is permitted.
