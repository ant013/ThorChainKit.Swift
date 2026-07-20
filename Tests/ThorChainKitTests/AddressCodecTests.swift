import Foundation
import XCTest
@testable import ThorChainKit

final class AddressCodecTests: XCTestCase {
    private let payload = Data(hex: "5a0dba49dab8fec87c6dd7c01b564ee72a8515a6")

    func testEncodeAndDecodeBindsAllSupportedNetworks() throws {
        let codec = AddressCodec()
        let networks = [
            Network.mainnet,
            try Network.stagenet(expectedChainId: "stage-1"),
            try Network.chainnet(expectedChainId: "chain-1"),
        ]

        for network in networks {
            let address = try codec.encode(payload: payload, network: network)
            XCTAssertEqual(address.network, network)
            XCTAssertEqual(try codec.decode(address.raw.uppercased(), network: network), address)
        }
    }

    func testEncodeRejectsWrongPayloadLength() {
        XCTAssertThrowsError(try AddressCodec().encode(payload: Data(repeating: 0, count: 19), network: .mainnet)) { error in
            XCTAssertEqual(error as? AddressError, .invalidPayloadLength(expected: 20, actual: 19))
        }
    }

    func testDecodeDelegatesInheritedValidation() throws {
        let codec = AddressCodec()
        let address = try codec.encode(payload: payload, network: .mainnet)
        let wrongNetworkAddress = try codec.encode(
            payload: payload,
            network: Network.stagenet(expectedChainId: "stage-1")
        )
        XCTAssertThrowsError(try codec.decode(wrongNetworkAddress.raw, network: .mainnet)) { error in
            XCTAssertEqual(error as? AddressError, .wrongHrp(expected: "thor", actual: "sthor"))
        }
        XCTAssertThrowsError(try codec.decode(address.raw.dropLast() + "q", network: .mainnet)) { error in
            XCTAssertEqual(error as? AddressError, .invalidChecksum)
        }
    }

    func testClassicBech32IsNotBech32m() throws {
        let address = try AddressCodec().encode(payload: payload, network: .mainnet)
        XCTAssertEqual(address.raw, "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean")
    }
}

private extension Data {
    init(hex: String) {
        self.init(hex.chunked(2).map { UInt8($0, radix: 16)! })
    }
}

private extension String {
    func chunked(_ size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map { offset in
            let start = index(startIndex, offsetBy: offset)
            let end = index(start, offsetBy: min(size, distance(from: start, to: endIndex)))
            return String(self[start..<end])
        }
    }
}
