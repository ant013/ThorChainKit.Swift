import BigInt
import XCTest
@testable import ThorChainKit

final class SendErrorTests: XCTestCase {
    func testEveryPublicCaseRendersDeterministically() {
        let changes = QuoteChanges(validating: [.sequence, .balance])!
        let fee = NativeFeeChange(previous: 1, current: BigUInt("18446744073709551617"))
        let rejection = BroadcastRejection(code: 7, codespace: "untrusted.provider", sanitizedLog: .invalidResponse)
        let errors: [SendError] = [
            .invalidAmount, .invalidRecipient, .selfRecipient, .recipientIsModule,
            .memoTooLong(maxUTF8Bytes: 256), .chainHalted, .accountUnavailable,
            .insufficientBalance, .providerUnavailable, .heightUnproven,
            .policyUnavailable, .kitNotStarted, .operationUnavailable, .quoteExpired,
            .quoteGenerationInvalidated, .quoteChanged(changes), .quoteAlreadyConsumed,
            .quoteOwnershipMismatch, .signerAddressMismatch, .invalidPublicKey,
            .signerCancelled, .signerFailed, .invalidSignature, .sendInProgress,
            .storageUnavailable, .broadcastRejected(rejection), .retryRecordMissing,
            .retryTerminal, .retryFeeChanged(fee), .retryBlocked(.providerInconsistent)
        ]

        for error in errors {
            XCTAssertEqual(error.description, error.localizedDescription)
            XCTAssertLessThan(error.description.utf8.count, 256)
            XCTAssertEqual(error.description, String(reflecting: error))
        }
        XCTAssertEqual(
            SendError.quoteChanged(changes).description,
            "quoteChanged(balance,sequence)"
        )
    }

    func testBroadcastRejectionUsesOnlyAllowlistedAndSanitizedValues() {
        let unknown = BroadcastRejection(
            code: 0,
            codespace: "https://wallet:secret@example.com",
            sanitizedLog: .providerUnavailable
        )
        let error = SendError.broadcastRejected(unknown)

        XCTAssertEqual(unknown.code, 1)
        XCTAssertEqual(unknown.codespace, .other)
        XCTAssertEqual(unknown.sanitizedLog, "providerUnavailable")
        XCTAssertFalse(error.description.contains("https://"))
        XCTAssertFalse(error.description.contains("secret"))
    }

    func testEmptyQuoteChangesCannotBeConstructed() {
        XCTAssertNil(QuoteChanges(validating: []))
    }

    func testNestedPayloadCategoriesAreFiniteAndSanitized() {
        let changes = QuoteChange.allCases
        for change in changes {
            let error = SendError.quoteChanged(QuoteChanges(validating: [change])!)
            XCTAssertLessThan(error.description.utf8.count, 256)
            XCTAssertFalse(error.description.contains("http"))
        }
        for category in [BroadcastCodespaceCategory.sdk, .thorchain, .other] {
            let rejection = BroadcastRejection(code: 9, codespace: category.rawValue, sanitizedLog: .invalidResponse)
            let error = SendError.broadcastRejected(rejection)
            XCTAssertTrue(error.description.contains(category.rawValue))
            XCTAssertFalse(error.description.contains("secret"))
        }
        for reason in [RetryBlockedReason.sequenceAdvanced, .providerInconsistent] {
            XCTAssertTrue(SendError.retryBlocked(reason).description.contains(reason.rawValue))
        }
    }
}

private extension QuoteChange {
    static var allCases: [QuoteChange] {
        [.providerIdentity, .heightRollback, .accountNumber, .sequence, .accountPublicKey,
         .balance, .nativeFee, .haltStatus, .memoPolicy, .recipientPolicy]
    }
}
