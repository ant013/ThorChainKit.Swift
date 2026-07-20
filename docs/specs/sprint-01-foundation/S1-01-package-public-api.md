# S1-01 — Package and Public API Foundation

**Status:** revision 11 after revision-10 adversarial REVISE; implementation blocked pending fresh review and explicit approval.
**Risk:** high because lifecycle command admission and dispatcher reentry remain a greenfield concurrency delta, now reduced to one serial owner with explicit reentry post-draining.
**Observable outcome:** the standalone Swift Package builds independently of Unstoppable Wallet; a public-only consumer constructs validated network, endpoint, address, and `Kit` values without starting work, while a locally connected `iOS Example` launches in fixture mode and displays the exact nil/idle/zero initial state without network or secret material.

## Evidence Revision

This revision is bound to ThorChainKit `771bad30bb4ff20fa32ed0f4be260a7b934899e9` on `feature/THR-12-package-public-api` and to these independently verified analog checkouts:

- TronKit `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` — primary package, facade, lifecycle, and Example spine plus supporting fail-closed value construction;
- EvmKit `be0286317c202084784c5a695928cdc985c4ff7b` — supporting workspace convention and primary fail-closed protocol-value constructor shape;
- Unstoppable Wallet `5b06860e6e0068f05411cacc568bbb50bca1c588` — consumer shape and lifecycle-ownership evidence only;
- Vultisig iOS `d3123dbe6ef1103937c272a8b1cd81f613af0acc` — THOR HRP vocabulary support plus force-unwrapped-endpoint and print-only-test counterexamples only;
- THORNode `a759cb4f99b1a13d5d94ace1dddcaf25c165641f` — pinned protocol dependency and known-answer address-vector source only.

Gimle trust for this slice is **RED** because mapped roots differ from the policy checkouts, Vultisig has no registered project, and the live Gimle runtime changed after the evidence context was frozen. Gimle results influenced discovery only; every selected fact was reverified through Serena plus targeted `rg`/Git reads. The slice report is `docs/reports/gimle/THR-12-s1-01-gimle-reliability.md`.

## Goal

Create the minimal scaffold in this authoritative `ThorChainKit.Swift` repository, define the dependency direction, and establish a constructible fail-closed API that feels familiar for Horizontal Systems kits without inheriting their lifecycle/test defects.

## Assumptions

- This repository is the product authority for the standalone package; Unstoppable Wallet remains a separate future consumer.
- Toolchain: Swift tools `5.10`. CI selects Xcode `26.3` (`17C529`) with Apple Swift `6.2.4`, asserts those exact identities, and compiles in Swift 5 language mode.
- Minimum library platform: iOS 13, matching TronKit/EvmKit; actors/async require back-deployment verification in CI. The repository-owned UIKit-free SwiftUI Example targets iOS 14 or later. If a dependency genuinely requires a newer library version, that library-platform bump is a separate change requiring approval.
- Protocol bounds: THORNode `a759cb4f99b1a13d5d94ace1dddcaf25c165641f` pins CometBFT `v0.38.21` and Cosmos SDK `v0.53.0`; S1-01 mirrors their [chain-ID](https://github.com/cometbft/cometbft/blob/v0.38.21/types/genesis.go) and [denom](https://github.com/cosmos/cosmos-sdk/blob/v0.53.0/types/coin.go) validation limits exactly. The same THORNode head supplies mainnet address `thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2`; independent classic-Bech32 encoding of its decoded payload produces the matching valid `sthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhue08995` and `cthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhupxcqek` vectors. All three decode to `33e56601b755fe1c896da0884b79f38e526d6efc`.
- UI acceptance runtime: default CI downloads [Maestro CLI `2.6.1`](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.6.1) `maestro.zip` directly and verifies the official asset SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b` before extraction. It pins `actions/checkout` to `34e114876b0b11c390a56381ad16ebd13914f8d5` and `actions/setup-java` to `c1e323688fd81a25caa38c78aa6df2d33d3e20d9`, installs Temurin `17.0.19+10`, and rejects a different CLI, Java version, or Java vendor before the fixture gate. Output handling follows Maestro's [separate report/artifact contract](https://docs.maestro.dev/maestro-flows/workspace-management/test-reports-and-artifacts).
- XCTest, not Swift Testing: it is compatible with the selected toolchain and existing ecosystem.
- The public module is UI-agnostic and does not import `MarketKit`, `RxSwift`, `UIKit`, `SwiftUI`, `WalletCore`, or app localization. Combine remains its state-publication framework.

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
- runnable SwiftUI + Combine `iOS Example` application/workspace retaining the verified TronKit project/workspace/package topology only;
- `.maestro` workspace and the first deterministic launch/public-API acceptance flow.

Out of scope:

- public-key derivation, secp256k1 validation, address/public-payload hashing or encoding, HTTP, endpoint probing/failover, persistence, and sync loop; the internal persistence-namespace SHA-256 defined below is the only S1-01 hashing;
- send/sign/broadcast/history/swap;
- host adapters;
- public seed/private-key API.

## Proposed Tree

```text
Package.swift
Package.resolved
Sources/ThorChainKit/
  ThorChainKit.swift
  Core/Kit.swift
  Core/KitFactory.swift
  Core/KitDependencies.swift
  Core/KitConfigurationError.swift
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
  Fixtures/S1-01-factory-syntax.txt
  Fixtures/S1-01-value-syntax.txt
  Fixtures/S1-01-public-symbols.txt
  Fixtures/S1-01-tests.txt
iOS Example/
  iOS Example.xcodeproj/
  iOS Example.xcworkspace/
  Sources/
    ThorChainExampleApp.swift
    Configuration.swift
    Core/ExampleRuntime.swift
    Presentation/DiagnosticsViewModel.swift
    Views/DiagnosticsView.swift
.maestro/
  config.yaml
  flows/00-launch-foundation.yaml
Scripts/verify-s1-01.sh
Scripts/verify-bigint-floor.sh
Scripts/test-s1-01-mutants.sh
Scripts/verify-s1-01-factory.swift
Scripts/verify-s1-01-values.swift
Scripts/verify-s1-01-xunit.swift
Scripts/run-maestro.sh
Scripts/test-run-maestro.sh
Scripts/scan-s1-01-artifacts.swift
.github/workflows/ci.yml
```

Files for S1-02…S1-05 are added by subsequent specs; S1-01 does not create empty speculative classes.

The workspace follows the verified kit contract: `container:iOS Example.xcodeproj` plus `group:..`, so the app target consumes the current root Swift Package rather than a released binary. TronKit contributes only this topology and its scenario inventory. The Example uses the SwiftUI `App` lifecycle, SwiftUI views, and Combine-backed observation; UIKit imports, UIKit lifecycle/view-controller types, and UIKit representable wrappers are prohibited. Chain-specific send/history views appear only in the corresponding future slices.

PR #1 historically delivered `AppDelegate.swift`, `MainController.swift`, and `DiagnosticsController.swift` at an iOS 13 Example floor. That completed evidence is not rewritten as if it were SwiftUI. Before S1-02 adds an Example view, the approved platform-correction slice replaces those files, raises only the Example floor to iOS 14 or later, preserves the library's iOS 13 floor and existing Maestro/accessibility contract, and proves the UIKit-free source scan.

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

`Package.resolved` locks the default root build to BigInt `5.7.0` at `e07e00fa1fd435143a2dcf8b7eec9a7710b2fdfe`. The manifest intentionally retains the compatible range from `5.0.0`; `Scripts/verify-bigint-floor.sh` copies the package to `mktemp -d`, resolves `BigInt` specifically at `5.0.0`, requires revision `19f5e8a48be155e34abb98a2bcf4a343316f0343` in that copy's lockfile, and builds/tests the copy in Swift-5 strict-concurrency warnings-as-errors mode. It never rewrites the repository lock. Default CI separately requires the committed lock and resolved dependency graph to match `5.7.0`/`e07e00fa…`. Thus the default graph is reproducible and the declared floor is built rather than inferred from the current resolver result.

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
        walletId: String,
        endpoints: EndpointConfiguration
    ) throws -> Kit
}
```

Requirements:

- a `walletId` whose entire contents are whitespace/newlines is rejected with `KitConfigurationError.invalidWalletId`; accepted IDs are not trimmed or rewritten before hashing.
- neither `walletId` nor its digest is public or returned by the kit. Kit- and Example-controlled logs, telemetry, URLs, headers, error descriptions, Maestro/JUnit output, accessibility values, and screenshots never emit either value.
- `Kit.instance` has one network authority: it derives `network` from `address.network` and stores that exact value. It accepts no redundant network argument and therefore has no address/network mismatch branch.
- the internal `persistenceNamespace` is lowercase hex `SHA256(walletId UTF-8 || 0x00 || network.persistenceKey UTF-8)`, not ambiguous string concatenation or URL order.
- `network.persistenceKey` is internal and exactly `environment.rawValue UTF-8 || 0x00 || expectedChainId UTF-8`; construction rejects control characters, so the delimiter is unambiguous.
- in S1-01 the public factory creates only the exact nil/idle/zero snapshot plus an internal `NoOpLifecycle`. Construction, `start`, `stop`, and `refresh` create no URL session, storage handle, task, timer, or network request; later sync/storage slices replace this inert dependency through the internal composition root.
- the auditable factory/no-op composition path is exactly `Core/KitFactory.swift`, `Core/KitDependencies.swift`, and `Core/Kit.swift`. Its sole executed callee outside those files is the exact `Network.persistenceKey` getter body in `Models/Network.swift`; that getter may only construct `environment.rawValue UTF-8 || 0x00 || expectedChainId UTF-8`. `KitDependencies` exposes only the lifecycle capability in S1-01, and `Kit.instance` may construct only validated values, `NoOpLifecycle`, and `Kit`; it may not delegate through any other helper.
- `Scripts/verify-s1-01-factory.swift` owns a positive normalized syntax/callee audit for exactly `Core/KitFactory.swift`, `Core/KitDependencies.swift`, `Core/Kit.swift`, and the exact `Network.persistenceKey` declaration/body in `Models/Network.swift`. It canonicalizes the pinned compiler's parsed declarations, imports, identifier/member references, and call shapes and requires exact equality with `Fixtures/S1-01-factory-syntax.txt`; the fixture permits only validated value construction, `NoOpLifecycle`, `Kit`, the dedicated serial facade `DispatchQueue(label:)`, the required current-value subjects, one retained `DispatchSpecificKey<UInt8>()`, one `facadeDispatcher.setSpecific(key:value:)`, and `DispatchQueue.getSpecific(key:)` reads of that same key. An extra helper, import, call, member reference, alias, wrapper, or global-queue submission fails before any blacklist check. Temporary-copy canaries inject `URLSession.shared`, `URLRequest`, `Data(contentsOf:)`, `FileManager.default`, `FileHandle(forUpdatingAtPath:)`, `UserDefaults.standard`, `sqlite3_open`, `Task {}`, `OperationQueue`, `DispatchQueue.global().async`, `Timer.scheduledTimer`, `DispatchSource.makeTimerSource`, an alias, a wrapper inside an allowed file, a helper outside the exact path, and `Data(contentsOf:)` inside `Network.persistenceKey`; every canary must fail the same named audit.
- `Scripts/verify-s1-01-values.swift` owns a separate positive normalized construction audit for every executable public-value construction entry and its exact transitive validation bodies. The roots are `Network.mainnet`, `Network.stagenet(expectedChainId:)`, `Network.chainnet(expectedChainId:)`, `EndpointFamilyDescriptor.init`, `EndpointPolicy.init`, `EndpointPolicy.default`, `EndpointConfiguration.init`, `Denom.init`, `Denom.rune`, and `Address.init`; the closure also includes the exact private validators plus `Bech32Codec` and `BitConversion` bodies they call. The audit pins every default-argument expression for `EndpointPolicy.init` (`5`, `300`, `[408, 429, 502, 503, 504]`, `nil`, `100`) and `EndpointConfiguration.init` (`nil`, `15`, `.default`), so generated default-argument paths cannot call an unaudited helper. Parsed declarations, stored/static initializer bodies, default expressions, imports, identifier/member references, and call shapes must equal `Fixtures/S1-01-value-syntax.txt`; a helper or callee outside that enumerated closure fails.
- `Scripts/verify-s1-01.sh` runs that positive value baseline and seven guarded one-change temporary-copy canaries: the existing Address I/O/task and endpoint I/O/task insertions, `Data(contentsOf:)` in `Network.mainnet`, `Task {}` in `Denom.rune`, and replacement of `EndpointConfiguration`'s `.default` expression with an out-of-closure helper. Every canary must fail the same positive value gate before the public-only consumer build runs.
- an internal initializer accepts `KitDependencies` for deterministic lifecycle tests. There is no lock/probe test surface; collaborator spies and dispatcher barriers exercise the single production admission path. The public factory cannot supply test dependencies and no dependency type is public.
- the factory does not start synchronization automatically.

```swift
public enum KitConfigurationError: Error, Equatable {
    case invalidWalletId
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
    public let network: Network

    public init(_ raw: String, network: Network) throws
    public var description: String { raw }
}
```

`Address.init` is strict in S1-01. It rejects empty/surrounding-whitespace input, mixed case, invalid characters/separator/length, classic-Bech32 checksum failure, wrong HRP for the supplied `Network`, non-zero or overlong convertBits padding, non-20-byte payloads, and any normalized input that does not equal its canonical re-encoding. All-uppercase valid input is accepted and stored as canonical lowercase. The decoded 20-byte payload is retained internally for later native operations; no S1-01 consumer requires it to be public. There is no unchecked public, SPI, or Example-only constructor. The minimum decoder and its private re-encode check are owned by S1-01; public payload exposure/encoding, public-key derivation, secp256k1 validation, and hashing remain S1-03.

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

`AccountState` and `SyncState` are intentionally not `Sendable` in S1-01 because the declared and independently built minimum BigInt `v5.0.0` defines `BigUInt` without `Sendable`; the default lock resolves `v5.7.0`, whose added conformance does not change this public contract. The synchronized facade owns their publication. A future conformance requires a separately verified dependency/toolchain change; `@unchecked Sendable` is prohibited.

## Dependency Direction

```text
Kit → internal protocols → implementations
Models ← Network / Crypto / Sync / Storage

Forbidden:
ThorChainKit → WalletCore / MarketKit / RxSwift / UI
```

## Threading Contract

- One dedicated serial `facadeDispatcher` is the sole owner of snapshots, the single `desiredRunning` value, the next lifecycle sequence, and the pending FIFO. There is no owner lock, second draining queue, or second desired-running/idempotence state machine in the Example, a host manager, or a later collaborator.
- `Kit` installs one private `DispatchSpecificKey<UInt8>` with value `1` on that dispatcher. A public getter called off-dispatcher uses `facadeDispatcher.sync`; the same getter called from dispatcher context reads the owned snapshot directly. No getter synchronously redispatches to its current queue.
- Each publisher has current-value semantics: a new subscriber immediately receives the current value. S1-01 has no post-construction snapshot mutation seam, so its only emissions are exactly `nil`, `.idle(cached: false)`, and `nil` for height, sync state, and account state respectively. Publisher delivery and lifecycle collaborators run on the same facade dispatcher, where a subscriber may synchronously read getters or call lifecycle methods without a queue self-wait. Publishers never terminate with an error; errors are represented within `SyncState`.
- An off-dispatcher lifecycle call enters with `facadeDispatcher.sync`. In that dispatcher turn it inspects/updates `desiredRunning`, assigns the next sequence to an effective command, appends it to the pending FIFO, and drains the FIFO through collaborator return before the synchronous turn ends. A no-op returns from the same turn without a collaborator call.
- A lifecycle call already on the facade dispatcher never calls `sync`. An effective reentrant `start`, `stop`, or running `refresh` performs the same state transition, sequence assignment, and FIFO append, then returns to the active collaborator/subscriber. The active turn post-drains every such command before yielding the dispatcher. `DispatchQueue.getSpecific(key:) == 1` for the retained key is the only reentry classification; a process-wide or mutable `isDraining` flag is forbidden.
- `start()` is an idempotent stopped → running transition; `stop()` is an idempotent running → stopped transition; `refresh()` forwards only when linearized while running. Sequence assignment and FIFO append cannot interleave with another public call because both occur in one serial-dispatcher turn.
- Nonoverlapping calls respect return-before-invocation order. Overlapping off-dispatcher calls may enter the serial dispatcher in either order, and the legal result is that complete sequential trace: `stop || start` from stopped may end stopped or running; `refresh || start` may no-op then start or start then forward refresh. Two overlapping starts or stops still forward at most one transition.
- Method 16 uses barriers and explicit call-entry control, never sleeps. An active command `C0` holds its collaborator on the facade dispatcher, an unrelated thread submits ordinary command `C1` and remains blocked, and the `C0` collaborator synchronously submits effective reentrant command `R`. `R` must return after FIFO append, then the same active turn must post-drain it before yielding to `C1`, proving exact collaborator order `C0, R, C1` and ordinary-call completion. The table repeats the trace for reentrant start, stop, and running refresh. `Scripts/test-s1-01-mutants.sh` baseline-runs method 16, applies exactly one guarded mutation that defers the reentrant command with `facadeDispatcher.async` instead of the owned FIFO/post-drain path, directly reruns only method 16, and requires failure.
- S1-01 exposes no post-construction snapshot mutation interface or competing-publication admission machinery. S1-05 owns the first such interface and extends this same serial owner with publication turns; it does not add another dispatcher or lock.
- Internal mutable sync/storage state in later slices remains actor-owned behind this facade; the facade itself is not declared `Sendable` without separately proven synchronization.
- Later async boundaries may carry only internal records whose stored fields are genuinely `Sendable` at the BigInt `5.0.0` floor. S1-04/S1-05 carry canonical decimal strings rather than `BigUInt` across their reader, synchronizer, and storage boundaries, then construct the frozen public `AccountState` only on this facade dispatcher. Neither `@unchecked Sendable` nor a BigUInt-backed transport/persistence record is permitted.
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

### S1-01B — public facade, inert lifecycle, and greenfield command admission

| Field | Decision |
|---|---|
| Analog family | Primary for facade/ownership only: TronKit `Kit` and `Kit.instance`. Supporting for consumer ownership only: exact Unstoppable `TronKitManager` and generic `AdapterManager`. Rejected: duplicate manager/adapter start ownership in the TronKit demo. |
| Coverage | Exact-checkout TronKit and EvmKit facades directly forward lifecycle calls; bounded exact searches of those kits and Unstoppable found no sequence/FIFO, completion-barrier, or dispatcher-reentry algorithm. The facade and ownership spine is verified, but command admission is an explicit **high-concurrency greenfield delta** with no analog implementation or test role. The rejected two-owner alternative is the revision-10 lock plus dispatcher design: a separate lock adds a second mutable-state owner and a classification problem without satisfying any trace the serial dispatcher cannot satisfy. |
| Invariants to preserve | Public facade, synchronous snapshot access, nonfailing Combine publishers, explicit `start/stop/refresh`, and one composition root. No concurrency-algorithm behavior is inherited from the analogs. |
| Required differences | Whitespace-only wallet rejection, network derived only from `address.network`, collision-resistant internal `persistenceNamespace`, internal-only decoded address payload, one serial-dispatcher owner of snapshots/`desiredRunning`/sequence/FIFO, exact `DispatchSpecificKey<UInt8>` identity, collaborator-context append-and-return plus active-turn post-drain, mandatory initial replay, idle/nil/zero initial state, no fake account/balance, and an auditable inert no-op factory including the transitive `Network.persistenceKey` getter. S1-01 adds no publication-turn machinery. |
| Rejected differences | Ambiguous `walletId-network` concatenation, public seed/private-key handling, public internal managers/storage, host imports, or two lifecycle owners. |
| Failure modes | Empty namespace, namespace disclosure, unique-ID collision, lifecycle call amplification/reordering, reentrant command deferred behind an already-waiting ordinary caller, dispatcher self-wait, early return for an ordinary effective call, auto-start, hidden factory side effects, non-idempotent transitions, absent account with balances, publisher error termination, or fabricated account state. |
| Tests before code | Invalid wallet input and network derivation from each valid address; exact positive factory syntax/callee fixture covering the transitive `Network.persistenceKey` getter with equivalent-capability, alias, wrapper, out-of-path-helper, and transitive-I/O canaries; both legal concurrent lifecycle orders and FIFO call counts; exact `C0, R, C1` post-drain barriers plus the deferred-async mutant; ordinary effective start/stop/refresh completion; barrier-controlled dispatcher-context reentry for start/stop/refresh; immediate mandatory publisher replay with synchronous getters and lifecycle calls; idle/nil/zero/no-account snapshot. |
| Verification | `PublicApiTests`, source-import allowlist, API-symbol audit, strict-concurrency compile, and the standalone public-only iOS-13 consumer build. |

### S1-01D — fail-closed protocol-derived public values

| Field | Decision |
|---|---|
| Analog family | Primary: EvmKit's throwing `Address.init(hex:)` validate-before-store path. Supporting: TronKit's throwing checksum/prefix/length `Address` constructors and Vultisig's exact THOR `thor/sthor/cthor` HRP branches. Rejected: EvmKit's permissive raw-data initializer, Vultisig's force-unwrapped endpoint URLs, and Vultisig's print-only THOR address test. |
| Coverage | Contract, implementation, composition, consumer, failure, boundary, dependency, state/error, and trust dimensions are independently current-tree verified at EvmKit `be028631`, TronKit `aa691bcd`, and Vultisig `d3123dbe`. Bounded EvmKit/TronKit searches found no direct constructor contract tests, and Vultisig's only THOR address test has no assertions; the analog test role is explicitly waived and replaced by exact S1-01 tables and a known-answer vector. |
| Invariants to preserve | Throwing public construction validates before storing; rejected inputs produce typed errors; real consumers cannot bypass validation accidentally. Vultisig contributes THOR vocabulary only, never the kit's lifecycle, ownership, endpoint, or public-model spine. |
| Required differences | Bind Network/Denom limits to THORNode `a759cb4f`'s CometBFT `v0.38.21` and Cosmos SDK `v0.53.0` pins; validate the complete endpoint contract; require strict classic Bech32 plus canonical re-encoding and exact 20-byte payload; keep payload internal; assert the `thor`, `sthor`, and `cthor` canonical vectors for payload `33e56601b755fe1c896da0884b79f38e526d6efc`. |
| Rejected differences | Public raw/payload initializers, force-unwrapped URLs, boolean-only validation without construction, print-only tests, endpoint probing/networking in S1-01, and protocol rules inferred from an application checkout instead of pinned sources. |
| Failure modes | Wrong chain-ID byte counting, permissive denom grammar, insecure or credential-bearing URL, invalid retry/page/attempt policy, reversible but wrong convertBits, Bech32m acceptance, wrong HRP, noncanonical address, or accidental public payload exposure. |
| Tests before code | Complete Network/endpoint/Denom boundary tables including stored/static/default-expression construction roots; classic-Bech32 and Bech32m separation; valid canonical `thor`, `sthor`, and `cthor` vectors mapping to one exact payload under `@testable`; wrong HRP, padding, payload-length, and canonical re-encoding failures; public symbol audit rejecting raw/payload API. |
| Verification | Methods 1–12, external public-only consumer, public symbol graph, pinned-source anchors, and strict-concurrency build. |

### S1-01C — local-package Example and fixture UI gate

| Field | Decision |
|---|---|
| Analog family | Primary: TronKit Example project/workspace/shared scheme for topology only. Supporting: EvmKit's independent `group:..` workspace and TonKit's SwiftUI shell. Rejected: TronKit/EvmKit UIKit lifecycle/controllers, persisted demo mnemonics/duplicate starts, and Vultisig's zero-case-green fixture filter. |
| Coverage | App implementation, composition, consumer, package boundary, and dependency direction are verified. No applicable UI-test/Maestro analog exists in TronKit/EvmKit; the test role is explicitly waived as an analog and introduced as a task-specific delta. |
| Invariants to preserve | Separate app project, shared runnable scheme, workspace link to the root package, and a thin Example-only runtime. |
| Required differences | SwiftUI `App` lifecycle at an iOS 14-or-later Example floor, SwiftUI views, one Combine-backed presentation model without duplicate state ownership, fixture-only default, stable accessibility IDs, visible `FIXTURE` badge, no secret or namespace entry/storage/output, one exact-UDID runner, repo-root-absolute artifact paths, immutable Maestro/action pins, argv-observable device canaries, strict manifest/JUnit-count guards, recursive fail-closed Vision OCR, and a fail-closed UIKit/core-SwiftUI import/type scan. |
| Rejected differences | UIKit imports/lifecycle/controllers/representables, SwiftUI in `Sources/ThorChainKit`, hardcoded or persisted mnemonic, provider credential, manager-owned start plus adapter start, localized/coordinate selectors, fixed sleeps, and a green zero-test result. |
| Failure modes | Wrong app ID, package not linked, nonbooted simulator ambiguity, workspace-relative, sibling-prefix, or symlink-root artifact escape, unverified Maestro archive, floating action tag, undiscovered flow, zero JUnit cases, skipped PNG through symlink/path escape, OCR read/decode/request failure treated as success, fixture labeled live, or secret leakage in YAML/logs/screenshots. |
| Tests before code | Named workspace-structure subgate plus exact build; one visible fixture flow; command-shim tests for one exact UDID and canonical component-contained artifact paths; zero/extra/skipped/error/failure JUnit canaries; recursive regular-PNG enumeration with enumerated-equals-processed assertion; `artifacts-escape`, symlinked-root, inner-symlink/path-escape, malformed-PNG, safe-first/secret-second, raw-text, and rendered-image canaries in a temporary copy. |
| Verification | SHA-256-verified Maestro `2.6.1` on Temurin `17.0.19+10` through full-SHA actions; one `THORCHAIN_SIMULATOR_UDID` for boot/build/install/launch/`maestro --device`; repo-root-absolute JUnit/test/debug paths; JUnit attributes `tests=1 failures=0 errors=0 skipped=0`; tracked-input, raw-artifact, and recursive fail-closed Vision-OCR text scans; canaries injected only into a temporary copy; and explicit recording when Maestro is unavailable. |

## Resolved Adversarial Rulings

1. `Address.init(_:, network:)` owns strict minimum classic-Bech32 decode/canonical validation in S1-01. No unchecked fixture path exists. S1-03 owns any separately approved public payload exposure/encoding and public-key derivation only.
2. The implementation PR changes the roadmap marker to contain its real PR number only. Reviewer, QA, and CI evidence bind to one final `headRefOid`; any push invalidates prior review/QA. After squash merge, the CTO records `mergeCommit.oid` in Paperclip, verifies it is on `origin/main`, and verifies the PR-number marker there before closing the slice. No `TBD`, merge-SHA placeholder, head mislabeled as merge, direct push, or roadmap-only follow-up PR is permitted.
3. The library iOS 13 floor remains pinned; the UIKit-free SwiftUI Example targets iOS 14 or later. Endpoint durations are finite positive `TimeInterval` seconds, not iOS-16-only `Duration`; `Denom` keeps a throwing validator without claiming `RawRepresentable`.
4. Stagenet and chainnet fix HRPs to `sthor` and `cthor` respectively and use coin type `931`. The canonical addresses `sthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhue08995` and `cthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhupxcqek` decode to the same exact 20-byte payload as the mainnet vector. `AccountState`, `SyncState`, and `SyncError` are owned and tested in S1-01.
5. The persistence digest and decoded address payload are internal. The S1-01 public factory composes only a no-op lifecycle and inert initial snapshot; an exact positive normalized declaration/import/identifier/member/call-shape fixture also pins the transitive `Network.persistenceKey` getter, and equivalent-capability, alias, wrapper, unaudited-helper, and transitive-I/O canaries prove the path creates no work or hidden capability.
6. One serial facade dispatcher owns snapshots, desired state, sequence assignment, FIFO append, collaborator invocation, and reentry post-draining; the rejected lock-plus-dispatcher design adds a second state owner without enabling any required trace. One retained `DispatchSpecificKey<UInt8>` identifies dispatcher context. Ordinary effective calls synchronously enter and wait through their collaborator return; true dispatcher-context reentry appends and returns so the active turn can post-drain before yielding. The deterministic `C0, R, C1` trace and deferred-async mutant prove that a waiting external caller cannot overtake a reentrant command. S1-05 extends the same owner with publication turns and adds no lock or second dispatcher.
7. The standalone library consumer targets iOS 13 under the pinned CI Xcode/Swift identity and a separately named Swift-5 strict-concurrency warnings-as-errors gate. The SwiftUI Example targets iOS 14 or later. The exact-device runner verifies Maestro archive SHA-256, uses full-SHA checkout/setup-java actions, exposes every device-bearing argv and resolved artifact path to shim canaries, and recursively fails closed on screenshot enumeration/read/decode/OCR errors before secret/namespace acceptance.
8. Network chain IDs are `1...50` UTF-8 bytes under CometBFT `v0.38.21`; denoms match Cosmos SDK `v0.53.0`'s `3...128`-byte ASCII grammar; endpoint tests enumerate every construction rule; an absent account rejects every nonempty balance set.
9. Protocol values use EvmKit's throwing validate-before-store shape as the primary analog, TronKit as independent fail-closed support, and Vultisig only for pinned THOR HRP vocabulary. Raw-data constructors, force-unwrapped endpoints, and print-only tests are rejected.
10. The valid canonical addresses `thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2`, `sthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhue08995`, and `cthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhupxcqek` must each decode under its matching Network to internal payload `33e56601b755fe1c896da0884b79f38e526d6efc`; round-trip-only convertBits tests or a mainnet-only hardcode are insufficient.
11. S1-05 consumes the exact frozen S1-01 public model: chain identity stays internal, `runeBalance` is a Kit projection, storage errors map to `.storageUnavailable`, and the bridge never receives duplicate lifecycle commands.
12. Merge requires green required checks, `mergeStateStatus == CLEAN`, an empty conflict-marker scan, an existing referenced plan file, exact-head Paperclip CR/QA evidence, and a final reviewer pass after `## QA Evidence` is present in the PR body.
13. S1-01's exact public-symbol and inert-factory audits are slice-versioned gates, not permanent whole-repository prohibitions. Each later slice owns an exact current-surface baseline plus cumulative prior-baseline subset compatibility, and replaces the factory capability gate only through the named transition in its own spec and CI script.
14. The committed Gimle report is a sanitized projection: it contains project labels, commits, and repository-relative paths but no operator-local absolute root. The canonical machine-local state/report remains outside the product repository.
15. Passing discovery is insufficient. The filtered XCTest run uses `--parallel --num-workers 1` because SwiftPM 6.2.4 emits XCTest xUnit only through that runner. `Scripts/verify-s1-01-xunit.swift` requires the xUnit report to contain exactly the 18 allowlisted cases with zero failures/errors and independently parses the captured runner transcript to require one terminal `passed` status for every allowlisted case and reject `skipped`, disabled, or failed status. A source gate rejects `XCTSkip`, `XCTExpectFailure`, conditional/availability disabling around the authoritative methods, and test-command `--skip`. A temporary `XCTSkip` canary proves the transcript/status gate fails even though SwiftPM's xUnit schema cannot represent skips.
16. The BigInt semver range retains the declared `5.0.0` floor, the committed root lock fixes the default graph at `5.7.0`/`e07e00fa…`, and the isolated minimum-version gate resolves and builds/tests exact `5.0.0`/`19f5e8a4…` without mutating that lock.
17. For `walletId == "wallet-01"` and mainnet, the exact bytes `wallet-01 || 0x00 || mainnet || 0x00 || thorchain-1` hash to internal namespace `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`. Separator removal or component reordering must fail the same method.
18. Public value construction has its own positive normalized closure, independent of the Core factory closure. It enumerates every public initializer, stored/static construction root, transitive validation body, and default expression; Address/endpoint I/O/task plus Network/Denom/default-path canaries must fail it. S1-04/S1-05 cross isolation only with internal `Sendable` decimal-string records and reconstruct BigUInt-backed public snapshots on the facade dispatcher.

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
8. `testAddressCanonicalizesValidNetworksAndUppercase()`.
9. `testAddressRejectsStructureCaseAndCanonicalViolations()`.
10. `testAddressRejectsClassicChecksumAndBech32m()`.
11. `testAddressRejectsWrongHrp()`.
12. `testAddressRejectsInvalidPaddingOrPayloadLength()`.
13. `testFactoryRejectsWhitespaceOnlyWalletId()`.
14. `testFactoryDerivesNetworkFromAddress()`.
15. `testFactoryCreatesNoWorkAndDoesNotStartLifecycle()`.
16. `testLifecycleSerializesIdempotentStartStopAndRunningRefresh()`.
17. `testInitialPublishersAllowReentrantSnapshotAndLifecycleAccess()`.
18. `testPersistenceNamespaceIsDeterministicInternalAndAbsentFromErrors()`.

Method 2 covers 50-byte acceptance, 51-byte rejection, UTF-8 byte counting, blank input, and controls. Method 5 is table-driven over empty families; normalized duplicate/empty/control-containing family IDs; non-HTTPS and hostless URLs; credentials, query, and fragment; client-ID trim/control/empty-to-nil normalization; non-finite/nonpositive timeout and revalidation seconds; negative lag; retry codes outside `408/429/502/503/504`; page counts outside `1...1000`; explicit attempts outside `1...families.count`; nil attempts; and `effectiveMaximumAttempts`. Method 6 covers 3/128-byte boundaries plus 2/129-byte, non-letter-prefix, Unicode, whitespace, and unsupported punctuation rejection. Method 7 covers both valid existence states, mixed/missing account-number/sequence pairs, and absent-account/nonempty-balance rejection. Method 8 constructs all three valid canonical vectors—`thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2`, `sthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhue08995`, and `cthor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhupxcqek`—under their matching Networks and asserts under `@testable` that each has exact internal payload `33e56601b755fe1c896da0884b79f38e526d6efc`; it also covers valid uppercase canonicalization. Method 9 is table-driven over empty/surrounding whitespace, invalid charset/separator/length, mixed case, and a fixed checksum-valid-but-noncanonical fixture. Method 10 includes both an ordinary checksum failure and a separately generated checksum-valid Bech32m address that classic Bech32 must reject. Method 14 constructs each Kit from only its Address, wallet ID, and endpoints, then proves `kit.network == address.network`. Method 16 holds active collaborator `C0` on the facade dispatcher, submits ordinary `C1` from an unrelated thread, and synchronously submits effective reentrant `R` from `C0`; it requires `R` to return after append, `C1` to remain blocked, and exact collaborator order `C0, R, C1` for reentrant start/stop/running-refresh without sleeps. The named outer mutant harness directly reruns method 16 against the one guarded deferred-async mutation. Method 17 proves mandatory initial replay plus synchronous getter and lifecycle access from dispatcher context. Method 18 asserts the exact internal known answer `SHA256("wallet-01\0mainnet\0thorchain-1") == e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015`; `Scripts/test-s1-01-mutants.sh` applies the separator/order source mutants one at a time and directly reruns method 18.

Manifest topology, source-import allowlist, generated public symbol graph, exact test discovery, and the external consumer are not XCTest methods. `Scripts/verify-s1-01.sh` executes them as distinct gates:

- parse `swift package dump-package` JSON and require exactly one `.library` product named `ThorChainKit`, one `ThorChainKit` target, and one `ThorChainKitTests` test target;
- assert `xcodebuild -version` is exactly Xcode `26.3` / build `17C529`, assert `xcrun swift --version` contains Apple Swift `6.2.4`, and require CI to select that developer directory before any build;
- compare source imports to the system/BigInt allowlist;
- reject UIKit imports/types in `Sources/ThorChainKit` and `iOS Example/Sources`, reject SwiftUI in `Sources/ThorChainKit`, and require the Example's SwiftUI `App` lifecycle plus iOS 14-or-later deployment target;
- run `swift package dump-symbol-graph`, canonicalize public declarations, and compare them with `Tests/ThorChainKitTests/Fixtures/S1-01-public-symbols.txt`;
- run `swift test list` and compare the discovered `PublicApiTests` names/count with `Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt`;
- run `swift test --enable-xctest --disable-swift-testing --parallel --num-workers 1 --filter ThorChainKitTests.PublicApiTests --xunit-output "$tmp/public-api.xml" 2>&1 | tee "$tmp/public-api.log"` under `set -o pipefail` and require the Swift process itself to exit zero, then invoke non-executable `Scripts/verify-s1-01-xunit.swift` through `xcrun swift`; require exactly the 18 allowlisted names in xUnit with zero failures/errors and exactly one terminal `passed` transcript status per name. Reject any skipped/disabled/failed terminal status, `XCTSkip`, `XCTExpectFailure`, conditional/availability disabling, or test-command `--skip`; a temporary-copy `XCTSkip` mutation must fail the transcript/status gate even though SwiftPM xUnit omits skip state;
- invoke non-executable `Scripts/verify-s1-01-factory.swift` through `xcrun swift` to compare the exact factory/dependency/Kit normalized declarations, imports, identifier/member references, and call shapes plus the exact `Network.persistenceKey` declaration/body with `Fixtures/S1-01-factory-syntax.txt`; positively allow only the named dispatcher-specific key operations and run every listed equivalent-capability, alias, wrapper, out-of-path helper, and transitive-getter I/O mutant, requiring the same positive allowlist gate to reject it;
- invoke non-executable `Scripts/verify-s1-01-values.swift` through `xcrun swift` to compare every enumerated initializer, static/stored construction body, transitive validation body, and default expression with `Fixtures/S1-01-value-syntax.txt`; require all seven Address/endpoint/Network/Denom/default-path temporary-copy canaries to fail that same positive gate;
- run executable `Scripts/test-s1-01-mutants.sh`; require one baseline pass, exactly one guarded transform per temporary copy, and direct nonrecursive mutant failures for method 16's deferred-async reentry and method 18's separator/order changes;
- require the committed BigInt `5.7.0`/`e07e00fa…` lock and default dependency graph, then run executable `Scripts/verify-bigint-floor.sh` to resolve/build/test exact `5.0.0`/`19f5e8a4…` in a temporary copy without changing the repository lock;
- require Git mode `100755`, `test -x`, and a valid shell shebang for every directly invoked shell script (`verify-s1-01.sh`, `verify-bigint-floor.sh`, `test-s1-01-mutants.sh`, `run-maestro.sh`, and `test-run-maestro.sh`); non-executable Swift helpers are invoked explicitly through `xcrun swift`;
- run `swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` as its own named subgate;
- create a `mktemp -d` Swift-tools-5.10 package with `platforms: [.iOS(.v13)]` that depends on the local root, uses only public `import ThorChainKit`, constructs the public value/factory surface, and build it with `xcodebuild -scheme ThorChainKitConsumer -destination 'generic/platform=iOS Simulator' IPHONEOS_DEPLOYMENT_TARGET=13.0 SWIFT_VERSION=5 SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO build`.
- run a named `verify-s1-01-example-workspace` subgate before the Example build; parse `iOS Example.xcworkspace/contents.xcworkspacedata` and require exactly `container:iOS Example.xcodeproj` plus `group:..` with no missing or extra package/project link.

The exact S1-01 public-symbol and factory capability comparisons apply to this slice only. Later slices must not rerun them as permanent whole-tree equality/prohibition gates: each owning spec names its replacement exact current-surface baseline, cumulative prior-baseline subset check, and factory-capability transition.

`.maestro/flows/00-launch-foundation.yaml`:

- launches the Example app with `clearState: true` and fixture mode;
- checks the visible `network`, `address`, `sync-state`, and `data-source` accessibility identifiers;
- proves that `data-source == FIXTURE`, the initial public values are nil/idle/zero/no-account, and the UI contains no seed/private-key field; only method 15's injected lifecycle spy proves that construction does not auto-start;
- saves a success screenshot through `takeScreenshot`; all screenshots remain ignored build artifacts.

Before the runner exists, the Example step first runs the named `verify-s1-01-example-workspace` subgate for exact `container:iOS Example.xcodeproj` plus `group:..`, then proves its build with `THORCHAIN_SIMULATOR_UDID=<exact> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination "platform=iOS Simulator,id=$THORCHAIN_SIMULATOR_UDID" CODE_SIGNING_ALLOWED=NO build`.

`Scripts/run-maestro.sh` is the sole UI entry point and requires `THORCHAIN_SIMULATOR_UDID` to match one UUID and identify an available iOS simulator. Default CI pins `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` and `actions/setup-java@c1e323688fd81a25caa38c78aa6df2d33d3e20d9`, downloads the release asset `maestro.zip` for `2.6.1`, verifies SHA-256 `3440825f514f537c6a96bcf5de995780c2a4a7f83a43208fdc95d4f1fecfad3b`, and only then extracts it. The runner also rejects any `maestro --version` other than `2.6.1` and any `java -version` not identifying Temurin `17.0.19+10`; those are compatibility checks, not substitutes for immutable provenance. The runner resolves `REPO_ROOT` through `git rev-parse --show-toplevel`, creates `$REPO_ROOT/build/maestro-results`, and passes absolute `$REPO_ROOT/.../junit.xml`, `$REPO_ROOT/.../artifacts`, and `$REPO_ROOT/.../debug` paths to `--output`, `--test-output-dir`, and `--debug-output`. This avoids Maestro workspace-relative output resolution and keeps the JUnit report—documented as separate from both artifact directories—inside the same scanned root. The runner passes the UDID to `xcrun simctl boot`, `xcrun simctl bootstatus -b`, the exact `xcodebuild -destination`, `xcrun simctl install`, and `xcrun simctl launch`; it then runs `maestro --device "$THORCHAIN_SIMULATOR_UDID" test --format junit --output "$REPO_ROOT/build/maestro-results/junit.xml" --test-output-dir "$REPO_ROOT/build/maestro-results/artifacts" --debug-output "$REPO_ROOT/build/maestro-results/debug" --flatten-debug-output .maestro`. All command output is captured under the same root; no unqualified `maestro test` is an accepted gate. The runner requires exactly one configured flow and JUnit attributes `tests=1`, `failures=0`, `errors=0`, and `skipped=0`. S1-01 has no live branch or `THORCHAIN_LIVE_TESTS` behavior.

`Scripts/test-run-maestro.sh` runs only against a temporary copy with PATH shims for `java`, `xcrun`, `xcodebuild`, and `maestro`. The shims record argv, synthesize the app/JUnit/artifact/debug outputs at the resolved absolute paths, and prove that every device-bearing command contains one canary UDID and every generated path remains beneath the temporary repository root. The runner and scanner canonicalize both the repository root and each output root, reject any symlink in either root or path component using `lstat`, and use component-aware containment rather than string prefixes. Wrong CLI/Java identity, workspace-relative path escape, substitution of a second UDID, an `artifacts-escape` sibling-prefix output, or a symlinked output root must fail the canary. This test never boots a device and cannot count as the live gate.

The secret/namespace scanner covers tracked source/configuration plus generated logs, JUnit, commands JSON, and screenshots. It scans raw bytes first. `Scripts/scan-s1-01-artifacts.swift` recursively enumerates each asserted artifact root, accepts only regular PNG files whose canonical path is component-contained beneath both that canonical artifact root and the canonical repository root, rejects a symlink in either root or any traversed component, and fails any file read, image decode, Vision request, or OCR error. It records the enumerated PNG count and requires it to equal the processed count before scanning normalized recognized text through the same patterns. Temporary-copy tests include safe-first/secret-second PNG ordering, a malformed PNG, an `artifacts-escape` sibling-prefix path, a symlinked output root, an inner symlink/path escape, and rendered secret/namespace text; the working tree is never contaminated with mnemonic/key/credential/wallet-ID material.

The canonical Gimle state and report may retain machine-local roots outside this repository. The committed `docs/reports/gimle/THR-12-s1-01-gimle-reliability.md` is rendered as a sanitized projection using project labels, commits, and repository-relative paths. The documentation gate rejects `/Users/`, `/Users/Shared/`, `/private/`, and `file://` in that committed report.

Do not use fixed sleeps. The mock lifecycle records calls synchronously and provides an expectation.

## Review and Merge Gate

The implementation PR links both `docs/superpowers/plans/2026-07-17-THR-12-s1-01-package-public-api.md` and the matching Paperclip plan document. Before merge, the CTO records the exact `headRefOid` and verifies:

1. `gh pr checks <PR>` exits zero with every required check complete and green; no required check is pending.
2. `gh pr view <PR> --json mergeStateStatus --jq .mergeStateStatus` is exactly `CLEAN`; `BEHIND`, `DIRTY`, or `BLOCKED` is a stop condition.
3. `gh pr diff <PR> | grep -E '^[+-]?(<<<<<<<|=======|>>>>>>>)'` returns no conflict marker.
4. `git cat-file -e <headRefOid>:docs/superpowers/plans/2026-07-17-THR-12-s1-01-package-public-api.md` succeeds, and the PR body links that path rather than a stale revision.
5. The latest Paperclip CodeReviewer `APPROVE` and QA `QA PASS` both cite the same `headRefOid`.
6. QA's concrete evidence is copied into the PR body's `## QA Evidence` block. The CodeReviewer then performs one final pass over that body and exact unchanged head, posts the final Paperclip approval, and submits the required GitHub approval before the CTO merges.

Any push after reviewer, QA, CI, or final-body evidence invalidates the affected evidence and restarts the exact-head gate.

## Verification

```text
set -o pipefail
xcodebuild -version && xcrun swift --version
swift package resolve
swift build
swift build -Xswiftc -swift-version -Xswiftc 5 -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
swift test --enable-xctest --disable-swift-testing --parallel --num-workers 1 --filter ThorChainKitTests.PublicApiTests --xunit-output <temporary>/public-api.xml 2>&1 | tee <temporary>/public-api.log
xcrun swift Scripts/verify-s1-01-xunit.swift <temporary>/public-api.xml <temporary>/public-api.log Tests/ThorChainKitTests/Fixtures/S1-01-tests.txt
xcrun swift Scripts/verify-s1-01-values.swift Tests/ThorChainKitTests/Fixtures/S1-01-value-syntax.txt
Scripts/verify-bigint-floor.sh
Scripts/test-s1-01-mutants.sh
swift test
Scripts/verify-s1-01.sh
THORCHAIN_SIMULATOR_UDID=<exact-udid> xcodebuild -workspace 'iOS Example/iOS Example.xcworkspace' -scheme 'iOS Example' -destination 'platform=iOS Simulator,id=<exact-udid>' CODE_SIGNING_ALLOWED=NO build
THORCHAIN_SIMULATOR_UDID=<exact-udid> Scripts/run-maestro.sh
```

`Scripts/verify-s1-01.sh` includes the temporary public-only Swift-tools-5.10/iOS-13 consumer build. No host `swift build` result substitutes for the iOS `xcodebuild` gate.

## Acceptance Criteria

- The package builds independently and contains one `ThorChainKit` library product.
- `ThorChainKitTests` exists and all 18 authoritative behavioral methods are discovered and executed exactly once with zero skips, disabled cases, failures, or errors; the `XCTSkip` canary fails the independent transcript/status gate even though SwiftPM's xUnit schema cannot encode skips.
- Public symbols and signatures exactly match the committed S1-01 symbol baseline. S1-02…S1-05 each own a slice-versioned exact current-surface baseline plus cumulative prior-baseline subset compatibility; additions are recorded only in the current baseline, while any prior removal or signature mutation fails.
- Network, endpoint, denom, and Address construction enforce every pinned boundary and invariant; valid canonical `thor`, `sthor`, and `cthor` addresses produce the exact internal 20-byte payload; the public factory rejects whitespace-only wallet IDs and derives its sole network from `address.network`; the fixed namespace input produces `e2df225b7a00d471b1b09ec2d3344df89a11e9cfe116c05f5290683480623015` and separator/order mutants fail.
- The exact positive public-value construction closure passes for every enumerated initializer, stored/static root, transitive body, and default expression; all seven Address/endpoint/Network/Denom/default-path canaries fail before the external consumer build.
- The exact positive factory syntax/callee allowlist, including the exact transitive `Network.persistenceKey` getter and dispatcher-specific key operations, passes; the factory does not start network/sync or create a network/request, task, operation/global queue, timer, dispatch-source, file, storage/database, wrapper, alias, or unaudited-helper capability.
- Initial getters and mandatory replaying publishers are exactly nil/idle/zero/no-account, without a fabricated account/balance or zero-as-height shortcut.
- There is no seed/private key, MarketKit, RxSwift, UIKit, SwiftUI, or WalletCore in the public API; Combine is the public state-publication framework.
- Parsed manifest topology, committed BigInt `5.7.0` default lock, isolated exact-`5.0.0` floor build/test, pinned Xcode/Swift identity, Swift-5 strict-concurrency warnings-as-errors, import allowlist, public symbol graph, exact test discovery, and temporary public-only iOS-13 consumer gates are green.
- The named Example workspace subgate proves exact `container:iOS Example.xcodeproj` plus `group:..`; the UIKit-free SwiftUI app then launches from the shared workspace/scheme, uses the local package root, and observes kit state through Combine.
- The sole exact-UDID Maestro runner uses immutable archive/action pins plus compatible Maestro/Temurin identities and repo-root-absolute output paths, reports one test with zero failures/errors/skips, and recursively fails closed while scanning the separate JUnit plus all raw/Vision-OCR artifacts; argv/path canaries prove one device and one artifact root end-to-end.
- The committed S1-01 public-symbol baseline exists and is the input to the separately enforced S1-02…S1-05 compatibility invariant.
- The committed Gimle report contains no operator-local absolute path; only the external canonical audit retains machine-local roots.
- Required checks are green, merge state is `CLEAN`, the diff has no conflict marker, the referenced plan exists, and final CodeReviewer approval follows QA evidence in the PR body. Reviewer, QA, and CI cite the same final `headRefOid`; the same PR carries the real PR-number roadmap marker, and post-merge evidence verifies `mergeCommit.oid` on `origin/main`.

## Pinned Decision

The minimum target is iOS 13 for parity with TronKit/EvmKit. S1-03/S1-05 dependency resolution must confirm HsCryptoKit/GRDB compatibility with iOS 13; incompatibility returns the spec for review, and the target is not raised silently.
