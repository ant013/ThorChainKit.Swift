# THR-159 S2-06 Gimle reliability report — design revision 3

Date: 2026-07-25

Gimle trust: RED.

The required codebase-memory project `Users-ant013-Data-AI-thorchain` exists
and was queried before current-tree reads. Its graph returned current
ThorChainKit send composition and test symbols. Gimle/Palace health was
reachable, but the runtime resolved to `/Users/ant013/Android/Gimle-Palace-serving`
with `native-dev` identity and no ThorChainKit project mapping. No Gimle result
was used as a load-bearing design fact. Serena was unavailable in this
workspace. Exact current-tree anchors were checked with targeted `rg`, Git, and
narrow reads.

Discovery is frozen at 2/2. The five discovery-2 findings were dispositioned:

- `THR-159-SEC-H01`: remains an operator decision. The approved secret format,
  derivation path, and signing backend are not guessed. Until chosen, Live is
  visibly unavailable and cannot construct a send session. The non-secret
  wallet-ID rule is fixed to a domain prefix plus SHA-256 of the canonical
  compressed public key.
- `THR-159-SEC-H02`: resolved by the deterministic `1...2^256-1` base-unit and
  32-byte canonical-magnitude bound.
- `THR-159-UI-H01`: resolved by `send.mode-badge`, full runtime node/value
  scanning, and an unlisted-node sensitive-value mutation.
- `THR-159-VOP-H01`: resolved by a versioned manifest with complete tracked
  input inventory, clean-input checks, exact HEAD/UDID, per-file and artifact
  digests, and fail-closed wrong-head/dirty/extra/missing/tampered cases.
- `THR-159-VOP-H02`: resolved by a purpose-created low-balance mainnet QA wallet;
  its existing funding does not authorize an irreversible send. The controlled
  LIVE checklist stops before confirmation/broadcast and proves zero
  send/retry/broadcaster events.

No product code changed. Explicit operator approval is still required for this
design revision, and the Live backend decision must precede implementation.
