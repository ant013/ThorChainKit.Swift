import BigInt
import Combine
import Foundation
import ThorChainKit

extension Kit: @retroactive @unchecked Sendable {}

@MainActor
final class SendViewModel: ObservableObject {
    @Published var recipient: String
    @Published var amount = ""
    @Published var memo = ""
    @Published private(set) var modeBadge: String
    @Published private(set) var review: SendQuote?
    @Published private(set) var resultState = ""
    @Published private(set) var localHash = ""
    @Published private(set) var pending: [PendingTransaction] = []
    @Published private(set) var pendingStatus = ""
    @Published private(set) var errorMessage = ""
    @Published private(set) var signerCallCount = 0
    @Published private(set) var currentFee = BigUInt(0)
    @Published private(set) var retryPreviousFee = BigUInt(0)
    @Published private(set) var retryCurrentFee = BigUInt(0)
    @Published private(set) var retryHashUnchanged = false
    @Published private(set) var retrySignerCountUnchanged = false
    @Published private(set) var quoteExpired = false

    let runtime: ExampleRuntime
    private var cancellables = Set<AnyCancellable>()
    private var signer: (any Signer)? { runtime.signer }

    init(runtime: ExampleRuntime) {
        self.recipient = runtime.recipient
        self.runtime = runtime
        modeBadge = runtime.mode.rawValue
        runtime.kit.pendingTransactionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.pending = transactions
                if let transaction = transactions.first(where: { if case .unknown = $0.state { true } else { false } }) {
                    self?.retryPreviousFee = transaction.nativeFee
                    self?.retryCurrentFee = transaction.nativeFee + 1
                }
            }
            .store(in: &cancellables)
        runtime.kit.pendingTransactionsStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.pendingStatus = Self.statusDescription(status)
            }
            .store(in: &cancellables)
        pending = runtime.kit.pendingTransactions
        pendingStatus = Self.statusDescription(runtime.kit.pendingTransactionsStatus)
#if EXAMPLE_FIXTURE
        signerCallCount = runtime.fixtureSignerCallCount
#endif
    }

    func quote() {
        errorMessage = ""
        quoteExpired = false
        guard let amountValue = SendAmountInput.parse(amount),
              let recipient = try? Address(recipient, network: runtime.network)
        else {
            review = nil
            errorMessage = "Enter a positive RUNE amount and valid recipient."
            return
        }
        Task {
            do {
                review = try await runtime.kit.quote(
                    to: recipient,
                    amount: .exact(amountValue),
                    memo: memo
                )
                currentFee = review?.nativeFee ?? 0
            } catch {
                review = nil
                errorMessage = "Quote unavailable."
            }
        }
    }

    func confirm() {
        guard let review, let signer else { return }
        Task {
            guard !(await runtime.isQuoteExpired(review.expiresAt)) else {
                quoteExpired = true
                resultState = "Quote expired — refresh required"
                return
            }
            do {
                let submission = try await runtime.kit.send(quote: review, signer: signer)
                localHash = submission.transactionId.hash
                resultState = Self.submissionDescription(submission.state)
#if EXAMPLE_FIXTURE
                signerCallCount = runtime.fixtureSignerCallCount
                if runtime.fixtureScenarioID != .retry {
                    try await runtime.finishFixtureTranscript()
                }
#endif
            } catch {
                errorMessage = "Send unavailable."
            }
        }
    }

    func retry(_ transaction: PendingTransaction, acceptingFee: BigUInt) {
        guard case .unknown = transaction.state else { return }
        guard acceptingFee == retryCurrentFee else {
            errorMessage = "Acknowledge the current native fee before retrying."
            return
        }
        Task {
            do {
                let signerCountBeforeRetry = signerCallCount
                let submission = try await runtime.kit.retryBroadcast(
                    transactionId: transaction.transactionId,
                    acceptingNativeFee: acceptingFee
                )
                localHash = submission.transactionId.hash
                resultState = Self.submissionDescription(submission.state)
#if EXAMPLE_FIXTURE
                signerCallCount = runtime.fixtureSignerCallCount
#endif
                retryHashUnchanged = submission.transactionId.hash == transaction.transactionId.hash
                retrySignerCountUnchanged = signerCallCount == signerCountBeforeRetry
#if EXAMPLE_FIXTURE
                try await runtime.finishFixtureTranscript()
#endif
            } catch {
                errorMessage = "Retry unavailable."
            }
        }
    }

    func refresh() {
        quoteExpired = false
        resultState = ""
        review = nil
        runtime.kit.refresh()
    }

    func advanceToExpiry() {
        guard review != nil else { return }
        Task {
            await runtime.advanceFixtureToExpiry()
            quoteExpired = true
            resultState = "Quote expired — refresh required"
#if EXAMPLE_FIXTURE
            try? await runtime.finishFixtureTranscript()
#endif
        }
    }

    private static func submissionDescription(_ state: SendSubmission.State) -> String {
        switch state {
        case .checkTxAccepted: return "CheckTx accepted — not confirmed"
        case .unknown: return "Unknown — retry available"
        }
    }

    private static func statusDescription(_ status: PendingTransactionsStatus) -> String {
        switch status {
        case .ready: return "READY"
        case .degraded: return "PENDING DATA UNAVAILABLE"
        }
    }
}
