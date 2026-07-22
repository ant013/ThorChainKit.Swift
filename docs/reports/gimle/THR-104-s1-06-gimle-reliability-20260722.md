# THR-104 S1-06 Gimle reliability report

**Authoritative correction run:** `THR-104-s1-06-v050-r2-20260722`

**ThorChainKit spec base:** `origin/main` /
`0f572e455be07df798a233eff31bbc27bb0940c5`

**Unstoppable implementation base:** official `origin/version/0.50` /
`8a63bfda028dd8543115b26dd777235a53304311`

**Workflow phase:** design revision 6; implementation remains blocked until
adversarial review and explicit approval of this revision.

**Trust:** GREEN for the Palace `uw-ios-app` identity and selected current-tree
claims; YELLOW fallback is recorded for unavailable codebase-memory.

**Revision 6 artifact hashes:** spec
`cbd16b637761df6f3b370a4ea79279a2bb7b84c2276a305ac800ba2e6e880bd3`; plan
`f9c59072bcc27b8b7bd3427d23eb5581a7987669392b60ce59585592e14564e7`.

## Identity

The implementation/evidence worktree is
`/Users/ant013/Data/AI/unstoppable-wallet-ios-THR-104-v0.50`, local branch
`local/THR-104-thorchain-lifecycle-v0.50`, exact clean HEAD
`8a63bfda028dd8543115b26dd777235a53304311`, with the official Horizontal
Systems origin. The old `master`-based branch and closed PR #7132 are retained
only as recovery evidence and do not influence implementation.

Palace runtime `0e9cf57c00ff970f584256126b500166580e7a72` is healthy. Project,
memory, and mounted-git slug `uw-ios-app` all report the same indexed/tree/HEAD
commit as the corrected worktree, with zero commits behind. The mount path is a
separate mirror, but exact commit identity and current-tree verification agree.

Codebase-memory project `Users-ant013-Data-AI-thorchain` was queried first and
returned `Transport closed`. This is recorded as `ENV-CBM-001`
(`environment_drift`, medium, confirmed, workaround). No codebase-memory claim
is used for the corrected design.

## Verified analog decision

The `version/0.50` composition spine is `TronKitManager` plus the current
`Core`/`AdapterFactory` injection path. The current manager-owned
`tronKit.start()` combined with empty `TronAdapter.start/stop/refresh` is the
rejected split-lifecycle counterexample. The S1-06 manager constructs and
caches an unstarted wrapper; the adapter alone owns start, stop, and refresh.

The corrected base retains `IAccountAddressProvider` and registered provider
resolution in `AccountAddress.swift`, with the default implementation in
`AccountAddressProvider.swift`. THOR address derivation therefore extends that
contract and conformer. The direct-static address edit produced for `master` is rejected;
`git apply --check` also proves the old patch does not apply cleanly to the
corrected base.

Because `IAccountAddressProvider` is public, the new THOR requirement has a
default `nil` implementation. Existing external conformers remain
source-compatible while the built-in provider supplies mnemonic derivation.

`Wallet.xcworkspace` already consumes `packages/WalletCore` locally. During
development, the uncommitted WalletCore manifest will use relative sibling
paths for ThorChainKit and MarketKit. Absolute operator paths are prohibited.

## Delivery and review boundary

Unstoppable changes remain local and uncommitted until the owner explicitly
authorizes final delivery. There is no Unstoppable push, PR, or merge in S1-06.
Local reviewer and QA evidence binds the snapshot as the exact
`version/0.50` base SHA plus SHA-256 of the complete binary diff. Delivery-form
remote revisions and commits are deferred to the final integration stage.

## Verification boundary

All tests and builds run on the local MacBook. GitHub Actions, Maestro, and CI
test/mutant/simulator execution are excluded. Unstoppable acceptance uses the
existing AppTests target and manual host verification; no ThorChainKit Maestro
suite is applied to the wallet application.

No implementation edit or test run was performed during this correction phase.
