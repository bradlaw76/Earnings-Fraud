# Spec: SSA Earnings Integrity Case Review

## 1. Overview

- App type: SSA earnings fraud and unreported wages case management demo
- Platform area: Dynamics 365 Customer Service
- Target audience: Internal SSA employees
- Primary users: Internal SSA case analysts and supervisors
- Environment: https://healthconnectcenter.crm.dynamics.com/
- Demo data: Yes
- Solution type: Unmanaged
- **Solution unique name:** `EarningsIntegrity`
- **Publisher prefix:** `earnInt` (new)

## 2. Problem Statement

SSA must protect benefit integrity while ensuring eligible beneficiaries continue receiving entitled support. Earnings discrepancies are difficult to review because wage signals are fragmented across reports, records, payment history, communications, and prior case actions. This leads to delays, inconsistent decisions, duplicate work, and weak supervisory visibility.

The required solution is a structured Dynamics 365 case review process that standardizes intake, triage, evidence review, decisioning, and escalation for earnings discrepancy and potential fraud scenarios.

## 3. Business Outcome

- Reduce analyst handling time for earnings discrepancy reviews
- Increase consistency of review steps and outcomes
- Improve visibility for supervisors and audit readiness
- Route high-risk cases quickly for overpayment review or fraud escalation

## 4. In Scope

- Case-centric model-driven experience for earnings discrepancy handling
- Dataverse schema for beneficiary, earnings, discrepancy, evidence, and findings
- Structured lifecycle states from intake to resolution
- Supervisor review and approval path
- Supervisor-facing summary/report web resource for case visibility and next-step guidance
- Outcome options:
  - Close case
  - Request more information
  - Create overpayment review
  - Escalate as fraud referral package
- Initial queue and task support for analyst work management
- Demo data set supporting realistic case walkthroughs

## 5. Out of Scope (Phase 1)

- External production integrations with payroll or federal source systems
- Advanced AI copilot in this first slice
- Full enterprise reporting warehouse
- Production hardening and compliance sign-off package

## 6. Core Workflow Stages

1. Intake
2. Triage and risk prioritization
3. Evidence collection and validation
4. Earnings comparison and discrepancy analysis
5. Supervisor review
6. Determination and disposition
7. Case closure and audit capture

## 7. Data Requirements (Initial Table Catalog)

- Case
- Contact / Beneficiary
- Benefit Enrollment
- Fraud Referral
- Earnings Record
- Earnings Discrepancy
- Employer
- Evidence Item
- Beneficiary Statement
- Payment History
- Risk Signal
- Investigation Finding
- Overpayment Review
- Fraud Escalation / Referral Package
- Task / Activity Queue
- User / Team (platform standard use)

## 8. Functional Requirements

- FR-01: System can create a case from an incoming earnings discrepancy signal
- FR-02: System can assign priority and queue based on risk signals
- FR-03: Analysts can capture and manage evidence items linked to a case
- FR-04: Analysts can compare reported earnings and authoritative records in one case context
- FR-05: Analysts can record findings and recommended disposition
- FR-06: Supervisors can review and approve/reject proposed determination
- FR-07: System supports outcome branching to close, info request, overpayment review, or fraud escalation
- FR-08: System tracks activities and ownership by analyst/team
- FR-09: System maintains complete audit history of status and determination actions
- FR-10: Demo scenario can be completed end to end with seeded data
- FR-11: Supervisors can view a report web resource that summarizes case status, risk, and next recommended action

## 9. Non-Functional Requirements

- NFR-01: Navigation and forms support analyst-first workflow
- NFR-02: Lifecycle status transitions are explicit and validated
- NFR-03: Security follows least-privilege role model (analyst vs supervisor)
- NFR-04: Solution artifacts remain source-controllable and script-built
- NFR-05: App remains environment-safe via variable/config patterns

## 10. Success Criteria

A successful demo shows:

- An earnings discrepancy enters the system and becomes a structured case
- Case is prioritized and routed for analyst action
- Analyst performs evidence and wage comparison steps in guided sequence
- Supervisor reviews and confirms disposition
- Supervisor opens the report web resource and sees a clear case summary with current risk and recommended next action
- Correct outcome is executed (close, request info, overpayment, or escalate)
- Audit trail clearly explains what happened and why

## 11. Acceptance Criteria

- AC-01: A case can be created with required fields and initial status
- AC-02: Risk-driven queue placement is visible in at least one working view
- AC-03: At least three linked records (earnings, evidence, finding) can be added per case
- AC-04: Supervisor-only approval action is enforced
- AC-05: All four disposition outcomes can be demonstrated
- AC-06: Case history shows timeline of status changes and key decisions
- AC-07: Demo script can be replayed by another team member without manual metadata edits
