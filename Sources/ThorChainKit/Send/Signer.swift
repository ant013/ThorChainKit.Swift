import Foundation

public protocol Signer: Sendable {
    var compressedPublicKey: Data { get }
    func sign(_ request: SigningRequest) async throws -> Data
}
