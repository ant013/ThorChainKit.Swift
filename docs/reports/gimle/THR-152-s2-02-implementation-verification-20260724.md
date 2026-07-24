# THR-152 S2-02 Implementation Verification

## Binding

- Slice: S2-02 height-pinned send preflight only.
- Approved design: revision 4, spec SHA-256 `7c8a348905707aa4446d7f536140ae49168855cf1f76b0c42faf375337bde414`.
- Approved implementation head: `81de7b4f9677b5eeb2893441abc2734bcaf31255`.
- Pull request: [#12](https://github.com/ant013/ThorChainKit.Swift/pull/12), base `main`.
- Discovery: `2/2` frozen. Closure: `1/5` mechanical exact-head correction.

## Changed areas

- Added internal send policy, exact Mimir halt evaluation, module-address vectors,
  recipient classification, snapshot digest, exact native-family manifest, and
  height-proof value types.
- Added bounded operation ownership that returns on cancellation/deadline and
  discards late dependency results.
- Added coordinator/provider seams for quote preparation and exact-family
  revalidation, plus the runtime quote insertion seam.
- Added focused contract tests for policy, halt boundaries, module vectors,
  manifest shape, snapshot digest, deadline/orphan ownership, recipient
  classification, common-height admission, revalidation monotonicity, and
  quote immutability.
- Added the minimal macOS 10.15 package platform declaration required by the
  existing HsCryptoKit dependency; the iOS 13 floor is unchanged.

## Verification

| Check | Result | Evidence |
|---|---|---|
| Swift syntax parse for touched sources/tests | PASS | `swiftc -parse Sources/ThorChainKit/Send/Preflight/*.swift Sources/ThorChainKit/Network/EndpointLease+Send.swift Sources/ThorChainKit/Network/EndpointOperationRunner.swift Tests/ThorChainKitTests/Send/Preflight/*.swift` |
| Whitespace/error diff check | PASS | `git diff --check` |
| Focused XCTest compilation/tests | UNRUN | `swift test --filter SendPreflightCoordinatorTests` on exact implementation head exited 1 before XCTest discovery: the checked-out `HsExtensions.Swift` dependency reports macOS 10.15 availability errors for `Task`, `PassthroughSubject`, and `AnyPublisher`, followed by `error: fatalError`. No test count or pass is claimed. |
| Full XCTest suite | UNRUN | `swift test` on exact implementation head exited 1 at the same dependency availability diagnostics before XCTest discovery. No test count or pass is claimed. |
| Vendored protobuf whitespace | PASS | Existing trailing whitespace in `upstream/cosmos_proto/cosmos.proto` lines 8–9 is preserved as byte-pinned source and explicitly excluded from hygiene checks by `Generated/Query/PROVENANCE.md`; no rewrite was made. |

## Gimle trust and limitations

Trust remains **YELLOW**. The accepted formalization report records the target
Gimle mapping/coverage gap and the current-tree Serena/rg fallback. No new
Gimle discovery was performed after the approved implementation transition.

The package/dependency deployment mismatch prevented typechecking and XCTest
execution in this run. The implementation was syntax-checked, and
`Scripts/generate-query-codec.sh --check` passed at the exact implementation
head; independent QA must run the focused filters and full suite before merge.
Live/fixture proof captures for the three families remain `UNRUN` and therefore
read-only as required by the approved spec.
