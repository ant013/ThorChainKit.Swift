@testable import ThorChainKit

final class TransactionStorageFixture {
    let storage: TransactionStorage

    private init(storage: TransactionStorage) {
        self.storage = storage
    }

    static func open(path: String) throws -> TransactionStorageFixture {
        try TransactionStorageFixture(storage: TransactionStorage(path: path))
    }
}
