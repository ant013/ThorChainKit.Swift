# THR-159 topology delta matrix

Correction revision `THR-159-TOPOLOGY-V2-R2` binds the topology delta to S2-06
spec commit `29611561f86765ee2ab9249a2de65a0989cc1626`, spec blob
`c0d862e9b861a117327864b60c534e539f9d5a8a`, while retaining architecture
revision 10 commit `518835315a65996b9321665213adb0516503df65` and bundle digest
`a843ca732687e70264bd0b6a961fd9a0a5219917e1f6ee71aa61060d94602bcc` as the
baseline. Fresh approval is required for this revision.

| Area | Preserved analog/invariant | Required delta | Rejected delta | Failure proof |
|---|---|---|---|---|
| Package ownership | WalletCore owns its crypto closure under one package root | Root ThorChainKit package owns the pinned HdWalletKit dependency and LiveSupport product | A second direct Xcode package root | Resolved graph has one local package reference and exact pins |
| Target boundary | S2-06 keeps Live and Fixture support separate | LiveSupport becomes a dynamic package product backed by `iOS Example/LiveSupport` | Moving LiveSupport into `ThorChainKit` or making FixtureSupport a package product | Target graph and source-membership audit |
| Library API/security | ThorChainKit is UI-agnostic and has no Example secrets | No library target/source/API change | Re-exporting wallet/crypto modules from ThorChainKit | Package target dependency inspection and public API diff |
| Build lifecycle | Unavailable/unresolved artifacts fail closed | Build both app schemes after graph collapse | Copying a generated framework binary or rerunning downloads | Exact xcodebuild logs; missing Crypto binary must disappear |
| Release/QA | Release excludes FixtureSupport | Live package product is Live-only; Fixture remains Fixture-only; bind the Live audit to the exact Release app, HEAD, and UDID and scan all app-bundle executables | Maestro or Fixture code in Live | Exact-artifact release audit rejects `FixtureSupport.framework` and fixture symbols in every scanned binary; guarded Maestro |
