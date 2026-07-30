import Foundation
import XCTest
@testable import ThorChainKit

final class KitLifecycleTests: XCTestCase {
    func testKitDelegatesDirectlyToSyncer() async throws {
        let kit = makeTestKit(address: try sendTestAddress(), persistenceNamespace: "lifecycle")

        kit.start()
        kit.start()
        kit.refresh()
        kit.stop()
        kit.stop()
        kit.refresh()

        if case .idle = kit.syncState {} else { XCTFail("stopped kit must be idle") }
    }

    func testInitialAccountPublishersReplayEmptyState() throws {
        let kit = makeTestKit(address: try sendTestAddress(), persistenceNamespace: "lifecycle")
        XCTAssertNil(kit.lastBlockHeight)
        XCTAssertEqual(kit.syncState, .idle(cached: false))
        XCTAssertNil(kit.accountState)
    }
}
