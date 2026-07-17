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
| Contract audit | default CI | parsed manifest topology, import allowlist, public symbol allowlist, exact test discovery, and public-only iOS consumer |
| WalletCore integration | host branch CI | manager/adapter/factory/consumer lifecycle |
| Example UI acceptance | default fixture CI via Maestro | public user-visible state, accessibility contract, cross-slice scenario |
| Opt-in live | manual/release gate | current endpoint/API compatibility and chain identity |
| Host product acceptance | manual `Development` checklist | observable create/import/enable/receive/relaunch/App Status behavior without Maestro |

## Traceability matrix

| Criterion | Unit/controlled | Integration/live |
|---|---|---|
| Package API isolated from host | exact 18-method PublicApiTests list + mandatory current-value publisher replay | parsed manifest/import/symbol/discovery gates + temporary public-only Swift 5.10/iOS 13 `xcodebuild` consumer |
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
- lifecycle sequence assignment and FIFO append becoming separable so a later sequence can overtake an earlier one, including the former post-unlock/pre-append gap;
- an S1-05 competing publication `P1` entering after lifecycle command `C` is admitted by synchronous subscriber delivery during `P0` but before `P0` drains `C`;
- public factory/no-op composition creating a URL session/request, storage/file/database handle, task, timer, dispatch source, or unaudited helper capability;
- offline cold/relaunch with cached state;
- wrong HRP/checksum/mixed-case/address payload length;
- MarketKit metadata unavailable on reconstruction.

## Determinism rules

- Inject transport, node probe, clock, sleeper, storage and lifecycle dependencies.
- Fixed `sleep` delays are prohibited.
- Async tests wait on continuations/expectations tied to observed events.
- S1-01 is the sole `desiredRunning`/idempotence owner. It assigns a sequence and appends the effective command to its pending FIFO in the same owner-lock critical section, then invokes collaborators on the shared facade dispatcher with that lock released. S1-05's bridge preserves accepted actor-command order but owns no duplicate desired-running filter.
- S1-01's internal admission probe lets command 0 emit a bounded nonblocking signal after sequence reservation and before append while the owner lock remains held; that hook cannot reenter `Kit`, block, or wait across threads. The same test blocks only at the second hook after append and owner-lock release. `Scripts/test-s1-01-mutants.sh` baseline-runs method 16, applies exactly one guarded append-after-second-hook mutation in a temporary copy, and directly reruns only method 16 without recursively invoking the full verifier; correct code proves `0, 1`, the mutant fails, and no sleep is permitted.
- S1-01 has no post-construction publication interface. Its completion tests cover three ordinary effective calls plus three collaborator-context dispatcher reentries. S1-05 owns atomic publication-turn admission: one admitted turn drains existing commands, delivers synchronously, and post-drains reentrant commands before another turn may enter. Its barrier test blocks `P0`, admits `C`, attempts `P1`, and proves exact `P0 → C → P1` order without sleeps.
- S1-01 endpoint tests enumerate every constructor rule: nonempty families, `https`, no credentials/query/fragment, normalized nonempty unique family IDs, separate `clientId` trim/control/empty-to-nil normalization, finite nonnegative lag, finite positive timeout/revalidation seconds, retryable-status subset, `1...1000` page count, explicit attempts in `1...families.count`, nil attempts, and the exact `effectiveMaximumAttempts` result.
- Retry count and requested URLs assert exact sequence.
- Random/property tests log seed on failure.
- Network live tests excluded from default CI and never make deterministic suite flaky.
- Maestro selectors use accessibility identifiers, not localized labels or screen coordinates.
- Committed Maestro YAML contains no mnemonic, API key or endpoint credential; runtime values arrive via environment.
- Fixture and live modes expose an explicit `data-source` badge so fixture success cannot masquerade as live evidence.
- S1-01's sole UI gate is `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh`; raw `maestro test` is not accepted. Boot, build, install, launch, and Maestro use that same UDID.
- S1-01 default CI pins `actions/checkout` to `34e114876b0b11c390a56381ad16ebd13914f8d5`, `actions/setup-java` to `c1e323688fd81a25caa38c78aa6df2d33d3e20d9`, and the Maestro `2.6.1` `maestro.zip` artifact to official SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`. It asserts Maestro `2.6.1` and Temurin `17.0.19+10` before the fixture flow.
- S1-01 resolves JUnit, test-output, and debug-output to absolute paths under one repository-root `build/maestro-results` tree. The runner and shims reject workspace-relative or outside-root artifacts, and the scanner covers the separate JUnit file plus both Maestro output trees.
- The S1-01 launcher requires one configured flow and JUnit `tests=1`, `failures=0`, `errors=0`, and `skipped=0`; detecting zero, extra, failed, errored, or skipped tests fails the gate.
- All Maestro rules apply only to `ThorChainKit/iOS Example`; the Unstoppable repository receives no Maestro YAML, runner, DEBUG transport, or acceptance launch arguments.
- Tracked inputs and generated logs/JUnit/screenshots pass a secret and namespace scan before publication. OCR recursively enumerates only regular PNG files component-contained beneath both a canonical artifact root and the canonical repository root; it rejects a symlink in either root or any traversed component, sibling-prefix/path escapes, and any read/decode/OCR error, then asserts enumerated count equals processed count. Temporary-copy canaries cover `artifacts-escape`, a symlinked output root, an inner symlink, safe-first/secret-second images, and malformed PNGs; positive canaries never enter the working tree.
- The exact S1-01 factory/no-op path is compared with a positive normalized declaration/import/identifier/member/call-shape fixture. It permits only the required values, inert lifecycle, `Kit`, dedicated serial queue, owner lock, and subjects; every additional helper/import/callee/member/alias/wrapper fails. Temporary-copy canaries cover `URLSession.shared`, `URLRequest`, `Data(contentsOf:)`, `FileManager.default`, `FileHandle(forUpdatingAtPath:)`, `UserDefaults.standard`, `sqlite3_open`, `Task {}`, `OperationQueue`, `DispatchQueue.global().async`, `Timer.scheduledTimer`, `DispatchSource.makeTimerSource`, an alias, an in-path wrapper, and an out-of-path helper.
- S1-01 runs the 18 allowlisted XCTest cases with `--parallel --num-workers 1 --xunit-output` under pipefail, requires the Swift process itself to exit zero, and captures the runner transcript. The xUnit parser requires exactly 18 cases and zero failures/errors; the independent transcript parser requires exactly one terminal `passed` status for every allowlisted case and rejects skipped/disabled/failed status. Source/command gates reject `XCTSkip`, `XCTExpectFailure`, conditional/availability disabling, and `--skip`; a temporary `XCTSkip` canary must fail the transcript/status gate even though SwiftPM xUnit cannot encode skips. Method 18 binds `wallet-01\0mainnet\0thorchain-1` to `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`, and the outer mutant harness must fail separator/order source changes.
- S1-01 commits the default BigInt resolution at `5.7.0`/`e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe` while preserving the manifest range from `5.0.0`. A temporary-copy minimum-version gate resolves exact `5.0.0`/`19f5e8a48be155e34abb98a2bcf4a343316f0343` and builds/tests it with strict-concurrency warnings as errors without changing the repository lock.
- Public surface and factory audits are slice-versioned: S1-01 is exact only at S1-01; each S1-02…S1-05 script compares its exact current baseline and cumulatively preserves every earlier declaration as an unchanged subset. S1-02/S1-03 repeat the inert factory audit, S1-04 splits production-inert from enumerated `_spi(Testing)` fixture composition, and S1-05 replaces it with the approved production read/storage/lifecycle composition allowlist while retaining no-auto-start/no-request/no-task construction.
- The committed S1-01 Gimle report contains project labels, commits, and repository-relative paths only; `/Users/`, `/Users/Shared/`, `/private/`, and `file://` fail the documentation gate. Machine-local roots remain only in the external canonical audit.
- The named `verify-s1-01-example-workspace` subgate parses the workspace and asserts exactly `container:iOS Example.xcodeproj` plus `group:..` before the exact-destination build.
- Directly invoked shell scripts have Git mode `100755`, pass `test -x`, and use a valid shell shebang. Non-executable Swift helpers are called through `xcrun swift`.

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
11. Before merge, `gh pr checks <PR>` is green, `mergeStateStatus` is `CLEAN`, the conflict-marker diff scan is empty, the PR-linked plan exists on the branch, and Paperclip Reviewer and QA evidence cite the exact final head. After QA evidence is copied into the PR body, the CodeReviewer performs one final exact-head pass.

## Live evidence record

For a controlled run, record:

- kit/host commit;
- final PR `headRefOid`; Reviewer, QA, and CI records are invalidated by any later push;
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
- The final implementation head has green required checks, `CLEAN` merge state, no conflict markers, a valid plan reference, Paperclip CodeReviewer approval, QA PASS, and a final CodeReviewer pass after the PR body contains QA evidence.
- The S1-01 repository marker contains the real PR number only; after merge, the CTO separately records `mergeCommit.oid`, verifies it is on `origin/main`, and confirms the PR-number marker there.
