import SwiftUI

struct AccountReadView: View {
    @ObservedObject var model: AccountReadViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let value = model.result {
                    row("Mode", value.mode, "account-read-mode")
                    row("Account Exists", value.exists, "account-read-exists")
                    row("RUNE", value.rune, "account-read-rune")
                    row("Height", value.height, "account-read-height")
                    row("Family", value.family, "account-read-family")
                } else {
                    Text("Loading")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Account Read")
        .onAppear { model.load() }
        .onDisappear { model.cancel() }
    }

    private func row(_ title: String, _ value: String, _ identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption).foregroundColor(.secondary)
            Text(value).accessibilityIdentifier(identifier)
        }
    }
}
