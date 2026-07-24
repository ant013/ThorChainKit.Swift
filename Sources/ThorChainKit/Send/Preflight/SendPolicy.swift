import Foundation
import CryptoKit
import BigInt

struct SendPolicy: Equatable, Sendable {
    let memoMaximumBytes: Int
    let operationDeadline: TimeInterval
    let revision: String

    static let standard = SendPolicy(uncheckedMemoMaximumBytes: 256, operationDeadline: 15, revision: "s2-02-v1")

    init(memoMaximumBytes: Int = 256, operationDeadline: TimeInterval = 15, revision: String = "s2-02-v1") throws {
        guard memoMaximumBytes > 0, operationDeadline.isFinite, operationDeadline > 0, !revision.isEmpty else {
            throw SendError.policyUnavailable
        }
        self.memoMaximumBytes = memoMaximumBytes
        self.operationDeadline = operationDeadline
        self.revision = revision
    }

    private init(uncheckedMemoMaximumBytes: Int, operationDeadline: TimeInterval, revision: String) {
        memoMaximumBytes = uncheckedMemoMaximumBytes; self.operationDeadline = operationDeadline; self.revision = revision
    }

    func validate(memo: String?) throws {
        guard let memo else { return }
        guard memo.utf8.count <= memoMaximumBytes else {
            throw SendError.memoTooLong(maxUTF8Bytes: memoMaximumBytes)
        }
    }

    func resolve(amount: SendAmount, spendableRune: BigUInt, nativeFee: BigUInt) throws -> BigUInt {
        guard spendableRune >= nativeFee else { throw SendError.insufficientBalance }
        let resolved: BigUInt
        if let exact = amount.exactAmount {
            guard exact > 0 else { throw SendError.invalidAmount }
            resolved = exact
        } else {
            guard spendableRune > nativeFee else { throw SendError.insufficientBalance }
            resolved = spendableRune - nativeFee
        }
        guard resolved > 0, resolved <= spendableRune - nativeFee else {
            throw SendError.insufficientBalance
        }
        guard resolved + nativeFee <= spendableRune else { throw SendError.insufficientBalance }
        return resolved
    }
}

struct MimirSnapshot: Equatable, Sendable {
    let haltChainGlobal: Int64
    let nodePauseChainGlobal: Int64
    let haltTHORChain: Int64
    let solvencyHaltTHORChain: Int64
}

enum HaltDecision: Equatable, Sendable {
    case allowed
    case halted

    var isHalted: Bool { self == .halted }
}

enum HaltEvaluator {
    static func evaluate(height: Int64, mimir: MimirSnapshot) throws -> HaltDecision {
        guard height > 0,
              [mimir.haltChainGlobal, mimir.nodePauseChainGlobal, mimir.haltTHORChain, mimir.solvencyHaltTHORChain]
                .allSatisfy({ $0 >= -1 })
        else { throw SendError.policyUnavailable }

        let halted = (mimir.haltChainGlobal > 0 && mimir.haltChainGlobal <= height)
            || (mimir.nodePauseChainGlobal > 0 && mimir.nodePauseChainGlobal >= height)
            || (mimir.haltTHORChain > 0 && mimir.haltTHORChain <= height)
            || (mimir.solvencyHaltTHORChain > 0 && mimir.solvencyHaltTHORChain <= height)
        return halted ? .halted : .allowed
    }
}

struct ForbiddenModuleAddressSet: Sendable, Equatable {
    static let supportedVersions: Set<String> = ["3.19.0", "3.19.1", "3.19.2", "3.19.3"]
    let revision = "thorchain-3.19-module-addresses-v1"
    private let addresses: Set<String>

    init(current: String, querier: String, network: Network = .mainnet) throws {
        guard Self.supportedVersions.contains(current), Self.supportedVersions.contains(querier) else {
            throw SendError.policyUnavailable
        }
        let names = ["asgard", "bond", "reserve", "lending", "affiliate_collector", "thorchain", "tcy_claim", "tcy_stake", "treasury"]
        var values = Set<String>()
        for name in names {
            let digest = SHA256.hash(data: Data(name.utf8))
            let words = try BitConversion.convert(Array(digest.prefix(20)), fromBits: 8, toBits: 5, pad: true)
            values.insert(Bech32Codec.encode(hrp: network.accountHrp, words: words))
        }
        addresses = values
    }

    func contains(_ address: String) -> Bool { addresses.contains(address.lowercased()) }
}
