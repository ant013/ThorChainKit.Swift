import SwiftUI
import ThorChainKit

struct SendReviewView: View {
    @ObservedObject var model: SendViewModel
    let review: SendQuote

    var body: some View {
        Section {
            Text(review.amount.description).accessibilityIdentifier("send.review.amount")
            Text(review.recipient.raw).accessibilityIdentifier("send.review.recipient")
            Text(review.memo ?? "").accessibilityIdentifier("send.review.memo")
            Text(review.nativeFee.description).accessibilityIdentifier("send.review.native-fee")
            Text(review.totalDebit.description).accessibilityIdentifier("send.review.total")
            Text(String(review.acceptedHeight)).accessibilityIdentifier("send.review.height")
            Text(Self.absoluteExpiry(review.expiresAt)).accessibilityIdentifier("send.review.expiry")
            Button("Confirm") { model.confirm() }
                .disabled(model.quoteExpired)
                .accessibilityIdentifier("send.confirm.button")
            Button("Refresh") { model.refresh() }
                .accessibilityIdentifier("send.refresh.button")
        } header: {
            Text("Review")
        }
    }

    private static func absoluteExpiry(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
