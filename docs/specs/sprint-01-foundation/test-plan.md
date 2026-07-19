# Sprint 1 — consolidated test and verification plan

## Purpose

This plan maps the acceptance criteria of the seven specs to specific test layers. It does not replace the test lists within each spec; if they conflict, the stricter criterion prevails.

## Test layers

| Layer | Execution | What it proves |
|---|---|---|
| Pure unit | routine local; one final hosted gate | network/address/amount/error invariants |
| Controlled async | routine local; one final hosted gate | cancellation, coalescing, generation, retry, pagination |
| Storage | routine local with temporary DB; one final hosted gate | migrations, atomic replace, restart/cache namespaces |
| Package integration | routine local; one final hosted gate | facade composition, publishers, real dependencies |
| Contract audit | routine local; one final hosted gate | parsed manifest topology, import allowlist, public symbol allowlist, exact test discovery, and public-only iOS consumer |
| WalletCore integration | host branch CI | manager/adapter/factory/consumer lifecycle |
| Example UI acceptance | routine local Maestro; one final hosted gate | public user-visible state, accessibility contract, cross-slice scenario |
| Opt-in live | manual/release gate | current endpoint/API compatibility and chain identity |
| Host product acceptance | manual `Development` checklist | observable create/import/enable/receive/relaunch/App Status behavior without Maestro |

## Traceability matrix

| Criterion | Unit/controlled | Integration/live |
|---|---|---|
| Package API isolated from host | exact 18-method PublicApiTests list + mandatory current-value publisher replay | parsed manifest/import/symbol/discovery gates + positive public-value construction closure + temporary public-only Swift 5.10/iOS 13 `xcodebuild` consumer |
| Atomic mainnet identity | NetworkTests | mainnet status/node-info exact `thorchain-1` |
| Address derivation | DerivationTests independent vectors | imported mnemonic full address match |
| Strict address validation | AddressCodecTests/fuzz + independently decoded THORNode address-to-20-byte-payload vector | Receive/parser real UI |
| Complete balances | fixture pagination tests | public address direct response comparison |
| Account absence distinction | fixtures/errors | known empty address live read |
| Cancellation/no stale publication | controlled continuations/clock | remove wallet during delayed proxy request |
| Persistence/restart | temporary GRDB reconstruction | AppTests reconstruction + manual app terminate/relaunch/offline observation |
| Generic adapter lifecycle | manager/adapter call counters | wallet enable/remove/refresh |
| MarketKit metadata | UID/cache/token tests | Manage Wallets discovery after cold launch |
| Cross-slice Example | package/component tests | Maestro fixture flows launch→address→endpoint→read→restart |

## Mandatory failure scenarios

- wrong chain ID;
- chain ID at 50 UTF-8 bytes accepted and 51 bytes rejected;
- denom outside the pinned 3...128-byte ASCII grammar;
- mixed endpoint identities;
- catching-up/stale endpoint, including fresh Comet + stale Cosmos REST;
- missing/mismatched `x-cosmos-block-height` on account or any balance page;
- single-family default policy construction;
- 429 and 503 with bounded failover;
- cancellation during probe, first page, later page, account request and sleep;
- malformed JSON and invalid decimal string;
- account not found versus unknown account type;
- absent account paired with any nonempty balance set;
- pagination cycle and partial-page failure;
- storage transaction failure;
- stop followed by late completion;
- an ordinary external effective start, stop, or running refresh returning before its held lifecycle collaborator completes;
- an S1-01 lifecycle collaborator making an effective reentrant start, stop, or running refresh that waits behind its active dispatcher drain;
- a reentrant lifecycle command being deferred to dispatcher async work so an already-waiting ordinary caller overtakes the active turn's required post-drain;
- an S1-05 competing publication `P1` entering after lifecycle command `C` is admitted by synchronous subscriber delivery during `P0` but before `P0` drains `C`;
- public factory/no-op composition creating a URL session/request, storage/file/database handle, task, timer, dispatch source, or unaudited helper capability;
- any enumerated Network/endpoint/Denom/Address initializer, stored/static root, transitive validator, or default expression creating I/O, a task, or an out-of-closure callee;
- a non-`Sendable` BigUInt-backed result crossing the S1-04 reader actor or S1-05 synchronizer/storage async boundary;
- a balance amount equal to or above `2^256`, or a cache row whose address/chain ID differs from the active Address, reaching public reconstruction;
- offline cold/relaunch with cached state;
- wrong HRP/checksum/mixed-case/address payload length;
- MarketKit metadata unavailable on reconstruction.

## Determinism rules

- Inject transport, node probe, clock, sleeper, storage and lifecycle dependencies.
- Fixed `sleep` delays are prohibited.
- Async tests wait on continuations/expectations tied to observed events.
- S1-01's one serial facade dispatcher is the sole snapshot/`desiredRunning`/sequence/FIFO owner; no lock or second draining queue exists. Off-dispatcher lifecycle methods enter synchronously, while a `DispatchSpecificKey<UInt8>`-identified reentrant method appends and returns to the active turn, which post-drains before yielding. S1-05's bridge preserves accepted actor-command order but owns no duplicate desired-running filter; actor-state-inconsistent duplicate start, stopped refresh, and duplicate stop are invariant failures in an isolated subprocess harness, while only valid running refresh work may coalesce.
- Method 16 blocks active collaborator `C0`, submits ordinary `C1` from an unrelated thread, then has `C0` synchronously submit effective reentrant `R`. It proves `R` returns after FIFO append, `C1` still waits, and exact callback order is `C0, R, C1` for reentrant start/stop/running refresh. `Scripts/test-s1-01-mutants.sh` baseline-runs method 16, applies exactly one guarded mutation that defers `R` with `facadeDispatcher.async`, and directly reruns only method 16 without recursively invoking the full verifier; the mutant fails and no sleep is permitted.
- S1-01 has no post-construction publication interface. Public getters use `facadeDispatcher.sync` only off-dispatcher and read directly in dispatcher context, so subscriber/collaborator reentry cannot self-wait. S1-05 owns atomic publication-turn admission on that same dispatcher: one admitted turn drains existing commands, delivers synchronously, and post-drains reentrant commands before another turn may enter. Its barrier test blocks `P0`, admits `C`, attempts `P1`, and proves exact `P0 → C → P1` order without sleeps.
- S1-01 endpoint tests enumerate every constructor rule: nonempty families, `https`, no credentials/query/fragment, normalized nonempty unique family IDs, separate `clientId` trim/control/empty-to-nil normalization, finite nonnegative lag, finite positive timeout/revalidation seconds, retryable-status subset, `1...1000` page count, explicit attempts in `1...families.count`, nil attempts, and the exact `effectiveMaximumAttempts` result.
- Retry count and requested URLs assert exact sequence.
- Random/property tests log seed on failure.
- Network live tests are local opt-in only, excluded from the hosted gate, and never make the deterministic suite flaky.
- Maestro selectors use accessibility identifiers, not localized labels or screen coordinates.
- Committed Maestro YAML contains no mnemonic, API key or endpoint credential; runtime values arrive via environment.
- Fixture and live modes expose an explicit `data-source` badge so fixture success cannot masquerade as live evidence.
- S1-01's sole UI gate is `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh`; raw `maestro test` is not accepted. Boot, build, install, launch, and Maestro use that same UDID.
- The final hosted gate preserves S1-01's pins: `actions/checkout` at `34e114876b0b11c390a56381ad16ebd13914f8d5`, `actions/setup-java` at `c1e323688fd81a25caa38c78aa6df2d33d3e20d9`, and the Maestro `2.6.1` `maestro.zip` artifact at official SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`. It asserts Maestro `2.6.1` and Temurin `17.0.19+10` before the fixture flow.
- S1-01 resolves JUnit, test-output, and debug-output to absolute paths under one repository-root `build/maestro-results` tree. The runner and shims reject workspace-relative or outside-root artifacts, and the scanner covers the separate JUnit file plus both Maestro output trees.
- The S1-01 launcher requires one configured flow and JUnit `tests=1`, `failures=0`, `errors=0`, and `skipped=0`; detecting zero, extra, failed, errored, or skipped tests fails the gate.
- All Maestro rules apply only to `ThorChainKit/iOS Example`; the Unstoppable repository receives no Maestro YAML, runner, DEBUG transport, or acceptance launch arguments.
- Tracked inputs and generated logs/JUnit/screenshots pass a secret and namespace scan before publication. OCR recursively enumerates only regular PNG files component-contained beneath both a canonical artifact root and the canonical repository root; it rejects a symlink in either root or any traversed component, sibling-prefix/path escapes, and any read/decode/OCR error, then asserts enumerated count equals processed count. Temporary-copy canaries cover `artifacts-escape`, a symlinked output root, an inner symlink, safe-first/secret-second images, and malformed PNGs; positive canaries never enter the working tree.
- The exact S1-01 factory/no-op path is compared with a positive normalized declaration/import/identifier/member/call-shape fixture that also pins the exact transitive `Network.persistenceKey` declaration/body. It permits only the required values, inert lifecycle, `Kit`, one dedicated serial queue, subjects, and the exact retained `DispatchSpecificKey<UInt8>` set/get operations; every additional helper/import/callee/member/alias/wrapper fails. Temporary-copy canaries cover `URLSession.shared`, `URLRequest`, `Data(contentsOf:)`, `FileManager.default`, `FileHandle(forUpdatingAtPath:)`, `UserDefaults.standard`, `sqlite3_open`, `Task {}`, `OperationQueue`, `DispatchQueue.global().async`, `Timer.scheduledTimer`, `DispatchSource.makeTimerSource`, an alias, an in-path wrapper, an out-of-path helper, and `Data(contentsOf:)` inserted into `Network.persistenceKey`.
- A second S1-01 positive normalized fixture covers every executable public-value root: `Network.mainnet/stagenet/chainnet`, endpoint-family/policy/configuration initializers, `EndpointPolicy.default`, `Denom.init/rune`, `Address.init`, all transitive validators, Bech32/bit conversion, and every endpoint default expression. An import, identifier/member reference, stored/static initializer body, default expression, call shape, wrapper, or helper outside that closure fails. Seven one-change temporary-copy canaries cover Address I/O/task, endpoint I/O/task, Network static initialization, Denom static initialization, and an out-of-closure default-argument helper; every canary must fail the same positive value gate before the public-only consumer build.
- S1-01 runs the 18 allowlisted XCTest cases with `--parallel --num-workers 1 --xunit-output` under pipefail, requires the Swift process itself to exit zero, and captures the runner transcript. The xUnit parser requires exactly 18 cases and zero failures/errors; the independent transcript parser requires exactly one terminal `passed` status for every allowlisted case and rejects skipped/disabled/failed status. Source/command gates reject `XCTSkip`, `XCTExpectFailure`, conditional/availability disabling, and `--skip`; a temporary `XCTSkip` canary must fail the transcript/status gate even though SwiftPM xUnit cannot encode skips. Method 18 binds `wallet-01\0mainnet\0thorchain-1` to `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`, and the outer mutant harness must fail separator/order source changes.
- S1-01 commits the default BigInt resolution at `5.7.0`/`e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe` while preserving the manifest range from `5.0.0`. A temporary-copy minimum-version gate resolves exact `5.0.0`/`19f5e8a48be155e34abb98a2bcf4a343316f0343` and builds/tests it with strict-concurrency warnings as errors without changing the repository lock.
- Public surface, factory, and value-construction audits are slice-versioned: S1-01 is exact only at S1-01; each S1-02…S1-05 script compares its exact current baseline and cumulatively preserves every earlier declaration as an unchanged subset. S1-02/S1-03 repeat the positive inert factory baseline. S1-04 preserves that exact positive production baseline; its SPI construction fixture starts only at `Core/TestingKitFactory.swift` and pins the exact enumerated `TestingHttpTransportAdapter`, `EndpointPool`, `RequestBuilder`, `LiveThorNodeClient`, `ReadOperationCoordinator`, `KitDependencies`, `Kit`, `TestingKitInstance`, and `Network.persistenceKey` initializer/getter bodies. A separate SPI read fixture pins one `TestingKitInstance.readAccount` → `AccountReading.read` → `TestingAccountReadProjection` path and rejects Kit publication, a second read, or an out-of-closure helper. S1-05 replaces the construction partitions with the approved positive production read/storage/lifecycle composition allowlist while retaining no-auto-start/no-request/no-task construction.
- S1-04's fixture AccountReadController must obtain `TestingKitInstance`, execute exactly one `readAccount()`, and render its balance/existence/height/family projection while `instance.kit` remains at the immutable S1-01 nil/idle/zero/no-account snapshot; fixture request counts and the SPI read syntax gate prevent static-label or unreachable-transport acceptance.
- S1-04's reader actor returns only internal `Sendable` canonical-decimal transport records whose amounts are at most 256 bits; exact `2^256 - 1` passes and `2^256` fails. S1-05 storage accepts/returns only an internal `Sendable` `StorageRecord`, and `LifecycleGate` requires its address and chain ID to exactly match the active Address before reconstructing bounded `BigUInt` plus the frozen public `AccountState` inside the S1-01 facade-dispatcher turn. Different-address, tampered-chain, and cached-`2^256` tests must fail before publication. `Scripts/test-s1-04-s1-05-isolation.sh` compiles the actual sources under Swift-5 complete concurrency warnings-as-errors at the exact BigInt `5.0.0` floor, then separately mutates the actual reader result and storage boundary to `AccountState`; both non-`Sendable` mutants must fail compilation. `@unchecked Sendable` and text-only substitutes are forbidden.
- The committed S1-01 Gimle report contains project labels, commits, and repository-relative paths only; `/Users/`, `/Users/Shared/`, `/private/`, and `file://` fail the documentation gate. Machine-local roots remain only in the external canonical audit.
- The named `verify-s1-01-example-workspace` subgate parses the workspace and asserts exactly `container:iOS Example.xcodeproj` plus `group:..` before the exact-destination build.
- Directly invoked shell scripts have Git mode `100755`, pass `test -x`, and use a valid shell shebang. Non-executable Swift helpers are called through `xcrun swift`.

## S1-02 endpoint-policy gate

Revision 16 adds the following local-first obligations before implementation may be considered complete. They run routinely on the operator MacBook; GitHub-hosted macOS runs them only once through the manual final exact-PR-head gate.

| Behavior | Deterministic evidence |
|---|---|
| S1-01 surface preservation | Compile the unchanged `Network`, `EndpointFamilyDescriptor`, `EndpointPolicy`, `EndpointConfiguration`, and error values through the pool; preserve the S1-01 symbol baseline as an exact subset. |
| Family identity | Three separately retained request results must all equal the expected identity; any observed mixed/foreign value locks the pool even when its sibling request fails and another family is healthy. Missing/duplicate/mismatched result indices cannot erase that fact. |
| Role freshness | Positive independent Cosmos/Comet heights pass; catching-up, nonpositive, cross-role-skewed, fresh-Comet+stale-Cosmos, and best-height-lagging families are stale. |
| Typed deterministic selection | `RoleProbeFailure: Error` and exactly three indexed per-family/role/request outcomes compile under strict concurrency and classify transport, HTTP/`Retry-After`, invalid field, identity, and cancellation; highest verified Comet height wins, ties use original order, and completion permutations preserve the fixed result. |
| Stale-family fallback | A correctly identified stale family may be excluded for another verified family; no remaining family returns distinct `catchingUp` or `staleEndpoint`, never `wrongNetwork`. |
| Probe lifecycle | Concurrent first lease and TTL revalidation coalesce through a waiter registry/shared token; one synchronous cancellation latch shared by `onCancel`, enrollment, and stable-order commit locking makes pre-cancel, registration/completion races, cancel-one, cancel-all, and reset deterministic without sleeps. |
| Health effects | An injected monotonic clock controls TTL and explicit `retryNotBefore`; retryable values only extend eligibility, expiry/TTL interaction is deterministic, and terminal/stale/invalid/cancelled outcomes create no timed health state. `recordFailure` rejects a lease from a stale generation without mutation. |
| Ownership boundary | `EndpointPool` performs no business read or retry. S1-04 alone tests attempt order, backoff, family-at-most-once, exhaustion, and cancellation propagation. |
| Live probe contract | Controlled transport proves exact base-path-preserving node-info/latest-block/status requests, decoder/status/cancellation behavior, and zero `/thorchain`, Midgard, gRPC, business-read, write, broadcast, or retry requests. |
| Diagnostics/UI | `ProviderError` has no actual/raw identity associated value. Hostile path/body/error/chain-ID sentinels are absent from typed diagnostics, logs, xUnit, Example UI, Maestro artifacts, and live JSON; only family/role/request, origin, local expected identity/classification, height/status, and fixed reason codes remain. |
| Example execution | The sole Testing SPI session calls the real pool while production `Kit` stays inert; source/syntax gates reject duplicated classification, static outcomes, or SPI imports outside tests/Example. |
| Slice-exact Maestro | Runner tests prove `s1-01` and `s1-02` each execute exactly one different allowlisted YAML and retain all provenance, containment, JUnit, OCR, and secret canaries. |
| Live separation | Exact schema-v1 keys/types/literals/arithmetic, source/path/head binding, duplicate/unknown-key rejection, and distinct fixture/live roots prevent fixture substitution. The validator recomputes the greatest-Comet-height/configuration-order winner; lower-height selection and later-equal-height-tie mutants must fail. |
| Hosted CI bootstrap/budget | Bootstrap mode compares pre-bootstrap `main` with a two-path CI-policy PR, proving its merge refs have no `pull_request` trigger and its merged commit has no `push` trigger. Exact `event=pull_request&head_sha=<merge-ref-sha>&per_page=1` and `event=push&head_sha=<merge-commit-sha>&per_page=1` API evidence must return HTTP 200 and `total_count == 0`. Steady-state mode proves `workflow_dispatch` only and binds `github.workflow_sha`, `github.sha`, same-repository PR `headRefOid`, `expected_head_sha`, checkout SHA, and run `head_sha` to one product head. A local stale-default-workflow mutant must fail before product verification. The bootstrap PR is recorded separately; Reviewer/QA cite local product outputs and the one final hosted product run. |

The narrow-to-broad command order is:

```bash
swift build
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --filter LiveNodeProbeTests
swift test --filter EndpointPoolTests
swift test --filter EndpointDiagnosticsTests
swift test
Scripts/verify-s1-02.sh
Scripts/verify-s1-02-ci-policy.sh steady-state --ref HEAD
Scripts/test-run-maestro.sh
THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh s1-02
```

The opt-in live command in the S1-02 spec runs locally only after deterministic gates pass. It validates two families and all three identity sources against the exact implementation head. Absence is `UNRUN`, an attempted unavailable/invalid run is nonzero failure, and its sanitized JSON cannot be replaced by fixture evidence.

Before the product branch exists, the separately reviewed bootstrap PR runs `Scripts/verify-s1-02-ci-policy.sh bootstrap --base-ref <pre-bootstrap-main> --candidate-ref <bootstrap-head>` locally. Mutants must fail for every automatic trigger, any third changed path, trigger-unrelated job-command drift, missing dispatch input, mutable checkout, head mismatch, or duplicate `main` suite. After PR creation and every update, retain the current merge-ref SHA and query the workflow-runs API with `event=pull_request`, that exact `head_sha`, and `per_page=1`; after merge, query `event=push` with the exact merge-commit SHA and `per_page=1`. Record filters, UTC observation time, HTTP 200, and the bounded response, and require `total_count == 0` for every tuple.

The steady-state verifier locally mutates the event context so the bootstrap/default-`main` workflow definition is used while checkout still targets the correct product SHA. That mutant must fail on workflow-definition/event-head binding before any product command or verification credit. The sole real dispatch names the same-repository PR head branch; preflight and retained run evidence require `github.workflow_sha == github.sha == headRefOid == expected_head_sha == checkout SHA == run head_sha` and record `github.workflow_ref`.

## Verification order per slice

1. `swift build` / compile of changed target.
2. Narrow new test class.
3. Full ThorChainKit test target.
4. Parsed package topology, import allowlist, generated symbol graph, exact test discovery, strict-concurrency build, and temporary public-only iOS consumer.
5. WalletCore narrow tests for S1-06/S1-07.
6. WalletCore/App build.
7. Maestro deterministic Example flow for the slice.
8. Opt-in live API gate.
9. Unstoppable manual create/import/relaunch/App Status checklist for S1-07.
10. Diff audit confirms that no Maestro/acceptance-only host files were added.
11. Before merge, Reviewer and QA first produce exact local command outputs at the same `headRefOid`; the CTO/operator then dispatches the sole GitHub-hosted macOS gate against that same-repository PR head branch. Before product commands it requires `github.workflow_sha`, `github.sha`, `headRefOid`, and `expected_head_sha` to equal the exact product head; retained checkout and run `head_sha` must match too. Once green, QA and CodeReviewer append attestations citing their unchanged local evidence and its workflow ref/SHA/run URL/status/head SHA. The CTO verifies `mergeStateStatus` is `CLEAN`, the conflict-marker diff scan is empty, and the PR-linked plan exists. Any push invalidates all evidence; merge/push to `main` does not rerun the suite.

## Live evidence record

For a controlled run, record:

- kit/host commit;
- final PR `headRefOid`; Reviewer, QA, and CI records are invalidated by any later push;
- timestamp/timezone;
- endpoint IDs/roles, without credentials;
- local expected chain ID, sanitized match classification, and heights; S1-02 never records an observed raw identity;
- test address class/provenance;
- expected and actual raw RUNE amount;
- create/import/relaunch result;
- Example Maestro flow name, mode (`FIXTURE`/`LIVE`) and JUnit/artifact location;
- the Unstoppable manual-checklist result separately from the Maestro evidence;
- unrun checks and the exact reason; an attempted unavailable live check is failure, not a skip/pass.

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
- The final implementation head has green required checks, `CLEAN` merge state, no conflict markers, a valid plan reference, Paperclip CodeReviewer approval, QA PASS, and a final CodeReviewer pass after the PR body contains QA evidence.
- The S1-01 repository marker contains the real PR number only; after merge, the CTO separately records `mergeCommit.oid`, verifies it is on `origin/main`, and confirms the PR-number marker there.
