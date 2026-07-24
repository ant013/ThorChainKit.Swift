# THR-152 — S2-02 Height-Pinned Send Preflight

Design revision 4. Discovery `2/2` is frozen; closure `1/5`.

## Binding

- Slice: S2-02 only; S2-01 is a dependency and S2-03+ remain out of scope.
- Base: `origin/main@db6c1d667c61f9778ec2605c0a60ac3be5f02227`.
- Primary spec: [`docs/specs/sprint-02-native-send/S2-02-pinned-preflight.md`](../../specs/sprint-02-native-send/S2-02-pinned-preflight.md).
- Spec SHA-256: `7c8a348905707aa4446d7f536140ae49168855cf1f76b0c42faf375337bde414`.
- Architecture source: revision-10 commit `518835315a65996b9321665213adb0516503df65`; canonical bundle digest `a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc`.
- Evidence run: `THR-152-s2-02-20260724-r2`, revised for design revision 4.
- Review budget: discovery `2/2` frozen; closure `1/5`.

## Goal and acceptance criteria

Implement only the approved S2-02 preflight boundary after explicit revision-bound approval:

1. A returned quote proves all required values from one provider family and one exact height, and carries a stable internal snapshot digest.
2. Missing, unproven, malformed, mismatched, or unsupported values fail closed with stable typed errors.
3. THOR fee, balance, halt, memo, account, and forbidden-module behavior follows the pinned spec and versioned protocol vectors.
4. A stopped or superseded client generation cannot start a late H0 request or insert/return a quote.
5. H1/H2 revalidation obtains a fresh coherent snapshot, never mutates the quote, and never switches provider family.
6. Tests demonstrate no cross-family or cross-height merge.

Out of scope: transaction/signing protobuf and signature, broadcast, pending journal, S2-05 retry/lookup implementation, UI, history, Unstoppable integration, live production mutation, and speculative provider abstractions. Query-only Cosmos/ABCI codecs required for approved proof modes are in scope with deterministic dependency/generated-source provenance.

The manifest registry is exactly `rorcual-mainnet`, `ibs-mainnet`, and
`keplr-mainnet`, with THR-139's six role-bound endpoint records. Liquify is not
a native-RUNE or send-capable family. Each family is currently `UNRUN` for the
complete S2-02 route/proof matrix and therefore read-only; no family becomes
send-capable until every required route has `PASS` evidence.

## Ordered steps

### 1. Formalization and review gate — CTO

- Check: bounded closure `1/5` rechecks frozen D-001..D-012 and direct changed-line regressions against the exact pushed revision-4 docs head recorded in the issue handoff; explicit assumptions/open questions are present; latest decisions are re-recorded against the current spec hash; no implementation files change.
- Paths: this plan, primary spec, `docs/reports/gimle/THR-152-s2-02-formalization-r3.md`, r2 state.
- Dependency: none.

### 2. Test-first contract implementation — ThorChainSwiftEngineer

- Check: add failing contract tests mapped one-to-one to each acceptance criterion, including digest vectors, public-error mapping, exact-family refresh, common-height skew, non-cooperative cancellation, orphan caps, and before/after quote immutability. Then implement the smallest approved delta in the spec's proposed areas. Run focused `swift test --filter ...` commands before the package suite.
- Paths: only the S2-02 source/test paths listed by the primary spec, plus the explicitly named runtime/store/composition seams, exact query-codec dependency, generated query sources, provenance manifest, and deterministic regeneration check. Transaction/signing codecs and S2-05 retry/lookup remain excluded.
- Dependency: Step 1 explicit approval; no implementation before it.

### 3. Mechanical review — ThorChainCodeReviewer

- Check: exact PR head reviewed against this plan and spec; required local checks and `gh pr checks` are green; no conflict markers; no silent scope reduction.
- Paths: implementation PR only.
- Dependency: Step 2 PR.

### 4. Adversarial/architecture review — ThorChainCodeReviewer

- Check: current-slice safety findings only; critical/high findings cite an acceptance criterion, exact changed line, and concrete failure; medium/low items become backlog.
- Dependency: Step 3 approval.

### 5. Independent QA — ThorChainQAEngineer

- Check: exact PR head, focused tests, package tests, and required live/fixture evidence per the primary spec; verify no cross-family/cross-height merge and fail-closed cancellation behavior.
- Dependency: Step 4 approval.

### 6. CTO merge gate — ThorChainCTO

- Check: CR `APPROVE` and QA `QA PASS` cite the exact head; required checks exit 0; merge only after all gates are satisfied.
- Dependency: Step 5 evidence.

## Verification commands

Formalization:

```text
git status --short --branch
git rev-parse HEAD
git diff --check
```

Implementation/QA, from the approved plan and spec:

```text
swift test --filter SendPreflightCoordinatorTests
swift test --filter EndpointOperationRunnerTests
swift test --filter HaltEvaluatorTests
swift test --filter RecipientAccountClassifierTests
swift test --filter ForbiddenModuleAddressSetTests
swift test --filter SendPolicyTests
swift test
```

The live or fixture preflight is mandatory before enabling each exact family; a
query-only response never authorizes a quote. Every artifact records capture
ID, exact head, one of the six role-bound records, proof mode, schema version,
timeout, redaction, and `PASS`/`FAIL`/`UNRUN`.

## Design decisions

- Primary family/lease spine: current `EndpointPool`/`EndpointLease`, constrained to THR-139's exact three-family/six-record native-RUNE registry; `EndpointOperationRunner` is a bounded greenfield owner because the structured `ReadOperationCoordinator` task-group drain is unsafe for non-cooperative dependencies.
- Primary policy/transport spine: current `LiveThorNodeClient` typed height/error handling, extended only by the approved S2-02 proof manifest.
- Primary lifecycle owner: current `SendRuntime`; `SendQuote` remains immutable and signing/broadcast remain later slices.
- Rejected pattern: EvmKit max-across-provider nonce aggregation; it cannot prove one THOR family/height.
- Fail-closed rule: no route value without its own approved proof at the captured height; no late callback may create or mutate a quote; every family without complete `PASS` evidence is read-only.
