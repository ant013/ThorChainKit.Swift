# Gimle reliability report: THR-155-s2-04-formalization-20260724

- Task: b34f82dc-4655-46d0-b148-628b53846a02
- Workflow/phase: analog_change / adversarial_review
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 5d54c3485c7a868970087d99505b26c32c577384
- Final HEAD: n/a
- Gimle runtime: n/a
- Indexed commit: n/a

## Metrics

- Calls: 0 (success 0, warning 0, error 0, false-success 0)
- Useful-call rate: n/a
- Response-byte coverage: 0/0; total n/a
- Duration coverage: 0/0; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 2
- Analog slices/candidates: 1/5

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|

Bug classes: {'mapping_bug': 1, 'environment_drift': 1}
Bug severities: {'high': 1, 'medium': 1}
Bug statuses: {'workaround': 2}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S2-04-signer-coordinator | critical | boundary, dependencies, lifecycle, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-S204-UW-OWNER | C-S204-VULTISIG-VERIFY, C-S204-HSCRYPTO-COMPACT, C-S204-GOLDEN | C-S204-INTERNAL-COUNTER |
  - Conflict: Unstoppable wrappers are concrete and synchronous, while S2-04 requires a host-owned async Sendable seam and cancellation-safe lifecycle.; resolution: Keep wrapper ownership as the primary boundary; introduce only the approved async Signer contract and coordinator races, with no seed/private-key derivation or concrete signer in the kit.
  - Conflict: HsCryptoKit exposes private-key production APIs, while ThorChainKit must only verify host-produced compact output.; resolution: Use HsCryptoKit only as supporting cryptographic shape evidence; the kit captures a public key once and verifies untrusted bytes.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-S204-UW-OWNER | S2-04-signer-coordinator | kept | F-S204-UW-OWNER | composition, consumer, contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | /Users/ant013/Ios/HorizontalSystems/unstoppable-wallet-ios/packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift |
| C-S204-VULTISIG-VERIFY | S2-04-signer-coordinator | supporting | F-S204-VULTISIG-VERIFY | consumer, contract, lifecycle_error | lifecycle, responsibility, state_errors, trust | known_current | /Users/ant013/Data/AI/thorchain/sources/vultisig-ios/VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift |
| C-S204-HSCRYPTO-COMPACT | S2-04-signer-coordinator | supporting | F-S204-HSCRYPTO-COMPACT | contract, implementation | dependencies, responsibility, trust | known_current | /Users/ant013/Ios/HorizontalSystems/HsCryptoKit.Swift/Sources/HsCryptoKit/Crypto.swift |
| C-S204-GOLDEN | S2-04-signer-coordinator | supporting | F-S204-GOLDEN | test | tests, trust | known_current | /Users/ant013/Data/AI/thorchain/sources/vultisig-ios/VultisigApp/VultisigAppTests/TestData/thorchain.json |
| C-S204-INTERNAL-COUNTER | S2-04-signer-coordinator | rejected | F-S204-INTERNAL-SIGNER-COUNTER | contract, counterexample, implementation | boundary, lifecycle, trust | known_current | /Users/ant013/Ios/HorizontalSystems/EvmKit.Swift/Sources/EvmKit/Core/Signer/Signer.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-S204-UW-OWNER | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current Unstoppable wrappers own concrete signer capability outside send handlers and mediate the kit send call. |
  - Serena: n/a
  - rg: TronKitManager.swift:140-166; targeted rg found owned signer property, signerNotSupported guard, and wrapper send calls.
  - Anchors: unstoppable-wallet-ios@4b697cb6:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:140-166
| F-S204-VULTISIG-VERIFY | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current Vultisig THOR signing verifies returned signatures against the expected secp256k1 public key before compiling the signed transaction. |
  - Serena: n/a
  - rg: thorchain.swift:186-205; targeted rg and narrow read confirm PublicKey construction and verify gate.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Blockchain/THORChain/Signing/thorchain.swift:186-205
| F-S204-HSCRYPTO-COMPACT | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | HsCryptoKit provides compact secp256k1 signing with normalized signature output as a supporting cryptographic shape. |
  - Serena: n/a
  - rg: Crypto.swift:109-124; targeted rg and narrow read confirm compact sign entry point and normalization path.
  - Anchors: hscryptokit@7c11ad0e:Sources/HsCryptoKit/Crypto.swift:109-124
| F-S204-INTERNAL-SIGNER-COUNTER | 1 | no | MATCH | no | rg | n/a | valid | known_current | EvmKit Signer owns concrete private-key signing objects and exposes seed/private-key factories, which violates the ThorChainKit host-secret boundary. |
  - Serena: n/a
  - rg: Signer.swift:1-67; targeted rg and narrow read confirm stored signers and instance(seed:<redacted> APIs.
  - Anchors: evm-kit@be028631:Sources/EvmKit/Core/Signer/Signer.swift:1-67
| F-S204-GOLDEN | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The pinned THORChain fixture is an independent deterministic test seam for the signing input and signature path. |
  - Serena: n/a
  - rg: thorchain.json:1; exact pinned Git read and path existence check confirm the fixture.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigAppTests/TestData/thorchain.json:1

## Adversarial decisions

- D-155-001@1 ACCEPT: Accept the host-owned async signer boundary with Unstoppable ownership as the primary analog.
- D-155-002@1 ACCEPT: Accept Vultisig and HsCryptoKit only as supporting verification/output evidence.
- D-155-003@1 ACCEPT: Accept fail-closed cancellation, cleanup, and shared-writer tests as material deltas.
- D-155-01@1 ACCEPT: Resolve gate scope by separating account admission from sequence reservation.
- D-155-02@1 ACCEPT: Retain an outstanding signer fence after prompt cancellation.
- D-155-03@1 ACCEPT: Use SendAttemptHandoff to transfer ownership into S2-05.
- D-155-04@1 ACCEPT: Integrate production factory and sync storage with DatabaseRuntime.
- D-155-05@1 ACCEPT: Make runtime ownership topology explicit.
- D-155-06@1 ACCEPT: Add integrated exact-byte golden verification.
- D-155-07@1 ACCEPT: Return typed repairPending and block signers until matching repair.
- D-155-08@1 ACCEPT: Pin executable discovery and strict-concurrency commands.
- D-155-09@1 ACCEPT: Test matching initialization-entry removal and retry.
- D-155-10@1 ACCEPT: Use an injected-clock bounded completion oracle.
- D-155-11@1 ACCEPT: Rebase formalization onto completed S2-03 integration base.

## Verification and acceptance


## Bugs and limitations

### GIM-THR155-MAP: ThorChainKit has no registered Gimle project or git mount

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.health / n/a / n/a
- Reproduction: Inspect palace.memory.health project and git mount lists; no Users-ant013-Data-AI-thorchain entry is present.
- Expected: A registered target project with runtime and indexed-commit identity.
- Actual: Target project and git mount are absent from the available Palace lists.
- Impact: Gimle cannot establish target-repository freshness for load-bearing analog claims.
- Workaround: Use codebase-memory plus exact checkout Git heads and targeted rg; retain RED trust.
- Anchors: n/a

### ENV-THR155-SERENA: Serena navigation tool unavailable

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: Serena / n/a / n/a
- Reproduction: Inspect enabled tool inventory; no Serena tool is callable.
- Expected: Serena declarations and references for selected candidates.
- Actual: No Serena tool is available in this session.
- Impact: Independent symbol verification falls back to targeted rg and Git reads.
- Workaround: Verify exact paths, current heads, line bounds, and narrow source reads with rg/Git.
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
