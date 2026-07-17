# S1-01 — Package and Public API Foundation

**Status:** slice evidence complete; adversarial review pending; implementation blocked pending review and explicit approval.
**Risk:** normal.
**Observable outcome:** the new standalone Swift Package builds independently of Unstoppable Wallet; a compile-smoke test creates a mainnet `Kit` with mock dependencies, while a locally connected `iOS Example` launches in fixture mode and displays public state without network/secret material.

## Evidence Revision

This revision is bound to ThorChainKit `771bad30bb4ff20fa32ed0f4be260a7b934899e9` on `feature/THR-12-package-public-api` and to these independently verified analog checkouts:

- TronKit `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` — primary package, facade, lifecycle, and Example spine;
- EvmKit `be0286317c202084784c5a695928cdc985c4ff7b` — supporting workspace convention and missing-test counterexample;
- Unstoppable Wallet `5b06860e6e0068f05411cacc568bbb50bca1c588` — consumer shape and lifecycle-ownership evidence only;
- Vultisig iOS `d3123dbe6ef1103937c272a8b1cd81f613af0acc` — zero-case-green supporting counterexample only.

Gimle trust for this slice is **RED** because its mapped TronKit and Unstoppable roots/HEADs differ from the policy-mandated checkouts. Gimle results influenced discovery only; every selected fact was reverified through Serena plus targeted `rg`/Git reads. The slice report is `docs/reports/gimle/THR-12-s1-01-gimle-reliability.md`.

## Goal

Create the minimal scaffold for the future `ThorChainKit.Swift` repository, define the dependency direction, and establish a stable API that feels familiar for Horizontal Systems kits without inheriting their lifecycle/test defects.

## Assumptions

- The package will be created in a separate future repository, not inside Unstoppable Wallet.
- Toolchain: Swift tools `5.10`, because the current WalletCore uses `5.10`.
- Minimum platform: iOS 13, matching TronKit/EvmKit; actors/async require back-deployment verification in CI. If a dependency genuinely requires a newer iOS version, the platform bump is a separate change requiring approval.
- XCTest, not Swift Testing: it is compatible with the selected toolchain and existing ecosystem.
- The public module does not import `MarketKit`, `RxSwift`, `SwiftUI`, `WalletCore`, or app localization.

## Scope

In scope:

- `Package.swift`, the library product, and the test target;
- public facade `ThorChainKit.Kit`;
- base immutable types `Network`, `Address`, `SyncState`, `AccountState`, `EndpointConfiguration`;
- public synchronous snapshot properties and Combine publishers;
- `start()`, `stop()`, `refresh()` with an injected lifecycle implementation for now;
- internal dependency-injection initializer for deterministic tests;
- API documentation and compile smoke;
- runnable `iOS Example` application/workspace based on the verified TronKit structure;
- `.maestro` workspace and the first deterministic launch/public-API acceptance flow.

Out of scope:

- real address derivation, HTTP, persistence, and sync loop;
- send/sign/broadcast/history/swap;
- host adapters;
- public seed/private-key API.

## Proposed Tree

```text
Package.swift
Sources/ThorChainKit/
  Core/Kit.swift
  Core/KitFactory.swift
  Core/KitDependencies.swift
  Models/Network.swift
  Models/Address.swift
  Models/SyncState.swift
  Models/SyncError.swift
  Models/AccountState.swift
  Models/Denom.swift
  Models/EndpointConfiguration.swift
Tests/ThorChainKitTests/
  PublicApiTests.swift
  Fixtures/
iOS Example/
  iOS Example.xcodeproj/
  iOS Example.xcworkspace/
  Sources/
    AppDelegate.swift
    Configuration.swift
    Core/ExampleRuntime.swift
    Controllers/MainController.swift
    Controllers/DiagnosticsController.swift
.maestro/
  config.yaml
  flows/00-launch-foundation.yaml
Scripts/run-maestro.sh
```

Files for S1-02…S1-05 are added by subsequent specs; S1-01 does not create empty speculative classes.

The workspace follows the verified kit contract: `container:iOS Example.xcodeproj` plus `group:..`, so the app target consumes the current root Swift Package rather than a released binary. The original UIKit/app-target structure from TronKit is used as a foundation, but chain-specific send/history screens appear only in the corresponding future slices.

## Package.swift

```swift
// swift-tools-version: 5.10
let package = Package(
    name: "ThorChainKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "ThorChainKit", targets: ["ThorChainKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "ThorChainKit", dependencies: ["BigInt"]),
        .testTarget(name: "ThorChainKitTests", dependencies: ["ThorChainKit"]),
    ]
)
```

`URLSession`, `Foundation`, `Combine`, and `CryptoKit` are system frameworks. S1-03 adds HsCryptoKit and the direct secp256k1 product for address derivation/point validation; HdWalletKit remains an existing host dependency. S1-05 adds GRDB together with persistence. This excludes speculative dependencies from the first slice.

## Public API

### `Kit`

```swift
public final class Kit {
    public let address: Address
    public let network: Network
    public let uniqueId: String

    public var lastBlockHeight: Int64? { get }
    public var syncState: SyncState { get }
    public var accountState: AccountState? { get }
    public var runeBalance: BigUInt { get }
    public var accountExists: Bool { get }

    public var lastBlockHeightPublisher: AnyPublisher<Int64, Never> { get }
    public var syncStatePublisher: AnyPublisher<SyncState, Never> { get }
    public var accountStatePublisher: AnyPublisher<AccountState, Never> { get }

    public func start()
    public func stop()
    public func refresh()
}
```

### Public Factory

```swift
public extension Kit {
    static func instance(
        address: Address,
        network: Network,
        walletId: String,
        endpoints: EndpointConfiguration
    ) throws -> Kit
}
```

Requirements:

- `walletId` is neither logged nor sent over the network; it is used only as a persistence namespace.
- `uniqueId` is lowercase hex `SHA256(walletId UTF-8 || 0x00 || network.persistenceKey UTF-8)`, not ambiguous string concatenation or URL order.
- an empty `walletId` is a typed configuration error.
- the public factory creates production dependencies; an internal initializer accepts `KitDependencies`.
- the factory does not start synchronization automatically.

### `Network`

```swift
public struct Network: Hashable, Sendable {
    public let environment: Environment
    public let expectedChainId: String
    public let accountHrp: String
    public let coinType: UInt32

    public static let mainnet: Network
    public static func stagenet(expectedChainId: String) throws -> Network
    public static func chainnet(expectedChainId: String) throws -> Network
}
```

`mainnet = { chainId: "thorchain-1", hrp: "thor", coinType: 931 }`. Stagenet/chainnet IDs are supplied explicitly; an empty/whitespace-only value is prohibited.

### `Address`

```swift
public struct Address: Hashable, Sendable, CustomStringConvertible {
    public let raw: String
    public let payload: Data
    public let network: Network

    public init(_ raw: String, network: Network) throws
    public var description: String { raw }
}
```

The constructor becomes strict in S1-03. Until then, the compile stub must not accept an obviously invalid string in the production factory; the test uses an internal fixture constructor.

### `AccountState`

```swift
public struct AccountState: Equatable, Sendable {
    public let accountNumber: UInt64?
    public let sequence: UInt64?
    public let balances: [Denom: BigUInt]
    public let acceptedHeight: Int64
    public let fetchedAt: Date
    public let providerFamilyId: String
    public let exists: Bool
}
```

`accountNumber/sequence == nil` is permitted only when `exists == false`; this invariant is checked by the initializer.
The initializer is intentionally internal: `AccountState` is a kit-produced snapshot, not caller configuration. A public memberwise initializer is not part of the promised API.

### `SyncState` and Stable Public Error Surface

```swift
public enum SyncState: Equatable, Sendable {
    case idle(cached: Bool)
    case syncing(previous: AccountState?)
    case synced(AccountState)
    case notSynced(SyncError, cached: AccountState?)
}

public enum SyncError: Error, Equatable, Sendable {
    case noConnection
    case rateLimited
    case wrongNetwork
    case nodeUnavailable
    case invalidResponse
    case storageUnavailable
    case internalInvariant
}
```

Detailed provider/API/GRDB errors remain internal and are mapped to this enum. Public types never reference the internal `EndpointLease`, `ProviderError`, `ApiError`, or storage implementation.

## Dependency Direction

```text
Kit → internal protocols → implementations
Models ← Network / Crypto / Sync / Storage

Forbidden:
ThorChainKit → WalletCore / MarketKit / RxSwift / UI
```

## Threading Contract

- Public getters return the latest atomically accepted snapshot.
- Publishers do not terminate with an error; errors are represented within `SyncState`.
- Lifecycle methods are safe to call from any queue and are idempotent.
- Internal mutable lifecycle/state in subsequent slices belongs to an actor; the facade is not declared `Sendable` without proven synchronization.
- There are no public callbacks/closures: only Combine values and typed snapshots.

## Complete Analog Delta Matrix

### S1-01A — SwiftPM product and test foundation

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit `Package.swift`. Supporting: TronKit local-package Example workspace. Rejected: EvmKit's library-only manifest with no `testTarget` or `Tests/`. |
| Coverage | Contract, implementation, composition, consumer, and tests are verified at TronKit `aa691bcd`; EvmKit `be028631` supplies an independent counterexample. |
| Invariants to preserve | One library product, one library target, a separately runnable test target, and a workspace that consumes `group:..`. |
| Required differences | Swift tools 5.10; iOS 13; exactly the S1-01 dependency set; seven public-API tests from this spec. |
| Rejected differences | TronKit's mature dependency graph, EvmKit's missing tests, speculative targets, and empty future-slice classes. |
| Failure modes | Extra public product, accidental host dependency, unresolved local package, zero discovered tests, or toolchain/platform drift. |
| Tests before code | Manifest/product assertion, compile/link smoke, host-import allowlist, then the seven `PublicApiTests`. |
| Verification | `swift package dump-package`, `swift build`, filtered tests, full tests, and a temporary Swift 5.10/iOS 17 WalletCore consumer. |

### S1-01B — public facade and inert lifecycle

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit `Kit` and `Kit.instance`. Supporting: exact Unstoppable `TronKitManager` consumer and generic `AdapterManager` lifecycle. Rejected: duplicate manager/adapter start ownership in the TronKit demo. |
| Coverage | Contract, implementation, composition, consumer, lifecycle/error, boundary, dependency, state, and trust dimensions are current-tree verified. No matching Tron/Evm lifecycle contract test exists; the test role is explicitly waived as an analog and added as a required delta. |
| Invariants to preserve | Public facade, synchronous snapshot access, nonfailing Combine publishers, explicit `start/stop/refresh`, and one composition root. |
| Required differences | Empty-wallet rejection, collision-resistant `uniqueId`, internal lifecycle DI, idle/zero initial state, no fake account, and no factory auto-start. |
| Rejected differences | Ambiguous `walletId-network` concatenation, public seed/private-key handling, public internal managers/storage, host imports, or two lifecycle owners. |
| Failure modes | Empty namespace, unique-ID collision, lifecycle call amplification, auto-start, non-idempotent stop, publisher error termination, or fabricated account state. |
| Tests before code | Empty wallet ID; factory inertness; exact lifecycle forwarding; initial idle/zero/no-account snapshot; public import surface. |
| Verification | `PublicApiTests`, source-import allowlist, API-symbol audit, and temporary WalletCore consumer build. |

### S1-01C — local-package Example and fixture UI gate

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit Example project/workspace/shared scheme. Supporting: EvmKit's independent `group:..` workspace. Rejected: persisted demo mnemonics/duplicate starts and Vultisig's zero-case-green fixture filter. |
| Coverage | App implementation, composition, consumer, package boundary, and dependency direction are verified. No applicable UI-test/Maestro analog exists in TronKit/EvmKit; the test role is explicitly waived as an analog and introduced as a task-specific delta. |
| Invariants to preserve | Separate app project, shared runnable scheme, workspace link to the root package, and a thin Example-only runtime. |
| Required differences | Fixture-only default, stable accessibility IDs, visible `FIXTURE` badge, no secret entry/storage, one launch flow, and manifest/JUnit-count guards. |
| Rejected differences | Hardcoded or persisted mnemonic, provider credential, manager-owned start plus adapter start, localized/coordinate selectors, fixed sleeps, and a green zero-test result. |
| Failure modes | Wrong app ID, package not linked, nonbooted simulator ambiguity, undiscovered flow, zero JUnit cases, fixture labeled live, or secret leakage in YAML/logs/screenshots. |
| Tests before code | Static manifest/flow count and secret scan, then build/install/launch assertions for network, address, sync state, data source, and inert lifecycle. |
| Verification | Workspace build, fixture Maestro flow, JUnit-count assertion, artifact canary scan, and explicit recording when Maestro is unavailable. |

## Open Questions for Adversarial Review

1. `Address.init(_:, network:)` promises a decoded `payload`, while the strict Bech32 codec belongs to S1-03. The review must choose between postponing public construction until S1-03 or explicitly moving the minimum decode/validation behavior into S1-01; implementation must not invent an empty/fake payload.
2. The roadmap contract requires the same implementation PR to contain the actual squash-merge commit SHA. That SHA does not exist before GitHub creates the squash commit. The review must propose a mechanically satisfiable marker rule before implementation begins; `TBD`, a head SHA mislabeled as a merge SHA, direct push, and a silent second PR remain prohibited.

## Tests Before Implementation

`Tests/ThorChainKitTests/PublicApiTests.swift`:

1. `testPackageExposesSingleThorChainKitProduct()` — compile/link smoke.
2. `testMainnetConstants()` — `thorchain-1`, `thor`, `931`.
3. `testFactoryRejectsEmptyWalletId()`.
4. `testFactoryDoesNotStartLifecycle()`.
5. `testStartStopRefreshForwardExactlyOnceToInjectedLifecycle()`.
6. `testInitialSnapshotIsIdleAndZeroWithoutPretendingAccountExists()`.
7. `testPublicSurfaceDoesNotImportHostModules()` — CI script/`swift package dump-package` + source import allowlist.

`.maestro/flows/00-launch-foundation.yaml`:

- launches the Example app with `clearState: true` and fixture mode;
- checks the visible `network`, `address`, `sync-state`, and `data-source` accessibility identifiers;
- proves that `data-source == FIXTURE`, the kit has not yet started automatically, and the UI contains no seed/private-key field;
- saves screenshots only in ignored build artifacts.

`Scripts/run-maestro.sh` verifies the CLI/version, builds and installs the simulator app, supplies `APP_ID`, and writes JUnit/screenshots/logs to `build/maestro-results`. Before launch, the script checks the expected flow manifest from `config.yaml`, prohibits an empty suite, and after completion checks the expected number of JUnit cases—the Vultisig-style “0 cases = green” outcome is unacceptable. Live flows are not part of the default invocation; they require `THORCHAIN_LIVE_TESTS=1`.

Do not use fixed sleeps. The mock lifecycle records calls synchronously and provides an expectation.

## Verification

```text
swift package resolve
swift build
swift test --filter PublicApiTests
swift test
swift package dump-package
xcodebuild build -workspace "iOS Example/iOS Example.xcworkspace" -scheme "iOS Example" -destination <simulator>
maestro test .maestro/flows/00-launch-foundation.yaml
```

Host compatibility is verified separately with a temporary consumer target using the current Swift 5.10/iOS 17 WalletCore settings.

## Acceptance Criteria

- The package builds independently and contains one `ThorChainKit` library product.
- `ThorChainKitTests` exists and runs.
- Public symbols and signatures match the spec, or the change is separately approved.
- The factory does not start network/sync.
- There is no seed/private key, MarketKit, RxSwift, SwiftUI, or WalletCore in the public API.
- All seven tests above are green.
- The Example app launches from the shared workspace/scheme and uses the local package root.
- The first Maestro flow is green; Example source contains no mnemonic, API key, or endpoint credential.
- S1-02…S1-05 can be added without changing the base public facade, except through additive API.

## Pinned Decision

The minimum target is iOS 13 for parity with TronKit/EvmKit. S1-03/S1-05 dependency resolution must confirm HsCryptoKit/GRDB compatibility with iOS 13; incompatibility returns the spec for review, and the target is not raised silently.
