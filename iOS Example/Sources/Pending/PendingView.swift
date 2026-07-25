import SwiftUI

struct PendingView: View {
    @ObservedObject var model: SendViewModel

    var body: some View {
        Section("Pending") {
            Text(model.pendingStatus).accessibilityIdentifier("send.pending.list")
            ForEach(model.pending, id: \.transactionId) { transaction in
                VStack(alignment: .leading) {
                    Text(transaction.transactionId.hash)
                        .accessibilityIdentifier("send.pending.\(transaction.transactionId.hash).state")
                    Text(Self.state(transaction.state))
                    if case .unknown = transaction.state {
                        Button("Retry") { model.retry(transaction, acceptingFee: true) }
                            .accessibilityIdentifier("send.retry.button")
                        Text(transaction.nativeFee.description)
                            .accessibilityIdentifier("send.retry.fee-change")
                    }
                }
            }
        }
    }

    private static func state(_ state: PendingTransaction.State) -> String {
        switch state {
        case .checkTxAccepted: return "CheckTx accepted — not confirmed"
        case .unknown: return "Unknown — retry available"
        }
    }
}
