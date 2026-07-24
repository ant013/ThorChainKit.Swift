# THR-152 S2-02 Memo-Limit Correction Verification

## Binding

- Slice: S2-02 height-pinned send preflight only.
- Correction commit: `a8e0281` (`fix(send): enforce dynamic auth memo limit`).
- Review finding: H-001, exact-height auth memo limit was decoded into the snapshot but not enforced before quote insertion.

## Correction

- `SendPolicy.validate(memo:maximumBytes:)` now supports the live limit while preserving the static-policy default.
- `SendPreflightCoordinator` validates the request memo against `snapshot.memoMaximumBytes` immediately before quote issuance.
- `testPreparationRejectsMemoAboveExactHeightAuthLimit` uses the default 256-byte policy with a 16-byte live snapshot limit and a 17-byte memo; it expects `memoTooLong(maxUTF8Bytes: 16)`.
- Existing auth decoder tests continue to cover zero, negative, malformed, and overflowing limits as fail-closed cases.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Swift syntax parse | PASS | `swiftc -parse Sources/ThorChainKit/Send/Preflight/SendPolicy.swift Sources/ThorChainKit/Send/Preflight/SendPreflightCoordinator.swift Sources/ThorChainKit/Send/Preflight/SendSnapshot.swift Tests/ThorChainKitTests/Send/Preflight/SendPreflightCoordinatorTests.swift` exited 0. |
| Diff whitespace check | PASS | `git diff HEAD^ HEAD --check` exited 0. |
| Focused regression XCTest | UNRUN | `swift test --filter SendPreflightCoordinatorTests/testPreparationRejectsMemoAboveExactHeightAuthLimit` stopped before XCTest discovery because the checked-out `HsExtensions.Swift` dependency reports macOS 10.15 availability errors for `Task`, `PassthroughSubject`, and `AnyPublisher`, followed by `error: fatalError`. |

## Gimle trust and limitations

Trust remains **YELLOW**. The requested codebase-memory project was ready but returned no matching symbols for this correction query; Serena and targeted `rg` independently verified the current-tree symbols and call sites. No new Gimle discovery was used to select implementation structure. XCTest execution remains for independent QA on a compatible deployment environment.
