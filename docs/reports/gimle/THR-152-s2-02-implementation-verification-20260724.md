# THR-152 S2-02 Implementation Verification

## Binding

- Slice: S2-02 height-pinned send preflight only.
- Approved design: revision 4, spec SHA-256 `7c8a348905707aa4446d7f536140ae49168855cf1f76b0c42faf375337bde414`.
- Approved implementation head: `139e2d36b86b8bf1d00e67f6bf325108880abad7`.
- Discovery: `2/2` frozen. Closure: `1/5` at implementation handoff.

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
| Focused XCTest compilation/tests | UNRUN | After the package platform fix, the host Xcode 26.2 toolchain fails while importing CoreGraphics: `/usr/local/include/IOKit/IOTypes.h` conflicts with the SDK definition of `IOPhysicalRange`, then `could not build Objective-C module 'CoreGraphics'`. A `-nostdinc` isolation attempt instead cannot load CoreFoundation. No test pass is claimed. |
| Full XCTest suite | UNRUN | Same host SDK/header conflict; no full-suite result is claimed. |

## Gimle trust and limitations

Trust remains **YELLOW**. The accepted formalization report records the target
Gimle mapping/coverage gap and the current-tree Serena/rg fallback. No new
Gimle discovery was performed after the approved implementation transition.

The package deployment mismatch prevented typechecking and XCTest execution in
this run. The implementation was syntax-checked, but independent QA must run
the focused filters and full suite before merge. Live/fixture proof captures for
the three families remain `UNRUN` and therefore read-only as required by the
approved spec.
