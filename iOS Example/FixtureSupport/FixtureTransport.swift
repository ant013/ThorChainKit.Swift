import Foundation
import CryptoKit
import ThorChainKit
@_spi(Testing) import ThorChainKit

public struct FixtureRequest: Equatable, Sendable {
    public let method: String
    public let origin: String
    public let path: String
    public let query: String
    public let body: Data?

    public init(method: String, origin: String, path: String, query: String = "", body: Data? = nil) {
        self.method = method
        self.origin = origin
        self.path = path
        self.query = query
        self.body = body
    }
}

public actor FixtureTranscript {
    private let expected: [FixtureRequest]
    private var position = 0

    public init(expected: [FixtureRequest]) { self.expected = expected }

    public func record(_ request: FixtureRequest) throws {
        guard position < expected.count, expected[position] == request else {
            throw URLError(.cannotParseResponse)
        }
        position += 1
    }

    public func finish() throws {
        guard position == expected.count else { throw URLError(.cannotParseResponse) }
    }
}

public actor FixtureTransport: TestingHTTPTransport {
    public private(set) var requestCount = 0
    private let scenario: FixtureScenario
    private let transcript: FixtureTranscript?
    private var offline = false
    private var pending = false
    private var broadcastCalls = 0
    private var continuations = [CheckedContinuation<Void, Never>]()

    public init(scenario: FixtureScenario, transcript: FixtureTranscript? = nil) {
        self.scenario = scenario
        self.transcript = transcript
    }

    public func setOffline(_ value: Bool) { offline = value }
    public var isPending: Bool { pending }
    public func setPending(_ value: Bool) {
        pending = value
        if !value { releasePending() }
    }
    public func releasePending() {
        pending = false
        let waiting = continuations
        continuations.removeAll()
        waiting.forEach { $0.resume() }
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCount += 1
        let url = try requireURL(request)
        try await transcript?.record(FixtureRequest(
            method: request.httpMethod ?? "GET",
            origin: "\(url.scheme ?? "")://\(url.host ?? "")\(url.port.map { ":\($0)" } ?? "")",
            path: url.path,
            query: url.query ?? "",
            body: request.httpBody
        ))
        if pending {
            await withTaskCancellationHandler(operation: {
                await withCheckedContinuation { continuations.append($0) }
            }, onCancel: { Task { await self.releasePending() } })
        }
        guard !offline else { throw URLError(.notConnectedToInternet) }
        let path = url.path
        let response: (Data, Int, [String: String])
        if path.hasSuffix("node_info") {
            response = (#"{"default_node_info":{"network":"thorchain-1"}}"#.data(using: .utf8)!, 200, [:])
        } else if path.hasSuffix("blocks/latest") || path == "/status" {
            response = (#"{"result":{"node_info":{"network":"thorchain-1"},"sync_info":{"latest_block_height":"12345678","catching_up":false},"block":{"header":{"chain_id":"thorchain-1","height":"12345678"}}}}"#.data(using: .utf8)!, 200, ["Grpc-Metadata-X-Cosmos-Block-Height": "12345678"])
        } else if path.contains("/accounts/") {
            response = (#"{"account":{"@type":"/cosmos.auth.v1beta1.BaseAccount","account_number":"123456","sequence":"1"}}"#.data(using: .utf8)!, 200, ["Grpc-Metadata-X-Cosmos-Block-Height": "12345678"])
        } else if path.contains("/balances/") {
            response = (#"{"balances":[{"denom":"rune","amount":"700000000"}],"pagination":{"next_key":null}}"#.data(using: .utf8)!, 200, ["Grpc-Metadata-X-Cosmos-Block-Height": "12345678"])
        } else if path.contains("/txs/") && scenario.id == .unknown {
            let hash = url.lastPathComponent
            response = (Data(#"{"code":5,"message":"rpc error: code = NotFound desc = tx not found: \#(hash): key not found","details":[]}"#.utf8), 404, [:])
        } else if request.httpMethod == "POST" {
            broadcastCalls += 1
            if scenario.id == .unknown && broadcastCalls == 1 {
                throw URLError(.networkConnectionLost)
            }
            guard let body = request.httpBody,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let encoded = object["tx_bytes"] as? String,
                  let raw = Data(base64Encoded: encoded) else { throw URLError(.cannotParseResponse) }
            let hash = Data(SHA256.hash(data: raw)).map { String(format: "%02X", $0) }.joined()
            response = (Data(#"{"tx_response":{"code":0,"codespace":"sdk","txhash":"\#(hash)"}}"#.utf8), 200, [:])
        } else {
            response = (Data(#"{"tx_response":{"code":1,"codespace":"sdk"}}"#.utf8), 404, [:])
        }
        var headers = response.2
        headers["Content-Type"] = "application/json"
        return (
            response.0,
            HTTPURLResponse(url: url, statusCode: response.1, httpVersion: nil, headerFields: headers)!
        )
    }

    private func requireURL(_ request: URLRequest) throws -> URL {
        guard let url = request.url else { throw URLError(.badURL) }
        return url
    }
}
