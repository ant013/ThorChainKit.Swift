import XCTest
@testable import ThorChainKit

final class PendingPublicationBarrierTests: XCTestCase {
    func testEveryGenerationIsPublishedBeforeTransport() async throws {
        let transactionID = try XCTUnwrap(TransactionID(hash: String(repeating: "A", count: 64)))
        let barrier = PendingPublicationBarrier()
        XCTAssertFalse(barrier.acknowledge(transactionID: transactionID, generation: 1))

        var events = [String]()
        events.append("journal")
        barrier.publish(transactionID: transactionID, generation: 1)
        events.append("published")
        let acknowledged = await barrier.wait(transactionID: transactionID, generation: 1)
        XCTAssertTrue(acknowledged)
        events.append("transport")
        XCTAssertEqual(events, ["journal", "published", "transport"])
    }

    func testObservationErrorInstallsReplacementGeneration() throws {
        let transactionID = try XCTUnwrap(TransactionID(hash: String(repeating: "B", count: 64)))
        let barrier = PendingPublicationBarrier()
        barrier.publish(transactionID: transactionID, generation: 1)
        barrier.reset()
        XCTAssertFalse(barrier.acknowledge(transactionID: transactionID, generation: 1))
        barrier.publish(transactionID: transactionID, generation: 2)
        XCTAssertTrue(barrier.acknowledge(transactionID: transactionID, generation: 2))
        XCTAssertFalse(barrier.acknowledge(transactionID: transactionID, generation: 1))
    }
}
