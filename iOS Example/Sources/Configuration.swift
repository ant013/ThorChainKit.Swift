import Foundation

enum Configuration {
    static let address = "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2"
    static let fixtureIdentifier = "fixture-instance"
    static let fixtureOfflineKey = "thorchainkit.example.fixture-offline"
    static let fixturePendingKey = "thorchainkit.example.fixture-pending"
    static let fixtureRequestCountKey = "thorchainkit.example.fixture-request-count"
    static let cosmosRestURL = URL(string: "https://rest.invalid")!
    static let cometBftURL = URL(string: "https://rpc.invalid")!
}
