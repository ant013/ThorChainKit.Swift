# THR-159 S2-06 Gimle reliability report — design revision 4

Date: 2026-07-25

Gimle trust: RED.

The required codebase-memory project `Users-ant013-Data-AI-thorchain` exists
and was queried before current-tree reads. Gimle/Palace health was reachable,
but the runtime resolved to `/Users/ant013/Android/Gimle-Palace-serving` with
`native-dev` identity and no ThorChainKit project mapping. No Gimle result was
used as a load-bearing design fact. Serena was unavailable in this workspace.
Exact current-tree anchors were checked with targeted `rg`, Git, and narrow
reads.

Discovery is frozen at 2/2. Revision 4 records the Board's answered Live
signer choice and the resulting concrete design:

- `THR-159-SEC-H01`: the Live target uses an Example-only support target with a
  fail-closed local loader for exactly twelve lowercase English BIP39 words
  from `THORCHAIN_TEST_MNEMONIC` in the ignored root `.env`; the controlled
  recipient is `THORCHAIN_TEST_RECIPIENT_ADDRESS`. It derives the standard
  BIP39 seed and exact THOR path `m/44'/931'/0'/0/0` through the pinned
  `HdWalletKit` backend, then atomically creates the matching address, signer,
  and Kit session. Missing, malformed, extra, or unreadable input publishes no
  session and never logs secret material. The app does not generate or fund
  the reusable QA wallet.
- `THR-159-SEC-H02`: remains resolved by the deterministic
  `1...2^256-1` base-unit and 32-byte canonical-magnitude bound.
- `THR-159-UI-H01`: remains resolved by `send.mode-badge`, full runtime
  node/value scanning, and an unlisted-node sensitive-value mutation.
- `THR-159-VOP-H01`: remains resolved by a versioned manifest with complete
  tracked input inventory, clean-input checks, exact HEAD/UDID, per-file and
  artifact digests, and fail-closed wrong-head/dirty/extra/missing/tampered
  cases.
- `THR-159-VOP-H02`: remains resolved by a purpose-created unfunded wallet
  and a controlled LIVE checklist that stops before confirmation/broadcast and
  proves zero send/retry/broadcaster events.

No product code, wallet, or funds changed. The revision requires a fresh
bounded adversarial review and explicit operator approval before implementation.
The independent roadmap-status repair must also be approved and landed before
the S2-06 formalization head is recreated from corrected `origin/main`.
