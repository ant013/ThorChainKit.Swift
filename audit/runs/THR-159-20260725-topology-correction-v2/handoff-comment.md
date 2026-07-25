## Phase 1.3 topology correction revised — discovery 1/2; closure 0/5

The correction is revised for targeted closure review on exact head
`65589a48129789ad32f4c7a9a373ed3c5b523d0c`. Architecture revision 10 remains
the baseline at commit `518835315a65996b9321665213adb0516503df65` with bundle
digest `a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc`.
The corrected LiveSupport topology is explicitly bound to the later S2-06 spec
revision at commit `29611561f86765ee2ab9249a2de65a0989cc1626`, spec blob
`c0d862e9b861a117327864b60c534e539f9d5a8a`; fresh approval is required.

**Finding:** package checkout is complete. The remaining direct-build failure is the Xcode 26.3 package-product wrapper: `/tmp/thr159-65589a4-fixture-debug.log:1333-1346` shows `Crypto_17A3B1FFC41E47_PackageProduct.framework/Info.plist` generated, then HsCryptoKit link fails because its binary is absent.

**Chosen bounded delta for adversarial review:**

- Add the existing pinned `HdWalletKit.Swift` revision `2fc0dbfc089f78a9804baafe8e1bc4aab69cbad1` to the repository root `Package.swift`.
- Add a dynamic local package product `ThorChainExampleLiveSupport` backed by target `LiveSupport` at `iOS Example/LiveSupport`, with direct dependencies on `ThorChainKit`, pinned HdWalletKit, pinned HsCryptoKit, and the existing secp256k1 product.
- Remove the second Xcode package root and native LiveSupport framework target; have the Live app link local `ThorChainKit` plus local `ThorChainExampleLiveSupport`.
- Keep native `ThorChainExampleFixtureSupport` and its Fixture-only dependency unchanged. Do not move LiveSupport into the library, re-export crypto modules, alter public APIs, secrets, pins, or runtime behavior.
- Build Fixture Debug and Live Release with fresh HEAD/UDID-scoped DerivedData, persisted logs, exit-zero checks, and `BUILD SUCCEEDED` assertions.
- Run `THORCHAIN_SIMULATOR_UDID="$UDID" Scripts/run-maestro.sh s2-06`; require five flows and JUnit `5/0/0/0` under exact-head/UDID artifacts.
- Bind the release audit to the exact Live Release app/DerivedData and HEAD/UDID; reject `FixtureSupport.framework` and scan every executable in the app bundle, including embedded frameworks.

**Evidence/plan artifacts:**

- `audit/runs/THR-159-20260725-topology-correction-v2/topology-spec-delta.md`
- `audit/runs/THR-159-20260725-topology-correction-v2/delta-matrix.md`
- `audit/runs/THR-159-20260725-topology-correction-v2/test-plan.md`
- Gimle state records trust `RED` because the ThorChainKit project is unmapped; the load-bearing analog is independently verified by current-tree rg/Git against Unstoppable WalletCore’s one-root composition.

No implementation files changed by this correction. After targeted closure acceptance and fresh design approval, ThorChainSwiftEngineer should implement only this topology delta, then ThorChainQAEngineer reruns both exact local builds, the exact-artifact release audit, and guarded five-flow Maestro.

[@ThorChainCodeReviewer](agent://f6ace1af-b996-4ab4-a8d1-941d1997679e?i=review) your turn.
