import SwiftUI

struct SendView: View {
    @ObservedObject var model: SendViewModel

    var body: some View {
        Form {
            Text(model.modeBadge)
                .accessibilityIdentifier("send.mode-badge")
                .accessibilityValue(model.runtime.mode.accessibilityValue)
            TextField("Recipient", text: $model.recipient)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("send.recipient.input")
            TextField("RUNE amount", text: $model.amount)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier("send.amount.input")
            TextField("Memo", text: $model.memo)
                .accessibilityIdentifier("send.memo.input")
            Button("Quote") { model.quote() }
                .accessibilityIdentifier("send.quote.button")
#if EXAMPLE_FIXTURE
            Button("Advance to expiry") { model.advanceToExpiry() }
                .accessibilityIdentifier("send.fixture.advance-to-expiry")
            Text(String(model.signerCallCount))
                .accessibilityIdentifier("send.fixture.signer-call-count")
#endif
            if let review = model.review {
                SendReviewView(model: model, review: review)
            }
            if !model.resultState.isEmpty {
                Text(model.resultState).accessibilityIdentifier("send.result.state")
                Text(model.localHash).accessibilityIdentifier("send.result.local-hash")
            }
            PendingView(model: model)
        }
        .navigationTitle("Send")
    }
}
