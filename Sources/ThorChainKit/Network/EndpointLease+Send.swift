import Foundation

enum SendEndpointRole: String, Sendable { case rest, rpc }

struct SendManifestRecord: Equatable, Sendable {
    let familyID: String
    let role: SendEndpointRole
    let scheme: String
    let host: String
    let port: Int
    let path: String
}

enum NativeRuneEndpointRegistry {
    static let familyIDs = ["rorcual-mainnet", "ibs-mainnet", "keplr-mainnet"]

    static func families() throws -> [EndpointFamilyDescriptor] {
        try [
            EndpointFamilyDescriptor(id: "rorcual-mainnet", cosmosRestURL: URL(string: "https://api-thorchain.rorcual.xyz/")!, cometBftURL: URL(string: "https://rpc-thorchain.rorcual.xyz/")!),
            EndpointFamilyDescriptor(id: "ibs-mainnet", cosmosRestURL: URL(string: "https://thorchain.ibs.team/api")!, cometBftURL: URL(string: "https://thorchain.ibs.team/rpc")!),
            EndpointFamilyDescriptor(id: "keplr-mainnet", cosmosRestURL: URL(string: "https://lcd-thorchain.keplr.app/")!, cometBftURL: URL(string: "https://rpc-thorchain.keplr.app/")!)
        ]
    }

    static func records() -> [SendManifestRecord] {
        [
            .init(familyID: "rorcual-mainnet", role: .rest, scheme: "https", host: "api-thorchain.rorcual.xyz", port: 443, path: "/"),
            .init(familyID: "rorcual-mainnet", role: .rpc, scheme: "https", host: "rpc-thorchain.rorcual.xyz", port: 443, path: "/"),
            .init(familyID: "ibs-mainnet", role: .rest, scheme: "https", host: "thorchain.ibs.team", port: 443, path: "/api"),
            .init(familyID: "ibs-mainnet", role: .rpc, scheme: "https", host: "thorchain.ibs.team", port: 443, path: "/rpc"),
            .init(familyID: "keplr-mainnet", role: .rest, scheme: "https", host: "lcd-thorchain.keplr.app", port: 443, path: "/"),
            .init(familyID: "keplr-mainnet", role: .rpc, scheme: "https", host: "rpc-thorchain.keplr.app", port: 443, path: "/")
        ]
    }

    static func validate(_ families: [EndpointFamilyDescriptor]) -> Bool {
        let actual = families.flatMap { family in
            [record(family: family, role: .rest, url: family.cosmosRestURL), record(family: family, role: .rpc, url: family.cometBftURL)]
        }
        return actual == records()
    }

    private static func record(family: EndpointFamilyDescriptor, role: SendEndpointRole, url: URL) -> SendManifestRecord {
        .init(familyID: family.id, role: role, scheme: url.scheme?.lowercased() ?? "", host: url.host?.lowercased() ?? "", port: url.port ?? 443, path: url.path.isEmpty ? "/" : url.path)
    }
}

extension EndpointLease {
    var sendFamilyID: String { family.id }
    var commonReadHeight: Int64 { min(cosmosReadHeight, cometReferenceHeight) }
}

enum HeightProof: Equatable, Sendable {
    case restHeader(expected: Int64, actual: Int64?)
    case cometABCI(expected: Int64, actual: Int64?)
    case body(expected: Int64, actual: Int64?)

    var isExact: Bool {
        switch self {
        case let .restHeader(expected, actual), let .cometABCI(expected, actual), let .body(expected, actual): actual == expected && expected > 0
        }
    }
}
