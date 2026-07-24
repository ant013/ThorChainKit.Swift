# Gimle reliability report: ec32f2de-c376-4eb5-a1e2-67f168aecbf2

- Task: ec32f2de-c376-4eb5-a1e2-67f168aecbf2
- Workflow/phase: evidence_audit / complete
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain-s2-02
- Base HEAD: 23ba7e8c4204dbb16efadaa092a1ff896263e8f7
- Final HEAD: f4943fe408bd437abc0770baa6517bb6ae1037fb
- Gimle runtime: n/a
- Indexed commit: n/a

## Metrics

- Calls: 5 (success 3, warning 0, error 2, false-success 0)
- Useful-call rate: 40.0%
- Response-byte coverage: 0/5; total n/a
- Duration coverage: 0/5; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 2
- Analog slices/candidates: 0/0

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace.code.find_references | 0 | 0 | 1 | 0 |
| palace.health.status | 1 | 0 | 0 | 0 |
| palace.memory.get_project_overview | 0 | 0 | 1 | 0 |
| palace.memory.health | 1 | 0 | 0 | 0 |
| palace.memory.list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 2}
Bug severities: {'medium': 2}
Bug statuses: {'workaround': 2}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | evidence | palace.health.status | 200 | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0002 | evidence | palace.memory.health | 200 | success | n/a/n/a | n/a | n/a | yes | 44136fa355b3678a | n/a |
| E-0003 | evidence | palace.memory.list_projects | 200 | success | n/a/n/a | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0004 | evidence | palace.memory.get_project_overview | 200 | error | n/a/n/a | n/a | n/a | no | 33297f6293db6631 | unknown_project |
| E-0005 | evidence | palace.code.find_references | 200 | error | n/a/n/a | n/a | n/a | no | 872adfdfac89236f | project_not_found |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-0001 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The active generator check can pin SwiftProtobuf by exact source commit and tag while proving generated output byte-for-byte. |
  - Serena: Serena could not parse shell symbols; current-tree shell was independently checked with rg and sh -n.
  - rg: Scripts/generate-query-codec.sh lines 38, 75-86; PROVENANCE.md lines 7-13.
  - Anchors: Scripts/generate-query-codec.sh:38
| F-0002 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The recorded protoc-gen-swift executable SHA-256 is not reproducible across clean builds and must not be used as the generator identity. |
  - Serena: n/a
  - rg: Git history shows the executable hash was added in 23ba7e8; local debug hash was 548f23 and two clean release builds produced df765b and 782643.
  - Anchors: Scripts/generate-query-codec.sh:83

## Adversarial decisions


## Verification and acceptance


## Bugs and limitations

### B-0001: Requested codebase-memory project is not registered in Gimle

- Class/severity/confidence/status: mapping_bug / medium / confirmed / workaround
- Tool/events/claims: palace.code.find_references / E-0005 / n/a
- Reproduction: Query overview for slug Users-ant013-Data-AI-thorchain; query references in the same project.
- Expected: Project overview and code references with freshness
- Actual: unknown_project and project_not_found; registered projects omit the requested slug
- Impact: Gimle-specific freshness and project mapping could not be used for this correction
- Workaround: Used codebase-memory, Serena, targeted rg, Git history, and exact local generator execution; no Gimle claim influenced the patch
- Anchors: n/a

### B-0002: Requested codebase-memory project is not registered in Gimle

- Class/severity/confidence/status: mapping_bug / medium / confirmed / workaround
- Tool/events/claims: palace.memory.get_project_overview / E-0004 / n/a
- Reproduction: Query overview for slug Users-ant013-Data-AI-thorchain
- Expected: Project overview with freshness and repository mapping
- Actual: unknown_project; registered project list contains no requested entry
- Impact: Gimle-specific freshness and project mapping could not be used for this correction
- Workaround: Used codebase-memory, Serena, targeted rg, Git history, and exact local generator execution
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
