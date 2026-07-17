# Sprint 1 — adversarial architecture review

## Conclusion

**Decision: ACCEPT.** After four independent rounds of architectural review, including a repeat verification after the Maestro boundary changed, no known critical- or high-severity findings remain in the design package. This decision permits presenting the package to the user for approval, but is not user approval and does not authorize implementation to begin.

The review was performed against the current versions of the seven slice specs and the consolidated test plan. The ThorChainKit, Unstoppable Wallet, and reference-kit source code was not changed.

## Round 1 — REVISE

The first round found the following load-bearing issues:

| Area | Finding | Resolution |
|---|---|---|
| S1-05 lifecycle | the generation check did not establish FIFO and compare-and-set before publication | introduced `LifecycleCommandBridge`, persistent generation, and generation CAS immediately before atomic save/publication |
| S1-04 failover | retry ownership could split between the HTTP client and endpoint pool | `ReadOperationCoordinator` became the sole owner of the entire complete read operation; a partial operation does not move between families |
| S1-06 adapter | the contracts were described approximately | recorded the exact current `IAdapter`, `IBalanceAdapter`, and `IDepositAdapter` properties and the existing `AdapterManager` lifecycle |
| S1-07 parser | an unnecessary parser protocol had been invented | uses the existing `IAddressParserItem` with `handle`/`isValid`; `AddressParserChain` does not change |
| S1-01/S1-04 API | public and internal testing surfaces were mixed | production API separated from `@_spi(Testing)` transport injection |
| S1-02 probes | Cosmos REST and CometBFT lacked independent role checks | introduced role-specific identity/freshness probes and an immutable family lease |
| S1-03 crypto | checking key length did not establish a valid secp256k1 point; the HdWallet contract was inaccurate | added `secp256k1_ec_pubkey_parse`; recorded the exact `coinType`, `xPrivKey`, `purpose`, `curve`, and compressed-public-key pipeline |
| S1-07 MarketKit | the metadata change had no dedicated test target | added `Package.swift`, a MarketKit test target, and metadata/UID tests to scope |
| S1-07 restore | sequential saves could incorrectly be read as an atomic transaction | recorded that current restore consists of three sequential, non-atomic `Void` saves; no network work is added to this path |

## Round 2 — REVISE

Three high-severity findings remained after the first revision:

1. **Cosmos REST freshness was not established independently of CometBFT.** S1-02 now obtains `cosmosLatestHeight` through Cosmos REST and `cometLatestHeight` through `/status`, checks bounded skew, and creates a lease with separate heights. S1-04 requires exact `x-cosmos-block-height == lease.cosmosReadHeight` for the auth account and every bank page.
2. **`maximumAttempts = 2` broke a valid single-family configuration.** The public default was changed to `nil`, meaning exactly one pass over all configured families; effective attempts for one family is `1`, and a value greater than the number of families is rejected.
3. **Offline UI acceptance was not reproducible.** The second revision proposed a DEBUG-only injected transport and a scenario on a disposable simulator. After the user's Maestro constraint, that solution was deemed obsolete and removed completely from Unstoppable; the current replacement was verified in round 4.

## Round 3 — ACCEPT

The repeat review verified the corrected high-risk boundaries:

- independent Cosmos/Comet heights, bounded skew, and a Cosmos-pinned lease;
- exact height header on the account and all pagination pages;
- correct single-family semantics;
- a single owner for whole-operation failover;
- cancellation, lifecycle generation CAS, and stop barrier;
- exact Unstoppable adapter/parser/restore contracts;
- the then-current DEBUG-only acceptance harness, process termination, cleanup, recovery, and artifact-secret policy.

Result for that revision: **ACCEPT**. The subsequent change to the Maestro scope materially changed the design and required a new review.

## Maestro-boundary revision and round 4 — ACCEPT

The user established a new strict boundary: Maestro applies only to the `iOS Example` in the standalone `ThorChainKit` repository; Maestro does not apply to Unstoppable.

The host `.maestro` flows, runner, acceptance fixtures, DEBUG transport/factory, and launch-argument hooks were removed from the design package. Automated verification of Unstoppable remains in the existing `AppTests`, while the observable product path goes through a concrete manual `Development` checklist.

The first pass of the revision review returned four high-severity findings; all were corrected before reevaluation:

1. The Testing SPI is limited to the `ThorChainKit/iOS Example` fixture target; Unstoppable does not import it.
2. A regular internal production abstraction, `IThorChainKit`, was introduced in WalletCore. Production `ThorChainKit.Kit` and the `AppTests` spy implement the same contract without SPI/DEBUG.
3. The manual checklist explicitly verifies offline relaunch, recovery, remove-wallet/cancellation, and reinstall without cache.
4. The integrity manifest is recalculated after the final design edits.

An independent repeat review verified the current files and returned **ACCEPT** with no critical/high findings. In particular, it confirmed:

- absence of Maestro/acceptance-only runtime in Unstoppable;
- ability to verify exact `start/stop/refresh` and the absence of orphan publication through a normal `IThorChainKit` spy in `AppTests`;
- separation of Example Maestro evidence and manual host evidence;
- complete manual sequence offline → recovery → remove → reinstall.

## Decision constraints

- Gimle trust remains `RED`; all load-bearing conclusions were reverified in the exact current trees through Serena and targeted `rg`.
- Maestro CLI is not installed on the current machine, so the Example YAML and runner currently exist only as an asserted design contract and apply exclusively to the future `ThorChainKit/iOS Example`.
- The user's term `Meteora` was interpreted as Maestro. If it refers to another internal tool, the UI layer must be rebound to its actual contract before implementation.
- Implementation remains blocked pending explicit user approval of the design package.
