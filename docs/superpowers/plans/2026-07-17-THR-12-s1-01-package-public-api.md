# THR-12 — S1-01 Package and Public API Foundation Plan

## Goal

Implement only S1-01: a standalone Swift package with a constructible fail-closed immutable value layer, an inert synchronized `ThorChainKit.Kit` facade, deterministic contract audits, and a local-package `iOS Example` with one fixture-only exact-simulator Maestro gate.

Implementation may begin only after the revised slice spec, this plan, the Gimle report, and a fresh adversarial review are pushed and the explicit revision-bound Paperclip confirmation is accepted.

The cross-slice verification authority remains `docs/specs/sprint-01-foundation/test-plan.md`; its S1-01 iOS floor, publisher replay, lifecycle, protocol-boundary, and Maestro requirements must stay identical to this plan.

## Acceptance Criteria

- Parsed `swift package dump-package` JSON shows exactly one `ThorChainKit` library product, one library target, and one `ThorChainKitTests` target.
- The authoritative 18 `PublicApiTests` methods are staged with their owning implementation, then locked by exact discovery, serialized SwiftPM xUnit, and an independent runner-transcript status gate proving all 18 executed once with zero skipped, disabled, failures, or errors.
- Network chain IDs enforce the pinned CometBFT `1...50` UTF-8-byte bound; `Denom` enforces the pinned Cosmos `3...128`-byte ASCII grammar; every endpoint constructor rule is table-covered; `Address` performs strict classic-Bech32 network-bound decoding and maps the known `thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2` vector to exact internal payload `33e56601b755fe1c896da0884b79f38e526d6efc`.
- Whitespace-only wallet IDs and address/network mismatch fail with stable typed errors; the persistence namespace remains internal; an exact positive syntax/callee allowlist proves the factory path creates no network, storage, task, operation/global queue, timer, dispatch source, alias, wrapper, or unaudited helper capability.
- One lock owns `desiredRunning`, sequence reservation, and FIFO append; two bounded admission-probe hooks plus a nonrecursive outer temporary-copy mutant harness prove append atomicity. S1-01 retains its command drain and has no post-construction publication interface; S1-05 owns publication-turn admission, publication pre/post-draining, and the deterministic `P0 → C → P1` regression.
- Initial/current-value replay is mandatory and exactly nil/idle/zero/no-account; an absent account rejects every nonempty balance set; S1-01 promises no later snapshot mutation. The fixed namespace input `wallet-01\0mainnet\0thorchain-1` yields `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`.
- Public source/API contains no seed/private key and no MarketKit, RxSwift, SwiftUI, or WalletCore import; BigUInt-containing types make no unproven `Sendable` claim.
- CI asserts Xcode 26.3 (`17C529`) and Apple Swift 6.2.4, compiles in Swift 5 mode, promotes complete strict-concurrency warnings to errors, requires the committed default BigInt `5.7.0` lock, and separately resolves/builds/tests the declared `5.0.0` floor in a temporary copy.
- A temporary Swift-tools-5.10/iOS-13 public-only consumer builds with the pinned Xcode for generic iOS Simulator.
- The named `verify-s1-01-example-workspace` subgate asserts exactly `container:iOS Example.xcodeproj` plus `group:..`; the shared workspace then builds on one exact simulator destination and launches in visibly labeled `FIXTURE` mode.
- `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh` uses pinned full action commits and a SHA-256-verified Maestro `2.6.1` archive with Temurin `17.0.19+10`, uses that UDID for boot/build/install/launch/`maestro --device`, resolves every output to one repo-root-absolute artifact tree, and reports JUnit `tests=1`, `failures=0`, `errors=0`, `skipped=0`.
- Command-shim canaries prove device argv, CLI/Java identity, immutable artifact provenance, and component-aware canonical artifact containment. OCR recursively processes every regular in-root PNG, rejects a symlink in any root/component, sibling-prefix and path escapes, and any read/decode/OCR error, asserts enumerated equals processed, and fails safe-first/secret-second plus malformed-image canaries.
- S1-01's exact public-symbol and inert-factory gates are slice-versioned; the owning S1-02…S1-05 specs define exact current baselines, cumulative prior subsets, and explicit capability transitions. The committed Gimle report contains no operator-local absolute root.
- Reviewer, QA, and required checks cite the same final `headRefOid`; the implementation PR stores only its real PR number in the roadmap marker. Merge requires green checks, `CLEAN` state, an empty conflict-marker scan, a valid plan reference, Paperclip approvals, and a final reviewer pass after QA evidence reaches the PR body; the CTO separately verifies `mergeCommit.oid` on `origin/main` after merge.

## Execution Steps

### 1. Establish executable package topology

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: accepted plan confirmation.
- Affected paths: `Package.swift`, `Package.resolved`, `Sources/ThorChainKit/ThorChainKit.swift`, `Tests/ThorChainKitTests/PublicApiTests.swift`, `Scripts/verify-bigint-floor.sh`, and the topology/dependency subgates in `Scripts/verify-s1-01.sh`.
- Test first: add an independent parsed-manifest topology check and observe its named failure because `Package.swift` is absent.
- Implementation: add `import PackageDescription`, Swift tools 5.10, iOS 13, one `ThorChainKit` library product/target, one test target, only the BigInt range from `5.0.0`, the committed default lock at `5.7.0`/`e07e00fa…`, and empty compiling source/test shells. Add the isolated floor script; do not add behavioral test bodies or allowlist fixtures yet.
- Acceptance: parsed topology is exact; extra products/targets/dependencies fail the topology gate; default resolution matches the committed `5.7.0` lock; the temporary-copy floor gate resolves exact `5.0.0`/`19f5e8a4…` and builds/tests it without changing that lock.
- Check: `swift package dump-package`, the topology/default-lock subgate, `swift build`, and `Scripts/verify-bigint-floor.sh`.
- Commit: `test: establish ThorChainKit package contract`.

### 2. Add the complete immutable value layer and methods 1–12

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 1.
- Affected paths: `Models/Network.swift`, `Models/EndpointConfiguration.swift`, `Network/EndpointFamilyDescriptor.swift`, `Network/EndpointPolicy.swift`, `Models/Denom.swift`, `Models/Address.swift`, `Models/AccountState.swift`, `Models/SyncState.swift`, `Models/SyncError.swift`, `Core/KitConfigurationError.swift`, `Address/AddressError.swift`, `Address/Bech32Codec.swift`, `Address/BitConversion.swift`, and `PublicApiTests.swift`.
- Test first: add only authoritative methods 1–12. Cover `thor/sthor/cthor` plus coin type 931; chain-ID 50-byte acceptance/51-byte rejection; denom grammar bounds; every endpoint rule (nonempty families, `https`, no credentials/query/fragment, normalized unique family IDs, separate `clientId` trim/control/empty-to-nil normalization, lag/retry finiteness and sign, retry subset, page count, per-family attempts, and effective attempts); both directions of the AccountState invariant; stable SyncError cases; table-driven Address structure/canonical/classic-checksum/Bech32m/HRP/padding/payload failures; and the exact known-answer address-to-20-byte-payload vector under `@testable`.
- Implementation: add exactly the public signatures and validation in the spec. `TimeInterval` is measured in seconds; `Denom` matches `[A-Za-z][A-Za-z0-9/:._-]{2,127}` and does not conform to `RawRepresentable`; strict `Address.init` performs classic checksum, exact HRP, canonical lowercase re-encoding, strict padding, and exact 20-byte payload checks.
- Acceptance: mainnet is `thorchain-1`/`thor`/`931`; stagenet is `sthor`/`931`; chainnet is `cthor`/`931`; persistence identity includes environment plus exact chain ID; every endpoint boundary and the known payload vector pass; no fake payload, unchecked initializer, probe, HTTP, failover, address/public-payload hashing, or public payload encoder appears. The internal persistence-namespace SHA-256 remains required.
- Check: `swift test --filter PublicApiTests` with exactly methods 1–12 present, plus `swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`.
- Commit: `feat: add S1-01 public value contracts`.

### 3. Add the inert synchronized facade and methods 13–18

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 2.
- Affected paths: `Sources/ThorChainKit/Core/Kit.swift`, `KitFactory.swift`, `KitDependencies.swift`, `Tests/ThorChainKitTests/PublicApiTests.swift`, and `Scripts/test-s1-01-mutants.sh`.
- Test first: add only methods 13–18: whitespace-only wallet ID, address/network mismatch, no-work factory behavior, both legal overlap orders, both admission-probe hooks, collaborator-context effective reentry for start/stop/refresh, mandatory replay, namespace absence, and the fixed namespace known answer. The first probe hook only emits a nonblocking signal under the owner lock; the second hook performs the post-append/unlock barrier wait. Add the nonrecursive outer harness that baseline-passes method 16, applies exactly one guarded post-unlock/pre-append source mutation in a temporary copy, directly reruns method 16, and requires failure. The same harness owns direct method-18 separator/order mutants.
- Implementation: create one nonrecursive owner lock for snapshots/`desiredRunning`/sequence-and-append and one internal FIFO facade dispatcher. A collaborator-context effective call appends and returns so the active drain can continue. Add only internal test dependencies/the bounded two-hook admission probe, the namespace, current-value publishers, and a factory backed by `NoOpLifecycle` plus the nil/idle/zero snapshot. S1-01 retains its command FIFO drain. Add no post-construction publication interface, publication-turn admission, or publication pre/post-draining; S1-05 owns only those deferred publication contracts.
- Acceptance: start/stop transition once, repeated calls are filtered before the bridge, running refresh forwards once, stopped refresh no-ops, append cannot separate from reservation under the executable mutant, no publisher/subscriber or lifecycle collaborator callback runs under the lock, the first probe cannot block/reenter/wait, the namespace known answer is exact, and the factory behavior remains inert.
- Check: `swift test --filter PublicApiTests` with expectation/barrier/call-entry synchronization, explicit assertion that no publisher/subscriber or lifecycle collaborator callback runs under the owner lock, the bounded first-probe-hook assertion, and no sleeps; then `Scripts/test-s1-01-mutants.sh`.
- Commit: `feat: add inert ThorChainKit facade`.

### 4. Lock the complete public, test, platform, and toolchain surface

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 3.
- Affected paths: `Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt`, `Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt`, `Tests/ThorChainKitTests/Fixtures/S1-01-factory-syntax.txt`, `Scripts/verify-s1-01.sh`, `Scripts/verify-s1-01-factory.swift`, `Scripts/verify-s1-01-xunit.swift`, `.github/workflows/ci.yml`, and public documentation only as required by the approved gates.
- Test first: after all 18 methods exist, prove that an extra product, forbidden import, extra public symbol, missing/extra test, `XCTSkip`, `XCTExpectFailure`, conditional/availability disabling, wrong Xcode/Swift identity, strict-concurrency warning, iOS-16-only public API, public-consumer use of an internal symbol, and every factory syntax/callee addition fail their named gates. Factory mutants cover `Data(contentsOf:)`, `FileManager.default`, `OperationQueue`, `DispatchQueue.global().async`, the prior capability categories, an alias, a wrapper inside an allowed file, and an out-of-path helper.
- Implementation: canonicalize/compare `dump-package`, generated symbol graph, `swift test list`, imports, toolchain identity, and the exact factory declarations/imports/identifier/member/call shapes. Run filtered XCTest with `--parallel --num-workers 1 --xunit-output` under pipefail, require the Swift process itself to exit zero, capture its transcript, require exactly 18 xUnit cases with zero failures/errors plus exactly one terminal `passed` transcript status per allowlisted name, and reject source/command disabling constructs. Run the named Swift-5 strict-concurrency command; generate a `mktemp -d` Swift-tools-5.10 package with `.iOS(.v13)` and build it using only public `import ThorChainKit` with `IPHONEOS_DEPLOYMENT_TARGET=13.0 SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.
- Acceptance: all audits are independently named and green; the discovered and executed allowlists are exactly 18 with no skipped/disabled case; the `XCTSkip` canary fails the transcript/status gate despite xUnit's schema; the positive factory fixture rejects every extra shape; host `swift build` is not an iOS compatibility substitute; no BigUInt-containing `Sendable` or `@unchecked Sendable` declaration exists. The committed Gimle report passes its operator-path rejection gate, and later-slice exact/subset/capability transitions remain named in S1-02…S1-05.
- Check: `Scripts/verify-s1-01.sh` under Xcode 26.3 (`17C529`) / Apple Swift 6.2.4.
- Commit: `test: lock S1-01 public API surface`.

### 5. Add and independently build the fixture-only iOS Example

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 4; an exact simulator UDID for the build check.
- Affected paths: `iOS Example/iOS Example.xcodeproj/`, shared scheme, `.xcworkspace/`, and the minimal `Sources/` files listed in the spec.
- Test first: the named executable `verify-s1-01-example-workspace` subgate fails until the workspace contains exactly `container:iOS Example.xcodeproj` and `group:..`; the exact destination build then fails until the scheme is complete.
- Implementation: add the UIKit diagnostics app using a valid public THOR address and safe `.invalid` fixture endpoints through the public factory; it never starts the kit or exposes an unchecked SPI.
- Acceptance: exact workspace/scheme build, visible `FIXTURE`, canonical address, nil/idle/zero/no-account state, and no mnemonic/key/provider-credential/wallet-ID/internal-namespace output or persistence.
- Check: `THORCHAIN_SIMULATOR_UDID=<exact> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination "platform=iOS Simulator,id=$THORCHAIN_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build`.
- Commit: `feat: add fixture-only iOS Example`.

### 6. Add the guarded exact-UDID Maestro flow and artifact scanner

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 5; exact simulator UDID and Maestro CLI for live execution.
- Affected paths: `.maestro/config.yaml`, `.maestro/flows/00-launch-foundation.yaml`, `Scripts/run-maestro.sh`, `Scripts/test-run-maestro.sh`, `Scripts/scan-s1-01-artifacts.swift`, `.github/workflows/ci.yml`, and ignore rules only for generated artifacts.
- Test first: in a temporary copy, record `java`/`xcrun`/`xcodebuild`/`maestro` argv and prove failure for changed action/archive provenance, wrong Maestro/Temurin identity, a substituted UDID, outside-root output, the `artifacts-escape` sibling-prefix mutant, a symlinked output root, bad manifest/JUnit, raw secret/namespace text, an inner symlink/path escape, unreadable or malformed PNG, processed-count mismatch, and a safe-first/secret-second OCR set.
- Implementation: pin `actions/checkout` to `34e114876b0b11c390a56381ad16ebd13914f8d5`, `actions/setup-java` to `c1e323688fd81a25caa38c78aa6df2d33d3e20d9`, and Maestro `2.6.1` `maestro.zip` to official SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`; require one UDID and root-absolute output paths. Canonicalize the repository root and each artifact root, use component-aware containment beneath both, and reject symlinks in either root or any traversed component. OCR recursively enumerates only regular in-root PNGs, fails read/decode/OCR errors, and asserts enumerated equals processed.
- Acceptance: immutable provenance verifies before execution; exactly one fixture flow and one passing/non-skipped JUnit test; every regular in-root PNG including the success screenshot is processed; any skipped/malformed/escaped artifact fails; no unqualified `maestro test` gate and no S1-01 live branch exist.
- Check: `Scripts/test-run-maestro.sh`, then `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh`; unavailable CLI/device is recorded as unrun, never green.
- Commit: `test: add guarded foundation Maestro flow`.

### 7. Prepare one exact-head implementation PR

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: steps 1–6.
- Affected paths: `docs/roadmap/sprint-01-foundation.md`, PR body, and these plan checkboxes/evidence; the temporary consumer remains outside the repository.
- Test first: roadmap lint rejects `#TBD`, merge/head SHA text, duplicates, and a marker not tied to the real PR number.
- Implementation: open the PR, update the S1-01 row status cell to `✅ Implemented — PR #<real> — <date>`, check off only completed plan steps, push the final head, and run all approved gates against that head.
- Acceptance: local `git rev-parse HEAD` equals the PR `headRefOid`; required checks are green; merge state is `CLEAN` and neither `BEHIND` nor `DIRTY`; the conflict-marker scan is empty; the PR-linked plan exists; Paperclip CR approval and QA PASS cite that head; the PR body contains `## QA Evidence`; and a final reviewer pass occurs after that body update.
- Check: spec commands, scope diff, roadmap lint, exact head comparison, `gh pr checks <PR>`, `gh pr view <PR> --json mergeStateStatus`, `gh pr diff <PR> | grep -E '^[+-]?(<<<<<<<|=======|>>>>>>>)'`, branch plan existence, and Paperclip evidence. After merge, prove `mergeCommit.oid` is on `origin/main` and read the marker from that commit.
- Commit: `docs: record S1-01 PR marker`.

## Review and Handoff Sequence

1. ThorChainCodeReviewer performs three fresh read-only architecture/security/verification lanes against this revision.
2. ThorChainCTO resolves every high/critical finding, updates artifacts/state, and requests explicit confirmation bound to the latest Paperclip plan revision.
3. ThorChainSwiftEngineer implements test-first and opens the PR.
4. ThorChainCodeReviewer performs exact-head mechanical review; the architecture reviewer performs adversarial code review.
5. ThorChainQAEngineer independently verifies the same `headRefOid`, and the engineer copies concrete QA evidence into the PR body without changing that head.
6. ThorChainCodeReviewer performs the final exact-head pass after the QA-evidence body update.
7. ThorChainCTO re-reads Reviewer/QA/CI evidence, verifies all merge-readiness gates and the marker, squash-merges, records/verifies `mergeCommit.oid` on `origin/main`, then closes the slice.

No phase may self-review, implement another role's fixes, or bypass the approval wait.
