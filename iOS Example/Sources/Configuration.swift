import Foundation

enum Configuration {
    static let address = "thor1w508d6qejxtdg4y5r3zarvary0c5xw7ku6wp68"
    static let recipient = "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean"
    static let fixtureIdentifier = "fixture-instance"
    static let fixtureOfflineKey = "thorchainkit.example.fixture-offline"
    static let fixturePendingKey = "thorchainkit.example.fixture-pending"
    static let fixtureRequestCountKey = "thorchainkit.example.fixture-request-count"
    static let cosmosRestURL = URL(string: "https://rest.invalid")!
    static let cometBftURL = URL(string: "https://rpc.invalid")!
    static let liveCosmosRestURL = URL(string: "https://thornode.ninerealms.com")!
    static let liveCometBftURL = URL(string: "https://thornode.ninerealms.com")!
    static let liveSecretURL = URL(fileURLWithPath: ".env", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
}
