# Gimle reliability report: thorchainkit-s1-01-THR-12-20260717

- Task: THR-12
- Workflow/phase: analog_change / adversarial_review
- Trust: **RED**
- Repository: ThorChainKit.Swift
- Base HEAD: 771bad30bb4ff20fa32ed0f4be260a7b934899e9
- Final HEAD: n/a
- Gimle runtime: 52bb684fdd9492519ed7c87b0cae67c7b978810e
- Indexed commit: n/a

## Metrics

- Calls: 32 (success 26, warning 6, error 0, false-success 0)
- Useful-call rate: 46.9%
- Response-byte coverage: 22/32; total 86355
- Duration coverage: 6/32; total 35000 ms
- Gimle agreement: 66.7%
- Gimle contradiction: 33.3%
- Location validity: 100.0%; coverage 6/6
- Freshness coverage: 66.7%
- Replacement/fallback claims: 2
- Bugs: 7
- Analog slices/candidates: 4/17

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 4 | 0 | 0 | 0 |
| palace.code.search_code | 2 | 0 | 0 | 0 |
| palace.code.search_graph | 2 | 1 | 0 | 0 |
| palace.code.semantic_search | 0 | 2 | 0 | 0 |
| palace.health.status | 5 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 7 | 1 | 0 | 0 |
| palace.memory.health | 4 | 0 | 0 | 0 |
| palace.memory.list_projects | 2 | 2 | 0 | 0 |

Bug classes: {'caller_error': 1, 'mapping_bug': 3, 'environment_drift': 2, 'coverage_gap': 1}
Bug severities: {'low': 2, 'high': 3, 'medium': 2}
Bug statuses: {'workaround': 7}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | ok | success | n/a/1 | 425 | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.health | ok | success | n/a/18 | 3000 | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace.memory.list_projects | ok | success | 18/18 | 20000 | n/a | yes | 44136fa355b3678a | n/a |
| E-0004 | preflight | palace.code.list_passthrough_projects | ok | success | n/a/7 | 300 | n/a | yes | 44136fa355b3678a | n/a |
| E-0005 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | 1300 | n/a | yes | 04799ff4fb4e3a8b | n/a |
| E-0006 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | 1300 | n/a | yes | 4282f54d43bbb349 | n/a |
| E-0007 | preflight | palace.memory.get_project_overview | ok | success | n/a/1 | 1400 | n/a | yes | e40d2aa6fdce6b6f | n/a |
| E-0008 | evidence | palace.code.search_graph | ok | success | 36/10 | 3200 | n/a | no | d6f16ed3d370e661 | n/a |
| E-0009 | evidence | palace.code.search_code | ok | success | 0/0 | 140 | n/a | no | 0077e62e43a44dad | n/a |
| E-0010 | evidence | palace.code.search_graph | ok | success | 10/10 | 3400 | n/a | no | cabd0824d1d4bb7d | n/a |
| E-0011 | evidence | palace.code.search_graph | ok | warning | 102/10 | 3200 | n/a | no | b9f90a09747b5f50 | Name-only search mixed current package paths with legacy application paths and truncated 102 matches; no decision used this result. |
| E-0012 | evidence | palace.code.search_code | ok | success | 0/0 | 140 | n/a | no | 7aa81eef796095c6 | n/a |
| E-0013 | adversarial_review | palace.health.status | success | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0014 | adversarial_review | palace.memory.health | success | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0015 | adversarial_review | palace.memory.list_projects | success | warning | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | Policy checkouts still differ from Palace repo_path mappings and freshness_state remains unknown for load-bearing projects. |
| E-0016 | adversarial_review | palace.code.list_passthrough_projects | success | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0017 | design | palace.health.status | ok | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0018 | design | palace.memory.health | ok | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0019 | design | palace.memory.list_projects | ok | success | 18/18 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0020 | design | palace.code.list_passthrough_projects | ok | success | n/a/7 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0021 | design | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 04799ff4fb4e3a8b | n/a |
| E-0022 | design | palace.memory.get_project_overview | ok | success | n/a/1 | n/a | n/a | yes | 4282f54d43bbb349 | n/a |
| E-0023 | evidence | palace.health.status | ok | success | n/a/1 | 520 | 200 | no | 44136fa355b3678a | n/a |
| E-0024 | evidence | palace.memory.health | ok | success | n/a/1 | 3100 | 10000 | no | 44136fa355b3678a | n/a |
| E-0025 | evidence | palace.memory.list_projects | ok | warning | 18/18 | 36000 | 10000 | no | 44136fa355b3678a | All relevant projects report freshness_state=unknown and identity_check=unchecked; Vultisig is not registered. |
| E-0026 | evidence | palace.code.list_passthrough_projects | ok | success | n/a/7 | 350 | 10000 | no | 44136fa355b3678a | n/a |
| E-0027 | evidence | palace.memory.get_project_overview | ok | success | n/a/1 | 1300 | 2400 | no | 04799ff4fb4e3a8b | n/a |
| E-0028 | evidence | palace.memory.get_project_overview | ok | success | n/a/1 | 1300 | 2400 | no | 4282f54d43bbb349 | n/a |
| E-0029 | adversarial_review | palace.health.status | ok | success | n/a/1 | 520 | n/a | no | 44136fa355b3678a | n/a |
| E-0030 | adversarial_review | palace.memory.get_project_overview | ok | warning | 1/1 | 1180 | n/a | no | e40d2aa6fdce6b6f | Payload is valid and mirror freshness is current at 8a63bfda, but repo_path and commit differ from the policy-mandated Unstoppable checkout 5b06860e; exact-checkout claims still... |
| E-0031 | adversarial_review | palace.code.semantic_search | ok | warning | 0/0 | 980 | n/a | no | 5b0a30810b8c66ca | Bounded indexed search returned zero candidates with complete reported symbol coverage, but project roots are not the policy-mandated checkouts; absence must be verified at exac... |
| E-0032 | adversarial_review | palace.code.semantic_search | ok | warning | 3/3 | 3300 | n/a | no | 03295673f797df04 | Three AdapterFactory/IAdapter hits contain no comparable ordering mechanism, but the indexed mirror is 8a63bfda rather than the mandated 5b06860e checkout. |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S1-01A | normal | boundary, dependencies, responsibility, tests | composition, consumer, contract, counterexample, implementation, test | n/a | A-TRON-PACKAGE | A-TRON-WORKSPACE | A-EVM-NO-TEST |
  - Conflict: TronKit uses Swift 5.5 and a mature dependency set, while the new host compatibility target is Swift 5.10 and S1-01 authorizes only BigInt.; resolution: Preserve only product/test/workspace topology; pin Swift 5.10, iOS 13, and BigInt, deferring all S1-03/S1-05 dependencies.
| S1-01B | high | boundary, dependencies, lifecycle, responsibility, state_errors, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | test | B-TRON-FACADE | B-UW-CONSUMER, B-UW-LIFECYCLE | B-TRON-DEMO-DUPLICATE-LIFECYCLE |
  - Conflict: TronKit composes uniqueId by ambiguous concatenation and Unstoppable TronKitManager auto-starts the kit even though generic AdapterManager also owns adapter lifecycle.; resolution: Keep the facade shape; hash walletId, NUL delimiter, and network persistenceKey; reject empty walletId; inject lifecycle internally; factory remains inert and S1-01 adds no host adapter.
  - Conflict: TronKit, EvmKit, and the exact Unstoppable managers directly forward lifecycle calls and do not establish the proposed lock-owned sequence/FIFO, synchronous completion, or reentrant command algorithm.; resolution: Use selected analogs only for facade boundary and lifecycle ownership. Treat command admission/completion as a high-concurrency greenfield delta with two bounded absence searches and deterministic tests; defer every post-construction publication race to S1-05.
| S1-01C | normal | boundary, dependencies, responsibility | composition, consumer, counterexample, implementation, test | test | C-TRON-WORKSPACE | C-EVM-WORKSPACE | C-TRON-DEMO-SECRETS, C-VULTISIG-ZERO-CASE |
  - Conflict: Both kit demos have empty scheme testables, duplicate lifecycle starts, and persisted mnemonic material; Vultisig shows a zero-case green test hazard.; resolution: Retain only project/workspace/shared-scheme/root-package topology; create a fixture-only diagnostics app, no secret persistence, stable accessibility IDs, and a runner that rejects empty manifests and mismatched JUnit counts.
| S1-01D | high | boundary, dependencies, responsibility, state_errors, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | test | D-EVM-THROWING-ADDRESS | D-TRON-THROWING-ADDRESS, D-VULTISIG-THOR-HRP | D-EVM-RAW-ADDRESS, D-VULTISIG-FORCE-URL, D-VULTISIG-PRINT-TEST |
  - Conflict: Horizontal address types expose raw payload construction/storage, while S1-01 requires network-bound strings with internal-only decoded bytes.; resolution: Adopt only validate-before-store throwing construction and stable errors; reject raw public construction/payload exposure.
  - Conflict: Vultisig confirms THOR HRPs but force-unwraps endpoints and its THOR address test has no assertions.; resolution: Use Vultisig only as pinned THOR vocabulary support; derive endpoint/denom/address rules from pinned protocol sources and require independent exact tests.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| A-TRON-PACKAGE | S1-01A | kept | F-TRON-PACKAGE | composition, contract, implementation, test | boundary, dependencies, responsibility, tests | known_current | Package.swift |
| A-TRON-WORKSPACE | S1-01A | supporting | F-TRON-WORKSPACE | composition, consumer | boundary, dependencies, responsibility | known_current | iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata |
| A-EVM-NO-TEST | S1-01A | rejected | F-EVM-PACKAGE | counterexample | boundary, dependencies, tests | known_current | Package.swift |
| B-TRON-FACADE | S1-01B | kept | F-TRON-FACADE | composition, contract, implementation, lifecycle_error | boundary, dependencies, lifecycle, responsibility, state_errors, trust | known_current | Sources/TronKit/Core/Kit.swift |
| B-UW-CONSUMER | S1-01B | supporting | F-UW-TRON-CONSUMER | composition, consumer | boundary, dependencies, lifecycle, responsibility, trust | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift |
| B-UW-LIFECYCLE | S1-01B | supporting | F-UW-ADAPTER-LIFECYCLE | consumer, lifecycle_error | boundary, lifecycle, responsibility, state_errors | known_current | packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift |
| B-TRON-DEMO-DUPLICATE-LIFECYCLE | S1-01B | rejected | F-TRON-DEMO-RISKS | counterexample, lifecycle_error | lifecycle, trust | known_current | iOS Example/Sources/Core/Manager.swift |
| C-TRON-WORKSPACE | S1-01C | kept | F-TRON-WORKSPACE | composition, consumer, implementation | boundary, dependencies, responsibility | known_current | iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata |
| C-EVM-WORKSPACE | S1-01C | supporting | F-EVM-WORKSPACE | composition, consumer, implementation | boundary, dependencies, responsibility | known_current | iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata |
| C-TRON-DEMO-SECRETS | S1-01C | rejected | F-TRON-DEMO-RISKS | counterexample | boundary, dependencies, responsibility | known_current | iOS Example/Sources/Core/Manager.swift |
| C-VULTISIG-ZERO-CASE | S1-01C | rejected | F-VULTISIG-ZERO-CASE | counterexample | responsibility | known_current | VultisigApp/VultisigAppTests/Chains/ChainHelperTests.swift |
| D-EVM-THROWING-ADDRESS | S1-01D | kept | F-PROTOCOL-EVM-ADDRESS | consumer, contract, implementation, lifecycle_error | boundary, responsibility, state_errors, trust | known_current | Sources/EvmKit/Models/Address.swift |
| D-TRON-THROWING-ADDRESS | S1-01D | supporting | F-PROTOCOL-TRON-ADDRESS | consumer, contract, implementation, lifecycle_error | boundary, responsibility, state_errors, trust | known_current | Sources/TronKit/Models/Address.swift |
| D-VULTISIG-THOR-HRP | S1-01D | supporting | F-PROTOCOL-VULTISIG-HRP | composition, consumer, contract | boundary, dependencies, responsibility, trust | known_current | VultisigApp/VultisigApp/Core/Services/AddressService.swift |
| D-EVM-RAW-ADDRESS | S1-01D | rejected | F-PROTOCOL-EVM-RAW-COUNTEREXAMPLE | counterexample, implementation | boundary, state_errors, trust | known_current | Sources/EvmKit/Models/Address.swift |
| D-VULTISIG-FORCE-URL | S1-01D | rejected | F-PROTOCOL-VULTISIG-ENDPOINT-COUNTEREXAMPLE | composition, counterexample, implementation | boundary, dependencies, state_errors, trust | known_current | VultisigApp/VultisigApp/Core/Utils/Endpoint.swift |
| D-VULTISIG-PRINT-TEST | S1-01D | rejected | F-PROTOCOL-VULTISIG-TEST-COUNTEREXAMPLE | counterexample, test | state_errors, trust | known_current | VultisigApp/VultisigAppTests/Chains/ThorAddressValidationTests.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-TRON-PACKAGE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The assigned TronKit checkout defines one TronKit library product and a TronKitTests target in Package.swift. |
  - Serena: Package.swift lines 9-12 library, 26-38 target, 40-47 testTarget.
  - rg: aa691bcd; rg confirms .library at 9, .target at 26, .testTarget at 40; two current XCTest files under Tests/TronKitTests.
  - Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Package.swift:9, TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Package.swift:40
| F-TRON-FACADE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The assigned TronKit Kit is a public facade with synchronous state, Combine publishers, explicit start/stop/refresh, and a static composition factory that returns without starti... |
  - Serena: Kit class and public extensions span lines 7-356; lifecycle lines 211-224; factory lines 245-325 has no start call.
  - rg: aa691bcd; exact methods at 212/217/222 and factory uniqueId composition at 256.
  - Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Sources/TronKit/Core/Kit.swift:8, TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Sources/TronKit/Core/Kit.swift:212, TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Sources/TronKit/Core/Kit.swift:246
| F-GIM-TRON-CURRENT | 1 | yes | CONTRADICTED | no | serena+rg | E-0005, E-0008 | valid | contradictory | The Gimle tron-kit result represents the exact policy-mandated TronKit checkout used for S1-01. |
  - Serena: Assigned checkout resolves the facade at aa691bcd.
  - rg: git and rg prove the assigned Package.swift contains a testTarget that the mapped Gimle search did not find.
  - Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:Sources/TronKit/Core/Kit.swift:8
| F-TRON-WORKSPACE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The assigned TronKit iOS Example is a runnable app whose workspace includes both iOS Example.xcodeproj and group:.. for the local package root; its shared scheme has no testables. |
  - Serena: Workspace XML lines 4 and 7; scheme lines 17, 29-30, 47.
  - rg: aa691bcd; exact workspace and scheme anchors match and Testables is empty.
  - Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata:4, TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:iOS Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme:29
| F-TRON-DEMO-RISKS | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The TronKit Example stores mnemonic words in UserDefaults and starts the kit from both Manager and adapter paths, so those demo choices are unsafe counterexamples. |
  - Serena: Example searches locate mnemonic_words, UserDefaults persistence, Manager start, and TrxAdapter start/stop.
  - rg: aa691bcd; Manager.swift lines 8, 38, 64, 80 and TrxAdapter.swift lines 32, 36.
  - Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:iOS Example/Sources/Core/Manager.swift:8, TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5:iOS Example/Sources/Adapters/TrxAdapter.swift:32
| F-UW-TRON-CONSUMER | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The assigned Unstoppable checkout composes TronKit.Kit with address, network, walletId, and providers, then auto-starts it inside TronKitManager. |
  - Serena: TronKitManager._tronKitWrapper lines 57-110 creates Kit.instance at 86 and calls start at 96.
  - rg: 5b06860e; exact matches at lines 58, 86, 89, 96, 135.
  - Anchors: unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:58, unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:96
| F-UW-ADAPTER-LIFECYCLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | The assigned Unstoppable AdapterManager owns generic adapter start/stop and refresh dispatch, demonstrating that a kit factory must not auto-start. |
  - Serena: AdapterManager._initAdapters lines 73-105 starts added adapters and stops removed adapters; refresh paths are explicit.
  - rg: 5b06860e; adapter.start line 83, adapter.stop line 104, refresh dispatch line 246.
  - Anchors: unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:74, unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:83
| F-GIM-UW-CURRENT | 1 | yes | CONTRADICTED | no | serena+rg | E-0007, E-0010 | valid | contradictory | The Gimle uw-ios-app result represents the exact policy consumer checkout used for S1-01. |
  - Serena: Assigned exact checkout resolves the consumer at 5b06860e.
  - rg: Git and rg confirm the current assigned manager/lifecycle anchors at a different HEAD.
  - Anchors: unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:58
| F-EVM-PACKAGE | 1 | yes | MATCH | yes | combined | E-0006, E-0012 | valid | known_current | At be028631, EvmKit has one library product and target but no testTarget or Tests directory. |
  - Serena: Assigned Package.swift contains only .library and .target.
  - rg: be028631; .library line 10, .target line 26, no .testTarget, Tests directory absent.
  - Anchors: EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b:Package.swift:10, EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b:Package.swift:26
| F-EVM-WORKSPACE | 1 | yes | MATCH | yes | combined | E-0006 | valid | known_current | At be028631, EvmKit independently uses the same local-package workspace shape as TronKit and its shared scheme also has no testables. |
  - Serena: Workspace lines 4 and 7 include project and group:..; scheme Testables is empty.
  - rg: be028631; exact workspace and scheme matches confirmed.
  - Anchors: EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b:iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata:4, EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b:iOS Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme:29
| F-VULTISIG-ZERO-CASE | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Pinned Vultisig ChainHelperTests filters fixtures by the ChainHelper filename prefix while only thorchainswap.json exists, so zero executed cases can still leave the XCTest green. |
  - Serena: Not available for the nested supporting checkout; claim uses exact rg and Git evidence.
  - rg: d3123dbe; filter at ChainHelperTests.swift:53, assertions only inside run cases, and no ChainHelper*.json fixture exists.
  - Anchors: vultisig-ios@d3123dbe6ef1103937c272a8b1cd81f613af0acc:VultisigApp/VultisigAppTests/Chains/ChainHelperTests.swift:53, vultisig-ios@d3123dbe6ef1103937c272a8b1cd81f613af0acc:VultisigApp/VultisigAppTests/TestData/thorchainswap.json:1
| F-HOST-TOOLCHAIN | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The assigned WalletCore package uses Swift tools 5.10 and iOS 17, establishing the temporary compatibility consumer settings. |
  - Serena: Package manifest is non-symbol text; exact verification uses rg.
  - rg: 5b06860e; Package.swift line 1 tools 5.10 and line 8 iOS 17.
  - Anchors: unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Package.swift:1, unstoppable-wallet-ios@5b06860e6e0068f05411cacc568bbb50bca1c588:packages/WalletCore/Package.swift:8
| F-TARGET-SEED | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | ThorChainKit HEAD is documentation-only and contains none of the S1-01 implementation paths. |
  - Serena: Target Serena project reports no programming language/symbol surface.
  - rg: git ls-tree at 771bad30 finds zero Package.swift, Sources, Tests, iOS Example, .maestro, or runner paths; 22 tracked AGENTS/ROADMAP/docs files.
  - Anchors: ThorChainKit.Swift@771bad30bb4ff20fa32ed0f4be260a7b934899e9:docs/specs/sprint-01-foundation/S1-01-package-public-api.md:1
| F-PROTOCOL-EVM-ADDRESS | 1 | yes | MATCH | yes | serena+rg | E-0028 | valid | known_current | At EvmKit be028631, public Address.init(hex:) validates prefix, exact length, symbols, and mixed-case checksum before storing bytes; real consumers use the throwing initializer. |
  - Serena: Exact Address struct and validate bodies are present at Sources/EvmKit/Models/Address.swift lines 6-75; iOS Example and ENS consumers call Address(hex:).
  - rg: git show HEAD confirms lines 6-75 and rg finds Address(hex:) consumers in Example, ENS, and transforms.
  - Anchors: EvmKit.Swift@be028631:Sources/EvmKit/Models/Address.swift:6, EvmKit.Swift@be028631:iOS Example/Sources/Core/Manager.swift:76
| F-PROTOCOL-TRON-ADDRESS | 1 | yes | MATCH | yes | serena+rg | E-0027 | valid | known_current | At TronKit aa691bcd, both public Address initializers throw after checksum, prefix, and exact-length validation, and production transforms/consumers use them. |
  - Serena: Exact Address initializer and validate bodies are present at Sources/TronKit/Models/Address.swift lines 6-59.
  - rg: git show HEAD confirms checksum/prefix/length validation; rg finds throwing Address use in transforms, signer, smart-contract parsing, and Example controllers.
  - Anchors: TronKit.Swift@aa691bcd:Sources/TronKit/Models/Address.swift:6, TronKit.Swift@aa691bcd:Sources/TronKit/Core/Transforms.swift:63
| F-PROTOCOL-VULTISIG-HRP | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At Vultisig d3123dbe, THOR-specific validation selects cthor for chainnet, sthor for stagenet, and the thorchain coin validator for mainnet; this is vocabulary support only. |
  - Serena: AddressService.validateAddress has exact cthor/sthor branches and delegates mainnet through Chain.thorChain.coinType.
  - rg: git show HEAD confirms VultisigApp/Core/Services/AddressService.swift lines 130-151 at d3123dbe.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Core/Services/AddressService.swift:130
| F-PROTOCOL-EVM-RAW-COUNTEREXAMPLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | EvmKit Address.init(raw:) accepts any byte count other than slicing 32 bytes, so it is not a fail-closed public constructor analog for THOR protocol values. |
  - Serena: Serena shows init(raw:) stores arbitrary non-32-byte Data unchanged.
  - rg: git show HEAD confirms Sources/EvmKit/Models/Address.swift lines 9-15 at be028631.
  - Anchors: EvmKit.Swift@be028631:Sources/EvmKit/Models/Address.swift:9
| F-PROTOCOL-VULTISIG-ENDPOINT-COUNTEREXAMPLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Vultisig endpoint composition force-unwraps URL(string:) through String.asUrl and therefore cannot define S1-01 public endpoint construction. |
  - Serena: Serena resolves Endpoint.thorchainNetworkInfo through private String.asUrl returning URL(string:self)!.
  - rg: git show HEAD confirms Endpoint.swift lines 150 and 731-734 at d3123dbe.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigApp/Core/Utils/Endpoint.swift:731
| F-PROTOCOL-VULTISIG-TEST-COUNTEREXAMPLE | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | Vultisig ThorAddressValidationTests contains two thor addresses but only prints three validation results and has no assertion, so it is not a usable contract-test oracle. |
  - Serena: Serena shows the sole test method loops and prints without XCTAssert.
  - rg: git show HEAD confirms ThorAddressValidationTests.swift lines 5-22 at d3123dbe.
  - Anchors: vultisig-ios@d3123dbe:VultisigApp/VultisigAppTests/Chains/ThorAddressValidationTests.swift:5
| F-PROTOCOL-PINNED-BOUNDS | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | THORNode a759cb4f pins CometBFT v0.38.21 and Cosmos SDK v0.53.0; those exact sources define MaxChainIDLen 50 and the 3-to-128 ASCII denom grammar. |
  - Serena: n/a
  - rg: Exact THORNode go.mod lines 62/65 pin the modules; official tagged sources show MaxChainIDLen=50 and reDnmString=[a-zA-Z][a-zA-Z0-9/:._-]{2,127}.
  - Anchors: THORNode@a759cb4f:go.mod:62, https://github.com/cometbft/cometbft/blob/v0.38.21/types/genesis.go, https://github.com/cosmos/cosmos-sdk/blob/v0.53.0/types/coin.go
| F-PROTOCOL-THOR-ADDRESS-VECTOR | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | THORNode a759cb4f uses thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2 in an asserted swap test; independent bech32@2.0.0 decoding yields the exact 20-byte payload 33e56601b755fe1c8... |
  - Serena: n/a
  - rg: git show HEAD confirms the address at x/thorchain/handler_swap_test.go:563; npx bech32@2.0.0 decode reports hrp thor, length 20, and the stated hex payload.
  - Anchors: THORNode@a759cb4f:x/thorchain/handler_swap_test.go:563, bech32@2.0.0:33e56601b755fe1c896da0884b79f38e526d6efc
| F-LIFECYCLE-KIT-FORWARDING-GAP | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At the mandated TronKit aa691bcd and EvmKit be028631 checkouts, the public Kit lifecycle methods directly forward start/stop/refresh; bounded Core and test searches expose no lo... |
  - Serena: TronKit Kit.start/stop/refresh at 212-224 and EvmKit Kit.start/stop/refresh at 111-122 contain only direct collaborator calls.
  - rg: Exact-head bounded searches of TronKit Core+Tests and EvmKit Core found lifecycle methods and subjects/queues but none of FIFO, desiredRunning, sequence+append, lock, or reentrant ordering vocabulary.
  - Anchors: TronKit.Swift@aa691bcd:Sources/TronKit/Core/Kit.swift:212, EvmKit.Swift@be028631:Sources/EvmKit/Core/Kit.swift:111
| F-LIFECYCLE-UW-MANAGER-GAP | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At mandated Unstoppable 5b06860e, the bounded AdapterManager and TronKitManager lifecycle lane uses serial queues for manager state but directly calls adapter/kit start, stop, a... |
  - Serena: AdapterManager._initAdapters directly starts/stops adapters; refreshAdapters stops then reconstructs; TronKitManager directly starts the new kit before publishing creation.
  - rg: At 5b06860e, targeted manager/adapter searches found DispatchQueue and direct lifecycle calls but no FIFO, desiredRunning, sequence+append, lock, or reentrant ordering mechanism.
  - Anchors: unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:74, unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/TronKitManager.swift:58
| F-VERIFICATION-SWIFTPM-XUNIT | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | SwiftPM 6.2.4 generates XCTest xUnit only through its parallel runner, and that XML generator records tests/failures but has no skipped representation; serialized parallel execu... |
  - Serena: n/a
  - rg: Exact swift-6.2.4-RELEASE SwiftTestCommand.swift lines 296-345 place xUnit generation only in shouldRunInParallel; XUnitGenerator records tests/failures and explicitly notes limited XCTest reporting. Local swift test --help confirms --parallel, --num-workers, and --xunit-output.
  - Anchors: swift-package-manager@swift-6.2.4-RELEASE:Sources/Commands/SwiftTestCommand.swift:296
| F-DEPENDENCY-BIGINT-FLOOR | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | BigInt v5.0.0 lacks BigUInt Sendable while v5.7.0 adds it; a manifest range from 5.0.0 currently resolves 5.7.0 and cannot by itself prove minimum-version compatibility. |
  - Serena: n/a
  - rg: Exact tags resolve to 19f5e8a48be155e34abb98a2bcf4a343316f0343 and e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe; targeted BigUInt declarations show no Sendable at v5.0.0 and Sendable at v5.7.0. Swift package resolve exposes an exact --version option.
  - Anchors: BigInt@v5.0.0:Sources/BigInt/BigUInt.swift; BigInt@v5.7.0:Sources/BigInt/BigUInt.swift

## Adversarial decisions

- D-001@4 ACCEPT: Protocol values and absent-account invariants are now fail-closed
- D-002@3 ACCEPT: Strict classic-Bech32 construction remains complete
- D-003@3 ACCEPT: Optional replaying snapshot publishers remain aligned
- D-004@4 ACCEPT: Revision-3 Maestro and consolidated-plan corrections are resolved
- D-005@3 ACCEPT: PR-head and post-merge identities remain separated
- D-006@5 ACCEPT: Effective dispatcher-context reentry no longer self-waits
- D-007@3 ACCEPT: iOS 13 and BigUInt concurrency claims are now bounded
- D-008@2 ACCEPT: Hashing non-goal is correctly narrowed
- D-009@2 ACCEPT: Canonical Gimle identity and Git anchors are corrected
- D-010@2 ACCEPT: UI evidence is limited to observable behavior
- D-011@2 REVISE: One-owner rule remains contradicted by the S1-05 start state machine
- D-012@2 ACCEPT: Revision-5 integrity bindings are mechanically correct
- D-013@4 REVISE: FIFO mutant lacks an outer executable harness
- D-014@3 REVISE: Factory inertness audit is blacklist-shaped
- D-015@3 REVISE: Plan over-defers S1-01 command draining
- D-016@1 REVISE: S1-05 does not consume the exact frozen S1-01 state/error contract
- D-017@1 REVISE: Endpoint fail-closed rules exceed the named RED coverage
- D-018@1 REVISE: Exact-head merge readiness and reviewer-QA sequencing are incomplete
- D-019@2 REVISE: Artifact containment lacks sibling-prefix and root-symlink canaries
- D-020@1 REVISE: The committed implementation plan is stale against the canonical Paperclip plan
- D-021@1 REVISE: The exact Example workspace structure has no named executable gate
- D-022@1 REVISE: Spec revision metadata is stale
- D-023@1 REVISE: Decoded address payload lacks an independent known-answer assertion
- D-024@1 REVISE: Security-sensitive protocol values lack their own verified analog slice
- D-025@1 REVISE: S1-05 storage key is not explicitly bound to the hashed namespace
- D-026@2 REVISE: Revision 6 truncated the Maestro digest
- D-027@1 REVISE: Permanent S1-01 gates conflict with approved later slices
- D-028@1 REVISE: Committed report leaks operator paths
- D-029@2 REVISE: SwiftPM xUnit execution evidence is incomplete
- D-030@1 REVISE: Persistence namespace lacks a fixed oracle
- D-031@1 REVISE: Plan and test text contain false-green wording
- D-032@1 REVISE: Novel lifecycle ordering was attributed to a forwarding analog
- D-033@1 REVISE: BigInt floor and resolved identity are unowned
- D-034@1 REVISE: Probe callback lock exception is underspecified
- D-035@1 REVISE: KitConfigurationError has no file owner

## Verification and acceptance


## Bugs and limitations

### GIM-THR12-BROAD-ADAPTER: Unscoped AdapterManager name query mixed legacy paths

- Class/severity/confidence/status: caller_error / low / confirmed / workaround
- Tool/events/claims: palace.code.search_graph / E-0011 / n/a
- Reproduction: search_graph project=uw-ios-app name_pattern=AdapterManager limit=10
- Expected: A bounded current WalletCore package result
- Actual: 102 matches across current and legacy application layouts; first page was truncated
- Impact: Result cannot select a load-bearing lifecycle consumer
- Workaround: Use the exact policy path and independently verify it in the assigned Unstoppable checkout with Serena and targeted rg
- Anchors: packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift

### GIM-THR12-TRON-MAPPING: Gimle TronKit mapping differs from the policy analog checkout

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0005 / n/a
- Reproduction: Compare tron-kit overview repo_path/tree_head with git -C TronKit.Swift rev-parse HEAD
- Expected: The indexed primary analog maps to the exact assigned checkout and HEAD aa691bcd8c79d57a554d72a4996bec4d7e1afce5
- Actual: Gimle maps GimleMirror/tron-kit at f8ce0c00d788a4e06ddfe07ce2a5d6be783dcce4
- Impact: Gimle facade/package findings cannot establish the current policy analog
- Workaround: Use Gimle only for candidate discovery and verify every selected TronKit fact in TronKit.Swift with Serena, rg, and Git
- Anchors: TronKit.Swift@aa691bcd8c79d57a554d72a4996bec4d7e1afce5

### GIM-THR12-UW-MAPPING: Gimle Unstoppable mapping differs from the policy consumer checkout

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview/palace.code.semantic_search / E-0007, E-0030, E-0032 / n/a
- Reproduction: Inspect uw-ios-app overview and bounded lifecycle semantic search after a healthy Palace probe.
- Expected: Indexed identity authoritative for Unstoppable 5b06860e.
- Actual: Overview and three search hits are from mirror 8a63bfda.
- Impact: Indexed data cannot establish lifecycle algorithm similarity or absence at the mandated checkout.
- Workaround: Verify AdapterManager and kit-manager lifecycle at 5b06860e with Serena and rg.
- Anchors: uw-ios-app@8a63bfda, unstoppable-wallet-ios@5b06860e

### GIM-THR12-EVM-PATH: Gimle and policy EvmKit roots differ although HEAD agrees

- Class/severity/confidence/status: environment_drift / low / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0006 / n/a
- Reproduction: Compare evm-kit overview repo_path/tree_head with the assigned EvmKit checkout
- Expected: One exact root for indexed and independent verification
- Actual: Roots differ, but both resolve to be0286317c202084784c5a695928cdc985c4ff7b
- Impact: Path identity must be stated explicitly even though content freshness agrees by commit
- Workaround: Verify the assigned EvmKit tree directly and cite the shared commit
- Anchors: EvmKit.Swift@be0286317c202084784c5a695928cdc985c4ff7b

### GIM-THR12-REV3-MAPPING: Palace kit mappings remain non-policy for lifecycle discovery

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects/palace.code.semantic_search / E-0015, E-0031 / n/a
- Reproduction: Inspect project mappings, then run the bounded tron-kit/evm-kit lifecycle semantic search.
- Expected: Fresh indexed identities bound to policy heads aa691bcd and be028631.
- Actual: Mappings remain non-policy; their lifecycle search returned zero but cannot establish exact-checkout absence.
- Impact: Indexed data cannot own facade or lifecycle-algorithm decisions.
- Workaround: Use Serena and rg at exact policy heads for every load-bearing fact.
- Anchors: TronKit.Swift@aa691bcd, EvmKit.Swift@be028631

### GIM-THR12-RUNTIME-DRIFT: Live Gimle runtime changed after the frozen evidence context

- Class/severity/confidence/status: environment_drift / medium / confirmed / workaround
- Tool/events/claims: palace.health.status / E-0023 / n/a
- Reproduction: Compare state.gimle_snapshot.runtime_id with the current palace.health.status git_sha.
- Expected: The frozen runtime identity remains available or the evidence context can record the current runtime.
- Actual: Checkpoint freezes 52bb684f while the live runtime reports 0e9cf57c; set-context is correctly rejected after evidence.
- Impact: Revision-6 discovery calls cannot claim continuity with the frozen runtime identity.
- Workaround: Treat new Gimle results as discovery-only and base all load-bearing choices on exact Serena plus rg/Git verification at pinned checkouts.
- Anchors: palace.health.status git_sha=0e9cf57c00ff970f584256126b500166580e7a72

### GIM-THR12-VULTISIG-COVERAGE: Vultisig supporting checkout is absent from the Gimle project registry

- Class/severity/confidence/status: coverage_gap / medium / confirmed / workaround
- Tool/events/claims: palace.memory.list_projects / E-0025 / n/a
- Reproduction: Call palace.memory.list_projects and search returned slugs for Vultisig.
- Expected: A discoverable Vultisig project mapping for the designated THOR-support checkout.
- Actual: No Vultisig slug is registered; only local Serena and Git/rg can inspect the pinned checkout.
- Impact: Gimle cannot discover or freshness-check the required THOR-specific supporting candidate.
- Workaround: Activate the exact local Vultisig checkout in Serena and independently verify a bounded supporting/counterexample candidate with rg and Git.
- Anchors: vultisig-ios

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
