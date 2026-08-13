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

### 40-Minute Presenter Console

- Provide a self-contained React HTML page that can remain open beside Dynamics during the 40-minute SSA demonstration.
- Organize every timed segment under a clear section header with separate on-screen actions, speaker notes, callouts, and status language where applicable.
- Use the new **Earnings Integrity - Analyst Dashboard** web resource as Step 02. Cover its analyst identity/refresh context, six workload filters, eight KPIs, expandable investigation/discrepancy/evidence/finding/task/recent-activity sections, and links to underlying Dataverse records while retaining the two-minute allocation.
- Include a three-minute Specialized Agent and Frontline Support segment after AI Insights and before the investigation finding. Show linked-agent selection, the Federal Earnings Fraud Navigator's bounded source-oriented response, and the SSA Agent Fraud Support frontline triage page.
- Explain that the linked agents can use approved website content as a grounded support source. Distinguish the Federal Earnings Fraud Navigator as subject-specific, NORA as broad organizational/general-knowledge support, and General IT Services & Support as general technical support.
- Describe the SSA Agent Fraud Support tab as a purpose-built page that helps frontline agents navigate fraud-related calls, authoritative resources, reporting, office lookup, and escalation paths.
- Position Agent Support as point-of-work guidance and routing rather than policy authority, legal advice, adjudication, or an autonomous fraud decision. Preserve explicit human judgment and authoritative-source guardrails.
- Keep the full demonstration at 40 minutes by reducing Agent Dashboard, Program Dashboard, and Workload/Hero Case Selection to two minutes each.
- Allocate five minutes to the hero-record introduction so the presenter can explain the generated Summary, visible command bar, case header, form tabs, and Business Process Flow before reviewing intake details. Reduce AI Insights to three minutes to preserve the 40-minute total.
- Present Hargrove as an open hero case with supervisor action still pending. Explain conditionally that resolving a Case makes it read-only and that an authorized user can reactivate it when additional work is required.
- Add section-level and action-level checkboxes, persistent browser progress, elapsed/remaining time, section navigation, expand/collapse controls, and a deliberate reset action.
- Keep the configurable-scenario, fictional-data, seeded-AI, synthetic-process-event, and human-decision guardrails visible during the presentation.
- Support direct local opening without requiring a development server or network connection.

## Success Criteria
End-to-end suspicious wage intake through supervisor disposition with auditability, explainable triage scoring, evidence gap tracking, and repeatable scripted deployment

## Environment
https://healthconnectcenter.crm.dynamics.com

## Demo Data Requirement
Yes

### Bulk Demo Data Expansion

- Create 50 additional Case (`incident`) records using Contacts that already exist in Dataverse; do not create Contacts.
- Set `demo_datacustomerapplication` (`DATA-Customer-Application`) to `581180001` on every new Case.
- Create one earnings discrepancy, one evidence item, and one investigation finding for each of the final 25 Cases in the batch.
- Correct the existing Patricia Nguyen EIR Case to `demo_datacustomerapplication = 581180001`.
- Use deterministic names and idempotent lookups so rerunning the seed does not create duplicates.
- Validate Case-to-Contact and child-to-Case links, required Case fields, duplicate names, and the application choice after creation.

### Case Timeline Activity Remediation

- Replace unrelated tactical-scenario content on the two Tasks and one Appointment linked to the Patricia Nguyen EIR Case.
- Keep all three activities open and preserve their existing Case, owner, and participant relationships without adding or deleting any activity records or parties.
- Use earnings-integrity subjects and descriptions covering IRS 1099 evidence verification, beneficiary-statement reconciliation, and a beneficiary clarification interview.
- Reschedule the activities to August 12-14, 2026, in a logical review sequence.
- Validate that no foreign tactical terminology remains in the remediated activities.

### Recent Case Task Expansion

- Select the 20 most recently created Cases where `demo_datacustomerapplication = 581180001`.
- Create three open Tasks per Case: intake/risk validation, evidence review, and follow-up/disposition preparation.
- Tailor Task wording to the Case review type and link every Task to its Case through the regarding relationship.
- Use deterministic subjects and idempotent lookups so rerunning the seed does not create duplicates.
- Stagger due dates in a logical sequence and validate 60 Tasks, three per target Case, with no duplicate subjects or incorrect Case links.

### Bulk Case AI Display Data

- Populate all eight `earnfrau_*` AI display fields on the 50 bulk Cases using deterministic demo analysis derived from each Case review profile and linked child records.
- Mark raw JSON with a seeded-demo source so the stored content is not represented as a live AI Builder result.
- Preserve the human-review guardrail in every generated analysis and never frame the output as an automated fraud determination.
- Make the web-resource Run AI Analysis button await the HTTP trigger response and fail immediately when the trigger is unauthorized or unreachable.
- Do not poll Dataverse after a rejected trigger request; display a clear configuration/authentication status instead.

### Process Mining Event Instrumentation

- Add an append-only `earnint_processevent` demo table related to Case (`incident`) for explicit lifecycle events that current-state records and disabled audit history cannot substantiate.
- Capture activity name, occurrence start/end, resource, resource type, previous/new status, queue/team, evidence context, finding/disposition context, supervisor decision, reassignment/rework indicators, source system, source record, and a required synthetic-demo indicator.
- Reuse eight existing scoped Cases without changing their current records and create four isolated `EIR-PM-*` Cases for completed-path duration analysis.
- Seed a 12-Case representative cohort across Low, Medium, High, and Critical risk with straight-through, additional-evidence, supervisor-return/revision, reassignment, and escalation variants.
- Resolve only the four new `EIR-PM-*` Cases. Do not resolve, reopen, reassign, or otherwise modify any existing Case.
- Use existing Dataverse users or teams as human resources and explicit workflow labels for automated events. Do not claim an AI Agent event unless a real model invocation is evidenced.
- Use deterministic event keys and idempotent lookups so reruns do not duplicate Cases or events.
- Keep all seeded event rows visibly labeled as synthetic demo instrumentation and retain the original evidence-derived export alongside the explicit rows.
- Update the `earnint_processevent` Information main form so every business/event field, the required Case lookup, Owner, and read-only creation/modification audit fields are visible on existing and future records.
- Organize the form into Event Details, Timing and Transition, Resource and Routing, Evidence and Disposition, and Lineage and Audit sections so analysts can inspect a complete event without opening Maker metadata.
- Update the Active Process Events, Inactive Process Events, and Process Event Associated View system views so analysts can scan the primary Process Mining fields without opening each record.
- Include Event Key, Case, Activity Name, Start/End Timestamp, Resource, Resource Type, Queue or Team, Risk Level, Evidence Status, Final Disposition, and the Synthetic Demo indicator while preserving each view's state filter.

### Dynamics All-Case Process Map

- Add a read-only Dynamics web resource named **Earnings Fraud Process Map** that presents all qualifying Cases in one visual process map rather than requiring analysts to inspect Process Event rows one Case at a time.
- Scope qualifying Cases by the global choice shown in Maker: `demo_datacustomerapplication` (`DATA-Customer-Application`) equals `581180001` (`EarningsFraud`). Do not use title prefixes as the report filter.
- Read lifecycle steps from `earnint_processevent` and order each Case path by `earnint_starttimestamp`, using the deterministic Event Key only as a stable tie-breaker.
- Aggregate identical transitions into shared directed edges and show the number and percentage of filtered Cases that followed each transition.
- Provide risk, status, lifecycle-variant, synthetic-event, and Case search filters plus a Case-level path drill-down without mutating Case or Process Event records.
- Show cohort KPIs for qualifying Cases, Cases with Process Events, completed paths, path variants, rework, reassignment, and escalation.
- Add independent operational metrics for median completed-path cycle time, completion rate, straight-through rate, automated-event share, human/queue handoffs, and event coverage so the report distinguishes speed and friction from simple volume.
- Rank bottlenecks by the median elapsed time from each activity to its next stored event, showing affected Case count, observation count, median wait, and maximum wait. Label these as observed Process Event intervals rather than SLA violations.
- Treat a path as complete only when its stored events include a terminal completion activity or final disposition; do not infer completion merely from an active BPF or solution membership.
- Display clear empty, partial-data, loading, and API-error states. Never substitute sample rows when live Dataverse data cannot be read.
- Surface the report from the Earnings Integrity V2 Demo App while preserving all existing app navigation entries.

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
- Process Mining enrichment is additive. Existing Case, activity, evidence, finding, queue, audit, and BPF records must not be altered.
- Synthetic process events are demonstration instrumentation, not reconstructed audit history, and must remain distinguishable through `earnint_issyntheticdemoevent` and `earnint_sourcesystem`.
- The all-Case Process Map is an operational visualization of stored Process Events. It must not represent synthetic rows as production audit history or imply that every filtered Case has a complete event history.

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
- The Process Mining cohort contains 12 Cases across all four risk levels and at least four materially different lifecycle variants.
- Four isolated `EIR-PM-*` Cases have explicit creation-to-disposition histories; existing Cases remain unchanged.
- Reassignment, analyst-to-supervisor handoff, return/revision, additional-evidence, escalation, and automated-workflow events are represented by explicit, timestamped process-event rows.
- The exporter produces chronologically ordered CSV rows with no missing CaseId, ActivityName, or StartTimestamp and labels all synthetic or inferred evidence in the quality report.
- The Active, Inactive, and Associated Process Event views retain their existing IDs, query types, and filters and expose the approved primary fields exactly once.
- The Earnings Fraud Process Map loads inside Dynamics, filters Cases only by `DATA-Customer-Application = EarningsFraud (581180001)`, and reconciles its Case and event totals to Dataverse.
- The map displays aggregate transitions and lets an analyst select a Case to inspect its timestamp-ordered path from first stored event through completion when a terminal event exists.
- Cases with no Process Events remain visible in coverage metrics and are not given inferred or fabricated paths.
- Operational metrics and bottleneck rankings recalculate with report filters, exclude missing or negative timestamp intervals, and identify when there is insufficient event history for a defensible measure.
