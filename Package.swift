// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ThorChainKit",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "ThorChainKit", targets: ["ThorChainKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "ThorChainKit", dependencies: ["BigInt"]),
        .testTarget(
            name: "ThorChainKitTests",
            dependencies: ["ThorChainKit"],
            exclude: ["Fixtures"]
        ),
    ]
)
