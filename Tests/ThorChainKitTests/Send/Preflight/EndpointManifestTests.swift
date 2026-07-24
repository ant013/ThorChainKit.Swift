import XCTest
@testable import ThorChainKit

final class EndpointManifestTests: XCTestCase {
    func testNativeRuneRegistryHasOnlyTheApprovedFamiliesAndSixRecords() throws {
        XCTAssertEqual(NativeRuneEndpointRegistry.familyIDs, ["rorcual-mainnet", "ibs-mainnet", "keplr-mainnet"])
        let families = try NativeRuneEndpointRegistry.families()
        XCTAssertTrue(NativeRuneEndpointRegistry.validate(families))
        XCTAssertEqual(NativeRuneEndpointRegistry.records().count, 6)
        XCTAssertFalse(NativeRuneEndpointRegistry.familyIDs.contains("liquify"))
    }

    func testEveryProofModeRequiresExactPositiveHeight() {
        XCTAssertTrue(HeightProof.restHeader(expected: 10, actual: 10).isExact)
        XCTAssertTrue(HeightProof.cometABCI(expected: 10, actual: 10).isExact)
        XCTAssertTrue(HeightProof.body(expected: 10, actual: 10).isExact)
        XCTAssertFalse(HeightProof.restHeader(expected: 10, actual: 11).isExact)
        XCTAssertFalse(HeightProof.body(expected: 10, actual: nil).isExact)
    }
}
