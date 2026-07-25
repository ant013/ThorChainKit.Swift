# THR-159 S2-06 topology-correction-v2 Gimle reliability report

Date: 2026-07-26  
Evidence head: `ea51548e82c1f96814050e49bc34462028f35c66`  
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
`rg`, current Xcode 26.3 installation/runtime inspection, the saved exact-head
build log, and current TronKit/EvmKit checkouts. The run checkpoint is
`audit/runs/runs/THR-159-20260725-topology-correction/state.json`.

## Load-bearing findings

- The root package exposes `ThorChainKit` and a separate dynamic
  `ThorChainExampleLiveSupport` product. Fixture Debug excludes LiveSupport,
  yet FixtureSupport and Fixture both link ThorChainKit.
- Xcode 26.3 reaches `HsCryptoKitdynamic-product` and asks for
  `Crypto_17A3B1FFC41E47_PackageProduct.framework/Crypto_17A3B1FFC41E47_PackageProduct`.
  The requested executable is absent; the real arm64 Crypto executable is
  present under the un-hashed framework name.
- TronKit and EvmKit each use one public kit library product consumed by one
  application target. This is the primary package-product boundary analog.
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

## Recorded defects and workarounds

| ID | Class | Severity | Impact | Workaround |
|---|---|---:|---|---|
| `B-TOPO-CODEBASE-HANG` | environment_drift | high | Codebase-memory-first graph evidence unavailable | Exact-head Git/`rg`/Xcode fallback; no graph claim |
| `B-TOPO-MAPPING` | mapping_bug | high | Target project/mount is absent from Gimle | Current-tree fallback; Gimle result excluded |
| `B-TOPO-SERENA` | environment_drift | medium | Serena verification unavailable | Targeted `rg` and Git reads |

No credentials, secrets, mnemonics, private keys, or dependency binaries are
stored in this report.
