# spec.md

## Scenario Summary
SSA Earnings Integrity Case Review V2 is a SSA earnings integrity and fraud case review for Dynamics 365 Customer Service.

## Problem Statement
Detect and resolve unreported SSA earnings discrepancies with auditable case workflows

## Target Audience
Fraud analysts and supervisors

## Users
Case workers, investigators, and supervisors

## Required Data Entities
incident, contact, earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding

## Required Experience and Artifacts
Case form updates, discrepancy/evidence/finding forms, active views, supervisor summary web resource, executive mode report

## Success Criteria
End-to-end case intake through supervisor disposition with auditability, executive report mode, and repeatable scripted deployment

## Environment
https://healthconnectcenter.crm.dynamics.com

## Demo Data Requirement
Yes

## Solution Packaging Decision
Unmanaged

## Report Scope (Table-Driven)
- Tables selected for reports: earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- Report types selected: web resource, dashboard KPI, queue/view summary

## Acceptance Criteria
- The scenario is clear and approved.
- Required entities and artifacts are identified.
- Success measures are specific enough to validate.
- The environment and solution type are agreed before implementation.
- Report scope is mapped from created/planned tables before build execution.
