# THR-164 implementation verification — `a16f6c3`

## Scope

- Production change: two inner `[weak self]` capture lists in
  `PendingTransactionRepository.installObservation()`.
- Regression: one deterministic queue-blocked weak-lifetime test and the
  existing test source's queue gate/drain helpers.
- No dependency, package, suppression, unchecked-conformance, application, or
  unrelated source changes.

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Diff audit | PASS | `git diff --check`; exact-head diff contains only the two approved files. |
| Strict Swift 5 capture probe | PASS | `xcrun swiftc -swift-version 5 -warn-concurrency -warnings-as-errors -typecheck` on the equivalent two-boundary closure shape. |
| Focused Xcode 26.6 test | BLOCKED | Exit `65` before ThorChainKit compilation; pre-existing `HsExtensions.AnyTask.Options` concurrency diagnostics stop the dependency build. No `PendingTransactionRepository.swift` diagnostic or `SwiftCompile` line was emitted. |
| SwiftPM fallback | BLOCKED | Host SwiftPM is Swift 5.8 and cannot load the package's Swift 5.10 manifest; the Xcode SwiftPM path also reports an unrelated dependency platform mismatch. |

The blocked Xcode run retained its local result bundle and log under the
operator's temporary run directory. Absolute operator paths are intentionally
omitted from this committed report.

## Exact head

- Branch: `feature/THR-164-pending-transaction-strict-concurrency`
- Commit: `a16f6c32cf98ff0ac1cc6a1bf0cbd2c559f29917`
- Approved design head: `4250e80c86905635ffe6a745f796a51e31001f9f`
