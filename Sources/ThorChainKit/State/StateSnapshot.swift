import BigInt
import Foundation

struct StateSnapshot: Equatable {
    let accountState: AccountState?
    let syncState: SyncState
    let lastBlockHeight: Int64?

    var runeBalance: BigUInt { accountState?.balances[.rune] ?? 0 }
}
