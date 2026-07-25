# THR-159 S2-06 closure 2 correction evidence

Date: 2026-07-25
Exact correction head: `8debca7`
Discovery: 2/2 frozen
Closure: 3/5 implementation correction

## Corrected findings

- Manifest validation compares each YAML `--example-scenario` value with its
  manifest flow name; the wrong-scenario mutation is rejected.
- The local runner produces a final simulator screenshot, Maestro hierarchy
  JSON, OCR self-test/result, and tracked-input scan before artifact
  verification.
- Fixture scenarios provide non-empty ordered request patterns. Probe calls are
  matched as an unordered concurrent prefix; subsequent method, origin, path,
  known query, and broadcast-body presence are checked in order. Each terminal
  fixture flow calls `finishTranscript()`.
- The duplicate signer declaration is removed. Retry projects unchanged local
  hash and signer-count booleans; expiry acceptance asserts Refresh visibility.

## Passing local checks

- `Scripts/test-run-maestro-s2-06.sh`
- `bash -n Scripts/run-maestro-s2-06.sh Scripts/test-run-maestro-s2-06.sh`
- `python3 -m py_compile Scripts/validate-s2-06-manifest.py Scripts/verify-s2-06-artifacts.py`
- `swiftc -parse` for touched Example Swift and OCR files
- `git diff --check`
- OCR self-test against a simulator screenshot using the runner's macOS
  framework include flags: `PASS scan-s2-06-ocr (1 PNG)`.

## Environment limitation

The exact local fixture build was started with Xcode 26.3 and the documented
iPhone 17 Pro simulator UDID. It remained in SwiftPM submodule resolution for
more than three minutes without reaching Example compilation and was stopped.
No hosted workflow was dispatched.

Gimle/codebase-memory indexed context was queried first and identified the
affected symbols. Serena and sequential-thinking MCP tools were unavailable in
this run; targeted current-tree `rg`, Git reads, and Swift/Python syntax checks
were used as the independent fallback. Gimle trust remains YELLOW.
