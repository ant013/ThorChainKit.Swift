# Gimle reliability report — THR-52 hosted acceptance recovery revision 8

## Scope and repository identity

This report covers a read-only, spec-only recovery design for the downstream
Maestro failure observed after the S1-02 ripgrep provisioning gates passed. The
reviewed worktree is `feature/THR-32-s1-02-endpoint-policy` at exact head
`64575a9aea42201b31f3549ba517f1e02017199d`. No hosted rerun, merge, workflow
edit, verifier edit, or implementation change was authorized.

The spec revision is
`docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md`
(revision 8). Revision 7's ripgrep design and existing CR/QA attestations are
preserved. Spec SHA-256:
`7481150d64959b522bf75422e5b7cafc8e42032d191adf5027661cc36332c9f7`.

## Gimle trust

Gimle trust remains **RED**. The target project mapping is unavailable: the
Gimle/Palace project lookup for `Users-ant013-Data-AI-thorchain` remains an
`unknown_project` mapping failure. This report does not treat that failure as
repository evidence.

Independent fallback evidence was used instead:

- codebase-memory project `Users-ant013-Data-AI-thorchain` is indexed and
  reports `ready`;
- Serena was activated for the exact worktree;
- targeted `rg` and Git reads verified the Maestro lifecycle and exact head;
- local read-only checks recorded Xcode 26.3 and iOS 26.3/18.6 runtimes, while
  also recording that the current shell lacks Maestro and uses Java 21 rather
  than the exact hosted pair;
- primary upstream evidence was reviewed directly from Maestro issues #3327
  and #3137.

## Evidence and diagnosis

Hosted run `29764294250` passed exact-head preflight, checkout, pinned ripgrep
provisioning, S1-02 policy/product verification, Swift build/tests, the guarded
Maestro runner, and pinned Maestro CLI installation. Xcode 26.3 built the
Example against the iPhoneSimulator 26.2 SDK; simulator install and launch
succeeded. Maestro 2.6.1 then failed before flow assertions while setting app
permissions:

`Unable to set permissions ... Failed to connect to /127.0.0.1:50637`

The current tree verifies that `Scripts/run-maestro.sh` requires Maestro 2.6.1
and Temurin 17.0.19+10, and performs boot/build/install/launch before invoking
the flow. The failure is consequently downstream of the ripgrep remediation.

Primary upstream references:

- https://github.com/mobile-dev-inc/Maestro/issues/3327 — XCUITest driver
  connection failure after installation on Maestro 2.6.0 + Xcode 26.4.
- https://github.com/mobile-dev-inc/Maestro/issues/3137 — Apple Silicon/iOS
  26.x driver installed and launched but did not listen on its HTTP port.

These records support the compatibility hypothesis but do not establish that
the exact Maestro 2.6.1/Xcode 26.3 tuple is incompatible.

## Recovery boundary

The spec preserves the exact ripgrep implementation, CR/QA attestations, and
approved head. It requires a read-only exact-pair reproduction with driver
readiness diagnostics before any future recovery implementation. It rejects
guessing a Maestro version, changing the runner, skipping permissions, or
treating build/install/launch as a Maestro pass. A future tuple or runner
change requires its own approved slice and digest-pinned evidence.

## Verification

Completed:

```text
git status --short --branch
git log -3 --format='%H %s'
shasum -a 256 docs/specs/sprint-01-foundation/S1-02-hosted-runner-ripgrep-provisioning.md
codebase-memory index_status(project=Users-ant013-Data-AI-thorchain)
codebase-memory search_graph(query=run Maestro simulator permissions)
Serena activate_project(/Users/ant013/Data/AI/thorchain)
targeted rg of Scripts/run-maestro.sh, .maestro, and .github/workflows/ci.yml
xcrun simctl list runtimes
xcodebuild -version
java -version
maestro --version (not installed in current shell)
```

Not run by design: hosted CI, merge, implementation tests, and workflow or
verifier edits. Explicit approval of the revision-bound recovery design is
required before any follow-up implementation.

## Residual risk

The exact operator reproduction is supplied evidence and could not be
independently repeated in the current shell because the pinned Maestro/Temurin
pair is not installed there. The hosted driver failure is therefore classified
as a high-confidence external compatibility hypothesis, not a proven root
cause. Gimle remains RED until target project mapping is repaired.
