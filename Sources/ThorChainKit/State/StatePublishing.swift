import Combine
import Foundation

final class StatePublishing {
    let lastBlockHeightSubject = CurrentValueSubject<Int64?, Never>(nil)
    let syncStateSubject = CurrentValueSubject<SyncState, Never>(.idle(cached: false))
    let accountStateSubject = CurrentValueSubject<AccountState?, Never>(nil)
    private(set) var snapshot = StateSnapshot(
        accountState: nil,
        syncState: .idle(cached: false),
        lastBlockHeight: nil
    )

    func apply(_ snapshot: StateSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
        lastBlockHeightSubject.send(snapshot.lastBlockHeight)
        syncStateSubject.send(snapshot.syncState)
        accountStateSubject.send(snapshot.accountState)
    }
}
