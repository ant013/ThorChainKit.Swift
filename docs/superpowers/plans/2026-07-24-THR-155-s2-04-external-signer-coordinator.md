# THR-155 — S2-04 External Signer and Per-Account Coordinator

## Goal

Implement the approved S2-04 slice at architecture revision 10: a host-owned
asynchronous signer boundary, compact key/signature verification, and a
per-account SendCoordinator with shared physical-database runtime ownership.
The kit returns only a verified `SignedTransaction` to S2-05.

Authoritative design: `docs/specs/sprint-02-native-send/S2-04-external-signer-coordinator.md`
at commit `518835315a65996b9321665213adb0516503df65`.

## Scope and acceptance criteria

- Request signing only after lifecycle admission, quote consumption, signer
  key/address binding, and coherent H1 preflight.
- Accept only one 33-byte compressed secp256k1 key and one 64-byte compact
  low-S signature verified over the exact S2-03 digest.
- Revalidate at H2 after asynchronous signing; discard stale, cancelled,
  expired, or late results without submission or broadcast.
- Serialize one attempt per wallet/network/sender/sequence namespace and
  return `sendInProgress` without a second signer call.
- Converge aliases and Kit instances for one physical SQLite file on one
  shared writer/runtime; allow distinct namespaces to overlap safely.
- Release owner-matched unlinked reservations and gates exactly once; leave a
  failed cleanup in explicit repair-pending state without invoking a signer.
- Never derive, observe, retain, log, or expose seed/private-key material.
- Exclude journal, broadcast, UI, host localization, and S2-05 behavior.

## Execution steps

1. **Plan-first review** — ThorChainCodeReviewer checks each step against the
   pinned spec and maps every acceptance criterion to a test and implementation
   area. Check: Paperclip review comment with `APPROVE` or bounded findings.

2. **Implementation** — ThorChainSwiftEngineer writes tests first, then the
   minimum implementation in the proposed `Send/Signing` and `Send/Storage`
   paths. Check: filtered signer/coordinator tests, strict-concurrency gate,
   and a PR whose diff stays within the approved paths.

3. **Mechanical/adversarial review** — CodeReviewer performs the bounded
   closure checks and the CTO coordinates any allowed correction. Check: exact
   PR-head evidence, no unapproved scope, and all blocker IDs resolved.

4. **Independent QA** — ThorChainQAEngineer verifies the exact PR head locally
   on the MacBook, including cancellation/late completion, shared-writer
   convergence, cleanup repair, and the no-secret boundary. Check: QA PASS
   citing the exact head.

5. **CTO merge gate** — CTO confirms CodeReviewer approval, QA PASS, local
   required checks, conflict-free diff, and spec/plan references before merge.

## Verification

```text
swift test --filter SignerVerifierTests
swift test --filter SendCoordinatorTests
swift test --filter SendCoordinatorConcurrencyTests
swift test --filter SigningRequestRedactionTests
swift test
strict-concurrency diagnostics gate
git diff --check
```

GitHub Actions is not an acceptance gate for ThorChainKit; no hosted test,
simulator, mutant, or Maestro run is authorized by this slice.

## Evidence and review limits

- Discovery starts at `0/2`; closure starts at `0/5`.
- High/critical findings block only when they cite a current acceptance
  criterion, exact repository evidence, and a concrete S2-04 safety,
  implementation, or verification failure.
- Gimle target-project mapping and Serena are unavailable in this session;
  current-tree Git/`rg` evidence is recorded as the fallback and remains a
  reliability limitation.

