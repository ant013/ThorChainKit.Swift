import Foundation

public enum FixtureScenarioID: String, CaseIterable, Sendable {
    case quoteReview = "send-quote-review"
    case checkTxAccepted = "send-checktx-accepted"
    case unknown = "send-unknown"
    case retry = "send-retry"
    case restartPending = "send-restart-pending"
}

public struct FixtureScenario: Sendable {
    public let id: FixtureScenarioID
    public let namespace: String
    public let acceptedHeight: Int64
    public let expiresAt: Date
    public let expectedDigest: Data
    public let expectedSignedBytes: Data
    public let expectedTransactionHash: String
    public let currentNativeFee: UInt64
    public let expectedRequests: [FixtureRequestPattern]

    public init(id: FixtureScenarioID, now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.id = id
        namespace = "thor-example/fixture/\(id.rawValue)"
        acceptedHeight = 12_345_678
        expiresAt = now.addingTimeInterval(60)
        expectedDigest = Data(hex: "1ff56dd4c3627af0cee040965178f50c8d7c854e909d7b54aedbd1b7bf110b68")
        expectedSignedBytes = Data(hex: "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
        expectedTransactionHash = expectedDigest.map { String(format: "%02X", $0) }.joined()
        currentNativeFee = 2
        expectedRequests = Self.expectedRequests(for: id, transactionHash: expectedTransactionHash)
    }

    private static func expectedRequests(for id: FixtureScenarioID, transactionHash: String) -> [FixtureRequestPattern] {
        let rest = "https://rest.invalid"
        let rpc = "https://rpc.invalid"
        let sender = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68"
        let probes = [
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/base/tendermint/v1beta1/node_info"),
            FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/base/tendermint/v1beta1/blocks/latest"),
            FixtureRequestPattern(method: "GET", origin: rpc, path: "/status")
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
        var requests = probes + quote
        if id != .quoteReview {
            requests += quote + quote
            requests.append(FixtureRequestPattern(method: "POST", origin: rest, path: "/cosmos/tx/v1beta1/txs", bodyRequired: true))
        }
        if id == .retry {
            requests.append(FixtureRequestPattern(method: "GET", origin: rest, path: "/cosmos/tx/v1beta1/txs/\(transactionHash)"))
            requests.append(FixtureRequestPattern(method: "POST", origin: rest, path: "/cosmos/tx/v1beta1/txs", bodyRequired: true))
        }
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

public actor FixtureClock {
    public private(set) var now: Date

    public init(now: Date) { self.now = now }

    public func advanceToExpiry(of scenario: FixtureScenario) {
        now = scenario.expiresAt
    }
}
