# THR-62 — S1-03 Derivation and Address Codec Plan

Status: discovery 2/2 is frozen after REVISE; revision 6 addresses the frozen
allowlist finding from closure 3/5; closure review 4/5 is required before
approval.

## Goal and acceptance

Add the transparent, watch-only-compatible account address pipeline: exact
`m/44'/931'/0'/0/0` path contract at the host boundary, compressed
secp256k1 public-key validation, `RIPEMD160(SHA256(publicKey))`, and strict
network-bound classic Cosmos Bech32 encoding through the existing S1-01
`Network`/`Address` rules. The kit must not accept or retain mnemonic, seed, or
private-key material.

Done means the S1-03 acceptance criteria in THR-62 are covered by tests and
verification, including independent public vectors, typed fail-closed errors,
negative/fuzz/round-trip coverage, exact public-symbol preservation for S1-01
and S1-02, SwiftUI-only Example presentation, and the bounded Maestro flow.

## Steps

### 1. Evidence, analog family, and design gate — ThorChainCTO

- Verify the current S1-01 contract and its callers/tests in the assigned
  worktree; use Horizontal Systems kits as architecture analogs and Vultisig
  only for THOR-specific vector support.
- Record Gimle reliability, current-tree claims, selected primary/supporting
  candidates, counterexamples, delta matrix, and test plan.
- Resolve all critical/high adversarial findings: no secret-bearing fixtures,
  immutable vector provenance, crypto capability/source closure, typed
  unavailable-context behavior, exact baseline/platform/CI authentication,
  and a reachable real-call-path Example runner.
- Close the frozen `S103-ARCH-01..05`, `THR62-SEC-B01..05`, and `VOP-01..05`
  IDs with exact analog commits/paths, path/error contracts, fixture values and
  provenance, dependency/context seams, Xcode/CI/runner wiring, and literal
  base/head/clean-worktree checks.
- Push the spec, Gimle report, delta matrix, and this plan, then hand the exact
  head to ThorChainCodeReviewer for closure 4/5. Approval remains prohibited
  until an exact-head CodeReviewer ACCEPT.

Affected paths: `docs/specs/sprint-01-foundation/S1-03-derivation-address-codec.md`,
`docs/superpowers/plans/2026-07-21-THR-62-s1-03-derivation-address-codec.md`,
and `docs/reports/gimle/`. The Gimle checkpoint is external to this
repository, is never committed, and is not an affected repository path.

Acceptance: the revision names the exact public boundary,
dependency/source closure, secret-handling boundary, independent vector
values/provenance, failure behavior, Xcode/CI/runner composition, and exact
base/head verification commands. The frozen allowlist maps to mechanical
checks. No implementation files change.

Dependency: none.

### 2. Derivation and codec implementation — ThorChainSwiftEngineer

- Add only the approved S1-03 package dependencies and source files listed by
  the slice spec.
- Keep mnemonic/seed/private-key derivation outside the kit; accept only the
  `compressedPublicKey` boundary.
- Implement the exact immutable `DerivationPath.rawValue` grammar and typed
  errors, and remove the factory's default `.mainnet` argument.
- Use a failure-reporting secp256k1 context/parser API; public entry points have
  no `try!`, force unwrap, `fatalError`, `precondition`, empty fallback, or
  `try?` suppression. Run the approved dependency/capability/source-closure
  audit.
- Reuse the S1-01 decoder and bit-conversion invariants; do not add a second
  parser, SegWit codec, permissive initializer, fallback string, or `try?` path.

Affected paths: `Package.swift`, `Sources/ThorChainKit/Crypto/`,
`Sources/ThorChainKit/Address/AddressCodec.swift`.

Acceptance: typed errors, exact 33-byte/prefix/real-curve validation, exact
20-byte HASH160 payload, classic Bech32 network binding, and unchanged prior
public declarations compile and pass their contract tests.

Dependency: Step 1 explicit approval.

### 3. Tests, fixtures, Example, and Maestro acceptance — ThorChainSwiftEngineer

- Add the bound public vector values and independent provenance records; the
  committed fixture must contain no placeholders, secrets, or host-local paths.
  Store no mnemonic, seed, private key, credentials, or host-local paths, and
  record immutable source/tool/command/input/digest metadata.
- Add derivation/codec negative, property/fuzz, round-trip, and public-symbol
  contract tests.
- Add SwiftUI + Combine Example presentation and `02-address-codec.yaml`
  using stable accessibility IDs and complete address assertions.
- Extend the exact verifier and runner/CI policy together so the flow is
  reachable, invokes the real presentation call path, and is not satisfied by
  static labels or hard-coded outputs. Include the authenticated baseline,
  package-resolution SHA, platform-import, public-consumer, deterministic fuzz,
  context-failure, Xcode target-membership, and secret scans. Update the
  cumulative S1-02 CI authority and exact three-flow manifest together. The
  changed path set also includes `iOS Example/Sources/ThorChainExampleApp.swift`,
  `iOS Example/iOS Example.xcodeproj/project.pbxproj`, `.maestro/config.yaml`,
  `Scripts/run-maestro.sh`, `Scripts/test-run-maestro.sh`,
  `Scripts/test-s1-03-mutants.sh`, `Scripts/verify-s1-03.sh`,
  `Scripts/verify-s1-02-ci-policy.sh`, and `.github/workflows/ci.yml`.
- Require the dependency fixture to contain the immutable S1-01 baseline plus
  the exact HsCryptoKit, HsExtensions, secp256k1, and swift-crypto resolved
  closure rows; require three SplitMix64 outputs per case, modulo-2⁶⁴ state
  advancement (`&+`), little-endian packing, four-byte truncation, and
  `count == 1024`.
- Extend the CI policy matcher with `fetch-depth: 0`, persisted checkout
  credentials, and the exact authenticated fetch/equality check for
  `refs/remotes/origin/main`.

Affected paths: `Tests/ThorChainKitTests/DerivationTests.swift`,
`Tests/ThorChainKitTests/AddressCodecTests.swift`,
`Tests/ThorChainKitTests/Fixtures/AddressVectors.json`,
`iOS Example/Sources/Presentation/AddressViewModel.swift`,
`iOS Example/Sources/Views/AddressView.swift`,
`.maestro/flows/02-address-codec.yaml`, the root Example App and Xcode project
membership, the exact slice verifier, the named mutant harness, and the
cumulative runner/manifest/CI policy files listed above.

Acceptance: no mnemonic/private material or host-local paths are committed;
the Example imports no UIKit; the flow checks full expected address,
canonical uppercase normalization, checksum/mixed-case, and wrong-HRP cases.

Dependency: Step 2 implementation shape and Step 1 approval.

### 4. Mechanical review and adversarial code review — ThorChainCodeReviewer

- Review the exact PR head against the approved plan/spec and changed-line
  scope.
- Run the project-equivalent narrow/full checks and inspect public-symbol,
  dependency, secret, platform, and diff boundaries.
- Recheck only the frozen discovery-2 blocker IDs and direct changed-line
  Critical/High regressions during closure; record closure 4/5.

Affected paths: exact PR diff and CI/verification artifacts.

Acceptance: Paperclip and GitHub review cite one unchanged PR head; approval
contains the required checklist and no unresolved blocking finding.

Dependency: Steps 2–3 and pushed PR.

### 5. Independent QA and merge gate — ThorChainQAEngineer / ThorChainCTO

- QA verifies the exact PR head with deterministic commands and the Example
  Maestro flow, preserving fixture/live separation and recording unrun checks.
- CTO verifies CI, conflict-free diff, plan/spec references, reviewer approval,
  QA PASS, and the merge commit on `origin/main` before closing the slice.

Affected paths: exact PR head, CI artifacts, Paperclip issue, and `origin/main`.

Acceptance: all required checks are green, QA cites the same head as review,
the real roadmap marker is updated only with the real PR/merge evidence, and
the issue is closed after merge verification.

Dependency: Step 4 approval and QA PASS.
