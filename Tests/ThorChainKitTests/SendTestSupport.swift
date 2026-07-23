import Foundation
import BigInt
@testable import ThorChainKit

func sendTestAddress() throws -> Address {
    try Address(
        "thor1x0jkvqdh2hlpeztd5zyyk70n3efx6mhudkmnn2",
        network: .mainnet
    )
}

func sendOtherAddress() throws -> Address {
    try Address(
        "thor1tgxm5jw6hrlvslrd6lqpk4jwuu4g29dxytrean",
        network: .mainnet
    )
}

final class TestSendClock: SendMonotonicClock, @unchecked Sendable {
    var now: UInt64

    init(now: UInt64 = 1_000) {
        self.now = now
    }
}

func issueTestQuote(
    in store: QuoteStore,
    clock: TestSendClock,
    generation: UInt64 = 7,
    amount: BigUInt = 100,
    nativeFee: BigUInt = 2,
    memo: String? = nil
) throws -> SendQuote {
    let amountMagnitude = SendMagnitude(amount).data
    let nativeFeeMagnitude = SendMagnitude(nativeFee).data
    let totalDebitMagnitude = SendMagnitude(amount + nativeFee).data
    return try store.issue(
        sender: try sendTestAddress(),
        recipient: try sendTestAddress(),
        amountMagnitude: amountMagnitude,
        isMaximum: false,
        nativeFeeMagnitude: nativeFeeMagnitude,
        totalDebitMagnitude: totalDebitMagnitude,
        memo: memo,
        acceptedHeight: 12,
        generation: generation
    )
}
