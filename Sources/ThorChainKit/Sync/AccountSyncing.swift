import Foundation

protocol AccountSyncing: Sendable {
    func start(generation: UInt64) async
    func stop(generation: UInt64) async
    func cancelRefresh() async
    func cancelStop() async
    func refresh() async
}
