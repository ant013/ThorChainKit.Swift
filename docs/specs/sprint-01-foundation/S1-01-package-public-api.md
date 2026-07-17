# S1-01 — Package and Public API Foundation

**Status:** revision 4 after adversarial REVISE; implementation blocked pending fresh review and explicit approval.
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
- Protocol bounds: THORNode `a759cb4f99b1a13d5d94ace1dddcaf25c165641f` pins CometBFT `v0.38.21` and Cosmos SDK `v0.53.0`; S1-01 mirrors their [chain-ID](https://github.com/cometbft/cometbft/blob/v0.38.21/types/genesis.go) and [denom](https://github.com/cosmos/cosmos-sdk/blob/v0.53.0/types/coin.go) validation limits exactly.
- UI acceptance runtime: default CI installs [Maestro CLI `2.6.1`](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.6.1) with Temurin `17.0.19+10` and rejects a different CLI, Java version, or Java vendor before running the fixture gate. Output handling follows Maestro's [separate report/artifact contract](https://docs.maestro.dev/maestro-flows/workspace-management/test-reports-and-artifacts).
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

- public-key derivation, secp256k1 validation, address/public-payload hashing or encoding, HTTP, endpoint probing/failover, persistence, and sync loop; the internal persistence-namespace SHA-256 defined below is the only S1-01 hashing;
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

`mainnet = { environment: .mainnet, chainId: "thorchain-1", hrp: "thor", coinType: 931 }`. `stagenet(expectedChainId:)` always uses `.stagenet`, HRP `"sthor"`, and coin type `931`; `chainnet(expectedChainId:)` always uses `.chainnet`, HRP `"cthor"`, and coin type `931`. Their chain IDs are supplied explicitly and stored exactly. A valid ID has `1...50` UTF-8 bytes, is not whitespace-only, and contains no control character, matching THORNode's pinned CometBFT `MaxChainIDLen = 50` byte check while retaining the kit's stricter control-safety rule. There is no arbitrary initializer that can detach HRP or coin type from environment.

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

`Denom` matches the default denom grammar from THORNode's pinned Cosmos SDK exactly: ASCII `[A-Za-z][A-Za-z0-9/:._-]{2,127}`, hence `3...128` ASCII bytes with a leading letter. It is opaque and case-sensitive, permits `/`, rejects Unicode, and recognizes native RUNE only as exact lowercase `rune`. S1-04 consumes this value and does not redeclare it.

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

`accountNumber` and `sequence` are both nonnil if and only if `exists == true`. Mixed optional pairs, either value when `exists == false`, missing values when `exists == true`, and any nonempty `balances` dictionary when `exists == false` are rejected by the internal throwing initializer. Therefore an absent account can expose only `runeBalance == 0`; it cannot fabricate a nonzero balance.
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

- One internal owner uses one nonrecursive lock for snapshot reads, the single `desiredRunning` value, and monotonically sequenced lifecycle commands; neither the Example nor a host manager owns a second lifecycle state machine.
- Public getters acquire that lock and return one accepted snapshot.
- Each publisher has current-value semantics: a new subscriber immediately receives the current value. S1-01 has no post-construction snapshot mutation seam, so its only emissions are exactly `nil`, `.idle(cached: false)`, and `nil` for height, sync state, and account state respectively. S1-02 must separately specify later publication/reset behavior.
- Combine subscription/delivery, every subject `send`, and every lifecycle collaborator invocation occur with the owner lock released. A subscriber may always synchronously read getters. The required lifecycle-reentry case is a subscriber's repeated `stop()` after an outer stop has already set `desiredRunning = false`; it returns as an immediate no-op while the outer collaborator waits for its publication barrier. Other lifecycle calls from a subscriber are valid only when no lifecycle collaborator is waiting for that delivery.
- Publishers do not terminate with an error; errors are represented within `SyncState`.
- The linearization point for `start()` and `stop()` is the locked inspection/update of `desiredRunning`. Each effective transition receives the next sequence number under that lock, then the lock is released before the command is submitted to one internal FIFO lifecycle dispatcher. The dispatcher invokes collaborators serially in sequence order even if overlapping callers reach it in reverse scheduling order; S1-01's production collaborator is the inert no-op dependency.
- An effective public lifecycle call returns only after its own ordered collaborator invocation returns; a call that linearizes as a no-op returns immediately. This preserves S1-05's synchronous stop barrier without holding the owner lock.
- `start()` is an idempotent transition: stopped → running forwards one internal `start`; a call linearized while running is a no-op.
- `stop()` is an idempotent transition: running → stopped forwards one internal `stop`; a call linearized while stopped is a no-op.
- The linearization point for `refresh()` is the locked `desiredRunning` read. A call linearized while running receives the next sequence and is submitted once to the same FIFO dispatcher after the lock is released; a call linearized while stopped is a no-op.
- Nonoverlapping calls respect return-before-invocation order. Calls whose intervals overlap may acquire the lock in either order, and the legal result is the corresponding sequential trace: `stop || start` from stopped may end stopped or running; `refresh || start` may no-op then start or start then forward refresh. Two overlapping starts or stops still forward at most one transition.
- S1-01 tests use barriers/expectations and explicit call-entry control, never sleeps, to exercise both legal overlap orders, FIFO callback order, exact callback counts, and final desired state. A separate barrier-controlled regression holds the S1-05-style stop collaborator on a simulated publication barrier while its subscriber reads a getter and reenters `stop()`; both calls must complete and no callback may run under the owner lock.
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
| Required differences | Whitespace-only wallet rejection, address/network equality, collision-resistant internal `persistenceNamespace`, one `desiredRunning` owner, sequenced FIFO lifecycle dispatch with collaborators outside the owner lock, mandatory replaying publishers, idle/nil/zero initial state, no fake account/balance, and an inert no-op factory. |
| Rejected differences | Ambiguous `walletId-network` concatenation, public seed/private-key handling, public internal managers/storage, host imports, or two lifecycle owners. |
| Failure modes | Empty namespace, namespace disclosure, unique-ID collision, address rebinding, lifecycle call amplification/reordering, lock-held collaborator deadlock, auto-start, non-idempotent transitions, absent account with balances, publisher error termination, or fabricated account state. |
| Tests before code | Invalid wallet/network inputs; factory inertness; both legal concurrent lifecycle orders and FIFO call counts; barrier-controlled outer-stop/subscriber-getter-and-stop reentry; immediate mandatory publisher replay with synchronous getters and lifecycle calls when no collaborator is waiting; idle/nil/zero/no-account snapshot. |
| Verification | `PublicApiTests`, source-import allowlist, API-symbol audit, strict-concurrency compile, and the standalone public-only iOS-13 consumer build. |

### S1-01C — local-package Example and fixture UI gate

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit Example project/workspace/shared scheme. Supporting: EvmKit's independent `group:..` workspace. Rejected: persisted demo mnemonics/duplicate starts and Vultisig's zero-case-green fixture filter. |
| Coverage | App implementation, composition, consumer, package boundary, and dependency direction are verified. No applicable UI-test/Maestro analog exists in TronKit/EvmKit; the test role is explicitly waived as an analog and introduced as a task-specific delta. |
| Invariants to preserve | Separate app project, shared runnable scheme, workspace link to the root package, and a thin Example-only runtime. |
| Required differences | Fixture-only default, stable accessibility IDs, visible `FIXTURE` badge, no secret or namespace entry/storage/output, one exact-UDID runner, repo-root-absolute artifact paths, pinned Maestro/Java runtime, argv-observable device canaries, strict manifest/JUnit-count guards, and Vision OCR over screenshots. |
| Rejected differences | Hardcoded or persisted mnemonic, provider credential, manager-owned start plus adapter start, localized/coordinate selectors, fixed sleeps, and a green zero-test result. |
| Failure modes | Wrong app ID, package not linked, nonbooted simulator ambiguity, workspace-relative artifact escape, unpinned CLI/Java drift, undiscovered flow, zero JUnit cases, fixture labeled live, or secret leakage in YAML/logs/screenshots. |
| Tests before code | Static manifest/flow count and scanner canaries; an exact-destination Example build; then command shims that record argv and reject a wrong UDID before live build/install/launch assertions. |
| Verification | Maestro `2.6.1` on Temurin `17.0.19+10`; one `THORCHAIN_SIMULATOR_UDID` for boot/build/install/launch/`maestro --device`; repo-root-absolute JUnit/test/debug paths; JUnit attributes `tests=1 failures=0 errors=0 skipped=0`; tracked-input, raw-artifact, and Vision-OCR text scans; canaries injected only into a temporary copy; and explicit recording when Maestro is unavailable. |

## Resolved Adversarial Rulings

1. `Address.init(_:, network:)` owns strict minimum classic-Bech32 decode/canonical validation in S1-01. No unchecked fixture path exists. S1-03 owns public payload encoding and public-key derivation only.
2. The implementation PR changes the roadmap marker to contain its real PR number only. Reviewer, QA, and CI evidence bind to one final `headRefOid`; any push invalidates prior review/QA. After squash merge, the CTO records `mergeCommit.oid` in Paperclip, verifies it is on `origin/main`, and verifies the PR-number marker there before closing the slice. No `TBD`, merge-SHA placeholder, head mislabeled as merge, direct push, or roadmap-only follow-up PR is permitted.
3. The iOS 13 floor remains pinned. Endpoint durations are finite positive `TimeInterval` seconds, not iOS-16-only `Duration`; `Denom` keeps a throwing validator without claiming `RawRepresentable`.
4. Stagenet and chainnet fix HRPs to `sthor` and `cthor` respectively and use coin type `931`. `AccountState`, `SyncState`, and `SyncError` are owned and tested in S1-01.
5. The persistence digest is internal. The S1-01 public factory composes only a no-op lifecycle and inert initial snapshot; it creates no network, storage, timer, or task.
6. Lifecycle calls linearize at the locked `desiredRunning` inspection/update, receive a monotonic sequence, and enter one FIFO dispatcher after the owner lock is released. Collaborators never run under that lock; the barrier-controlled outer-stop/subscriber-stop regression proves the S1-05 publication cycle cannot deadlock.
7. The standalone consumer targets iOS 13 under the pinned CI Xcode/Swift identity and a separately named Swift-5 strict-concurrency warnings-as-errors gate. The exact-device runner pins Maestro `2.6.1` and Temurin `17.0.19+10`, exposes every device-bearing argv and resolved artifact path to shim canaries, and OCRs screenshot text before secret/namespace acceptance.
8. Network chain IDs are `1...50` UTF-8 bytes under CometBFT `v0.38.21`; denoms match Cosmos SDK `v0.53.0`'s `3...128`-byte ASCII grammar; an absent account rejects every nonempty balance set.

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

Method 2 covers 50-byte acceptance, 51-byte rejection, UTF-8 byte counting, blank input, and controls. Method 5 covers hostless HTTPS URLs, non-finite/nonpositive seconds, normalized duplicate IDs, and control-containing family/client IDs. Method 6 covers 3/128-byte boundaries plus 2/129-byte, non-letter-prefix, Unicode, whitespace, and unsupported punctuation rejection. Method 7 covers both valid existence states, mixed/missing account-number/sequence pairs, and absent-account/nonempty-balance rejection. Method 9 is table-driven over empty/surrounding whitespace, invalid charset/separator/length, mixed case, and a fixed checksum-valid-but-noncanonical fixture. Method 10 includes both an ordinary checksum failure and a checksum-valid Bech32m address that classic Bech32 must reject. Method 16 includes the barrier-controlled outer-stop/subscriber-getter-and-stop regression and proves effective external calls wait for their ordered collaborator without holding the owner lock. Method 17 proves mandatory initial replay plus synchronous getter and lifecycle access when no collaborator is waiting on that delivery.

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
- proves that `data-source == FIXTURE`, the initial public values are nil/idle/zero/no-account, and the UI contains no seed/private-key field; only method 15's injected lifecycle spy proves that construction does not auto-start;
- saves a success screenshot through `takeScreenshot`; all screenshots remain ignored build artifacts.

Before the runner exists, the Example step proves its build with `THORCHAIN_SIMULATOR_UDID=<exact> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination "platform=iOS Simulator,id=$THORCHAIN_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build`.

`Scripts/run-maestro.sh` is the sole UI entry point and requires `THORCHAIN_SIMULATOR_UDID` to match one UUID and identify an available iOS simulator. Default CI installs Maestro with `MAESTRO_VERSION=2.6.1` on `actions/setup-java` Temurin `17.0.19+10`; the runner rejects any `maestro --version` other than `2.6.1` and any `java -version` not identifying that Temurin runtime. The runner resolves `REPO_ROOT` through `git rev-parse --show-toplevel`, creates `$REPO_ROOT/build/maestro-results`, and passes absolute `$REPO_ROOT/.../junit.xml`, `$REPO_ROOT/.../artifacts`, and `$REPO_ROOT/.../debug` paths to `--output`, `--test-output-dir`, and `--debug-output`. This avoids Maestro workspace-relative output resolution and keeps the JUnit report—documented as separate from both artifact directories—inside the same scanned root. The runner passes the UDID to `xcrun simctl boot`, `xcrun simctl bootstatus -b`, the exact `xcodebuild -destination`, `xcrun simctl install`, and `xcrun simctl launch`; it then runs `maestro --device "$THORCHAIN_SIMULATOR_UDID" test --format junit --output "$REPO_ROOT/build/maestro-results/junit.xml" --test-output-dir "$REPO_ROOT/build/maestro-results/artifacts" --debug-output "$REPO_ROOT/build/maestro-results/debug" --flatten-debug-output .maestro`. All command output is captured under the same root; no unqualified `maestro test` is an accepted gate. The runner requires exactly one configured flow and JUnit attributes `tests=1`, `failures=0`, `errors=0`, and `skipped=0`. S1-01 has no live branch or `THORCHAIN_LIVE_TESTS` behavior.

`Scripts/test-run-maestro.sh` runs only against a temporary copy with PATH shims for `java`, `xcrun`, `xcodebuild`, and `maestro`. The shims record argv, synthesize the app/JUnit/artifact/debug outputs at the resolved absolute paths, and prove that every device-bearing command contains one canary UDID and every generated path remains beneath the temporary repository root. Wrong CLI/Java identity, workspace-relative path escape, or substitution of a second UDID must fail the canary. This test never boots a device and cannot count as the live gate.

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
- Network and denom construction enforce the pinned CometBFT/Cosmos byte/grammar bounds; Address construction is fail-closed and network-bound; the public factory rejects whitespace-only wallet IDs and address/network mismatch.
- The factory does not start network/sync.
- Initial getters and mandatory replaying publishers are exactly nil/idle/zero/no-account, without a fabricated account/balance or zero-as-height shortcut.
- There is no seed/private key, MarketKit, RxSwift, SwiftUI, or WalletCore in the public API.
- Parsed manifest topology, pinned Xcode/Swift identity, Swift-5 strict-concurrency warnings-as-errors, import allowlist, public symbol graph, exact test discovery, and temporary public-only iOS-13 consumer gates are green.
- The Example app launches from the shared workspace/scheme and uses the local package root.
- The sole exact-UDID Maestro runner uses pinned Maestro/Temurin identities and repo-root-absolute output paths, reports one test with zero failures/errors/skips, and scans the separate JUnit plus all raw/Vision-OCR artifacts; argv/path canaries prove one device and one artifact root end-to-end.
- S1-02…S1-05 can be added without changing the base public facade, except through additive API.
- Reviewer, QA, and CI cite the same final `headRefOid`; the same PR carries the real PR-number roadmap marker, and post-merge evidence verifies `mergeCommit.oid` on `origin/main`.

## Pinned Decision

The minimum target is iOS 13 for parity with TronKit/EvmKit. S1-03/S1-05 dependency resolution must confirm HsCryptoKit/GRDB compatibility with iOS 13; incompatibility returns the spec for review, and the target is not raised silently.
