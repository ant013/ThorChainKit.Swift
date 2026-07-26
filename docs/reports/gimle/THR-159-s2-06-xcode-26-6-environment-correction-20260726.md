# THR-159 S2-06 Xcode 26.6 environment-correction Gimle reliability report

Date: 2026-07-26  
Reviewed implementation head before this correction: `e0c4ff1e5b49bf2d6c790b792d5bd74347ca8ae6`  
Toolchain: Xcode `26.6 (17F113)`; iOS Simulator SDK/runtime `26.5`  
Simulator: iPhone 17 Pro `5AD222A4-19E7-48A2-BA76-A4540893DB36`  
Scope: environment binding only; no product code, provider policy, slice acceptance, or five-flow changes

## Trust

Gimle trust is **RED** for this correction. The codebase-memory project
`Users-ant013-Data-AI-thorchain` exists and contains the indexed repository,
but its bounded documentation search returned no S2-06 environment text.
Palace health and memory health were reachable, while the runtime resolved to
the separate dirty `native-dev` Gimle-Palace-serving checkout and the target
ThorChainKit project was absent from the Palace project registry. No Palace
result was used as a load-bearing design fact. Serena and sequential-thinking
tools were not exposed in this run.

The fallback basis is independently anchored to the exact implementation head,
targeted `rg`, Git reads, and current host checks. The run checkpoint is
`audit/runs/THR-159-20260726-xcode-26-6/state.json`.

## Environment evidence

- `xcodebuild -version` → Xcode `26.6`, build `17F113`.
- `xcrun --sdk iphonesimulator --show-sdk-version` → `26.5`.
- `xcrun simctl list runtimes` → installed `com.apple.CoreSimulator.SimRuntime.iOS-26-5`.
- `xcrun simctl getenv 5AD222A4-19E7-48A2-BA76-A4540893DB36 SIMULATOR_RUNTIME_VERSION` → `26.5`.
- The reviewed spec and plan previously bound formal acceptance to Xcode 26.3/iOS 26.2. The correction changes only that binding and names the exact UDID.

## Bounded adversarial review

Outcome: **ACCEPT for the documentation/environment correction**; this is not
QA approval of the product slice.

- Identity/freshness: the exact host output matches the operator-provided
  Xcode, SDK, runtime, and UDID.
- Scope: the correction is limited to the S2-06 spec, plan, and this Gimle
  report; product code, package/provider policy, and five-flow assertions are
  unchanged.
- Historical evidence: prior Xcode 26.3 wrapper failures remain retained and
  explicitly labeled historical rather than being presented as current
  Xcode 26.6 results.
- Smaller alternative: changing only the spec/plan binding without a new
  immutable reliability report would lose the environment provenance, so the
  three-file correction is the minimum auditable change.

## Required QA continuation

The following checks remain unrun and must be performed by
ThorChainQAEngineer on the resulting corrected commit:

```text
xcodebuild -workspace iOS Example/iOS Example.xcworkspace -scheme ThorChainExampleLive -configuration Release -destination id=5AD222A4-19E7-48A2-BA76-A4540893DB36 build
xcodebuild -workspace iOS Example/iOS Example.xcworkspace -scheme ThorChainExampleFixture -configuration Debug -destination id=5AD222A4-19E7-48A2-BA76-A4540893DB36 build
THORCHAIN_SIMULATOR_UDID=5AD222A4-19E7-48A2-BA76-A4540893DB36 Scripts/run-maestro.sh s2-06
```

No build, Maestro, simulator, artifact, or release-symbol pass is claimed by
this report.

## Recorded Gimle limitations

| ID | Class | Severity | Workaround |
|---|---|---:|---|
| `B-ENV-THORCHAIN-UNREGISTERED` | mapping_bug | high | Codebase-memory plus exact-head Git/rg fallback |
| `B-ENV-PALACE-MEMORY-GAP` | mapping_bug | high | Current-tree fallback; no Palace decision used |
| `B-ENV-PALACE-RUNTIME-MISMATCH` | environment_drift | medium | Report runtime identity and use independent host evidence |

No credentials, secrets, mnemonics, private keys, or dependency binaries are
stored in this report.
