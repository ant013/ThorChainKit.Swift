import BigInt
import Foundation
import XCTest
@testable import ThorChainKit

final class DirectLifecycleAdmissionTests: XCTestCase {
    func testStartActivatesAndStopInvalidatesSendRuntime() async throws {
        let address = try sendTestAddress()
        let runtime = SendRuntime(address: address)
        let kit = makeTestKit(
            address: address,
            sendRuntime: runtime,
            persistenceNamespace: "direct-admission"
        )

        kit.start()
        do {
            _ = try await kit.quote(to: try sendOtherAddress(), amount: .exact(BigUInt(0)))
            XCTFail("active runtime should reach local validation")
        } catch let error as SendError {
            XCTAssertEqual(error, .invalidAmount)
        }

        kit.stop()
        do {
            _ = try await kit.quote(to: try sendOtherAddress(), amount: .exact(BigUInt(1)))
            XCTFail("stopped runtime must reject admission")
        } catch let error as SendError {
            XCTAssertEqual(error, .kitNotStarted)
        }
    }
}
