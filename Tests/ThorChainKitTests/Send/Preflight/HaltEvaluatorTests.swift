import XCTest
@testable import ThorChainKit

final class HaltEvaluatorTests: XCTestCase {
    func testUnsetMimirValuesAreInactive() throws {
        let snapshot = MimirSnapshot(
            haltChainGlobal: -1,
            nodePauseChainGlobal: -1,
            haltTHORChain: 0,
            solvencyHaltTHORChain: -1
        )
        XCTAssertEqual(try HaltEvaluator.evaluate(height: 100, mimir: snapshot), .allowed)
    }

    func testBoundariesUseThePinnedHeight() {
        let snapshot = MimirSnapshot(
            haltChainGlobal: 100,
            nodePauseChainGlobal: -1,
            haltTHORChain: -1,
            solvencyHaltTHORChain: -1
        )
        XCTAssertEqual(try? HaltEvaluator.evaluate(height: 99, mimir: snapshot), .allowed)
        XCTAssertEqual(try? HaltEvaluator.evaluate(height: 100, mimir: snapshot), .halted)
        XCTAssertEqual(try? HaltEvaluator.evaluate(height: 101, mimir: snapshot), .halted)
    }
}
