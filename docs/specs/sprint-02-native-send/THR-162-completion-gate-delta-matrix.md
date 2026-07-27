# THR-162 — Delta matrix

| Candidate | Decision | Reason / proof required |
|---|---|---|
| `sending Result<T, Error>` on private `CompletionGate.finish` | Primary | Models the one-way transfer consumed by `CheckedContinuation.resume(with:)`; must reproduce/fix the strict diagnostic in a bounded compiler probe. |
| `T: Sendable` on `CompletionGate` | Reject unless separately proven | Duplicates an existing public runner boundary and does not by itself establish transfer of the `Result` value/error. |
| Switch to separate `resume(returning:)` / `resume(throwing:)` calls | Fallback only | More source and branching; consider only if the compiler proves the primary candidate insufficient. |
| `@preconcurrency`, warning suppression, or new `@unchecked Sendable` | Reject | Violates the acceptance boundary and hides rather than corrects the transfer contract. |
| `EndpointPool` lifecycle rewrite | Reject | Different actor/latch ownership analog, outside the current slice. |
| EvmKit direct continuation forwarding | Counterexample, not primary | It lacks this gate's exactly-once detached-task race and orphan-accounting responsibility. |

Preserve the existing public API, lock/latch behavior, resume-outside-lock
ordering, error mapping, cancellation/deadline/lifecycle handling, and orphan
counter semantics.

