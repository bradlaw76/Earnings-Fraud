# Demo Walkthrough: SSA Earnings Integrity Case Review V2

## Purpose
This walkthrough is for the engineer/operator running the demo. It is derived from scenario files and should stay aligned to the implemented solution.

## Scenario Source
- Derived from: answers.md, spec.md, plan.md, and tasks.md in specs/ssa-earnings-integrity-case-review-v2/
- Scenario name: SSA Earnings Integrity Case Review V2
- Platform area: Dynamics 365 Customer Service

- Environment: https://healthconnectcenter.crm.dynamics.com

## Scenario Requirements Snapshot
- Business problem: Detect and resolve unreported SSA earnings discrepancies with auditable case workflows
- Success criteria: End-to-end case intake through supervisor disposition with auditability, executive report mode, and repeatable scripted deployment
- Required entities: incident, contact, earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- Required artifacts: Case form updates, discrepancy/evidence/finding forms, active views, supervisor summary web resource, executive mode report

### Explicit Entity Mapping
No explicit entity mapping block found.

### Validation Plan
- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.

## Engineer Runbook
### Pre-demo Setup
- Confirm environment access and app load at https://healthconnectcenter.crm.dynamics.com.
- Open **Earnings Integrity V2 Demo App** from the app switcher.
- Verify the following records exist (seeded 2026-07-30):
  - Cases: EIR-2025-0041 (Hargrove), EIR-2025-0052 (Castillo), EIR-2025-0067 (Whitfield), EIR-2025-0033 (Nguyen)
  - Earnings Discrepancies: 6 records linked across cases
  - Evidence Items: 9 records (W-2s, 1099s, wage statements, employer confirmations)
  - Investigation Findings: 3 records (Hargrove=Pending, Castillo=In Progress, Nguyen=Approved)
- Pre-open the **Active Cases - DATA** view as the landing screen.
- Pre-open the Hargrove case in a second browser tab as the hero record.
- If Nguyen case (EIR-2025-0033) is still Active, resolve it manually before the demo.
- To re-seed if data was deleted: `pwsh ./scripts/bootstrap/97-seed-demo-data.ps1`

### Implementation Walkthrough Checklist
- [x] Review answers.md with stakeholder
- [x] Finalize spec.md
- [x] Finalize plan.md
- [x] Approve build environment and permissions
- [x] Define Dataverse tables and columns for: incident, contact, earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- [x] Define required app artifacts for: Case form updates, discrepancy/evidence/finding forms, active views, supervisor summary web resource, executive mode report
- [x] Build report mapping matrix for tables: earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- [x] Confirm report types/placement: web resource, dashboard KPI, queue/view summary
- [x] Decide demo data approach: Yes — seeded 2026-07-30 via 97-seed-demo-data.ps1
- [x] Run pwsh ./scripts/bootstrap/00-prereq-check.ps1
- [x] Run pwsh ./scripts/bootstrap/10-auth-connect.ps1
- [x] Build and seed all demo data (4 cases, 4 contacts, 6 discrepancies, 9 evidence items, 3 findings)
- [ ] Manually resolve Nguyen case (EIR-2025-0033) in Maker portal
- [x] Update docs/build-log.md

### What To Show (Implementation-Oriented)
- Open **Active Cases - DATA** view to show the 4-case queue at different stages.
- Hero record: **EIR-2025-0041 — Hargrove, Robert** (In Progress, pending supervisor).
- Show **Active Earnings Discrepancies**: 2 Hargrove records, Q1+Q2 2025, $12,400 each, source=IRS Wage Feed W-2.
- Show **Active Evidence Items**: W-2 (verified), Beneficiary Statement (unverified), Employer Confirmation (verified).
- Show **Active Investigation Findings**: Hargrove finding with recommended disposition = Create Overpayment Review.
- Close with **EIR-2025-0033 — Nguyen** as the resolved/approved example.

### Risk Mitigation During Demo
- If live data is missing, pivot to nearest prepared record and narrate expected outcome.
- If automation is delayed, show artifact evidence and explain eventual state.
- If a screen/view is unavailable, use the closest form/view that still proves the scenario.

## Review Gate
- [x] Walkthrough reflects current spec/plan/tasks.
- [x] Mapping section matches implemented standard/custom model.
- [x] Success criteria can be demonstrated in under 15 minutes.
- [ ] Nguyen case manually resolved in portal (one remaining manual step).
