import SwiftUI

struct LifecycleView: View {
    @ObservedObject var model: LifecycleViewModel

    var body: some View {
        Form {
            Section {
                Button("Start") { model.start() }
                    .accessibilityIdentifier("lifecycle-start")
                Button("Stop") { model.stop() }
                    .accessibilityIdentifier("lifecycle-stop")
                Button("Refresh") { model.refresh() }
                    .accessibilityIdentifier("lifecycle-refresh")
            } header: {
                Text("Lifecycle")
            }
            Section {
                Button("Offline") { model.toggleOffline() }
                    .accessibilityIdentifier("fixture-offline")
                Button("Pending request") { model.togglePending() }
                    .accessibilityIdentifier("fixture-pending")
                if model.pending {
                    Button("Release pending request") { model.releasePending() }
                        .accessibilityIdentifier("fixture-release-pending")
                }
                Text("Requests: \(model.requestCount)")
                    .accessibilityIdentifier("fixture-request-count")
                Text("Offline: \(model.offline)")
                    .accessibilityIdentifier("fixture-offline-state")
                Text("Pending: \(model.pending)")
                    .accessibilityIdentifier("fixture-pending-state")
            } header: {
                Text("Fixture")
            }
            Section {
                Text(model.syncDescription)
                    .accessibilityIdentifier("lifecycle-sync-state")
                Text("RUNE: \(model.runeBalance)")
                    .accessibilityIdentifier("fixture-rune")
                HStack {
                    Text("Accepted Height: \(model.acceptedHeight)")
                        .accessibilityIdentifier("fixture-accepted-height")
                    Text("Last Block Height: \(model.lastBlockHeight)")
                        .accessibilityIdentifier("fixture-last-block-height")
                }
            } header: {
                Text("State")
            }
        }
        .navigationTitle("Lifecycle")
    }
}
