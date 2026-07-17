# THR-12 — S1-01 Package and Public API Foundation Plan

## Goal

Implement only S1-01: a standalone Swift package with a constructible fail-closed immutable value layer, an inert synchronized `ThorChainKit.Kit` facade, deterministic contract audits, and a local-package `iOS Example` with one fixture-only exact-simulator Maestro gate.

Implementation may begin only after the revised slice spec, this plan, the Gimle report, and a fresh adversarial review are pushed and the explicit revision-bound Paperclip confirmation is accepted.

## Acceptance Criteria

- Parsed `swift package dump-package` JSON shows exactly one `ThorChainKit` library product, one library target, and one `ThorChainKitTests` target.
- The exact 18-method `PublicApiTests` allowlist is discovered and green; manifest, import, symbol-graph, discovery, and external-consumer audits run as separate executable gates.
- Network/endpoint/denom values are publicly constructible and validated; `Address` performs strict classic-Bech32 network-bound decoding with no unchecked fixture path.
- Whitespace-only wallet IDs and address/network mismatch fail with stable typed errors; factory construction performs no lifecycle work.
- One synchronized owner linearizes lifecycle calls; start/stop are idempotent, running refresh forwards once per call, stopped refresh is a no-op, and initial/replayed state is exactly nil/idle/zero/no-account.
- Public source/API contains no seed/private key and no MarketKit, RxSwift, SwiftUI, or WalletCore import; BigUInt-containing types make no unproven `Sendable` claim under Swift 5.10.
- The shared Example workspace builds against `group:..`, constructs only public validated values, and launches in visibly labeled `FIXTURE` mode without live-test behavior.
- `THORCHAIN_SIMULATOR_UDID=<exact> Scripts/run-maestro.sh` is the sole UI gate and reports JUnit `tests=1`, `failures=0`, `errors=0`, `skipped=0` on the same boot/build/install/launch device.
- Secret/namespace scanning covers tracked inputs and generated logs/JUnit/screenshots; its positive canary runs only in a temporary copy.
- A temporary Swift-tools-5.10/iOS-17 local-package consumer using only public `import ThorChainKit` builds with `xcodebuild` for generic iOS Simulator.
- Reviewer, QA, and CI cite the same final `headRefOid`; the implementation PR stores only its real PR number in the roadmap marker, and the CTO separately verifies `mergeCommit.oid` on `origin/main` after merge.

## Execution Steps

### 1. Establish package topology and failing contract gates

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: accepted plan confirmation.
- Affected paths: `Package.swift`, `Tests/ThorChainKitTests/PublicApiTests.swift`, `Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt`, `Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt`, `Scripts/verify-s1-01.sh`.
- Test first: add the exact behavioral test/discovery allowlist plus manifest/import/symbol/consumer canaries and observe failure because no package exists.
- Implementation: add `import PackageDescription`, Swift tools 5.10, iOS 13, one `ThorChainKit` library product/target, one test target, and only BigInt.
- Acceptance: parsed topology is exact; extra products/targets/imports/symbols/tests fail their own named gates.
- Check: `swift package dump-package` JSON assertions, `swift build`, and the initially failing `Scripts/verify-s1-01.sh` subgates.
- Commit: `test: establish ThorChainKit package contract`.

### 2. Add the complete immutable public value layer

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 1.
- Affected paths: `Models/Network.swift`, `Models/EndpointConfiguration.swift`, `Network/EndpointFamilyDescriptor.swift`, `Network/EndpointPolicy.swift`, `Models/Denom.swift`, `Models/Address.swift`, `Address/AddressError.swift`, `Address/Bech32Codec.swift`, `Address/BitConversion.swift`, and `PublicApiTests.swift`.
- Test first: methods 1–12 from the authoritative list, including invalid endpoint bounds and valid/invalid external THOR address fixtures.
- Implementation: add exactly the public signatures and validation in the spec; strict `Address.init` performs classic checksum, mixed-case, exact HRP, canonical lowercase, strict padding/re-encode, and exact 20-byte payload checks.
- Acceptance: mainnet is `thorchain-1`/`thor`/`931`; persistence identity includes environment plus exact chain ID; no fake payload, unchecked initializer, probe, HTTP, failover, hashing, or public payload encoder appears.
- Check: `swift test --filter PublicApiTests` for methods 1–12 plus strict-concurrency compile of the value layer.
- Commit: `feat: add S1-01 public value contracts`.

### 3. Add the inert synchronized Kit facade

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 2.
- Affected paths: `Sources/ThorChainKit/Core/Kit.swift`, `KitFactory.swift`, `KitDependencies.swift`, and `PublicApiTests.swift`.
- Test first: methods 13–18, including whitespace-only ID, address/network mismatch, inert factory, concurrent lifecycle ordering/call counts, immediate optional publisher replay, and namespace-safe errors.
- Implementation: create one synchronized lifecycle/snapshot owner, internal injected dependencies, exact `uniqueId`, optional current-value publishers, and public factory without auto-start.
- Acceptance: start/stop transition once, repeated/concurrent transitions no-op, every running refresh forwards once, stopped refresh no-ops, and initial getters/publishers are nil/idle/zero/no-account.
- Check: `swift test --filter PublicApiTests` with expectation/barrier synchronization and no sleeps.
- Commit: `feat: add inert ThorChainKit facade`.

### 4. Lock the public and toolchain surface

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 3.
- Affected paths: public documentation, both allowlist fixtures, and `Scripts/verify-s1-01.sh` only as required by the approved gates.
- Test first: prove that a temporary extra product, forbidden import, extra public symbol, missing/extra test, and public-consumer use of an internal symbol each fail the corresponding gate.
- Implementation: canonicalize/compare `dump-package`, generated symbol graph, `swift test list`, and imports; generate a temporary Swift-tools-5.10/iOS-17 public-only local-package consumer and build it with `xcodebuild -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`.
- Acceptance: all contract audits are independently named and green; host `swift build` is not used as an iOS compatibility substitute; no BigUInt-containing `Sendable` or `@unchecked Sendable` declaration exists.
- Check: `Scripts/verify-s1-01.sh`.
- Commit: `test: lock S1-01 public API surface`.

### 5. Add the local-package fixture-only iOS Example

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 4.
- Affected paths: `iOS Example/iOS Example.xcodeproj/`, shared scheme, `.xcworkspace/`, and the minimal `Sources/` files listed in the spec.
- Test first: structure/build assertion fails until the workspace includes `container:iOS Example.xcodeproj` and `group:..`.
- Implementation: add the UIKit diagnostics app using a valid public THOR address and safe `.invalid` fixture endpoints through the public factory; it never starts the kit or exposes an unchecked SPI.
- Acceptance: exact workspace/scheme build, visible `FIXTURE`, canonical address, nil/idle/zero/no-account state, and no mnemonic/key/provider-credential/wallet-ID/unique-ID output or persistence.
- Check: the build step inside the exact-UDID runner; no independent ambiguous simulator command.
- Commit: `feat: add fixture-only iOS Example`.

### 6. Add the guarded exact-UDID Maestro flow

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 5; exact simulator UDID and Maestro CLI for live execution.
- Affected paths: `.maestro/config.yaml`, `.maestro/flows/00-launch-foundation.yaml`, `Scripts/run-maestro.sh`, scanner/test helper, and ignore rules only if generated artifacts require them.
- Test first: in a temporary copy only, prove failure for empty/extra manifest entries, zero/mismatched/skipped/error/failure JUnit attributes, missing/different UDID use, and a secret/namespace canary.
- Implementation: require `THORCHAIN_SIMULATOR_UDID`, use it for boot/build/install/launch/Maestro, emit artifacts under `build/maestro-results`, and scan tracked inputs plus logs/JUnit/screenshots.
- Acceptance: exactly one fixture flow and one passing/non-skipped JUnit test; no raw `maestro test` gate and no S1-01 live branch.
- Check: `THORCHAIN_SIMULATOR_UDID=<exact-udid> Scripts/run-maestro.sh`; unavailable CLI/device is recorded as unrun, never green.
- Commit: `test: add guarded foundation Maestro flow`.

### 7. Prepare one exact-head implementation PR

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: steps 1–6.
- Affected paths: `docs/roadmap/sprint-01-foundation.md`, PR body, and plan checkboxes/evidence; temporary consumer remains outside the repository.
- Test first: roadmap lint rejects `#TBD`, merge/head SHA text, duplicates, and a marker not tied to the real PR number.
- Implementation: open the PR, update the S1-01 row status cell to `✅ Implemented — PR #<real> — <date>`, push the final head, and run all approved gates against that head.
- Acceptance: no later push after Reviewer/QA/CI evidence; no roadmap-only follow-up or direct push; PR body links this plan and contains `## QA Evidence`.
- Check: spec commands, `git diff --name-only origin/main...HEAD`, roadmap lint, `gh pr view --json headRefOid`, and required PR checks.
- Commit: `docs: record S1-01 PR marker`.

## Review and Handoff Sequence

1. ThorChainCodeReviewer performs three fresh read-only architecture/security/verification lanes against this revision.
2. ThorChainCTO resolves every high/critical finding, updates artifacts/state, and requests explicit confirmation bound to the latest Paperclip plan revision.
3. ThorChainSwiftEngineer implements test-first and opens the PR.
4. ThorChainCodeReviewer performs exact-head mechanical review; the architecture reviewer performs adversarial code review.
5. ThorChainQAEngineer independently verifies the same `headRefOid`.
6. ThorChainCTO verifies approval, QA, CI, exact head, and PR marker; squash-merges; records/verifies `mergeCommit.oid` on `origin/main`; then closes the slice.

No phase may self-review, implement another role's fixes, or bypass the approval wait.
