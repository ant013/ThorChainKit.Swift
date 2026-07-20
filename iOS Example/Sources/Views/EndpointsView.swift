import SwiftUI

struct EndpointsView: View {
    @ObservedObject var model: EndpointsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 8) {
                    button("Healthy", identifier: "endpoint-scenario-healthy", scenario: .healthy)
                    button("Mixed", identifier: "endpoint-scenario-mixed", scenario: .mixedIdentity)
                    button(
                        "Catching Up",
                        identifier: "endpoint-scenario-catching-up",
                        scenario: .catchingUp
                    )
                    button(
                        "Stale Cosmos",
                        identifier: "endpoint-scenario-stale-cosmos",
                        scenario: .staleCosmos
                    )
                }

                if let snapshot = model.snapshot {
                    VStack(alignment: .leading, spacing: 12) {
                        row("Selected", snapshot.selectedFamilyId, "endpoint-selected-family")
                        row("Expected Identity", snapshot.expectedChainId, "endpoint-expected-identity")
                        row("Identity", snapshot.identityClassification, "endpoint-identity")
                        row("Cosmos Origin", snapshot.cosmosOrigin, "endpoint-cosmos-origin")
                        row("Comet Origin", snapshot.cometOrigin, "endpoint-comet-origin")
                        row("Cosmos Height", snapshot.cosmosHeight, "endpoint-cosmos-height")
                        row("Comet Height", snapshot.cometHeight, "endpoint-comet-height")
                        row("Height Skew", snapshot.heightSkew, "endpoint-height-skew")
                        row("Catching Up", snapshot.catchingUp, "endpoint-catching-up")
                        row("Rejection", snapshot.rejectionReason, "endpoint-rejection")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Endpoint Policy")
        .onAppear { model.load(.healthy) }
        .onDisappear { model.cancel() }
    }

    private func button(
        _ title: String,
        identifier: String,
        scenario: EndpointScenario
    ) -> some View {
        Button(title) { model.load(scenario) }
            .accessibilityIdentifier(identifier)
    }

    private func row(_ title: String, _ value: String, _ identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .accessibilityIdentifier(identifier)
        }
    }
}
