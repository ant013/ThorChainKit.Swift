# THR-159 S2-06 exact-head correction evidence

Date: 2026-07-25
Exact correction head: `ce02d66833605c1610049c0f1d2970f701139d7d`
Discovery: 2/2 frozen
Closure: 5/5; changed-line correction evidence

## Corrected

- `Scripts/verify-s2-06-artifacts.py` now validates the runner layout
  `artifacts/s2-06/<head>/<udid>/`: the leaf must equal the requested UDID and
  its parent must equal the current Git head. Wrong-head and wrong-UDID probes
  fail closed; a correctly shaped but missing directory reaches the missing-
  artifact check.
- `ThorChainExampleLiveSupport` declares its existing pinned `HsCryptoKit`
  product directly because its source imports that product.

## Exact-head verification

- `Scripts/test-run-maestro-s2-06.sh`: PASS (semantic and negative mutations).
- `Scripts/audit-example-target-graph.sh`: PASS.
- `bash -n Scripts/run-maestro-s2-06.sh Scripts/test-run-maestro-s2-06.sh`: PASS.
- `python3 -m py_compile Scripts/verify-s2-06-artifacts.py`: PASS.
- `plutil -lint iOS Example/iOS Example.xcodeproj/project.pbxproj`: PASS.
- `git diff --check`: PASS.
- Wrong-head and wrong-UDID verifier probes: rejected with non-zero status.

The guarded exact-head runner was executed with an available iPhone 17 Pro
simulator UDID. Package resolution succeeded and the build reached the known
linker failure: Xcode 26.3 produces `Crypto.framework/Crypto`, while the
HsCryptoKit package-product link requests the missing hashed
`Crypto_17A3B1FFC41E47_PackageProduct.framework/Crypto_17A3B1FFC41E47_PackageProduct`.
The same failure was reproduced for Fixture Debug and Live Release. No Maestro
artifact directory or release binary was produced, so artifact verification,
Maestro flows, and the release fixture-symbol audit remain fail-closed.

Several bounded integration experiments were reverted because they did not
produce the missing binary or violated the existing target boundary: direct
Crypto product declarations produced only the hashed wrapper Info.plist, and a
static ThorChainKit product caused Xcode to reject duplicate linkage by the app
and support target. The branch contains no changes from those experiments.

Gimle/codebase-memory indexed context was queried first. The ThorChainKit
project is not registered in the available Gimle git mounts, current scripts
are absent from the code graph, and Serena/sequential-thinking MCP tools were
unavailable; targeted `rg`, Git reads, Xcode build output, and static checks are
the independent fallback. Gimle trust remains RED/YELLOW as recorded by the
prior S2-06 evidence reports; no Gimle result was used as implementation truth.
