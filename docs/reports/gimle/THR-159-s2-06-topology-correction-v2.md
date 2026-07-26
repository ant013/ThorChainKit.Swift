# THR-159 S2-06 topology-correction-v2 Gimle reliability report

Date: 2026-07-26  
Design head before this revision: `d5e62d2a3cbea7eebf6d2efdd28c4f1656baef00`
Compatibility evidence head: `ea51548e82c1f96814050e49bc34462028f35c66`
Toolchain: Xcode `26.3 (17C529)`; simulator runtime iOS `26.2`  
Discovery: `2/2` frozen; closure: not started

## Trust

Gimle trust is **RED** for this revision. Palace health and memory health were
reachable, but the target project `Users-ant013-Data-AI-thorchain` is not
registered in the available Gimle project/mount inventory. The bounded
codebase-memory graph query for the same project did not return within 52
seconds and was terminated. Serena navigation tools were not exposed in this
run. No Gimle, codebase-memory, or similarly named project result was used as a
load-bearing design fact.

Fallback evidence is independently anchored to exact-head Git reads, targeted
`rg`, codebase-memory symbol discovery, current Xcode 26.3 installation/runtime
inspection, the saved exact-head build-log digest, and current TronKit/EvmKit
checkouts. Serena was not exposed. The run checkpoint is
`audit/runs/THR-159-20260725-cto/state.json`.

## Load-bearing findings

- The root package exposes `ThorChainKit` and a separate dynamic
  `ThorChainExampleLiveSupport` product. Current `Package.swift:53-62` makes
  LiveSupport depend on ThorChainKit, while current project lines 82-84 and
  126-128 also make the apps/support targets link it directly; this is the
  contradictory graph under review.
- Xcode 26.3 reaches `HsCryptoKitdynamic-product` and asks for
  `Crypto_17A3B1FFC41E47_PackageProduct.framework/Crypto_17A3B1FFC41E47_PackageProduct`.
  The requested executable is absent; the real arm64 Crypto executable is
  present under the un-hashed framework name.
- TronKit `aa691bcd8c79d57a554d72a4996bec4d7e1afce5` and EvmKit
  `be0286317c202084784c5a695928cdc985c4ff7b` each use one public kit library
  product consumed by one application target. These are the primary
  package-product boundary analogs; Unstoppable `b38f5fdcedaec7f22979f6db1dcc991ab8de6edf` is
  not used as the ownership spine.
- The direct root Crypto/_CryptoExtras and static ThorChainKit experiments are
  rejected counterexamples: they did not produce the missing wrapper or they
  introduced duplicate linkage. They must not be repeated.

## Revision-5 decision

No safe repository-only package-graph delta is proven. Preserve current pins
and target boundaries, fail closed on all build/Maestro/artifact/release claims,
and require a separately approved compatibility slice to choose one explicit
owner for the shared crypto closure. That slice must prove a real Crypto
executable, no duplicate ThorChainKit linkage, FixtureSupport exclusion from
Live artifacts, and successful Fixture Debug plus Live Release package-graph
preparation on the exact toolchain/runtime.

## Revision-6 design correction

The review's package-ownership finding is resolved in the design, not claimed
as a successful build: each app directly owns its package closure, while
LiveSupport and FixtureSupport become Foundation-only helper targets. Live
derivation, signer, and Kit construction move to Example-owned `Sources/Signing`;
Fixture Kit adapters move there as well. Step 0 must prove this exact graph and
both complete builds before any later step can start.

The LIVE ingress is now simulator-only app-container staging through
`simctl push`, with regular-file/no-symlink, mode/size, single-read, and cleanup
checks. The derivation test binds the independently checked BIP39 seed vector
(`abandon` ×11 + `about`, empty passphrase, seed digest/value recorded in the
spec) to the independent THOR public-key/address vector and a non-secret
expected QA sender address before publishing the session. Controlled LIVE uses
the test-only SPI transport-level broadcast deny/recorder and count-only
signer/send/retry guards. Matching `sdk/19` is terminal CheckTx acceptance and
survives restart; initial unknown warns that the transaction may already
execute and prohibits replacement send. Steps 1–4 explicitly depend on Step 0.

## Recorded defects and workarounds

| ID | Class | Severity | Impact | Workaround |
|---|---|---:|---|---|
| `B-TOPO-CODEBASE-HANG` | environment_drift | high | Prior bounded graph call timed out during the topology run | Current run codebase-memory status is `ready` with 199,702 nodes/860,716 edges; exact-head Git/`rg` remains the independent basis |
| `B-TOPO-MAPPING` | mapping_bug | high | Target project/mount is absent from Gimle | Current-tree fallback; Gimle result excluded |
| `B-TOPO-SERENA` | environment_drift | medium | Serena verification unavailable | Targeted `rg` and Git reads |

No credentials, secrets, mnemonics, private keys, or dependency binaries are
stored in this report.
