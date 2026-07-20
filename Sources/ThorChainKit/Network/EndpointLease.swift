import Foundation

struct EndpointLease: Sendable {
    let family: EndpointFamilyDescriptor
    let verifiedChainId: String
    let cosmosReadHeight: Int64
    let cometReferenceHeight: Int64
    let poolGeneration: UInt64
}
