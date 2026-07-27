# THR-162 — Delta matrix

**Revision:** 3 — discovery 1/2; closure 2/5

| Candidate | Decision | Reason / proof required |
|---|---|---|
| THR-152 S2-02 CompletionGate correction | Primary historical correction/verification analog | Same gate responsibility and cancellation/completion race; proves the existing release-before-resume invariant, focused race test, focused caller tests, and upstream strict-gate limitation. It does not prove the new `sending` annotation. |
| Current `CompletionGate` / `EndpointOperationRunner` | Supporting current-tree implementation and consumer evidence | Confirms the exact private boundary, four finish paths, `T: Sendable` runner boundary, and existing race/orphan tests. |
| `sending Result<T, Error>` on private `CompletionGate.finish` | Conditional source delta | Models the one-way transfer consumed by `CheckedContinuation.resume(with:)`; implementation requires the accepted exact S2-07 full-host A/B proof. Isolated and reduced probes remain non-causal limitations. |
| `T: Sendable` on `CompletionGate` | Reject unless separately proven | Duplicates an existing public runner boundary and does not by itself establish transfer of the `Result` value/error. |
| Switch to separate `resume(returning:)` / `resume(throwing:)` calls | Fallback only | More source and branching; consider only if the compiler proves the primary candidate insufficient. |
| `@preconcurrency`, warning suppression, or new `@unchecked Sendable` | Reject | Violates the acceptance boundary and hides rather than corrects the transfer contract. |
| `EndpointPool` lifecycle rewrite | Reject | Different actor/latch ownership analog, outside the current slice. |
| EndpointPool continuation delivery | Supporting boundary only | Its actor ownership differs from the lock-owned detached-task gate; it informs delivery shape but not lifecycle ownership. |
| EvmKit direct continuation forwarding | Rejected counterexample | It lacks this gate's exactly-once detached-task race and orphan-accounting responsibility. |

Preserve the existing public API, lock/latch behavior, resume-outside-lock
ordering, error mapping, cancellation/deadline/lifecycle handling, and orphan
counter semantics.
