import SwiftUI
import ThorChainKit

struct AddressView: View {
    @StateObject private var model: AddressViewModel

    init(network: Network) {
        _model = StateObject(wrappedValue: AddressViewModel(network: network))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                row("Derived Address", model.derivedAddress, "derived-address")
                row("Uppercase Normalization", model.canonicalUppercase, "canonical-uppercase")
                row("Mixed Case", model.mixedCaseResult, "mixed-case-result")
                row("Wrong HRP", model.wrongHrpResult, "wrong-hrp-result")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle("Address Codec")
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
