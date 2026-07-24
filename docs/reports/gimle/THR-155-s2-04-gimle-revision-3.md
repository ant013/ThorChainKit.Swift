# Gimle reliability report: 751add34-bb29-4396-9041-87967c5a6ab2

- Task: b34f82dc-4655-46d0-b148-628b53846a02
- Workflow/phase: analog_change / adversarial_review
- Trust: **RED**
- Repository: /Users/ant013/Data/AI/thorchain
- Base HEAD: 372d9c178defdeed31ed4e581382b834debef951
- Final HEAD: n/a
- Gimle runtime: native-dev
- Indexed commit: unknown

## Metrics

- Calls: 3 (success 2, warning 0, error 1, false-success 0)
- Useful-call rate: 0.0%
- Response-byte coverage: 0/3; total n/a
- Duration coverage: 0/3; total n/a ms
- Gimle agreement: n/a
- Gimle contradiction: n/a
- Location validity: n/a; coverage 0/0
- Freshness coverage: n/a
- Replacement/fallback claims: 0
- Bugs: 1
- Analog slices/candidates: 1/0

### Calls by tool

| Tool | Success | Warning | Error | False-success |
|---|---:|---:|---:|---:|
| palace_memory.palace_health_status | 1 | 0 | 0 | 0 |
| palace_memory.palace_memory_get_project_overview | 0 | 0 | 1 | 0 |
| palace_memory.palace_memory_list_projects | 1 | 0 | 0 | 0 |

Bug classes: {'mapping_bug': 1}
Bug severities: {'high': 1}
Bug statuses: {'workaround': 1}

## Gimle calls

| Event | Phase | Tool | Protocol | Outcome | Total/returned | Bytes | Duration | Used | Args hash | Warnings |
|---|---|---|---|---|---|---:|---:|:---:|---|---|
| E-0001 | preflight | palace_memory.palace_health_status | success | success | n/a/1 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0002 | preflight | palace_memory.palace_memory_list_projects | success | success | n/a/17 | n/a | n/a | no | 44136fa355b3678a | n/a |
| E-0003 | preflight | palace_memory.palace_memory_get_project_overview | success | error | n/a/0 | n/a | n/a | no | 33297f6293db6631 | unknown_project |

## Component analog family

| Slice | Risk | Required dimensions | Required roles | Waived roles | Primary | Supporting | Counterexamples |
|---|---|---|---|---|---|---|---|
| S2-04 | critical | responsibility | counterexample | n/a | n/a | n/a | n/a |
  - Greenfield: Two independent bounded discovery lanes found no current ThorChainKit full coordinator spine; the coordinator/handoff remains a greenfield delta with external analogs only as supporting design evidence.

### Analog candidates

| Candidate | Slice | Disposition | Fact | Roles | Dimensions | Freshness | Path |
|---|---|---|---|---|---|---|---|

## Evidence claims

| Fact | Rev | Load-bearing | Verdict | Accepted | Basis | Events | Location | Freshness | Claim |
|---|---:|:---:|---|:---:|---|---|---|---|---|
| F-155-03 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The S2-03 implementation commit d548b9b contains DirectSignCodec.swift and DirectSignCodecTests.swift, while the current S2-04 docs branch merge-base is the earlier docs-only ef... |
  - Serena: n/a
  - rg: git cat-file -e origin/feature/THR-154-s2-03-direct-sign:Sources/ThorChainKit/Protocol/DirectSignCodec.swift; git cat-file -e ...Tests/DirectSignCodecTests.swift; git merge-base HEAD origin/feature/THR-154-s2-03-direct-sign
  - Anchors: d548b9b5b858e6ed96793a8d3e40de6084e96efa
| F-155-07 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | Current SendError.swift defines SendError but has no repairPending case; the internal coordinator result therefore needs a separately named typed result path. |
  - Serena: n/a
  - rg: rg -n "enum SendError\|repairPending" Sources/ThorChainKit/Send/Errors/SendError.swift
  - Anchors: Sources/ThorChainKit/Send/Errors/SendError.swift:53-63
| F-155-08 | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The repository verification convention pins Apple Swift through xcrun swift; bare swift is Swift 5.8.1 while xcrun swift is Apple Swift 6.2.4. |
  - Serena: n/a
  - rg: xcrun swift --version; swift --version; Scripts/verify-s1-01.sh:273-278
  - Anchors: Scripts/verify-s1-01.sh:273-278
| F-155-03-HANDOFF | 1 | yes | MATCH | yes | rg | n/a | valid | known_current | The revised S2-04 design defines one reservationOwnerToken as the attempt token and durable owner-CAS credential, and carries it in the internal SendAttemptHandoff. |
  - Serena: n/a
  - rg: S2-04 spec revision 3: lines 96-100 and 154-163
  - Anchors: docs/specs/sprint-02-native-send/S2-04-external-signer-coordinator.md:96-100,154-163

## Adversarial decisions

- D-155-REVIEW-1@1 REVISE: Targeted review requested revision for token identity/return shape, typed repair-pending result, pinned toolchain commands, coherent suspension fixtures, and the S2-03 implementation base.

## Verification and acceptance


## Bugs and limitations

### GIMLE-THR155-MAP-01: Target project is present in codebase-memory but absent from Palace memory project registry

- Class/severity/confidence/status: mapping_bug / high / confirmed / workaround
- Tool/events/claims: palace_memory.palace_memory_get_project_overview / E-0003 / n/a
- Reproduction: Lookup project slug Users-ant013-Data-AI-thorchain after Palace project listing; lookup returns unknown_project while codebase-memory index_status reports ready with 3940 nodes.
- Expected: The target project slug resolves in the Gimle/Palace project registry with current identity metadata.
- Actual: Palace returns unknown_project; no target git mount or indexed commit can be resolved.
- Impact: Gimle target discovery and freshness cannot be used as load-bearing evidence for S2-04.
- Workaround: Use codebase-memory for discovery and verify all load-bearing facts with targeted rg/Git; retain RED Gimle trust and report the mapping defect.
- Anchors: n/a

## Interpretation

Contradicted or unverifiable Gimle evidence was not accepted as repository truth. A verified fallback does not erase the defect.
