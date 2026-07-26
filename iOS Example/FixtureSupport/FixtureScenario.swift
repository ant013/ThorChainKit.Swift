import Foundation

public struct FixtureRequestPattern: Sendable {
    public let method: String
    public let origin: String
    public let path: String
    public let query: String?
    public let bodyRequired: Bool

    public init(method: String, origin: String, path: String, query: String? = nil, bodyRequired: Bool = false) {
        self.method = method
        self.origin = origin
        self.path = path
        self.query = query
        self.bodyRequired = bodyRequired
    }
}

public struct FixtureScenario: Sendable {
    public let namespace: String
    public let expectedDigest: Data
    public let expectedSignedBytes: Data
    public let expectedRequests: [FixtureRequestPattern]

    public init() {
        namespace = "thor-example/fixture/send-checktx-accepted"
        expectedDigest = Data(hex: "1ff56dd4c3627af0cee040965178f50c8d7c854e909d7b54aedbd1b7bf110b68")
        expectedSignedBytes = Data(hex: "0a530a510a0e2f74797065732e4d736753656e64123f0a14751e76e8199196d454941c45d1b3a323f1433bd612145a0dba49dab8fec87c6dd7c01b564ee72a8515a61a110a0472756e65120931303030303030303012590a500a460a1f2f636f736d6f732e63727970746f2e736563703235366b312e5075624b657912230a210279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f8179812040a0208011801120510c08db7011a4023103daa64330d051da3bfa85ea7c8af9080edf19b19a306403303634b0992a32cc1b9061b2e76cd245edb2976bb437bc6636dfb23deae31e38508c5478dae45")
        expectedRequests = Self.expectedRequests()
    }

    private static func expectedRequests() -> [FixtureRequestPattern] {
        let rest = "https://api-thorchain.rorcual.xyz"
        let rpc = "https://rpc-thorchain.rorcual.xyz"
        let sender = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68"
        let probes = [
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/base/tendermint/v1beta1/node_info"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/base/tendermint/v1beta1/blocks/latest"),
            FixtureRequestPattern(method: "GET", origin: rpc, path: "/status")
        ]
        let lifecycle = [
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/auth/v1beta1/accounts/\(sender)"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/bank/v1beta1/balances/\(sender)", query: "pagination.limit=100")
        ]
        let quote = [
            FixtureRequestPattern(method: "GET", origin: rpc, path: "/abci_query"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/bank/v1beta1/spendable_balances/\(sender)/by_denom", query: "denom=rune"),
            FixtureRequestPattern(method: "GET", origin: rpc, path: "/abci_query"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/thorchain/mimir/key/HaltChainGlobal", query: "height=12345678"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/thorchain/mimir/key/NodePauseChainGlobal", query: "height=12345678"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/thorchain/mimir/key/HaltTHORChain", query: "height=12345678"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/thorchain/mimir/key/SolvencyHaltTHORChain", query: "height=12345678"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/auth/v1beta1/params"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/thorchain/version", query: "height=12345678"),
            FixtureRequestPattern(method: "GET", origin: rpc, path: "/abci_query")
        ]
        var requests = probes + lifecycle + quote
        requests.append(FixtureRequestPattern(method: "POST", origin: rest, path: "/cosmos/tx/v1beta1/txs", bodyRequired: true))
        return requests
    }
}

private extension Data {
    init(hex: String) {
        self.init(stride(from: 0, to: hex.count, by: 2).compactMap {
            let start = hex.index(hex.startIndex, offsetBy: $0)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)
        })
    }
}
