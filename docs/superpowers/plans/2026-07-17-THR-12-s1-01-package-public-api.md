# THR-12 — S1-01 Package and Public API Foundation Plan

## Goal

Implement only S1-01: a standalone Swift package with a constructible fail-closed immutable value layer, an inert synchronized `ThorChainKit.Kit` facade, deterministic contract audits, and a local-package `iOS Example` with one fixture-only exact-simulator Maestro gate.

Implementation may begin only after the revised slice spec, this plan, the Gimle report, and a fresh adversarial review are pushed and the explicit revision-bound Paperclip confirmation is accepted.

The cross-slice verification authority remains `docs/specs/sprint-01-foundation/test-plan.md`; its S1-01 iOS floor, publisher replay, lifecycle, protocol-boundary, and Maestro requirements must stay identical to this plan.

## Acceptance Criteria

- Parsed `swift package dump-package` JSON shows exactly one `ThorChainKit` library product, one library target, and one `ThorChainKitTests` target.
- The authoritative 18 `PublicApiTests` methods are staged with their owning implementation, then locked by an exact discovery allowlist after all 18 exist.
- Network chain IDs enforce the pinned CometBFT `1...50` UTF-8-byte bound; `Denom` enforces the pinned Cosmos `3...128`-byte ASCII grammar; finite `TimeInterval` endpoint values and state-model invariants are constructible and validated; `Address` performs strict classic-Bech32 network-bound decoding with structural/canonical and Bech32m rejection coverage.
- Whitespace-only wallet IDs and address/network mismatch fail with stable typed errors; the persistence namespace remains internal; factory construction and lifecycle create no network, storage, timer, or task.
- One lock owns `desiredRunning` and command sequencing; one FIFO dispatcher invokes lifecycle collaborators with that lock released; start/stop are idempotent, running refresh forwards once, stopped refresh no-ops, and a barrier-controlled outer-stop/subscriber-stop reentry cannot deadlock.
- Initial/current-value replay is mandatory and exactly nil/idle/zero/no-account; an absent account rejects every nonempty balance set; S1-01 promises no later snapshot mutation.
- Public source/API contains no seed/private key and no MarketKit, RxSwift, SwiftUI, or WalletCore import; BigUInt-containing types make no unproven `Sendable` claim.
- CI asserts Xcode 26.3 (`17C529`) and Apple Swift 6.2.4, compiles in Swift 5 mode, and promotes complete strict-concurrency warnings to errors.
- A temporary Swift-tools-5.10/iOS-13 public-only consumer builds with the pinned Xcode for generic iOS Simulator.
- The shared Example workspace builds against `group:..` on one exact simulator destination and launches in visibly labeled `FIXTURE` mode.
- `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh` pins Maestro `2.6.1` on Temurin `17.0.19+10`, uses that UDID for boot/build/install/launch/`maestro --device`, resolves every output to one repo-root-absolute artifact tree, and reports JUnit `tests=1`, `failures=0`, `errors=0`, `skipped=0`.
- Command-shim canaries prove device argv, CLI/Java identity, and resolved artifact-path consistency; secret/namespace scanning covers tracked inputs, the separate JUnit report, raw generated artifacts, and Vision-OCR text from every PNG. Canaries run only in a temporary copy.
- Reviewer, QA, and CI cite the same final `headRefOid`; the implementation PR stores only its real PR number in the roadmap marker, and the CTO separately verifies `mergeCommit.oid` on `origin/main` after merge.

## Execution Steps

### 1. Establish executable package topology

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: accepted plan confirmation.
- Affected paths: `Package.swift`, `Sources/ThorChainKit/ThorChainKit.swift`, `Tests/ThorChainKitTests/PublicApiTests.swift`, and the topology subgate in `Scripts/verify-s1-01.sh`.
- Test first: add an independent parsed-manifest topology check and observe its named failure because `Package.swift` is absent.
- Implementation: add `import PackageDescription`, Swift tools 5.10, iOS 13, one `ThorChainKit` library product/target, one test target, only BigInt, and empty compiling source/test shells. Do not add behavioral test bodies or allowlist fixtures yet.
- Acceptance: parsed topology is exact; extra products/targets/dependencies fail the topology gate; `swift build` succeeds without a future-slice stub.
- Check: `swift package dump-package`, the topology subgate, and `swift build`.
- Commit: `test: establish ThorChainKit package contract`.

### 2. Add the complete immutable value layer and methods 1–12

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 1.
- Affected paths: `Models/Network.swift`, `Models/EndpointConfiguration.swift`, `Network/EndpointFamilyDescriptor.swift`, `Network/EndpointPolicy.swift`, `Models/Denom.swift`, `Models/Address.swift`, `Models/AccountState.swift`, `Models/SyncState.swift`, `Models/SyncError.swift`, `Address/AddressError.swift`, `Address/Bech32Codec.swift`, `Address/BitConversion.swift`, and `PublicApiTests.swift`.
- Test first: add only authoritative methods 1–12. Cover `thor/sthor/cthor` plus coin type 931; chain-ID 50-byte acceptance/51-byte rejection with UTF-8 byte counting; denom 3/128-byte acceptance and 2/129-byte, Unicode, non-letter-prefix, whitespace, and unsupported-punctuation rejection; normalized/control-safe endpoint fields; hostless URL and finite-positive seconds rejection; both directions of the AccountState existence invariant including absent-account/nonempty-balances; stable SyncError cases; and table-driven Address structure/canonical/classic-checksum/Bech32m/HRP/padding/payload failures.
- Implementation: add exactly the public signatures and validation in the spec. `TimeInterval` is measured in seconds; `Denom` matches `[A-Za-z][A-Za-z0-9/:._-]{2,127}` and does not conform to `RawRepresentable`; strict `Address.init` performs classic checksum, exact HRP, canonical lowercase re-encoding, strict padding, and exact 20-byte payload checks.
- Acceptance: mainnet is `thorchain-1`/`thor`/`931`; stagenet is `sthor`/`931`; chainnet is `cthor`/`931`; persistence identity includes environment plus exact chain ID; no fake payload, unchecked initializer, probe, HTTP, failover, address/public-payload hashing, or public payload encoder appears. The internal persistence-namespace SHA-256 remains required.
- Check: `swift test --filter PublicApiTests` with exactly methods 1–12 present, plus `swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors`.
- Commit: `feat: add S1-01 public value contracts`.

### 3. Add the inert synchronized facade and methods 13–18

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 2.
- Affected paths: `Sources/ThorChainKit/Core/Kit.swift`, `KitFactory.swift`, `KitDependencies.swift`, and `PublicApiTests.swift`.
- Test first: add only methods 13–18: whitespace-only wallet ID, address/network mismatch, no-work inert factory, both legal overlap orders with exact FIFO lifecycle call counts, a barrier-controlled S1-05-style outer stop whose subscriber reads a getter and reenters stop, mandatory initial current-value replay, and deterministic internal namespace absent from errors/public API.
- Implementation: create one nonrecursive owner lock for snapshots/`desiredRunning`/monotonic command sequence, one internal FIFO dispatcher that invokes collaborators only after that lock is released, internal test dependencies, the internal persistence namespace, current-value initial publishers, and a public factory backed only by `NoOpLifecycle` and the nil/idle/zero snapshot.
- Acceptance: start/stop transition once, repeated calls no-op, overlapping calls match one documented sequential trace and FIFO callback order, every running refresh forwards once, stopped refresh no-ops, the outer-stop/subscriber-stop barrier regression completes without deadlock, and no URL session/storage/task/timer is created.
- Check: `swift test --filter PublicApiTests` with expectation/barrier/call-entry synchronization, explicit assertion that no collaborator runs under the owner lock, and no sleeps.
- Commit: `feat: add inert ThorChainKit facade`.

### 4. Lock the complete public, test, platform, and toolchain surface

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 3.
- Affected paths: `Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt`, `Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt`, `Scripts/verify-s1-01.sh`, `.github/workflows/ci.yml`, and public documentation only as required by the approved gates.
- Test first: after all 18 methods exist, prove that an extra product, forbidden import, extra public symbol, missing/extra test, wrong Xcode/Swift identity, strict-concurrency warning, iOS-16-only public API, and public-consumer use of an internal symbol each fail their own named canary.
- Implementation: canonicalize/compare `dump-package`, generated symbol graph, `swift test list`, imports, and toolchain identity; run the named Swift-5 strict-concurrency command; generate a `mktemp -d` Swift-tools-5.10 package with `.iOS(.v13)` and build it using only public `import ThorChainKit` with `IPHONEOS_DEPLOYMENT_TARGET=13.0 SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.
- Acceptance: all audits are independently named and green; the discovered allowlist is exactly 18; host `swift build` is not an iOS compatibility substitute; no BigUInt-containing `Sendable` or `@unchecked Sendable` declaration exists.
- Check: `Scripts/verify-s1-01.sh` under Xcode 26.3 (`17C529`) / Apple Swift 6.2.4.
- Commit: `test: lock S1-01 public API surface`.

### 5. Add and independently build the fixture-only iOS Example

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 4; an exact simulator UDID for the build check.
- Affected paths: `iOS Example/iOS Example.xcodeproj/`, shared scheme, `.xcworkspace/`, and the minimal `Sources/` files listed in the spec.
- Test first: structure/build assertions fail until the workspace includes `container:iOS Example.xcodeproj` and `group:..` and the exact destination can build the scheme.
- Implementation: add the UIKit diagnostics app using a valid public THOR address and safe `.invalid` fixture endpoints through the public factory; it never starts the kit or exposes an unchecked SPI.
- Acceptance: exact workspace/scheme build, visible `FIXTURE`, canonical address, nil/idle/zero/no-account state, and no mnemonic/key/provider-credential/wallet-ID/internal-namespace output or persistence.
- Check: `THORCHAIN_SIMULATOR_UDID=<exact> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination "platform=iOS Simulator,id=$THORCHAIN_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build`.
- Commit: `feat: add fixture-only iOS Example`.

### 6. Add the guarded exact-UDID Maestro flow and artifact scanner

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 5; exact simulator UDID and Maestro CLI for live execution.
- Affected paths: `.maestro/config.yaml`, `.maestro/flows/00-launch-foundation.yaml`, `Scripts/run-maestro.sh`, `Scripts/test-run-maestro.sh`, `Scripts/scan-s1-01-artifacts.swift`, `.github/workflows/ci.yml`, and ignore rules only for generated artifacts.
- Test first: in a temporary copy, use PATH shims that record `java`/`xcrun`/`xcodebuild`/`maestro` argv and prove failure for wrong Maestro/Temurin identity, a substituted UDID, any non-absolute or outside-root output path, empty/extra manifest entries, zero/mismatched/skipped/error/failure JUnit attributes, raw secret/namespace text, and a rendered PNG canary recognized by Vision OCR.
- Implementation: install/assert Maestro `2.6.1` with `MAESTRO_VERSION=2.6.1` and `actions/setup-java` Temurin `17.0.19+10`; require one UUID and use it for simctl boot/bootstatus/install/launch, the xcodebuild destination, and `maestro --device`; resolve `REPO_ROOT` and pass absolute JUnit/test-output/debug-output paths under `$REPO_ROOT/build/maestro-results`; capture logs; OCR every PNG through `VNRecognizeTextRequest`; scan the separate JUnit, normalized OCR text, and raw artifact/debug trees.
- Acceptance: exactly one fixture flow and one passing/non-skipped JUnit test; the success screenshot is scanned; Maestro's workspace-relative path rules cannot move an artifact outside the asserted root; no unqualified `maestro test` gate and no S1-01 live branch exist.
- Check: `Scripts/test-run-maestro.sh`, then `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh`; unavailable CLI/device is recorded as unrun, never green.
- Commit: `test: add guarded foundation Maestro flow`.

### 7. Prepare one exact-head implementation PR

- [ ] Completion evidence recorded in this plan and the implementation commit.
- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: steps 1–6.
- Affected paths: `docs/roadmap/sprint-01-foundation.md`, PR body, and these plan checkboxes/evidence; the temporary consumer remains outside the repository.
- Test first: roadmap lint rejects `#TBD`, merge/head SHA text, duplicates, and a marker not tied to the real PR number.
- Implementation: open the PR, update the S1-01 row status cell to `✅ Implemented — PR #<real> — <date>`, check off only completed plan steps, push the final head, and run all approved gates against that head.
- Acceptance: local `git rev-parse HEAD` equals `gh pr view <PR> --json headRefOid --jq .headRefOid`; no later push occurs after Reviewer/QA/CI evidence; PR body links this plan and contains `## QA Evidence`.
- Check: spec commands, `git diff --name-only origin/main...HEAD`, roadmap lint, exact head comparison, and required PR checks. Immediately before merge the CTO re-reads Reviewer/QA/CI evidence against that OID; after merge, fetches `origin/main`, proves `git merge-base --is-ancestor <mergeCommit.oid> origin/main`, and reads the PR-number marker from `git show <mergeCommit.oid>:docs/roadmap/sprint-01-foundation.md`.
- Commit: `docs: record S1-01 PR marker`.

## Review and Handoff Sequence

1. ThorChainCodeReviewer performs three fresh read-only architecture/security/verification lanes against this revision.
2. ThorChainCTO resolves every high/critical finding, updates artifacts/state, and requests explicit confirmation bound to the latest Paperclip plan revision.
3. ThorChainSwiftEngineer implements test-first and opens the PR.
4. ThorChainCodeReviewer performs exact-head mechanical review; the architecture reviewer performs adversarial code review.
5. ThorChainQAEngineer independently verifies the same `headRefOid`.
6. ThorChainCTO re-reads Reviewer/QA/CI evidence, verifies exact head and marker, squash-merges, records/verifies `mergeCommit.oid` on `origin/main`, then closes the slice.

No phase may self-review, implement another role's fixes, or bypass the approval wait.
