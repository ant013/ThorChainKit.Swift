import Foundation

final class AccountStateManager {
    private(set) var accountState: AccountState?

    func accept(_ accountState: AccountState) {
        self.accountState = accountState
    }
}
