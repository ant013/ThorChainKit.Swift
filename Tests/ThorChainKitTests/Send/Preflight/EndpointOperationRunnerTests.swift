import XCTest
@testable import ThorChainKit

final class EndpointOperationRunnerTests: XCTestCase {
    func testDeadlineDoesNotAwaitAStalledOperation() async {
        let runner = EndpointOperationRunner(deadline: 0.01, maximumOrphanedOperations: 1)
        do {
            _ = try await runner.run {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return 1
            }
            XCTFail("deadline must win")
        } catch let error as EndpointOperationError {
            XCTAssertEqual(error, .deadlineExceeded)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testCancellationReturnsWithoutAwaitingNonCooperativeOperationAndCapsOrphans() async {
        let runner = EndpointOperationRunner(deadline: 10, maximumOrphanedOperations: 1)
        let task = Task {
            try await runner.run {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                return 1
            }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("cancelled operation must fail") }
        catch let error as EndpointOperationError { XCTAssertEqual(error, .cancelled) }
        catch { XCTFail("unexpected error: \(error)") }

        do {
            _ = try await runner.run { 2 }
            XCTFail("orphan cap must fail closed")
        } catch let error as EndpointOperationError {
            XCTAssertEqual(error, .orphanCapReached)
        } catch { XCTFail("unexpected error: \(error)") }
    }
}
