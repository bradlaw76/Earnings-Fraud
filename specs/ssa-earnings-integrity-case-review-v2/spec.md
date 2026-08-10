# spec.md

## Scenario Summary
SSA Earnings Integrity Case Review V2 is a Dynamics 365 Customer Service demo for SSA earnings integrity where suspicious wage reports are treated as intake signals into a structured, human-reviewed case lifecycle.

## Problem Statement
Detect, triage, and resolve suspicious wage and earnings discrepancy scenarios with auditable workflows while preserving human analyst and supervisor decision authority.

## Target Audience
Fraud analysts and supervisors

## Users
Case workers, investigators, and supervisors

## Required Data Entities
incident, contact, earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding

## Required Experience and Artifacts
Case form updates, discrepancy/evidence/finding forms, active views, supervisor summary web resource, executive mode report, AI-assisted case summary and triage outputs with human-review guardrails, and the Earnings Fraud Case Review Business Process Flow (BPF)

## Success Criteria
End-to-end suspicious wage intake through supervisor disposition with auditability, explainable triage scoring, evidence gap tracking, and repeatable scripted deployment

## Environment
https://healthconnectcenter.crm.dynamics.com

## Demo Data Requirement
Yes

## Solution Packaging Decision
Unmanaged

## Report Scope (Table-Driven)
- Tables selected for reports: earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- Report types selected: web resource, dashboard KPI, queue/view summary

## Case Anchor Decision
- Anchor table: `incident` (OOB Case)
- Contact remains the beneficiary profile record.
- Custom tables remain supporting entities linked to case.

## Guardrails
- AI outputs are triage assistance only and must not be framed as automated fraud adjudication.
- Final determination and escalation actions require analyst and supervisor review.
- Demo data only; no real SSA data or real SSNs.
- The BPF does not resolve or close a Case. An analyst manually finishes the process after recording the human decision.

## Earnings Fraud Case Review BPF

- Base table: OOB Case (`incident`)
- Solution: `FederalEarningsFraud` (unmanaged)
- Process owner: fraud analyst; supervisor participation is required only on the conditional high-risk path.
- Branch predicate: `earnint_supervisorreviewrequired = Yes`. The Yes route includes Supervisor Review; the No route continues directly to Disposition.

- **Intake** — required: `earnint_reviewtype`, `earnint_referralsource`, `earnint_allegationtype`, and `earnint_discrepancytype`. Captures the intake signal and classification.
- **Risk Triage** — required: `earnint_riskrating`, `earnint_fraudriskscore`, `earnint_confidencelevel`, `earnint_humanreviewrequired`, and `earnint_supervisorreviewrequired`. Risk scores inform the analyst; they do not determine the outcome.
- **Evidence Validation** — required: `earnint_evidencestatus`, `earnint_identityvalidationstatus`, and `earnint_beneficiaryresponsestatus`. The Case form subgrids remain the authoritative place to review related evidence.
- **Earnings Analysis** — required: `earnint_fraudlikelihood` and `earnint_confidencescore`. Review related discrepancy, evidence, and finding records before continuing.
- **Supervisor Review (conditional)** — required: `earnint_supervisorapproval`. Required only when Supervisor Review Required is Yes.
- **Disposition** — required: `earnint_casedisposition` and `earnint_finaldetermination`. Both fields are required before the demo decision is complete.
- **Complete Review** — no required inputs. Analyst manually selects Finish; Case state is unchanged.

AI summary fields (`earnint_aisummary`, `earnint_supportingevidencesummary`, `earnint_nextbestaction`, and `earnint_airawjson`) are informational only and must never be required BPF steps or branch predicates.

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
- Report scope is mapped from created/planned tables before build execution.
- The active BPF is based on `incident`, is included in `FederalEarningsFraud`, and is available in the Earnings Integrity V2 Demo App.
- A Yes-path case requires Supervisor Review, while a No-path case bypasses it.
- Completing the BPF requires documented human disposition and determination but does not automatically resolve the Case.
