# Plan: SSA Earnings Integrity Case Review

## 1. Planning Gate Status

- Discovery questionnaire: Complete (14 questions, including Q6b, Q12, Q13)
- Spec artifact: Complete
- Plan artifact: Complete
- Task artifact: Complete
- Build scripts 20-60: Ready to start
- Solution name: `EarningsIntegrity` (confirmed Q12)
- Publisher prefix: `earnInt` (confirmed Q13, new prefix)

## 2. Build Strategy

Use the repository wizard sequence and keep all implementation script-driven:

1. Validate prerequisites
2. Authenticate to target Dataverse environment
3. Define payloads for tables, columns, and relationships
4. Run scripts 20, 30, 40, 50, 60 in order
5. Verify artifacts in Maker portal
6. Export and unpack solution to source control

## 3. Architecture Approach

### 3.1 App Style

- Model-driven app centered on Case as the workflow anchor
- Supporting tables for beneficiary, earnings, discrepancies, evidence, findings, and outcomes
- Queue and activity views to support analyst throughput

### 3.2 Data and Relationship Approach

- Parent-first creation order
- Case has one-to-many links to operational records (earnings discrepancies, evidence, findings, tasks)
- Lookup relationships from disposition records (overpayment review, fraud escalation) back to Case
- Required status and status reason on key process tables

### 3.3 Workflow and Automation Approach

- Phase 1: Focus on schema and model-driven UX (forms/views)
- Phase 2: Add Power Automate orchestration for intake routing and escalation
- Surface supervisory summaries through a report web resource or HTML summary area when the case context needs operational visibility.
- Keep business rules in-app where deterministic and immediate

## 4. Environment and Security

- Target environment URL: https://healthconnectcenter.crm.dynamics.com/
- Output solution type: Unmanaged
- Security model baseline:
  - Analyst role: create/read/update operational case records
  - Supervisor role: approve/reject findings and escalation decisions
- Audit fields and status changes must be preserved for traceability

## 5. ALM and Source Control

- Build from payload JSON + bootstrap scripts
- Export unmanaged solution after validation
- Unpack into source-managed solution folder
- Commit only source-controlled artifacts (never include local auth/session files)

## 6. Risks and Mitigations

- Risk: Over-scoping too many entities before proving core case flow
  - Mitigation: Build minimum viable schema for case lifecycle first
- Risk: Authentication/session failures during build
  - Mitigation: Re-run auth script and validate with az and pac profile checks
- Risk: Relationship ordering failures
  - Mitigation: Strict script order and dependency-aware payload naming

## 7. Validation Gates

- Gate A: Prereq check returns all PASS
- Gate B: Authentication confirms valid Azure and PAC profiles
- Gate C: Spec, plan, and tasks consistency reviewed before script 20
- Gate D: Each build script reports zero failed count
- Gate E: Maker portal shows expected tables, forms, and views
- Gate F: Solution export and unpack completed for version control

## 8. Definition of Done

Done for this planning phase means:

- Spec, plan, and tasks are complete and aligned
- Scope is clear enough for payload authoring
- Build order and validation gates are explicit
- Team can proceed to implementation without ambiguity
