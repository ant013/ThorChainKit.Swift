import Foundation
import XCTest

final class GeneratedProvenanceTests: XCTestCase {
    func testTransactionCodecProvenanceAndGeneratedSurfaceArePinned() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let provenance = try String(contentsOf: root.appendingPathComponent("Sources/ThorChainKit/Protocol/Generated/PROVENANCE.md"))
        XCTAssertTrue(provenance.contains("a759cb4f"))
        XCTAssertTrue(provenance.contains("v0.53.0"))
        XCTAssertTrue(provenance.contains("1.33.3"))
        XCTAssertTrue(provenance.contains("c169a5744230951031770e27e475ff6eefe51f9d"))
        XCTAssertTrue(provenance.contains("libprotoc` exact `34.1"))

        let generated = try String(contentsOf: root.appendingPathComponent("Sources/ThorChainKit/Protocol/Generated/Tx.pb.swift"))
        XCTAssertTrue(generated.contains("Cosmos_Tx_V1beta1_SignDoc"))
        XCTAssertTrue(generated.contains("Cosmos_Tx_V1beta1_TxRaw"))
    }
}
