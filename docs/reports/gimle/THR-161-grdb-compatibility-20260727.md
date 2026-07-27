# Gimle reliability report: THR-161-grdb-compatibility-20260727

- Task: 66212009-331a-4747-9abd-f7f691fd2cf6
- Workflow/phase: analog_change / verification
- Trust: **RED**
- Repository: ThorChainKit.Swift correction checkout
- Base HEAD: 65c8e370db983c6bd500448266a4f8f51561ca5f
- Final HEAD: f8751ee0929543bc11272350bcc7e9ac3d10dc5c
- Gimle runtime: native-dev
- Indexed commit: n/a

## Metrics

- Calls: 4 (success 3, warning 0, error 0, false-success 1)
- Useful-call rate: 100.0%
- Response-byte coverage: 0/4; total n/a
- Duration coverage: 0/4; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 1
- Analog slices/candidates: 1/7

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.list_passthrough_projects | 1 | 0 | 0 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 0 | 0 | 0 | 1 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1}
Bug severities: {'high': 1}
Bug statuses: {'workaround': 1}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace.health.status | success | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace.memory.list_projects | success | success | n/a/20 | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace.memory.get_project_overview | success | false_success | n/a/n/a | n/a | n/a | yes | 33297f6293db6631 | payload returned ok=false unknown_project |
| E-0004 | preflight | palace.code.list_passthrough_projects | success | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S161-GRDB-PIN | normal | boundary, dependencies, responsibility, state_errors, tests, trust | composition, consumer, contract, counterexample, implementation, lifecycle_error, test | n/a | C-161-MANIFEST-CHANGE | C-161-RESOLVED-CHANGE, C-161-CONTRACT, C-161-CONSUMER, C-161-ERROR, C-161-TEST | C-161-OLD-PIN |
  - Conflict: The historical manifest correction and resolved-state correction are separate commits.; resolution: Keep the one-line Package.swift change and the required Package.resolved refresh as one approved prerequisite delta; do not copy unrelated historical changes.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-161-MANIFEST-CHANGE | S161-GRDB-PIN | kept | F-161-003 | implementation | responsibility | known_current | Package.swift@da502c439f530de5f45588bd2fb0c8d5b9fd9799 |
| C-161-RESOLVED-CHANGE | S161-GRDB-PIN | supporting | F-161-004 | composition | dependencies | known_current | Package.resolved@3f492c8c7f334d69ce0cacb14157ba9846f59c69 |
| C-161-CONTRACT | S161-GRDB-PIN | supporting | F-161-001 | contract | boundary | known_current | Package.swift |
| C-161-CONSUMER | S161-GRDB-PIN | supporting | F-161-001 | consumer | trust | known_current | Package.swift |
| C-161-ERROR | S161-GRDB-PIN | supporting | F-161-002 | lifecycle_error | state_errors | known_current | Package.resolved |
| C-161-TEST | S161-GRDB-PIN | supporting | F-161-004 | test | tests | known_current | Package.resolved@3f492c8c7f334d69ce0cacb14157ba9846f59c69 |
| C-161-OLD-PIN | S161-GRDB-PIN | rejected | F-161-001 | counterexample | dependencies | known_current | Package.swift |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-161-001 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | At the frozen origin/main head, ThorChainKit Package.swift declares iOS 13 and pins GRDB.swift exact 6.29.1. |
  - Serena: Serena unavailable in the current tool environment.
  - rg: sed/rg on Package.swift lines 6 and 20-23; git show 65c8e370:Package.swift agrees.
  - Anchors: Package.swift:6,20-23
| F-161-002 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | At the frozen origin/main head, Package.resolved records GRDB 6.29.1 at revision dd6b98ce04eda39aa22f066cd421c24d7236ea8a. |
  - Serena: Serena unavailable in the current tool environment.
  - rg: rg on Package.resolved lines 14-19; git show 65c8e370:Package.resolved agrees.
  - Anchors: Package.resolved:14-19
| F-161-003 | 1 | yes | MATCH | yes | rg | n/a | not_applicable | known_current | The repository history contains a package-only analog da502c439f530de5f45588bd2fb0c8d5b9fd9799 that changes only Package.swift GRDB exact 6.29.1 to 6.29.3. |
  - Serena: Serena unavailable; Git object verification used for historical analog.
  - rg: git show da502c4 --stat and -- Package.swift show one-file, one-line dependency correction.
  - Anchors: git commit da502c439f530de5f45588bd2fb0c8d5b9fd9799
| F-161-004 | 1 | yes | MATCH | yes | rg | n/a | not_applicable | known_current | The repository history contains a resolved-state analog 3f492c8c7f334d69ce0cacb14157ba9846f59c69 that changes only Package.resolved to GRDB revision 2cf6c756e1e5ef6901ebae16576a... |
  - Serena: Serena unavailable; Git object verification used for historical analog.
  - rg: git show 3f492c8 --stat and -- Package.resolved show one-file resolved-state update.
  - Anchors: git commit 3f492c8c7f334d69ce0cacb14157ba9846f59c69
| F-161-005 | 2 | yes | MATCH | yes | rg | n/a | valid | known_current | Upstream GRDB tag v6.29.3 resolves to 2cf6c756e1e5ef6901ebae16576a7e4e4b834622 and declares iOS 11, so the ThorChainKit iOS 13 floor remains unchanged. |
  - Serena: n/a
  - rg: git show 2cf6c756e1e5ef6901ebae16576a7e4e4b834622:Package.swift; targeted rg for platforms
  - Anchors: upstream GRDB Package.swift platforms declaration at v6.29.3
| F-161-006 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Existing dependency verification scripts encode the GRDB version and revision as acceptance contracts that must be updated with this prerequisite. |
  - Serena: n/a
  - rg: Scripts/test-s1-05-dependency-floor.sh:18-20; Scripts/verify-s1-03.sh:167-172; Scripts/verify-bigint-floor.sh:66-70
  - Anchors: current verification scripts in the frozen base

## Adversarial decisions

- D-161-ARCH-001@3 ACCEPT: ACCEPT: final committed spec allowlist covers only package state and directly affected verifier assertions; host and Unstoppable source remain out of scope.
- D-161-SEC-002@3 ACCEPT: ACCEPT: final committed design requires isolated approved MarketKit host-graph resolution, structural non-GRDB lockfile preservation, temporary-copy resolution, and fail-closed behavior.
- D-161-VERIFY-003@4 ACCEPT: ACCEPT: final committed verification uses an explicit correction-head placeholder, immutable base for diffs, xcrun SwiftPM deterministic test filtering, host-graph test, lockfile check, and device-floor verifier.

## Verification and acceptance

- Exact implementation head `f8751ee0929543bc11272350bcc7e9ac3d10dc5c` remained clean against base `65c8e370db983c6bd500448266a4f8f51561ca5f`; the six-file implementation diff stayed within the approved allowlist.
- `Scripts/test-thr-161-grdb-compatibility.sh --marketkit-url https://github.com/horizontalsystems/MarketKit.Swift.git --marketkit-revision 2c327452237cfbbdc4d87bcd5dd417d1da46a61e`: PASS. The manifest/lock contract, frozen GRDB 6.29.1 rejection, corrected host graph, exact MarketKit revision, GRDB 6.29.3 pin, and non-GRDB lock preservation all passed.
- Generic local iOS build: PASS. Explicit `iphoneos` device-floor build with `IPHONEOS_DEPLOYMENT_TARGET=13.0`: `** BUILD SUCCEEDED **`.
- `Package.resolved` SHA-256: `d4f311c9e43a1e20be3288564e5cc87b8d7cbc8ad8eb61d37e7a33e4bfd4730d`.
- Existing deterministic fixture selection: 82/82 pass; the separately renamed S2-02 test passed 1/1. The stale 83rd fixture entry is pre-existing and unrelated to THR-161.
- No hosted Actions, source edits, Unstoppable changes, or fail-closed exception were used.


## Bugs and limitations

### GIMLE-THR161-001: Gimle has no registered project for the ThorChainKit target slug

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0003 / n/a
- Reproduction: palace.memory.get_project_overview(slug=Users-ant013-Data-AI-thorchain) returned a successful MCP envelope with payload ok=false and error=unknown_project; palace.memory.list_projects returned no matching ThorChainKit project.
- Expected: The exact target project resolves to a registered Gimle project with repository mapping and freshness metadata.
- Actual: The target project is absent from Gimle project discovery, so indexed code/freshness identity cannot be resolved.
- Impact: Gimle cannot supply load-bearing package-compatibility analog evidence or freshness for this correction.
- Workaround: Use codebase-memory plus exact current-tree Git/rg/package-manager evidence; report Gimle trust RED and do not treat Gimle as a selected source.
- Anchors: palace.memory.list_projects result and exact unknown_project payload

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
