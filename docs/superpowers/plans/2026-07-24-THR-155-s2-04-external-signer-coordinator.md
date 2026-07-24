# THR-155 — S2-04 External Signer and Per-Account Coordinator (design revision 6)

## Goal

Implement the S2-04 slice at architecture revision 10: a host-owned
asynchronous signer boundary, compact key/signature verification, and a
per-account SendCoordinator with shared physical-database runtime ownership.
The internal coordinator transfers an owned `SendAttemptHandoff` whose only
transaction payload is a verified `SignedTransaction`; S2-04 has no public
bare-transaction return while ownership is retained.
This revision addresses discovery-1/2 findings and the revision-5 targeted
review; implementation remains gated on explicit approval of this revision.

Authoritative design: `docs/specs/sprint-02-native-send/S2-04-external-signer-coordinator.md`
on merged S2-03 implementation base
`3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`, whose tree is identical to the
exact accepted PR head `d548b9b5b858e6ed96793a8d3e40de6084e96efa`,
with architecture requirements traced to
`518835315a65996b9321665213adb0516503df65`.

## Scope and acceptance criteria

- Request signing only after lifecycle admission, quote consumption, signer
  key/address binding, and coherent H1 preflight.
- Accept only one 33-byte compressed secp256k1 key and one 64-byte compact
  low-S signature verified over the exact S2-03 digest.
- Revalidate at H2 after asynchronous signing; discard stale, cancelled,
  expired, or late results without submission or broadcast.
- Serialize one account gate per wallet/network/sender across all sequences
  and return `sendInProgress` without a second signer call. Keep
  `(namespace, sender, sequence)` only as the durable reservation key.
- Retain an outstanding-signer fence after prompt cancellation of a
  non-cooperative signer; a second send cannot start until that task completes
  or the process/runtime restarts.
- Converge aliases and Kit instances for one physical SQLite file on one
  shared writer/runtime; allow distinct namespaces to overlap safely.
- Transfer the exact account gate, shared `reservationOwnerToken`/attempt
  token, operation hold, runtime, and transaction into an internal
  `SendAttemptHandoff` consumed by S2-05; do not return a bare value while
  retaining ownership.
- Keep the existing public `Kit.send` facade fail-closed as
  `SendError.operationUnavailable` with zero side effects until S2-05 consumes
  the internal handoff.
- Release owner-matched unlinked reservations exactly once; leave failed
  cleanup in typed internal `SendCoordinatorResult.repairPending(RepairIntent)`
  state without invoking a signer; S2-04 does not complete repair or retry a
  fresh quote.
- Make production `KitFactory` and `GrdbAccountStateStorage` use the shared
  `DatabaseRuntime` through an already-migrated writer initializer; test
  physical-file identity, one migration barrier, and initialization retry.
- Never derive, observe, retain, log, or expose seed/private-key material.
- Exclude journal, broadcast, UI, host localization, and S2-05 behavior.

## Execution steps

1. **Plan-first review** — ThorChainCodeReviewer checks each step against the
   pinned spec and the AC1–AC7 matrix, including the exact-base preflight and
   public fail-closed boundary. Check: Paperclip review comment with `APPROVE`
   or bounded findings.

2. **Implementation** — ThorChainSwiftEngineer writes tests first, then the
   minimum implementation in the proposed `Send/Signing`, `Send/Storage`,
   including `SendCoordinatorResult.swift`,
   `Core/KitFactory.swift`, and `Storage/GrdbAccountStateStorage.swift` paths.
   Check: exact-base preflight; filtered signer/coordinator, golden cross-wire,
   cancellation-fence, repair-pending, public-boundary, registry-retry, and
   physical-writer tests; strict-concurrency gate; and a PR whose diff stays
   within the approved paths. The implementation worktree must descend from
   merged S2-03 commit `3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`,
   whose tree equals accepted head
   `d548b9b5b858e6ed96793a8d3e40de6084e96efa`, and contain both
   `DirectSignCodec.swift` and `DirectSignCodecTests.swift`.

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
test "$(git rev-parse 'd548b9b5b858e6ed96793a8d3e40de6084e96efa^{tree}')" = "$(git rev-parse '3e8d103821a5c2388143a0ce8d99d4d7c674d9ed^{tree}')"
git merge-base --is-ancestor 3e8d103821a5c2388143a0ce8d99d4d7c674d9ed HEAD
git cat-file -e HEAD:Sources/ThorChainKit/Protocol/DirectSignCodec.swift
git cat-file -e HEAD:Tests/ThorChainKitTests/Protocol/DirectSignCodecTests.swift
test "$(xcrun swift test --list-tests | rg -c 'SignerVerifierTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorConcurrencyTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'SigningRequestRedactionTests')" -gt 0
test "$(xcrun swift test --list-tests | rg -c 'KitCompositionTests[./]testTwoKitsShareOnePhysicalWriterAndMigrationBarrier')" -eq 1
test "$(xcrun swift test --list-tests | rg -c 'KitCompositionTests[./]testInitializationFailureRemovesOnlyMatchingEntry')" -eq 1
test "$(xcrun swift test --list-tests | rg -c 'SendCoordinatorPublicBoundaryTests[./]testPublicSendIsUnavailableAndSideEffectFree')" -eq 1
xcrun swift test --filter SignerVerifierTests
xcrun swift test --filter SendCoordinatorTests
xcrun swift test --filter SendCoordinatorConcurrencyTests
xcrun swift test --filter SigningRequestRedactionTests
xcrun swift test --filter KitCompositionTests
xcrun swift test --filter SendCoordinatorPublicBoundaryTests
xcrun swift test
xcrun swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
# Expected-no-match audits: each rg must exit 1; exit 0 or 2 fails.
secret_audit_status=0
rg -n -i '(seed|mnemonic|private[ -]?key|derive)' Sources/ThorChainKit/Send Sources/ThorChainKit/Core/Kit+Send.swift || secret_audit_status=$?
test "$secret_audit_status" -eq 1
public_symbol_audit_status=0
rg -n 'public[[:space:]]+.*(SignedTransaction|SendAttemptHandoff)' Sources/ThorChainKit/Send Sources/ThorChainKit/Core/Kit+Send.swift || public_symbol_audit_status=$?
test "$public_symbol_audit_status" -eq 1
git diff --check
```

GitHub Actions is not an acceptance gate for ThorChainKit; no hosted test,
simulator, mutant, or Maestro run is authorized by this slice.

## Acceptance-to-test matrix

The authoritative AC1–AC7 mapping is in the spec. The implementation must
retain these exact observable anchors:

| Acceptance | Required test/area |
|---|---|
| AC1 | `SendCoordinatorTests.testSignerStartsAfterAdmissionQuoteConsumptionBindingAndH1` |
| AC2 | `SignerVerifierTests.testCompactSignatureRules`; `SendCoordinatorTests.testExactDigestAndTxRawCrossWireIsRejected` |
| AC3 | `SendCoordinatorTests.testH2RejectsChangedStaleCancelledExpiredAndLateResults` |
| AC4 | Admission/hold ordering, stop, and `repairPending` tests in `SendCoordinatorTests` |
| AC5 | Same-account gate, retained fence, and fresh-attempt-after-release tests in `SendCoordinatorConcurrencyTests` |
| AC6 | One physical writer/migration barrier and matching-entry retry tests in `KitCompositionTests` |
| AC7 | `SendCoordinatorPublicBoundaryTests.testPublicSendIsUnavailableAndSideEffectFree` plus exact negative source audit |

## Evidence and review limits

- Discovery remains frozen at `1/2`; closure remains `0/5`.
- High/critical findings block only when they cite a current acceptance
  criterion, exact repository evidence, and a concrete S2-04 safety,
  implementation, or verification failure.
- Gimle target-project mapping and Serena are unavailable in this session;
  current-tree Git/`rg` evidence is recorded as the fallback and remains a
  reliability limitation.

## Revision 4 blocker resolution map

| Finding | Resolution | Required proof |
|---|---|---|
| D-155-01 | Account gate omits sequence; durable reservation retains it. | Same-account, different-sequence concurrency test. |
| D-155-02 | Outstanding-signer fence remains after prompt cancellation. | Non-cooperative signer cancellation/second-send test. |
| D-155-03 | One reservation owner-CAS token is shared by account state, durable reservation, and internal handoff; the public facade remains `operationUnavailable` until S2-05 consumes the handoff. | Handoff ownership/token-identity test and public-boundary side-effect test; no S2-05 implementation. |
| D-155-04/09 | `DatabaseRuntime.open(...)` is the sole writer/migration constructor; storage receives an already-migrated writer and matching initialization entries are retryable. | Two-Kit one-physical-writer/one-migration-barrier test plus concurrent failure/retry test. |
| D-155-05 | The client lease owns lifecycle generation and quote invalidation only; the admitted attempt owns the operation hold through finalization or typed repair transfer. | Two-namespace/one-writer and stop/hold ownership tests. |
| D-155-06 | One golden test binds digest, signature verification, and TxRaw bytes. | Correct and cross-wired vectors. |
| D-155-07 | S2-04 only creates/retains typed `repairPending(RepairIntent)` and blocks signers; S2-05 owns repair completion and fresh-quote retry. | Typed-result assertion, no-signer-while-pending test, and explicit S2-05 follow-up boundary. |
| D-155-08 | Literal test discovery and strict-concurrency commands are pinned to `xcrun swift`. | Command output plus `git diff --check`. |
| D-155-09 | Matching initialization entry is removed and retryable. | Concurrent waiter failure/retry test. |
| D-155-10 | Permanent and releasable signer fixtures are signer-only; provider cancellation is a separate prompt-release/no-later-request fixture; release is followed by one fresh successful same-account signer attempt. | Three bounded completion-oracle tests. |
| D-155-11 | Implementation base is merged S2-03 `3e8d103821a5c2388143a0ce8d99d4d7c674d9ed`, whose tree equals exact accepted head `d548b9b5b858e6ed96793a8d3e40de6084e96efa`. | Executable tree-equivalence, merged-base ancestry, and two `git cat-file -e` checks before tests. |
| Verification mapping | AC1–AC7 each has an exact test/observable and command; AC3, AC6, and AC7 no longer rely on prose-only coverage. | Matrix above plus exact focused commands and source audit. |

No implementation, hosted dispatch, Maestro run, simulator run, or S2-05
product work is authorized before explicit approval of the revised spec and
plan.
