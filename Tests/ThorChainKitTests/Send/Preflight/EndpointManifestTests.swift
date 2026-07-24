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

    func testCapabilityManifestIsExactlyThreeFamiliesAndTenReadOnlyRoutes() {
        let capabilities = NativeRuneEndpointRegistry.capabilities()
        XCTAssertEqual(capabilities.count, 3)
        XCTAssertEqual(capabilities.map(\.familyID), NativeRuneEndpointRegistry.familyIDs)
        for capability in capabilities {
            XCTAssertEqual(capability.routes.count, 10)
            XCTAssertEqual(capability.status, .unrun)
            XCTAssertFalse(capability.isSendCapable)
            XCTAssertTrue(capability.routes.allSatisfy { $0.capabilityStatus == .unrun })
            XCTAssertTrue(capability.routes.allSatisfy { !$0.schemaRevision.isEmpty })
            XCTAssertTrue(capability.routes.allSatisfy { !$0.path.isEmpty && !$0.supportedNodeRevision.isEmpty })
            XCTAssertEqual(capability.routes.filter { $0.queryKey != nil }.count, 4)
            XCTAssertEqual(Set(capability.routes.compactMap(\.queryKey)), ["HaltChainGlobal", "NodePauseChainGlobal", "HaltTHORChain", "SolvencyHaltTHORChain"])
            let spendable = capability.routes.first { $0.route == "spendable-rune" }!
            XCTAssertEqual(spendable.path, "/cosmos/bank/v1beta1/spendable_balances/{address}/by_denom")
            XCTAssertEqual(spendable.queryParameterName, "denom")
            XCTAssertEqual(spendable.queryParameterValue, "rune")
            XCTAssertNil(spendable.historicalHeightParameter)
            XCTAssertNil(capability.routes.first { $0.route == "auth-params" }?.historicalHeightParameter)
            XCTAssertEqual(capability.routes.filter { $0.route.hasPrefix("mimir-") || $0.route == "node-version" }.count, 5)
            XCTAssertTrue(capability.routes.filter { $0.route.hasPrefix("mimir-") || $0.route == "node-version" }.allSatisfy { $0.historicalHeightParameter == "height" })
            XCTAssertEqual(capability.routes.first { $0.route == "network-fee" }?.proofMode, .cometABCI)
            XCTAssertEqual(capability.routes.first { $0.route == "node-version" }?.path, "/thorchain/version")
            XCTAssertTrue(capability.routes.filter { $0.route.hasPrefix("mimir-") }.allSatisfy { $0.path == "/thorchain/mimir/key/{key}" })
        }
    }

    func testCapabilityManifestRejectsUnknownFamilyAndLiquify() {
        XCTAssertFalse(NativeRuneEndpointRegistry.familyIDs.contains("liquify-mainnet"))
        XCTAssertFalse(NativeRuneEndpointRegistry.familyIDs.contains("unknown-mainnet"))
        XCTAssertFalse(NativeRuneEndpointRegistry.capabilities().contains { $0.familyID == "liquify-mainnet" })
    }

    func testEveryFamilyPinsEveryRouteToOneProofAndEncoding() {
        let expectedRoutes = Set([
            "account", "spendable-rune", "network-fee",
            "mimir-halt-chain-global", "mimir-node-pause-chain-global",
            "mimir-halt-thorchain", "mimir-solvency-halt-thorchain",
            "auth-params", "node-version", "recipient-account"
        ])
        for family in NativeRuneEndpointRegistry.capabilities() {
            XCTAssertEqual(Set(family.routes.map(\.route)), expectedRoutes)
            XCTAssertEqual(family.routes.filter { $0.proofMode == .cometABCI }.count, 3)
            XCTAssertEqual(family.routes.filter { $0.proofMode == .bodyHeight }.count, 0)
            XCTAssertEqual(family.routes.filter { $0.proofMode == .restHeader }.count, 7)
            XCTAssertTrue(family.routes.allSatisfy { $0.requestEncoding == ($0.proofMode == .cometABCI ? .protobufABCI : .jsonREST) })
        }
    }

    func testCapabilityStatusDistinguishesPassFailAndUnrun() {
        let pass = NativeRuneEndpointRegistry.capabilities().map { capability in
            SendFamilyCapability(familyID: capability.familyID, manifestRevision: capability.manifestRevision, routes: capability.routes.map { route in routeCopy(route, status: .pass) })
        }
        XCTAssertTrue(pass.allSatisfy { $0.status == .pass && $0.isSendCapable })
        let fail = pass.map { capability in
            SendFamilyCapability(familyID: capability.familyID, manifestRevision: capability.manifestRevision, routes: capability.routes.enumerated().map { index, route in routeCopy(route, status: index == 0 ? .fail : .pass) })
        }
        XCTAssertTrue(fail.allSatisfy { $0.status == .fail && !$0.isSendCapable })
        let unrun = pass.map { capability in
            SendFamilyCapability(familyID: capability.familyID, manifestRevision: capability.manifestRevision, routes: capability.routes.enumerated().map { index, route in routeCopy(route, status: index == 0 ? .unrun : .pass) })
        }
        XCTAssertTrue(unrun.allSatisfy { $0.status == .unrun && !$0.isSendCapable })
    }

    private func routeCopy(_ route: SendManifestRoute, status: SendCapabilityStatus) -> SendManifestRoute {
        SendManifestRoute(record: route.record, route: route.route, path: route.path, requestEncoding: route.requestEncoding, decoder: route.decoder, proofMode: route.proofMode, schemaRevision: route.schemaRevision, supportedNodeRevision: route.supportedNodeRevision, historicalHeightParameter: route.historicalHeightParameter, queryKey: route.queryKey, queryParameterName: route.queryParameterName, queryParameterValue: route.queryParameterValue, capabilityStatus: status)
    }
}
