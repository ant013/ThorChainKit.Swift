# Gimle reliability report: THR-52-ripgrep-provisioning-20260720-r2

- Task: 04ee70d8-5cc8-415a-9df6-bc65ede0dc37
- Workflow/phase: analog_change / awaiting_approval
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d
- Final HEAD: n/a
- Gimle runtime: 0e9cf57c00ff970f584256126b500166580e7a72
- Indexed commit: e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d

## Metrics

- Calls: 3 (success 2, warning 1, error 0, false-success 0)
- Useful-call rate: 100.0%
- Response-byte coverage: 3/3; total 3043
- Duration coverage: 0/3; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 1
- Analog slices/candidates: 1/4

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 0 | 1 | 0 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1}
Bug severities: {'high': 1}
Bug statuses: {'workaround': 1}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | 200 | success | n/a/1 | 393 | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | 200 | success | n/a/1 | 2500 | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.get_project_overview | 200 | warning | n/a/1 | 150 | n/a | yes | 33297f6293db6631 | unknown_project |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S1-02-RG-PROVISION | high | dependencies, responsibility, trust | contract, counterexample, implementation | n/a | C-001 | C-002, C-004 | C-003 |
  - Conflict: The current pinned-tool analog is a zip workflow block, while ripgrep is a tar.gz CLI asset.; resolution: Preserve the security/lifecycle shape—literal URL, verify-before-extract, temp staging, PATH export, version assertion—and adapt archive format.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|
| C-001 | S1-02-RG-PROVISION | kept | F-001 | implementation | responsibility | known_current | .github/workflows/ci.yml |
| C-002 | S1-02-RG-PROVISION | supporting | F-003 | contract | dependencies | known_current | https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0 |
| C-004 | S1-02-RG-PROVISION | supporting | F-003 | contract | trust | known_current | https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0 |
| C-003 | S1-02-RG-PROVISION | rejected | F-004 | counterexample | dependencies | known_current | .github/workflows/ci.yml |

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-001 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At exact head e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d, .github/workflows/ci.yml provides the current pinned-tool provisioning analog: curl a pinned release URL, verify a litera... |
  - Serena: Serena search found .github/workflows/ci.yml lines 89-94: pinned Maestro URL, shasum -a 256 -c -, unzip, GITHUB_PATH.
  - rg: rg --hidden and git show at exact head confirmed the same order and lines.
  - Anchors: .github/workflows/ci.yml:89-94@e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d
| F-002 | 1 | yes | MATCH | yes | serena+rg | n/a | valid | known_current | At exact head, Scripts/verify-s1-02.sh consumes rg in its hosted test-discovery pipeline after Swift test listing. |
  - Serena: Serena search found Scripts/verify-s1-02.sh lines 206-210: swift test list piped to rg, sorted, and compared with the exact allowlist.
  - rg: rg located the failing pipeline at Scripts/verify-s1-02.sh:208; git show exact head confirmed it.
  - Anchors: Scripts/verify-s1-02.sh:206-210@e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d
| F-003 | 1 | yes | MATCH | yes | rg | n/a | not_applicable | known_current | The official BurntSushi/ripgrep 15.2.0 release publishes ripgrep-15.2.0-aarch64-apple-darwin.tar.gz with GitHub asset digest sha256:3750b2e93f37e0c692657da574d7019a101c0084da05a... |
  - Serena: n/a
  - rg: GitHub API release tag 15.2.0 reports the exact asset URL, size 1764284, and digest; direct download shasum reproduced it and the .sha256 sidecar matched.
  - Anchors: https://github.com/BurntSushi/ripgrep/releases/tag/15.2.0; official asset URL
| F-004 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | No existing repository workflow or script provides a second ripgrep provisioning path; package-manager installation would be a new mutable alternative. |
  - Serena: n/a
  - rg: Targeted rg --hidden over .github/workflows, Scripts, and docs found no brew install, apt install, or ripgrep provisioning block.
  - Anchors: .github/workflows/ci.yml:85-102; Scripts/verify-s1-02.sh:206-210@e9c667a07ab46ecbc7116e1f8e1fa932ff956b8d

## Adversarial decisions

- D-001@2 ACCEPT: Current-tree workflow and verifier anchors are fresh and identity-bound for the revised spec.
- D-002@2 ACCEPT: External executable remains pinned and fail-closed for the revised spec.
- D-003@2 ACCEPT: Workflow plus existing policy verifier is the minimum coherent change.
- D-004@3 ACCEPT: The existing CI-policy verifier provides the durable regression guard for pinned ripgrep provisioning.

## Verification and acceptance


## Bugs and limitations

### G-0001: ThorChainKit codebase-memory project is not registered in Gimle project registry

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0003 / n/a
- Reproduction: Request overview for slug Users-ant013-Data-AI-thorchain after codebase-memory lists the indexed project.
- Expected: Project overview resolves repository identity and indexed commit.
- Actual: unknown_project; Gimle registry lists no ThorChainKit project while codebase-memory indexes the repository.
- Impact: Gimle cannot provide project-scoped freshness or analog discovery for the target repository; load-bearing conclusions use codebase-memory, Serena, Git, and targeted rg fallback.
- Workaround: Keep Gimle trust RED and use independently verified current-tree evidence.
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
