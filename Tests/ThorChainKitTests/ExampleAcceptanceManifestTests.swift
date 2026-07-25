import XCTest

final class ExampleAcceptanceManifestTests: XCTestCase {
    private struct Manifest: Decodable {
        struct Flow: Decodable {
            let flow: String
            let actions: [String]
            let assertions: [String]
        }
        let flows: [Flow]
    }

    private let flows = [
        "send-quote-review",
        "send-checktx-accepted",
        "send-unknown",
        "send-retry",
        "send-restart-pending"
    ]

    func testCommittedManifestHasExactlyTheFiveSprintTwoFlows() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Scripts/sprint-02-flow-manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        XCTAssertEqual(manifest.flows.map(\.flow), flows)
    }

    func testEachFlowHasActionAndAssertionMatrix() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Scripts/sprint-02-flow-manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        for flow in manifest.flows {
            XCTAssertFalse(flow.actions.isEmpty)
            XCTAssertFalse(flow.assertions.isEmpty)
        }
    }
}
