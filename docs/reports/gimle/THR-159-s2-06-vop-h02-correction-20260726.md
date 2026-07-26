# THR-159 S2-06 VOP-H02 correction evidence

Date: 2026-07-26  
Design revision: 7  
Discovery: 2/2 frozen  
Closure: 0/5 before this correction

## Decision

The authoritative S2-06 Maestro command is:

```text
THORCHAIN_SIMULATOR_UDID=<UDID> Scripts/run-maestro.sh s2-06
```

The `s2-06` token is required by the existing runner dispatch. The design and
plan now name this command consistently. No product implementation files were
changed.

## Current-tree evidence

- `Scripts/run-maestro.sh:15-19` dispatches to `run-maestro-s2-06.sh` only when
  the first argument is `s2-06`.
- `Scripts/run-maestro.sh:21-27` requires exactly one slice token for the
  remaining dispatch paths.
- The no-token reproduction with a syntactically valid UDID exited `1` with
  `FAIL run-maestro: exactly one slice token is required`.
- The corrected `s2-06` reproduction entered the S2-06 wrapper and printed
  `S2-06 semantic manifest contract OK` plus the negative-mutation result before
  stopping at the known local Xcode plug-in/runtime failure (exit `70`). It did
  not claim a simulator or five-flow pass.
- `bash -n Scripts/run-maestro.sh Scripts/run-maestro-s2-06.sh` passed.
- `git diff --check` passed.

## Gimle reliability

Gimle trust remains **RED**. The ready codebase-memory index returned zero
matches for the runner query, Serena was unavailable, and the target project is
not present in the available Palace inventory. The decision uses exact current
tree reads and targeted `rg`/Git evidence only. These substrate limitations are
reported, not treated as acceptance failures for this documentation correction.

No credentials, secrets, mnemonics, private keys, or dependency binaries are
stored in this report.
