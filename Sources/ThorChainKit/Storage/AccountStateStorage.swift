import Foundation

protocol AccountStateStorage: Sendable {
    func load(key: StorageKey) async throws -> StorageRecord?
    func advanceGeneration(key: StorageKey) throws -> UInt64
    func saveIfCurrent(_ record: StorageRecord, key: StorageKey, expectedGeneration: UInt64) async throws -> Bool
    func clear(key: StorageKey) async throws
}
