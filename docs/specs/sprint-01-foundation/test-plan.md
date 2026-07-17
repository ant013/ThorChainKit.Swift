# Sprint 1 — consolidated test and verification plan

## Purpose

This plan maps the acceptance criteria of the seven specs to specific test layers. It does not replace the test lists within each spec; if they conflict, the stricter criterion prevails.

## Test layers

| Layer | Execution | What it proves |
|---|---|---|
| Pure unit | default CI | network/address/amount/error invariants |
| Controlled async | default CI | cancellation, coalescing, generation, retry, pagination |
| Storage | default CI, temporary DB | migrations, atomic replace, restart/cache namespaces |
| Package integration | default CI | facade composition, publishers, real dependencies |
| WalletCore integration | host branch CI | manager/adapter/factory/consumer lifecycle |
| Example UI acceptance | default fixture CI via Maestro | public user-visible state, accessibility contract, cross-slice scenario |
| Opt-in live | manual/release gate | current endpoint/API compatibility and chain identity |
| Host product acceptance | manual `Development` checklist | observable create/import/enable/receive/relaunch/App Status behavior without Maestro |

## Traceability matrix

| Criterion | Unit/controlled | Integration/live |
|---|---|---|
| Package API isolated from host | PublicApiTests + import allowlist | temporary WalletCore consumer build |
| Atomic mainnet identity | NetworkTests | mainnet status/node-info exact `thorchain-1` |
| Address derivation | DerivationTests independent vectors | imported mnemonic full address match |
| Strict address validation | AddressCodecTests/fuzz | Receive/parser real UI |
| Complete balances | fixture pagination tests | public address direct response comparison |
| Account absence distinction | fixtures/errors | known empty address live read |
| Cancellation/no stale publication | controlled continuations/clock | remove wallet during delayed proxy request |
| Persistence/restart | temporary GRDB reconstruction | AppTests reconstruction + manual app terminate/relaunch/offline observation |
| Generic adapter lifecycle | manager/adapter call counters | wallet enable/remove/refresh |
| MarketKit metadata | UID/cache/token tests | Manage Wallets discovery after cold launch |
| Cross-slice Example | package/component tests | Maestro fixture flows launch→address→endpoint→read→restart |

## Mandatory failure scenarios

- wrong chain ID;
- mixed endpoint identities;
- catching-up/stale endpoint, including fresh Comet + stale Cosmos REST;
- missing/mismatched `x-cosmos-block-height` on account or any balance page;
- single-family default policy construction;
- 429 and 503 with bounded failover;
- cancellation during probe, first page, later page, account request and sleep;
- malformed JSON and invalid decimal string;
- account not found versus unknown account type;
- pagination cycle and partial-page failure;
- storage transaction failure;
- stop followed by late completion;
- offline cold/relaunch with cached state;
- wrong HRP/checksum/mixed-case/address payload length;
- MarketKit metadata unavailable on reconstruction.

## Determinism rules

- Inject transport, node probe, clock, sleeper, storage and lifecycle dependencies.
- Fixed `sleep` delays are prohibited.
- Async tests wait on continuations/expectations tied to observed events.
- Retry count and requested URLs assert exact sequence.
- Random/property tests log seed on failure.
- Network live tests excluded from default CI and never make deterministic suite flaky.
- Maestro selectors use accessibility identifiers, not localized labels or screen coordinates.
- Committed Maestro YAML contains no mnemonic, API key or endpoint credential; runtime values arrive via environment.
- Fixture and live modes expose an explicit `data-source` badge so fixture success cannot masquerade as live evidence.
- The Maestro launcher verifies a non-empty expected-flow manifest and JUnit case count; detecting zero flows/tests fails the gate.
- All Maestro rules apply only to `ThorChainKit/iOS Example`; the Unstoppable repository receives no Maestro YAML, runner, DEBUG transport, or acceptance launch arguments.
- Example artifacts pass a secret/canary scan before publication.

## Verification order per slice

1. `swift build` / compile of changed target.
2. Narrow new test class.
3. Full ThorChainKit test target.
4. Package dependency/manifest inspection.
5. WalletCore narrow tests for S1-06/S1-07.
6. WalletCore/App build.
7. Maestro deterministic Example flow for the slice.
8. Opt-in live API gate.
9. Unstoppable manual create/import/relaunch/App Status checklist for S1-07.
10. Diff audit confirms that no Maestro/acceptance-only host files were added.

## Live evidence record

For a controlled run, record:

- kit/host commit;
- timestamp/timezone;
- endpoint IDs/roles, without credentials;
- returned chain ID and heights;
- test address class/provenance;
- expected and actual raw RUNE amount;
- create/import/relaunch result;
- Example Maestro flow name, mode (`FIXTURE`/`LIVE`) and JUnit/artifact location;
- the Unstoppable manual-checklist result separately from the Maestro evidence;
- skipped/unavailable checks and the exact reason.

The mnemonic/private key must not appear in the evidence. Use a public fixture mnemonic or a purpose-created test account without user funds.

## Sprint exit gate

- All default deterministic tests are green.
- There are no ignored/skipped deterministic tests.
- Live failures are not masked by fixture success.
- Mainnet identity and balance reads have been completed against at least two endpoint providers, or only one approved provider is documented as available.
- App create/import/relaunch paths have been completed on a physical device or release-equivalent simulator where the process was actually terminated.
- All deterministic Example Maestro flows are green; live flows are either green or explicitly unrun with a reason.
- After an offline relaunch, the wallet/address/cache are preserved, and state truthfully shows failure/stale.
- Unstoppable contains no `.maestro`, acceptance transport, or test launch-argument branches.
- All high/critical adversarial findings are closed.
