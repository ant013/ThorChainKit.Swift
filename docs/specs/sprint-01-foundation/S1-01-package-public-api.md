# S1-01 — Package and Public API Foundation

**Status:** revision 3 after adversarial REVISE; implementation blocked pending fresh review and explicit approval.
**Risk:** normal.
**Observable outcome:** the standalone Swift Package builds independently of Unstoppable Wallet; a public-only consumer constructs validated network, endpoint, address, and `Kit` values without starting work, while a locally connected `iOS Example` launches in fixture mode and displays the exact nil/idle/zero initial state without network or secret material.

## Evidence Revision

This revision is bound to ThorChainKit `771bad30bb4ff20fa32ed0f4be260a7b934899e9` on `feature/THR-12-package-public-api` and to these independently verified analog checkouts:

- TronKit `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` — primary package, facade, lifecycle, and Example spine;
- EvmKit `be0286317c202084784c5a695928cdc985c4ff7b` — supporting workspace convention and missing-test counterexample;
- Unstoppable Wallet `5b06860e6e0068f05411cacc568bbb50bca1c588` — consumer shape and lifecycle-ownership evidence only;
- Vultisig iOS `d3123dbe6ef1103937c272a8b1cd81f613af0acc` — zero-case-green supporting counterexample only.

Gimle trust for this slice is **RED** because its mapped TronKit and Unstoppable roots/HEADs differ from the policy-mandated checkouts. Gimle results influenced discovery only; every selected fact was reverified through Serena plus targeted `rg`/Git reads. The slice report is `docs/reports/gimle/THR-12-s1-01-gimle-reliability.md`.

## Goal

Create the minimal scaffold in this authoritative `ThorChainKit.Swift` repository, define the dependency direction, and establish a constructible fail-closed API that feels familiar for Horizontal Systems kits without inheriting their lifecycle/test defects.

## Assumptions

- This repository is the product authority for the standalone package; Unstoppable Wallet remains a separate future consumer.
- Toolchain: Swift tools `5.10`. CI selects Xcode `26.3` (`17C529`) with Apple Swift `6.2.4`, asserts those exact identities, and compiles in Swift 5 language mode.
- Minimum platform: iOS 13, matching TronKit/EvmKit; actors/async require back-deployment verification in CI. If a dependency genuinely requires a newer iOS version, the platform bump is a separate change requiring approval.
- XCTest, not Swift Testing: it is compatible with the selected toolchain and existing ecosystem.
- The public module does not import `MarketKit`, `RxSwift`, `SwiftUI`, `WalletCore`, or app localization.

## Scope

In scope:

- `Package.swift`, the library product, and the test target;
- public facade `ThorChainKit.Kit`;
- the complete immutable value layer required by the public factory: `Network`, `EndpointFamilyDescriptor`, `EndpointPolicy`, `EndpointConfiguration`, `Denom`, `Address`, `SyncState`, and `AccountState`;
- construction-time validation and typed configuration/address errors;
- strict classic-Bech32 address decoding sufficient to construct a canonical network-bound 20-byte account address;
- public synchronous snapshot properties and Combine publishers;
- `start()`, `stop()`, `refresh()` with an injected lifecycle implementation for now;
- internal dependency-injection initializer for deterministic tests;
- API documentation and compile smoke;
- runnable `iOS Example` application/workspace based on the verified TronKit structure;
- `.maestro` workspace and the first deterministic launch/public-API acceptance flow.

Out of scope:

- public-key derivation, secp256k1 validation, hashing, public payload encoding, HTTP, endpoint probing/failover, persistence, and sync loop;
- send/sign/broadcast/history/swap;
- host adapters;
- public seed/private-key API.

## Proposed Tree

```text
Package.swift
Sources/ThorChainKit/
  ThorChainKit.swift
  Core/Kit.swift
  Core/KitFactory.swift
  Core/KitDependencies.swift
  Address/AddressError.swift
  Address/Bech32Codec.swift
  Address/BitConversion.swift
  Models/Network.swift
  Models/Address.swift
  Models/SyncState.swift
  Models/SyncError.swift
  Models/AccountState.swift
  Models/Denom.swift
  Models/EndpointConfiguration.swift
  Network/EndpointFamilyDescriptor.swift
  Network/EndpointPolicy.swift
Tests/ThorChainKitTests/
  PublicApiTests.swift
  Fixtures/S1-01-public-symbols.txt
  Fixtures/S1-01-tests.txt
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
Scripts/verify-s1-01.sh
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
Scripts/scan-s1-01-artifacts.swift
.github/workflows/ci.yml
```

Files for S1-02…S1-05 are added by subsequent specs; S1-01 does not create empty speculative classes.

The workspace follows the verified kit contract: `container:iOS Example.xcodeproj` plus `group:..`, so the app target consumes the current root Swift Package rather than a released binary. The original UIKit/app-target structure from TronKit is used as a foundation, but chain-specific send/history screens appear only in the corresponding future slices.

## Package.swift

```swift
// swift-tools-version: 5.10
import PackageDescription

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

    public var lastBlockHeight: Int64? { get }
    public var syncState: SyncState { get }
    public var accountState: AccountState? { get }
    public var runeBalance: BigUInt { get }
    public var accountExists: Bool { get }

    public var lastBlockHeightPublisher: AnyPublisher<Int64?, Never> { get }
    public var syncStatePublisher: AnyPublisher<SyncState, Never> { get }
    public var accountStatePublisher: AnyPublisher<AccountState?, Never> { get }

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

- a `walletId` whose entire contents are whitespace/newlines is rejected with `KitConfigurationError.invalidWalletId`; accepted IDs are not trimmed or rewritten before hashing.
- neither `walletId` nor its digest is public or returned by the kit. Kit- and Example-controlled logs, telemetry, URLs, headers, error descriptions, Maestro/JUnit output, accessibility values, and screenshots never emit either value.
- the internal `persistenceNamespace` is lowercase hex `SHA256(walletId UTF-8 || 0x00 || network.persistenceKey UTF-8)`, not ambiguous string concatenation or URL order.
- `network.persistenceKey` is internal and exactly `environment.rawValue UTF-8 || 0x00 || expectedChainId UTF-8`; construction rejects control characters, so the delimiter is unambiguous.
- `address.network` must equal `network`; mismatch throws `KitConfigurationError.addressNetworkMismatch` without rebinding the address or fabricating payload bytes.
- in S1-01 the public factory creates only the exact nil/idle/zero snapshot plus an internal `NoOpLifecycle`. Construction, `start`, `stop`, and `refresh` create no URL session, storage handle, task, timer, or network request; later sync/storage slices replace this inert dependency through the internal composition root.
- an internal initializer accepts `KitDependencies` for deterministic lifecycle tests; no dependency type is public.
- the factory does not start synchronization automatically.

```swift
public enum KitConfigurationError: Error, Equatable {
    case invalidWalletId
    case addressNetworkMismatch
    case invalidChainId
    case invalidDenom
}
```

`Network.stagenet/chainnet` throw `.invalidChainId`; `Denom.init` throws `.invalidDenom`. These cases carry no rejected input, so error descriptions cannot disclose wallet/configuration material.

### `Network`

```swift
public struct Network: Hashable, Sendable {
    public enum Environment: String, Hashable, Sendable {
        case mainnet
        case stagenet
        case chainnet
    }

    public let environment: Environment
    public let expectedChainId: String
    public let accountHrp: String
    public let coinType: UInt32

    public static let mainnet: Network
    public static func stagenet(expectedChainId: String) throws -> Network
    public static func chainnet(expectedChainId: String) throws -> Network
}
```

`mainnet = { environment: .mainnet, chainId: "thorchain-1", hrp: "thor", coinType: 931 }`. `stagenet(expectedChainId:)` always uses `.stagenet`, HRP `"sthor"`, and coin type `931`; `chainnet(expectedChainId:)` always uses `.chainnet`, HRP `"cthor"`, and coin type `931`. Their chain IDs are supplied explicitly and stored exactly; an empty/whitespace-only/control-containing value is prohibited. There is no arbitrary initializer that can detach HRP or coin type from environment.

### Endpoint Values

```swift
public struct EndpointFamilyDescriptor: Hashable, Sendable {
    public let id: String
    public let cosmosRestURL: URL
    public let cometBftURL: URL

    public init(id: String, cosmosRestURL: URL, cometBftURL: URL) throws
}

public struct EndpointPolicy: Hashable, Sendable {
    public let maximumHeightLag: Int64
    public let identityRevalidationInterval: TimeInterval
    public let retryableStatusCodes: Set<Int>
    public let maximumAttempts: Int?
    public let maximumBalancePageCount: Int

    public init(
        maximumHeightLag: Int64 = 5,
        identityRevalidationInterval: TimeInterval = 300,
        retryableStatusCodes: Set<Int> = [408, 429, 502, 503, 504],
        maximumAttempts: Int? = nil,
        maximumBalancePageCount: Int = 100
    ) throws

    public static let `default`: EndpointPolicy
}

public struct EndpointConfiguration: Sendable {
    public let families: [EndpointFamilyDescriptor]
    public let clientId: String?
    public let requestTimeout: TimeInterval
    public let policy: EndpointPolicy
    public var effectiveMaximumAttempts: Int { get }

    public init(
        families: [EndpointFamilyDescriptor],
        clientId: String? = nil,
        requestTimeout: TimeInterval = 15,
        policy: EndpointPolicy = .default
    ) throws
}

public enum EndpointConfigurationError: Error, Equatable {
    case emptyFamilies
    case duplicateFamilyId(String)
    case invalidFamilyId
    case invalidClientId
    case insecureURL
    case urlContainsCredentialsQueryOrFragment
    case invalidPolicyField(String)
}
```

S1-01 owns these immutable values and construction checks: families are non-empty; each family ID is trimmed once, rejected if empty or control-containing, stored in trimmed form, and deduplicated against the other stored IDs; both URLs use `https`, have a nonempty host, and contain no credentials/query/fragment; `clientId` is trimmed once, rejects control characters, and maps empty to nil; timeout and revalidation interval are finite positive `TimeInterval` values measured in seconds; height lag is nonnegative; retryable codes are a subset of `408/429/502/503/504`; page count is in `1...1000`; and explicit attempts are in `1...families.count`. Nil attempts mean each family at most once and `effectiveMaximumAttempts == families.count`. S1-02 consumes these values and adds probing, identity verification, health, leases, and selection; it does not redeclare or relax construction.

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

`Address.init` is strict in S1-01. It rejects empty/surrounding-whitespace input, mixed case, invalid characters/separator/length, classic-Bech32 checksum failure, wrong HRP for the supplied `Network`, non-zero or overlong convertBits padding, non-20-byte payloads, and any normalized input that does not equal its canonical re-encoding. All-uppercase valid input is accepted and stored as canonical lowercase. There is no unchecked public, SPI, or Example-only constructor. The minimum decoder and its private re-encode check are owned by S1-01; public payload encoding, public-key derivation, secp256k1 validation, and hashing remain S1-03.

```swift
public enum AddressError: Error, Equatable {
    case empty
    case invalidCharacter(Character)
    case mixedCase
    case tooLong
    case missingSeparator
    case invalidChecksum
    case invalidPadding
    case wrongHrp(expected: String, actual: String)
    case invalidPayloadLength(expected: Int, actual: Int)
}
```

### `Denom`

```swift
public struct Denom: Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) throws
    public static let rune: Denom
}
```

`Denom` is non-empty, contains no whitespace/control characters, is opaque and case-sensitive, permits `/`, and recognizes native RUNE only as exact lowercase `rune`. S1-04 consumes this value and does not redeclare it.

### `AccountState`

```swift
public struct AccountState: Equatable {
    public let accountNumber: UInt64?
    public let sequence: UInt64?
    public let balances: [Denom: BigUInt]
    public let acceptedHeight: Int64
    public let fetchedAt: Date
    public let providerFamilyId: String
    public let exists: Bool
}
```

`accountNumber` and `sequence` are both nonnil if and only if `exists == true`. Mixed optional pairs, either value when `exists == false`, and missing values when `exists == true` are rejected by the internal throwing initializer.
The initializer is intentionally internal: `AccountState` is a kit-produced snapshot, not caller configuration. A public memberwise initializer is not part of the promised API.

### `SyncState` and Stable Public Error Surface

```swift
public enum SyncState: Equatable {
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

`AccountState` and `SyncState` are intentionally not `Sendable` in S1-01 because the declared minimum BigInt `v5.0.0` defines `BigUInt` without `Sendable`. The synchronized facade owns their publication. A future conformance requires a separately verified dependency/toolchain change; `@unchecked Sendable` is prohibited.

## Dependency Direction

```text
Kit → internal protocols → implementations
Models ← Network / Crypto / Sync / Storage

Forbidden:
ThorChainKit → WalletCore / MarketKit / RxSwift / UI
```

## Threading Contract

- One internal owner uses one nonrecursive lock for snapshot reads and lifecycle state; neither the Example nor a host manager owns a second lifecycle state machine.
- Public getters acquire that lock and return one accepted snapshot.
- Each publisher has current-value semantics: a new subscriber immediately receives the current value. S1-01 has no post-construction snapshot mutation seam, so its only emissions are exactly `nil`, `.idle(cached: false)`, and `nil` for height, sync state, and account state respectively. S1-02 must separately specify later publication/reset behavior.
- Combine subscription/delivery and every subject `send` occur with the owner lock released. A subscriber may synchronously read getters and call `start/refresh/stop` during delivery without deadlock or recursive lock acquisition.
- Publishers do not terminate with an error; errors are represented within `SyncState`.
- The linearization point for `start()` and `stop()` is the locked inspection/update of the private running flag. The internal lifecycle callback is forwarded exactly once while the same lock still owns that order; S1-01's production callback is the non-reentrant no-op dependency.
- `start()` is an idempotent transition: stopped → running forwards one internal `start`; a call linearized while running is a no-op.
- `stop()` is an idempotent transition: running → stopped forwards one internal `stop`; a call linearized while stopped is a no-op.
- The linearization point for `refresh()` is the locked running-state read. A call linearized while running forwards exactly once before the lock is released; a call linearized while stopped is a no-op.
- Nonoverlapping calls respect return-before-invocation order. Calls whose intervals overlap may acquire the lock in either order, and the legal result is the corresponding sequential trace: `stop || start` from stopped may end stopped or running; `refresh || start` may no-op then start or start then forward refresh. Two overlapping starts or stops still forward at most one transition.
- S1-01 tests use barriers/expectations and explicit call-entry control, never sleeps, to exercise both legal overlap orders, exact callback counts, and final state.
- Internal mutable sync/storage state in later slices remains actor-owned behind this facade; the facade itself is not declared `Sendable` without separately proven synchronization.
- There are no public callbacks/closures: only Combine values and typed snapshots.

## Complete Analog Delta Matrix

### S1-01A — SwiftPM product and test foundation

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit `Package.swift`. Supporting: TronKit local-package Example workspace. Rejected: EvmKit's library-only manifest with no `testTarget` or `Tests/`. |
| Coverage | Contract, implementation, composition, consumer, and tests are verified at TronKit `aa691bcd`; EvmKit `be028631` supplies an independent counterexample. |
| Invariants to preserve | One library product, one library target, a separately runnable test target, and a workspace that consumes `group:..`. |
| Required differences | Swift tools 5.10; iOS 13; Xcode 26.3/Swift 6.2.4 CI identity with Swift 5 mode; exactly the S1-01 dependency set; behavioral XCTest bodies staged with their owning values/facade; the complete 18-method allowlist locked only afterward; separate executable manifest/import/symbol/discovery/consumer gates. |
| Rejected differences | TronKit's mature dependency graph, EvmKit's missing tests, speculative targets, and empty future-slice classes. |
| Failure modes | Extra public product, accidental host dependency, unresolved local package, zero discovered tests, or toolchain/platform drift. |
| Tests before code | The independent topology gate first; methods 1–12 before the value layer; methods 13–18 before the facade; then canaries for manifest topology, import allowlist, symbol allowlist, exact completed test discovery, strict concurrency, and the external iOS consumer. |
| Verification | Parsed `swift package dump-package` JSON, Swift-5 strict-concurrency warnings-as-errors build, filtered/full tests, generated symbol-graph comparison, and a temporary Swift-tools-5.10/iOS-13 public-only consumer built by the pinned Xcode. |

### S1-01B — public facade and inert lifecycle

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit `Kit` and `Kit.instance`. Supporting: exact Unstoppable `TronKitManager` consumer and generic `AdapterManager` lifecycle. Rejected: duplicate manager/adapter start ownership in the TronKit demo. |
| Coverage | Contract, implementation, composition, consumer, lifecycle/error, boundary, dependency, state, and trust dimensions are current-tree verified. No matching Tron/Evm lifecycle contract test exists; the test role is explicitly waived as an analog and added as a required delta. |
| Invariants to preserve | Public facade, synchronous snapshot access, nonfailing Combine publishers, explicit `start/stop/refresh`, and one composition root. |
| Required differences | Whitespace-only wallet rejection, address/network equality, collision-resistant internal `persistenceNamespace`, one explicitly linearized lifecycle owner, publisher delivery outside its lock, optional replaying publishers, idle/nil/zero initial state, no fake account, and an inert no-op factory. |
| Rejected differences | Ambiguous `walletId-network` concatenation, public seed/private-key handling, public internal managers/storage, host imports, or two lifecycle owners. |
| Failure modes | Empty namespace, namespace disclosure, unique-ID collision, address rebinding, lifecycle call amplification, auto-start, non-idempotent transitions, absent state coerced to zero, publisher error termination, or fabricated account state. |
| Tests before code | Invalid wallet/network inputs; factory inertness; both legal concurrent lifecycle orders and call counts; immediate optional publisher replay with synchronous getter/lifecycle reentry; idle/nil/zero/no-account snapshot. |
| Verification | `PublicApiTests`, source-import allowlist, API-symbol audit, strict-concurrency compile, and the standalone public-only iOS-13 consumer build. |

### S1-01C — local-package Example and fixture UI gate

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit Example project/workspace/shared scheme. Supporting: EvmKit's independent `group:..` workspace. Rejected: persisted demo mnemonics/duplicate starts and Vultisig's zero-case-green fixture filter. |
| Coverage | App implementation, composition, consumer, package boundary, and dependency direction are verified. No applicable UI-test/Maestro analog exists in TronKit/EvmKit; the test role is explicitly waived as an analog and introduced as a task-specific delta. |
| Invariants to preserve | Separate app project, shared runnable scheme, workspace link to the root package, and a thin Example-only runtime. |
| Required differences | Fixture-only default, stable accessibility IDs, visible `FIXTURE` badge, no secret or namespace entry/storage/output, one exact-UDID runner, argv-observable device canaries, strict manifest/JUnit-count guards, and Vision OCR over screenshots. |
| Rejected differences | Hardcoded or persisted mnemonic, provider credential, manager-owned start plus adapter start, localized/coordinate selectors, fixed sleeps, and a green zero-test result. |
| Failure modes | Wrong app ID, package not linked, nonbooted simulator ambiguity, undiscovered flow, zero JUnit cases, fixture labeled live, or secret leakage in YAML/logs/screenshots. |
| Tests before code | Static manifest/flow count and scanner canaries; an exact-destination Example build; then command shims that record argv and reject a wrong UDID before live build/install/launch assertions. |
| Verification | One `THORCHAIN_SIMULATOR_UDID` for boot/build/install/launch/`maestro --device`; JUnit attributes `tests=1 failures=0 errors=0 skipped=0`; tracked-input, raw-artifact, and Vision-OCR text scans; canaries injected only into a temporary copy; and explicit recording when Maestro is unavailable. |

## Resolved Adversarial Rulings

1. `Address.init(_:, network:)` owns strict minimum classic-Bech32 decode/canonical validation in S1-01. No unchecked fixture path exists. S1-03 owns public payload encoding and public-key derivation only.
2. The implementation PR changes the roadmap marker to contain its real PR number only. Reviewer, QA, and CI evidence bind to one final `headRefOid`; any push invalidates prior review/QA. After squash merge, the CTO records `mergeCommit.oid` in Paperclip, verifies it is on `origin/main`, and verifies the PR-number marker there before closing the slice. No `TBD`, merge-SHA placeholder, head mislabeled as merge, direct push, or roadmap-only follow-up PR is permitted.
3. The iOS 13 floor remains pinned. Endpoint durations are finite positive `TimeInterval` seconds, not iOS-16-only `Duration`; `Denom` keeps a throwing validator without claiming `RawRepresentable`.
4. Stagenet and chainnet fix HRPs to `sthor` and `cthor` respectively and use coin type `931`. `AccountState`, `SyncState`, and `SyncError` are owned and tested in S1-01.
5. The persistence digest is internal. The S1-01 public factory composes only a no-op lifecycle and inert initial snapshot; it creates no network, storage, timer, or task.
6. Lifecycle calls linearize at the locked running-state inspection/update. Overlapping calls may take either lock order; Combine delivery occurs after the lock is released and is tested with synchronous subscriber reentry.
7. The standalone consumer targets iOS 13 under the pinned CI Xcode/Swift identity and a separately named Swift-5 strict-concurrency warnings-as-errors gate. The exact-device runner exposes every device-bearing argv to a shim canary and OCRs screenshot text before secret/namespace acceptance.

## Tests Before Implementation

`Tests/ThorChainKitTests/PublicApiTests.swift`:

The authoritative behavioral XCTest list contains exactly 18 methods. Methods 1–12 are added with the value layer, methods 13–18 are added with the facade, and the complete discovery allowlist is created only after method 18 exists:

1. `testNetworkConstants()`.
2. `testNetworkRejectsBlankOrControlContainingChainId()`.
3. `testNetworkPersistenceKeyIncludesEnvironmentAndExactChainId()`.
4. `testEndpointConfigurationNormalizesAndAcceptsSingleFamilyDefaults()`.
5. `testEndpointConfigurationRejectsInvalidValues()`.
6. `testDenomAcceptsRuneAndRejectsInvalidValues()`.
7. `testStateModelsEnforceAccountExistenceAndStableSyncErrors()`.
8. `testAddressCanonicalizesValidMainnetAndUppercase()`.
9. `testAddressRejectsStructureCaseAndCanonicalViolations()`.
10. `testAddressRejectsClassicChecksumAndBech32m()`.
11. `testAddressRejectsWrongHrp()`.
12. `testAddressRejectsInvalidPaddingOrPayloadLength()`.
13. `testFactoryRejectsWhitespaceOnlyWalletId()`.
14. `testFactoryRejectsAddressNetworkMismatch()`.
15. `testFactoryCreatesNoWorkAndDoesNotStartLifecycle()`.
16. `testLifecycleSerializesIdempotentStartStopAndRunningRefresh()`.
17. `testInitialPublishersAllowReentrantSnapshotAndLifecycleAccess()`.
18. `testPersistenceNamespaceIsDeterministicInternalAndAbsentFromErrors()`.

Method 5 covers hostless HTTPS URLs, non-finite/nonpositive seconds, normalized duplicate IDs, and control-containing family/client IDs. Method 7 covers both valid existence states plus mixed/missing account-number/sequence pairs. Method 9 is table-driven over empty/surrounding whitespace, invalid charset/separator/length, mixed case, and a fixed checksum-valid-but-noncanonical fixture. Method 10 includes both an ordinary checksum failure and a checksum-valid Bech32m address that classic Bech32 must reject.

Manifest topology, source-import allowlist, generated public symbol graph, exact test discovery, and the external consumer are not XCTest methods. `Scripts/verify-s1-01.sh` executes them as distinct gates:

- parse `swift package dump-package` JSON and require exactly one `.library` product named `ThorChainKit`, one `ThorChainKit` target, and one `ThorChainKitTests` test target;
- assert `xcodebuild -version` is exactly Xcode `26.3` / build `17C529`, assert `xcrun swift --version` contains Apple Swift `6.2.4`, and require CI to select that developer directory before any build;
- compare source imports to the system/BigInt allowlist;
- run `swift package dump-symbol-graph`, canonicalize public declarations, and compare them with `Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt`;
- run `swift test list` and compare the discovered `PublicApiTests` names/count with `Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt`;
- run `swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` as its own named subgate;
- create a `mktemp -d` Swift-tools-5.10 package with `platforms: [.iOS(.v13)]` that depends on the local root, uses only public `import ThorChainKit`, constructs the public value/factory surface, and build it with `xcodebuild -scheme ThorChainKitConsumer -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=13.0 SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO build`.

`.maestro/flows/00-launch-foundation.yaml`:

- launches the Example app with `clearState: true` and fixture mode;
- checks the visible `network`, `address`, `sync-state`, and `data-source` accessibility identifiers;
- proves that `data-source == FIXTURE`, the kit has not yet started automatically, and the UI contains no seed/private-key field;
- saves a success screenshot through `takeScreenshot`; all screenshots remain ignored build artifacts.

Before the runner exists, the Example step proves its build with `THORCHAIN_SIMULATOR_UDID=<exact> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination "platform=iOS Simulator,id=$THORCHAIN_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build`.

`Scripts/run-maestro.sh` is the sole UI entry point and requires `THORCHAIN_SIMULATOR_UDID` to match one UUID and identify an available iOS simulator. The runner passes that value to `xcrun simctl boot`, `xcrun simctl bootstatus -b`, the exact `xcodebuild -destination`, `xcrun simctl install`, and `xcrun simctl launch`; it then runs `maestro --device "$THORCHAIN_SIMULATOR_UDID" test --format junit --output build/maestro-results/junit.xml --test-output-dir build/maestro-results/artifacts --debug-output build/maestro-results/debug --flatten-debug-output .maestro`. All command output is captured under `build/maestro-results`; no unqualified `maestro test` is an accepted gate. The runner requires exactly one configured flow and JUnit attributes `tests=1`, `failures=0`, `errors=0`, and `skipped=0`. S1-01 has no live branch or `THORCHAIN_LIVE_TESTS` behavior.

`Scripts/test-run-maestro.sh` runs only against a temporary copy with PATH shims for `xcrun`, `xcodebuild`, and `maestro`. The shims record argv, synthesize the app/JUnit artifacts, and prove that every device-bearing command contains one canary UDID; substitution of a second UDID must fail the canary. This test never boots a device and cannot count as the live gate.

The secret/namespace scanner covers tracked source/configuration plus generated logs, JUnit, commands JSON, and screenshots. It scans raw bytes first, then `Scripts/scan-s1-01-artifacts.swift` uses Vision `VNRecognizeTextRequest` on every PNG and sends normalized recognized text through the same patterns. Positive text and rendered-image canaries are injected only into a `mktemp -d` copy of those inputs; the working tree is never contaminated with mnemonic/key/credential/wallet-ID material.

Do not use fixed sleeps. The mock lifecycle records calls synchronously and provides an expectation.

## Verification

```text
xcodebuild -version && xcrun swift --version
swift package resolve
swift build
swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --filter PublicApiTests
swift test
Scripts/verify-s1-01.sh
THORCHAIN_SIMULATOR_UDID=<exact-udid> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination 'platform=iOS Simulator,id=<exact-udid>' CODE_SIGNING_ALLOWED=NO build
THORCHAIN_SIMULATOR_UDID=<exact-udid> Scripts/run-maestro.sh
```

`Scripts/verify-s1-01.sh` includes the temporary public-only Swift-tools-5.10/iOS-13 consumer build. No host `swift build` result substitutes for the iOS `xcodebuild` gate.

## Acceptance Criteria

- The package builds independently and contains one `ThorChainKit` library product.
- `ThorChainKitTests` exists and all 18 authoritative behavioral methods are discovered and pass.
- Public symbols and signatures match the spec, or the change is separately approved.
- Address construction is fail-closed and network-bound; the public factory rejects whitespace-only wallet IDs and address/network mismatch.
- The factory does not start network/sync.
- Initial getters and replaying publishers are exactly nil/idle/zero/no-account, without a fabricated account or zero-as-height shortcut.
- There is no seed/private key, MarketKit, RxSwift, SwiftUI, or WalletCore in the public API.
- Parsed manifest topology, pinned Xcode/Swift identity, Swift-5 strict-concurrency warnings-as-errors, import allowlist, public symbol graph, exact test discovery, and temporary public-only iOS-13 consumer gates are green.
- The Example app launches from the shared workspace/scheme and uses the local package root.
- The sole exact-UDID Maestro runner reports one test with zero failures/errors/skips; argv canaries prove one device end-to-end; raw and Vision-OCR scans find no mnemonic, API key, endpoint credential, wallet ID, or internal persistence namespace in tracked inputs or artifacts.
- S1-02…S1-05 can be added without changing the base public facade, except through additive API.
- Reviewer, QA, and CI cite the same final `headRefOid`; the same PR carries the real PR-number roadmap marker, and post-merge evidence verifies `mergeCommit.oid` on `origin/main`.

## Pinned Decision

The minimum target is iOS 13 for parity with TronKit/EvmKit. S1-03/S1-05 dependency resolution must confirm HsCryptoKit/GRDB compatibility with iOS 13; incompatibility returns the spec for review, and the target is not raised silently.
