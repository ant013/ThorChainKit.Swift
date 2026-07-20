# Kit Example apps and UI acceptance strategy

## Short answer

`TronKit` and `EvmKit` have separate runnable `iOS Example` apps. These are application targets for manual interaction with the real network, not automated UI-test bundles. `<Testables>` is empty in the shared schemes of both apps.

ThorChainKit adopts a composite model:

1. `ThorChainKitTests` establishes deterministic correctness.
2. `iOS Example` becomes the permanent SwiftUI + Combine manual/live harness; TronKit contributes only its project/workspace/package topology and functional scenarios.
3. Maestro flows perform UI acceptance of the Example app for every slice.
4. `Unstoppable/AppTests` establishes host contracts.
5. Unstoppable is verified through `AppTests` and a manual product checklist; Maestro is not used in the host repository.

## Verified sources

| Repository | HEAD | Runnable app | Automated package tests |
|---|---|---|---|
| TronKit.Swift | `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` | `iOS Example` / `TronKit Demo.app` | `TronKitTests`, 2 XCTest files |
| EvmKit.Swift | `be0286317c202084784c5a695928cdc985c4ff7b` | `iOS Example` / `EvmKit Demo.app` | none |

### TronKit anchors

- `TronKit.Swift@aa691bcd:Package.swift:41` — separate SwiftPM `TronKitTests` target.
- `TronKit.Swift@aa691bcd:iOS Example/iOS Example.xcodeproj/project.pbxproj:160` — application target.
- `TronKit.Swift@aa691bcd:iOS Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme:25` — runnable scheme with empty `Testables`.
- `TronKit.Swift@aa691bcd:iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata:4` — project plus `group:..`, meaning the root local package.
- `TronKit.Swift@aa691bcd:iOS Example/Sources/Core/Manager.swift:23` — Kit/signer/adapter composition.
- `TronKit.Swift@aa691bcd:iOS Example/Sources/Controllers/MainController.swift:10` — balance/history/receive/native send/TRC20 send tabs.
- `TronKit.Swift@aa691bcd:README.md:59` — app described as a starting point for library usage.

### EvmKit anchors

- `EvmKit.Swift@be028631:Package.swift:25` — library target only; no test target.
- `EvmKit.Swift@be028631:iOS Example/iOS Example.xcodeproj/project.pbxproj:154` — application target.
- `EvmKit.Swift@be028631:iOS Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme:25` — runnable scheme with empty `Testables`.
- `EvmKit.Swift@be028631:iOS Example/iOS Example.xcworkspace/contents.xcworkspacedata:4` — project plus root package.
- `EvmKit.Swift@be028631:iOS Example/Sources/Core/Manager.swift:23` — Kit/signer/adapter composition.
- `EvmKit.Swift@be028631:iOS Example/Sources/Controllers/MainController.swift:10` — balance/history/receive/send tabs.
- `EvmKit.Swift@be028631:README.md:209` — app described as a starting point.

## What can be used as a foundation

Preserved:

- `iOS Example` directory;
- separate `.xcodeproj`, shared scheme, and `.xcworkspace`;
- workspace linkage to the root of the local Swift Package;
- a thin runtime/adapter facade between the Kit and screens;
- incremental expansion of the tab/screen surface: address → balance → receive → send → history;
- support for mnemonic and watch-only scenarios once the corresponding feature is authorized by the spec.

Not carried over:

- an embedded mnemonic or provider credentials;
- storing the mnemonic in `UserDefaults`;
- implicitly unwrapped singleton state;
- `Manager`-owned `start()` alongside the adapter lifecycle;
- logout without established `stop()`/cancellation;
- an “all features covered” claim without assertions.

Thus, only the Example application/workspace topology and functional scenario inventory are carried over. UIKit lifecycle/controllers are rejected; the repository-owned Example uses a SwiftUI `App`, SwiftUI views, and Combine-backed observation under the approved ThorChainKit contract.

## Verification of the general Horizontal Systems convention

A runnable app exists in most chain kits: BitcoinKit, BitcoinCashKit, DashKit, BinanceChainKit, HdWalletKit, MarketKit, TonKit, StellarKit, and MoneroKit. However, the presence of an app says almost nothing about the presence of tests: many packages have a demo but no test target.

The most useful combination is:

- TronKit — chain-demo topology and functional scenarios, not its UIKit implementation;
- TonKit `DemoApp` — the SwiftUI shell reference for the already approved UIKit-free presentation boundary;
- HdWalletKit — proper separation of a small runnable demo and independent derivation XCTest;
- current Unstoppable contracts — the only authoritative production adapter lifecycle.

## ThorChainKit `iOS Example`

S1-01 creates the app; subsequent slices extend it:

The target presentation architecture is SwiftUI + Combine. `Sources/ThorChainKit` remains UI-agnostic; UIKit is prohibited in both the library and Example, while SwiftUI is confined to the Example. The already merged UIKit scaffold is migration debt and must be replaced before the next Example screen is added.

| Slice | Screen/outcome |
|---|---|
| S1-01 | local package launch, Network/Address/SyncState compile surface, explicit fixture badge |
| S1-02 | endpoint family, expected/actual chain ID, height, catching-up, failure reason |
| S1-03 | full address derivation/validation, watch-only input, wrong HRP/checksum |
| S1-04 | complete account/bank read, pagination result, active family |
| S1-05 | start/stop/refresh, cached/fresh/error state, app restart |
| Sprint 2 | fee/sequence, build/sign/broadcast and native RUNE send |
| Sprint 3 | transaction history/status and explorer |

The default mode is a read-only fixture. Live mode requires explicit launch configuration. No secret material is committed or persisted by the app.

## UI acceptance through Maestro

The user's term `Meteora` is currently interpreted as **Maestro**: no separate available framework/tool named Meteora was found. If there is an internal Meteora, this section must be rebound to its actual contract before implementation.

Maestro CLI is not installed on the current machine (`command -v maestro` is empty); therefore, the architecture and acceptance contracts are recorded, but the YAML flows themselves have not yet been created or run.

Maestro uses YAML flows, `appId`, environment variables, and commands such as `launchApp`, `tapOn`, `inputText`, and `assertVisible`; flows can be composed through `runFlow`. The official docs also support a separate output directory, screenshots/logs, and JUnit reporting: [iOS setup](https://docs.maestro.dev/getting-started/build-and-install-your-app/ios), [flow model](https://docs.maestro.dev/maestro-flows), [workspace configuration](https://docs.maestro.dev/reference/workspace-configuration), [reports/artifacts](https://docs.maestro.dev/cli/test-suites-and-reports).

Proposed tree:

```text
.maestro/
  config.yaml
  common/
    launch-fixture.yaml
    assert-diagnostics.yaml
  flows/
    00-launch-foundation.yaml
    01-endpoint-policy.yaml
    02-address-codec.yaml
    03-account-read-fixture.yaml
    04-lifecycle-restart.yaml
  flows-live/
    03-account-read-mainnet.yaml
```

The tool boundary is strict: `.maestro`, YAML flows, runner scripts, and acceptance-only launch arguments exist only in the future `ThorChainKit` repository and run only its `iOS Example`. No such files or hooks are added to Unstoppable.

## Acceptance rules

- Selectors are based on stable accessibility IDs, not coordinates or localized text.
- Fixture mode runs in default CI; live mode is always opt-in.
- The UI explicitly displays `FIXTURE` or `LIVE` so fixture success cannot be mistaken for network evidence.
- `APP_ID`, an allowlisted public fixture ID/address, endpoints, and the live flag are passed through environment variables; mnemonic text is not stored in YAML.
- YAML, screenshots, JUnit, and logs contain no seed/private key/provider credentials.
- A UI flow does not replace unit assertions for raw values, cancellation/CAS, and DTO parsing.
- An Example flow does not replace the real Unstoppable adapter/AppTests gate.
- Live skip/unavailable is recorded as unrun with a reason, not as green success.
- The launcher checks the expected flow manifest and JUnit case count; an empty/undiscovered suite is a failure.

## Unstoppable acceptance surface

Current Unstoppable has no separate demo or UI-test target. It has `App`, host-based `AppTests`, and a shared `Development` scheme:

- `unstoppable-wallet-ios@5b06860e:Unstoppable/Unstoppable.xcodeproj/project.pbxproj:321` — app/test targets.
- `unstoppable-wallet-ios@5b06860e:Unstoppable/Unstoppable.xcodeproj/xcshareddata/xcschemes/Development.xcscheme:10` — App + AppTests.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Core/Managers/AdapterManager.swift:74` — actual start/stop owner.
- `unstoppable-wallet-ios@5b06860e:packages/WalletCore/Sources/WalletCore/Modules/AppStatus/AppStatusViewModel.swift:84` — existing status-diagnostics consumer to which THORChain must be added.

Therefore, package UI acceptance and host integration remain two independent gates: the first is automated with Maestro in `iOS Example`; the second uses `AppTests` and a manual run of Unstoppable without Maestro.

## Gimle reliability note

Gimle semantic search did not surface the existing Example-app symbols for either TronKit or EvmKit, even though the current trees contain app targets. The results also lacked per-row commit linkage. The conclusions in this report are based on Serena, Xcode project/workspace inspection, and targeted `rg`; Gimle remains discovery-only pending repeat verification after index repair.
