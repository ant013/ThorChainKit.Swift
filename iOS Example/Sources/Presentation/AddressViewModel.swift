import Combine
import Foundation
import ThorChainKit

@MainActor
final class AddressViewModel: ObservableObject {
    @Published private(set) var derivedAddress = "unavailable"
    @Published private(set) var canonicalUppercase = "unavailable"
    @Published private(set) var mixedCaseResult = "unavailable"
    @Published private(set) var wrongHrpResult = "unavailable"

    init(network: Network) {
        let publicKey = Data([
            0x02, 0xa9, 0xac, 0x9f, 0x7a, 0x97, 0xda, 0x41, 0x55, 0x9e, 0x16,
            0x84, 0x01, 0x1b, 0x6a, 0x9b, 0x0b, 0x9c, 0x04, 0x45, 0x29, 0x7d,
            0x5f, 0x51, 0xde, 0xa0, 0x89, 0x7f, 0xd4, 0xa3, 0x9c, 0x31, 0xc7,
        ])
        do {
            let address = try AccountAddressFactory.address(
                compressedPublicKey: publicKey,
                network: network
            )
            let codec = AddressCodec()
            derivedAddress = address.raw
            canonicalUppercase = try codec.decode(address.raw.uppercased(), network: network).raw
            mixedCaseResult = Self.failureName {
                try codec.decode(
                    address.raw.prefix(6).uppercased() + String(address.raw.dropFirst(6)),
                    network: network
                )
            }
            let stagenet = try Network.stagenet(expectedChainId: "stage-1")
            let wrongNetworkAddress = try codec.encode(payload: Data(repeating: 0, count: 20), network: stagenet)
            wrongHrpResult = Self.failureName {
                try codec.decode(wrongNetworkAddress.raw, network: network)
            }
        } catch {
            derivedAddress = "unavailable"
        }
    }

    private static func failureName(_ operation: () throws -> Address) -> String {
        do {
            _ = try operation()
            return "accepted"
        } catch let error as AddressError {
            switch error {
            case .mixedCase: return "mixedCase"
            case .wrongHrp: return "wrongHrp"
            default: return "invalidAddress"
            }
        } catch {
            return "invalidAddress"
        }
    }
}
