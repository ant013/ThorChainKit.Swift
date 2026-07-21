import Foundation

struct RequestBuilder: Sendable {
    private let baseURL: URL
    private let requestTimeout: TimeInterval
    private let clientId: String?

    init(baseURL: URL, requestTimeout: TimeInterval, clientId: String?) {
        self.baseURL = baseURL
        self.requestTimeout = requestTimeout
        self.clientId = clientId
    }

    func request(
        path: [String],
        queryItems: [URLQueryItem] = [],
        cosmosHeight: Int64? = nil
    ) -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        let base = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedPath = path.map(encodePathComponent).filter { !$0.isEmpty }
        components.percentEncodedPath = "/" + ([base] + encodedPath).filter { !$0.isEmpty }.joined(separator: "/")
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let clientId, !clientId.isEmpty {
            request.setValue(clientId, forHTTPHeaderField: "X-Client-ID")
        }
        if let cosmosHeight {
            request.setValue(String(cosmosHeight), forHTTPHeaderField: "x-cosmos-block-height")
        }
        return request
    }

    private func encodePathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/")))!
    }
}
