import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: DiagnosticsViewModel
    @StateObject private var endpoints: EndpointsViewModel

    init(model: DiagnosticsViewModel) {
        self.model = model
        _endpoints = StateObject(wrappedValue: EndpointsViewModel(runtime: model.runtime))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                row("Data Source", value: "FIXTURE", identifier: "data-source")
                row("Network", value: model.network, identifier: "network")
                row("Address", value: model.address, identifier: "address")
                row("Sync State", value: model.syncDescription, identifier: "sync-state")
                row(
                    "Last Block",
                    value: model.lastBlockHeight.map(String.init) ?? "nil",
                    identifier: "last-block"
                )
                row("RUNE Balance", value: model.runeBalance, identifier: "rune-balance")
                row("Account Exists", value: model.accountExists, identifier: "account-exists")
                row(
                    "Account State",
                    value: model.accountStateDescription,
                    identifier: "account-state"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("THORChainKit")
        .toolbar {
            HStack {
                NavigationLink(destination: AddressView(network: model.runtime.network)) {
                    Text("Address")
                        .accessibilityIdentifier("address-codec-open")
                }
                NavigationLink(destination: EndpointsView(model: endpoints)) {
                    Text("Endpoints")
                        .accessibilityIdentifier("endpoint-policy-open")
                }
            }
        }
    }

    private func row(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .accessibilityIdentifier(identifier)
        }
    }
}
