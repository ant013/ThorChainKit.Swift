# THR-159 S2-06 module and package-graph correction

Date: 2026-07-25
Base head: `d2c49d0d2d70ea4803522905af0d1cb3fb478d1d`
Discovery: 2/2 frozen
Closure: 5/5; changed-line correction

## Implemented

- `LiveSupport` is the explicit module name for both LiveSupport
  configurations.
- `FixtureSupport` is the explicit module name for both FixtureSupport
  configurations.
- The direct Xcode `HsCryptoKit.Swift` package root and product dependency were
  removed. The pinned product remains owned by the existing local
  `ThorChainKit` package graph and the pinned `HdWalletKit` dependency graph;
  no package pin or library source changed.

## Verification

Passing checks:

- `Scripts/test-run-maestro-s2-06.sh`
- `Scripts/audit-example-target-graph.sh`
- `bash -n Scripts/run-maestro-s2-06.sh Scripts/test-run-maestro-s2-06.sh`
- `python3 -m py_compile Scripts/verify-s2-06-artifacts.py`
- `find 'iOS Example' -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse`
- `plutil -lint 'iOS Example/iOS Example.xcodeproj/project.pbxproj'`
- `git diff --check`
- Targeted assertions: two `LiveSupport` and two `FixtureSupport` module names;
  no direct Xcode `HsCryptoKit` package reference/product remains; the pinned
  `HdWalletKit` reference remains.

The required Fixture Debug and Live Release simulator builds were attempted
against UDID `0A88BC07-1DF9-490A-BCAF-6FA2165F6B17`, but Xcode stopped during
package graph preparation before compiling Example sources. The host retried
cloning `swift-protobuf` and its nested `protobuf`/`abseil` repositories from
GitHub despite existing cached checkouts; the clone made no progress and was
terminated. No build, Maestro, artifact, or release-symbol claim is made from
that attempt.

No Unstoppable files, package pins, library APIs, secrets, or hosted workflows
were changed.
