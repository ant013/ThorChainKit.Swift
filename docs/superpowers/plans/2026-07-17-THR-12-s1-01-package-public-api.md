# THR-12 — S1-01 Package and Public API Foundation Plan

## Goal

Implement only S1-01: a minimal standalone Swift package, inert public `ThorChainKit.Kit` facade, deterministic contract tests, and a local-package `iOS Example` with one fixture-only Maestro launch gate.

Implementation may begin only after the slice spec, this plan, the Gimle report, and the adversarial review are pushed and the explicit Paperclip confirmation is accepted.

## Acceptance Criteria

- `swift package dump-package` shows exactly one `ThorChainKit` library product and one `ThorChainKitTests` target.
- All seven `PublicApiTests` in the slice spec pass.
- Empty wallet IDs fail; factory construction does not start lifecycle work; initial state is idle/zero with no fabricated account.
- Public source/API contains no seed/private key and no MarketKit, RxSwift, SwiftUI, or WalletCore import.
- The shared Example workspace builds against `group:..` and launches in visibly labeled `FIXTURE` mode.
- The Maestro runner rejects an empty manifest or zero/mismatched JUnit case count and emits no committed/runtime secret material.
- The temporary Swift 5.10/iOS 17 WalletCore consumer compiles.
- Reviewer, QA, CI, exact-head, approval, and roadmap-marker gates are satisfied before CTO merge.

## Unresolved Preconditions

The adversarial review must resolve two questions in the spec before approval:

1. public `Address` construction versus the S1-03 codec boundary;
2. a mechanically possible replacement for the unknowable pre-merge squash SHA marker.

## Execution Steps

### 1. Establish package topology

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: accepted plan confirmation; resolved Address/marker rulings.
- Affected paths: `Package.swift`, `Tests/ThorChainKitTests/PublicApiTests.swift`, the minimum source files needed to compile the test target.
- Test first: add the manifest/product and compile/link assertions; observe failure because the package/product does not exist.
- Implementation: add one `ThorChainKit` library product/target, one test target, Swift 5.10, iOS 13, and only BigInt.
- Acceptance: `swift package dump-package` reports one product and the named targets; no S1-02+ file exists.
- Check: `swift package dump-package && swift build`.
- Commit: `test: establish ThorChainKit package contract`.

### 2. Add immutable public models

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 1; resolved Address ruling.
- Affected paths: `Sources/ThorChainKit/Models/Network.swift`, `Address.swift`, `SyncState.swift`, `SyncError.swift`, `AccountState.swift`, `Denom.swift`, `EndpointConfiguration.swift`; `PublicApiTests.swift`.
- Test first: add mainnet constants, initial-state value, and configuration-invalid cases from the spec.
- Implementation: add only the public values/invariants needed by S1-01; keep account snapshot construction internal.
- Acceptance: mainnet is exactly `thorchain-1`/`thor`/`931`; invalid configuration fails with typed errors; no fake payload/account state is introduced.
- Check: `swift test --filter PublicApiTests/testMainnetConstants` plus the resolved Address/configuration tests.
- Commit: `feat: add S1-01 public value contracts`.

### 3. Add the inert Kit facade and deterministic lifecycle seam

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 2.
- Affected paths: `Sources/ThorChainKit/Core/Kit.swift`, `KitFactory.swift`, `KitDependencies.swift`; `PublicApiTests.swift`.
- Test first: add empty-wallet rejection, no-auto-start, exact lifecycle forwarding, and idle/zero/no-account assertions.
- Implementation: create the facade, atomically readable initial snapshot, nonfailing publishers, internal injected lifecycle, and collision-resistant `uniqueId`.
- Acceptance: factory creation performs zero lifecycle calls; each explicit lifecycle method forwards once; public API exposes no internal manager/storage.
- Check: `swift test --filter PublicApiTests`.
- Commit: `feat: add inert ThorChainKit facade`.

### 4. Lock the public surface

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 3.
- Affected paths: public source documentation, `PublicApiTests.swift`, the smallest source-import/API audit script or test fixture justified by the spec.
- Test first: make the import/API audit fail on a canary host-module import and on an extra library product.
- Implementation: document public symbols and enforce the host-import/secret surface without exposing SPI as public API.
- Acceptance: all seven public API tests pass and only allowed system/BigInt imports appear.
- Check: `swift test && swift package dump-package` plus targeted `rg` import/secret audit.
- Commit: `test: lock S1-01 public API surface`.

### 5. Add the local-package iOS Example

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 4.
- Affected paths: `iOS Example/iOS Example.xcodeproj/`, shared scheme, `.xcworkspace/`, and minimal `Sources/` files listed in the spec.
- Test first: add a build/structure assertion that fails until the workspace includes both `container:iOS Example.xcodeproj` and `group:..`.
- Implementation: create the minimal UIKit diagnostics app, fixture runtime, and stable accessibility IDs for network, address, sync state, lifecycle state, and data source.
- Acceptance: app builds through the shared workspace/scheme, displays `FIXTURE`, and contains no mnemonic/private-key/provider-credential entry or persistence.
- Check: `xcodebuild build -workspace "iOS Example/iOS Example.xcworkspace" -scheme "iOS Example" -destination <approved simulator>`.
- Commit: `feat: add fixture-only iOS Example`.

### 6. Add the guarded Maestro launch flow

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: step 5; Maestro CLI availability for live execution is not assumed.
- Affected paths: `.maestro/config.yaml`, `.maestro/flows/00-launch-foundation.yaml`, `Scripts/run-maestro.sh`, ignore rules only if artifacts require them.
- Test first: run the runner against an empty/mismatched manifest and prove nonzero exit; add a secret canary and prove the scan rejects it.
- Implementation: build/install the Example, pass `APP_ID`, run the one expected fixture flow, emit JUnit/artifacts under `build/maestro-results`, and compare expected/actual case counts.
- Acceptance: flow asserts the four public diagnostics plus inert lifecycle and absence of secret fields; fixture evidence is never labeled live.
- Check: `maestro test .maestro/flows/00-launch-foundation.yaml` through `Scripts/run-maestro.sh`; if CLI is unavailable, record the exact unrun reason and do not claim green.
- Commit: `test: add guarded foundation Maestro flow`.

### 7. Prove compatibility and prepare the review PR

- Suggested owner: ThorChainSwiftEngineer.
- Dependencies: steps 1–6; resolved roadmap-marker ruling.
- Affected paths: temporary external consumer outside the repository; the canonical roadmap marker path only as allowed by the resolved ruling; PR body.
- Test first: compile the temporary consumer before any compatibility workaround; capture the real failure if one exists.
- Implementation: make only approved compatibility corrections, update the plan checkboxes/evidence, and open the PR to `main` with the plan link and `## QA Evidence` section.
- Acceptance: narrow/full package tests, Example build, guarded fixture flow where available, secret/import audits, and temporary consumer all agree on one PR head; no unrelated file changes.
- Check: the exact commands in the spec, `git diff --name-only origin/main...HEAD`, and PR checks.
- Commit: `docs: record S1-01 verification and marker` only if the resolved marker rule permits it in this PR.

## Review and Handoff Sequence

1. ThorChainCodeReviewer performs the three independent architecture/security/verification reviews of this spec and plan.
2. ThorChainCTO resolves every high/critical finding, updates artifacts/state, and requests explicit user confirmation bound to the latest plan revision.
3. ThorChainSwiftEngineer implements test-first and opens the PR.
4. ThorChainCodeReviewer performs exact-head mechanical review; the architecture reviewer performs adversarial code review.
5. ThorChainQAEngineer independently verifies the exact PR head.
6. ThorChainCTO checks approvals, QA, CI, marker, and exact head, then squash-merges.

No phase may self-review, implement another role's fixes, or bypass the approval wait.
