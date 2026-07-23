import Foundation
import XCTest
@testable import ThorChainKit

final class QuoteStoreTests: XCTestCase {
    func testConsumeIsAtomicAndOneUse() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock)

        XCTAssertNoThrow(try store.consume(quote, activeGeneration: 7))
        XCTAssertThrowsError(try store.consume(quote, activeGeneration: 7)) { error in
            XCTAssertEqual(error as? SendError, .quoteAlreadyConsumed)
        }
    }

    func testConcurrentConsumeHasOneWinner() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock)
        let results = ConcurrentQuoteResults()

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            let result = Result { try store.consume(quote, activeGeneration: 7) }
            results.append(result)
        }

        XCTAssertEqual(results.values.compactMap { try? $0.get() }.count, 1)
        XCTAssertEqual(
            results.values.compactMap { result -> SendError? in
                guard case let .failure(error) = result else { return nil }
                return error as? SendError
            }.filter { $0 == .quoteAlreadyConsumed }.count,
            31
        )
    }

    func testExpiryUsesTenSecondExclusiveBoundary() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock)

        clock.now += 9_999_999_999
        XCTAssertNoThrow(try store.consume(quote, activeGeneration: 7))

        let second = try issueTestQuote(in: store, clock: clock, generation: 8)
        clock.now += 10_000_000_000
        XCTAssertThrowsError(try store.consume(second, activeGeneration: 8)) { error in
            XCTAssertEqual(error as? SendError, .quoteExpired)
        }
    }

    func testAuthorityAndGenerationArePerStoreAndPerLifecycle() throws {
        let clock = TestSendClock()
        let first = QuoteStore(clock: clock)
        let second = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: first, clock: clock)

        XCTAssertThrowsError(try second.consume(quote, activeGeneration: 7)) { error in
            XCTAssertEqual(error as? SendError, .quoteOwnershipMismatch)
        }
        XCTAssertThrowsError(try first.consume(quote, activeGeneration: 8)) { error in
            XCTAssertEqual(error as? SendError, .quoteGenerationInvalidated)
        }
    }

    func testInvalidationLeavesStoredQuoteUnavailable() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock, generation: 3)

        store.invalidate(generation: 3)
        XCTAssertThrowsError(try store.consume(quote, activeGeneration: 4)) { error in
            XCTAssertEqual(error as? SendError, .quoteGenerationInvalidated)
        }
    }

    func testTerminalTombstoneIsKeptThroughOriginatingDeadlineThenCleaned() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock, generation: 3)

        store.invalidate(generation: 3)
        XCTAssertFalse(store.isEmpty())
        clock.now += 9_999_999_999
        XCTAssertFalse(store.isEmpty())
        clock.now += 1
        XCTAssertTrue(store.isEmpty())
        XCTAssertThrowsError(try store.consume(quote, activeGeneration: 3)) { error in
            XCTAssertEqual(error as? SendError, .quoteExpired)
        }
    }

    func testConsumedTombstoneIsKeptThroughOriginatingDeadlineThenCleaned() throws {
        let clock = TestSendClock()
        let store = QuoteStore(clock: clock)
        let quote = try issueTestQuote(in: store, clock: clock)

        XCTAssertNoThrow(try store.consume(quote, activeGeneration: 7))
        XCTAssertFalse(store.isEmpty())
        clock.now += 10_000_000_000 - 1
        XCTAssertFalse(store.isEmpty())
        clock.now += 1
        XCTAssertTrue(store.isEmpty())
    }

    func testOwnUnexpiredMissingQuoteIsUnavailable() throws {
        let clientID = UUID()
        let clock = TestSendClock()
        let source = QuoteStore(clientID: clientID, clock: clock)
        let destination = QuoteStore(clientID: clientID, clock: clock)
        let quote = try issueTestQuote(in: source, clock: clock)

        XCTAssertThrowsError(try destination.consume(quote, activeGeneration: 7)) { error in
            XCTAssertEqual(error as? SendError, .operationUnavailable)
        }
    }
}

private final class ConcurrentQuoteResults: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values = [Result<QuoteAuthorityRecord, Error>]()

    func append(_ value: Result<QuoteAuthorityRecord, Error>) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }
}
