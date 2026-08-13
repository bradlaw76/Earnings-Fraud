# plan.md

## Build Approach

- Platform area: Dynamics 365 Customer Service
- Environment: <https://healthconnectcenter.crm.dynamics.com>
- Solution type: Unmanaged
- Anchor model: OOB Case (`incident`) as the primary lifecycle record

## Proposed Workstreams

1. Discovery review and approval
2. Dataverse schema expansion (review type, referral source, allegation type, risk/confidence, outcome fields)
3. Forms/views/pages/app experience design aligned to case anchor
4. Flow/copilot automation design with AI-assisted triage and human-review guardrails
5. Demo data planning
6. Solution export/unpack/git workflow
7. Validation and handoff
8. Choice visual semantics: apply accessible colors to each custom choice option and retain Fluent icon mappings for a future custom grid renderer.
9. Case lifecycle BPF: create, activate, solution-install, and expose the Earnings Fraud Case Review BPF for `incident`.
10. Presenter console: bundle the approved 40-minute talk track into one directly openable React HTML artifact with persistent checklist state and timing controls.

## Presenter Console Approach

1. Use the approved 40-minute Markdown talk track as the controlling content source.
2. Build a compact presenter-first interface with a sticky control header, section rail, completion progress, elapsed/remaining timer, and readable content panels.
3. Persist section/action completion, collapsed state, and timer state in `localStorage`; keep reset explicit so an accidental refresh does not erase progress.
4. Bundle React and all styles/scripts into one HTML file so the artifact works from the local file system with no server or network dependency.
5. Validate content coverage, browser errors, persistence, responsive layout, direct-file loading, and desktop/mobile screenshots.
6. Insert Specialized Agent and Frontline Support immediately after AI Insights so the narrative moves from case summarization to employee guidance before the formal finding and supervisor decision.
7. Allocate three minutes to Agent Support and reduce Agent Dashboard, Program Dashboard, and Workload/Hero Case Selection from three minutes to two minutes each; retain all evidence, supervisor, configuration, and closing time so the cumulative total remains 40 minutes.
8. Demonstrate linked-agent specialization, a bounded response to the `$24,000` question, authoritative-source routing, OIG escalation, and frontline call triage without presenting the agent as policy authority or a decision maker.
9. Explain the support architecture within the same three-minute segment: approved website content can ground responses; the Earnings Fraud Navigator handles subject-specific questions; NORA provides broad organizational help; General IT handles technical support; and the SSA Agent Fraud Support tab provides a curated navigation surface for frontline agents.
10. Replace the generic Step 02 Agent Dashboard narrative with the actual Earnings Integrity - Analyst Dashboard web resource. In two minutes, establish the analyst/refresh context, show six filters and eight KPIs, expand My Investigations, point to the five additional work sections, and explain that record links open the underlying Dataverse rows. Preserve hero-case opening for Step 04.
11. Keep Step 01 visually quiet and distinct from Step 02: start at the top of the Analyst Dashboard, preserve default filters and the initial My Investigations state, avoid opening any record, and move focus to the analyst banner only at the transition.
12. In Step 04, keep the presenter in Active/My Cases while explaining the workload view and case variation. Search for Hargrove after that explanation, then open the record as the final action immediately before the Step 05 case-summary walkthrough.
13. Expand Step 05 from four to five minutes. Introduce the generated Summary and its AI-content caveat first; orient the audience to the open case status, visible commands, case header, form tabs, and current Business Process Flow stage labels; then show intake classification and the timeline. Explain that a Case becomes read-only if or when it is resolved and can be reactivated by an authorized user. Reduce AI Insights from four to three minutes so the demonstration remains 40 minutes.
14. Keep the Hargrove narrative consistent as an open case with supervisor action pending. Use the later supervisor segment to stop immediately before the accountable human decision.

## Bulk Demo Data Expansion

1. Discover existing Contacts already linked to EIR Cases and reuse them in a deterministic rotation.
2. Correct the Patricia Nguyen EIR Case application choice to `581180001`.
3. Create an idempotent batch of 50 active Cases with complete review, risk, evidence-status, and disposition fields.
4. For Cases 26 through 50, create one linked earnings discrepancy, evidence item, and investigation finding per Case.
5. Run a no-write preview before creation, then validate exact batch counts, relationship coverage, duplicate names, required values, and `demo_datacustomerapplication = 581180001` after creation.

## Case Timeline Activity Remediation

1. Locate the two Tasks and one Appointment containing Obsidian, Bravo Talon, Ghost-6, extraction, or tactical content.
2. Verify all three activities regard the Patricia Nguyen EIR Case before updating them.
3. Rewrite the activity subjects, descriptions, and Appointment location for the earnings-integrity review scenario.
4. Keep the activities open and reschedule them in order for August 12, August 13, and August 14, 2026.
5. Preserve every activity record, owner, regarding party, and participant; do not create or delete activities or activity parties.
6. Verify the Case link, new values, open states, and removal of foreign terminology from the activity content.

## Recent Case Task Expansion

1. Query the 20 newest Cases scoped to `demo_datacustomerapplication = 581180001` and verify each has a Contact and review metadata.
2. Generate three deterministic Tasks per Case for intake/risk validation, evidence review, and follow-up/disposition preparation.
3. Tailor descriptions to unreported earnings, multiple-employer, employer-mismatch, or late-reporting review profiles.
4. Keep Tasks open, inherit normal or high priority from Case risk, and stagger due dates across the three work types.
5. Validate an exact total of 60 generated Tasks, three per target Case, correct regarding links, open state, and unique subjects.

## Bulk Case AI Display Data

1. Query the 50 deterministic bulk Cases and their linked discrepancies, evidence items, and findings.
2. Generate review-profile-specific summaries, evidence summaries, next actions, risk signals, evidence gaps, confidence rationale, and human-review notes.
3. Store structured raw JSON with `source = SEEDED_DEMO_ANALYSIS` and update the eight `earnfrau_*` Case fields idempotently.
4. Replace the web resource's fire-and-forget `no-cors` trigger call with an awaited request that only polls after an accepted response.
5. Deploy the updated web resource and validate Case 050 field rendering, exact populated-Case counts, and explicit trigger failure handling.

## Process Mining Event Instrumentation

1. Create an unmanaged, user-owned `earnint_processevent` table with a required Case lookup and structured columns for the complete event contract.
2. Add the table and Case relationship to `FederalEarningsFraud`; do not change existing table definitions or lifecycle records.
3. Select eight existing scoped Cases, balanced across available risk levels, for additive active-path events only.
4. Create four deterministic `EIR-PM-*` Cases, one for each risk level, with linked discrepancy, evidence, and finding context where needed.
5. Seed approximately 100-120 explicit event rows across 12 Cases. Include straight-through, evidence-loop, supervisor-return/revision, reassignment, escalation, and automated-workflow variants.
6. Use occurrence timestamps spanning realistic working intervals and explicit start/end times where duration matters. Do not rely on `createdon` as the business occurrence timestamp.
7. Resolve only the four new `EIR-PM-*` Cases after their final disposition events are created. Leave the eight existing Cases and all pre-existing records unchanged.
8. Implement `-WhatIf` preview, deterministic names, idempotent record lookup, retry/backoff, and post-write validation in one replayable script.
9. Update the Process Mining exporter to prefer explicit process events, retain evidence-derived events for non-cohort Cases, and prevent duplicate semantic events within the cohort.
10. Regenerate the four CSV outputs and validate activity coverage, variants, duration, waiting time, handoffs, reassignment, rework, bottlenecks, risk differences, and human-versus-automated work.
11. Patch the existing `earnint_processevent` Information main form in place, preserving the form ID and adding controls for all event-contract fields, Case, Owner, and read-only audit metadata.
12. Publish customizations and validate the live form has one control for each intended field and that existing Process Event records expose populated values.
13. Patch the existing Active Process Events, Inactive Process Events, and Process Event Associated View views in place with the approved primary field set, preserving their IDs, query types, and state filters.
14. Publish the table and validate all three views have the exact columns, no duplicates, and the correct `statecode` predicate.

### Process event table contract

- Primary name: deterministic event key (`CaseId|Sequence|ActivityName`)
- Case lookup: `earnint_caseid_processevent` to `incident`
- Event fields: `earnint_activityname`, `earnint_starttimestamp`, `earnint_endtimestamp`
- Resource fields: `earnint_resource`, `earnint_resourcetype`, `earnint_queueorteam`
- Transition fields: `earnint_previousstatus`, `earnint_newstatus`, `earnint_reassignmentindicator`, `earnint_reworkindicator`
- Context fields: `earnint_risklevel`, `earnint_discrepancyamount`, `earnint_evidencetype`, `earnint_evidencestatus`, `earnint_findingtype`, `earnint_recommendeddisposition`, `earnint_finaldisposition`, `earnint_supervisordecision`
- Lineage fields: `earnint_sourcesystem`, `earnint_sourcerecordid`, `earnint_issyntheticdemoevent`

### Process event main form

- Event Details: Event Key, Case, Activity Name, Risk Level, Discrepancy Amount.
- Timing and Transition: Start Timestamp, End Timestamp, Previous Status, New Status, Reassignment Indicator, Rework Indicator.
- Resource and Routing: Resource, Resource Type, Queue or Team, Owner.
- Evidence and Disposition: Evidence Type, Evidence Status, Finding Type, Recommended Disposition, Final Disposition, Supervisor Decision.
- Lineage and Audit: Source System, Source Record ID, Is Synthetic Demo Event, Created On/By, Modified On/By.

### Process event primary views

- Event identity: Event Key, Case, Activity Name.
- Timing: Start Timestamp, End Timestamp.
- Work routing: Resource, Resource Type, Queue or Team.
- Case context: Risk Level, Evidence Status, Final Disposition.
- Lineage: Is Synthetic Demo Event.
- Preserve the existing Active Process Events, Inactive Process Events, and Process Event Associated View IDs, query types, and `statecode` filters.

### Process Mining validation thresholds

- Exactly 12 cohort Cases: eight existing plus four isolated new Cases.
- At least four lifecycle variants and all four risk levels.
- At least four completed Cases with explicit close/disposition events.
- At least three supervisor handoffs, three rework loops, three reassignments, and two escalation paths.
- At least one automated-workflow event per cohort Case; no unsupported AI Agent classification.
- No missing CaseId, ActivityName, StartTimestamp, ResourceType, or synthetic-demo indicator on explicit process events.
- No duplicate deterministic event keys and no existing-record updates outside the four new Case resolution actions.

## Dynamics All-Case Process Map

1. Add a self-contained HTML web resource at `earnint_/report/earnings-fraud-process-map.html` and register it in the existing web-resource payload/build flow.
2. Query `incident` with `demo_datacustomerapplication eq 581180001`, selecting Case identity, state/status, risk, disposition, and modified timestamps; follow `@odata.nextLink` so the report is not capped to one page.
3. Query `earnint_processevent` for the qualifying Case IDs in bounded batches, selecting event identity, Case lookup, activity, timestamps, resource/routing, transition flags, disposition, source, and synthetic indicator.
4. Sort each Case event list by occurrence timestamp and deterministic Event Key, collapse only consecutive duplicate activity labels, and preserve loops when an activity recurs later in the path.
5. Derive path variants from the full normalized activity sequence and aggregate node/edge counts across Cases. Keep Cases without event rows in coverage KPIs but outside path-frequency denominators.
6. Render an accessible left-to-right process map using native HTML/CSS/SVG with stable dimensions, responsive horizontal scrolling, directional edges, transition counts, and a legend. Do not depend on an external CDN.
7. Add filter controls for risk, Case status, path variant, synthetic-event scope, and Case text search. Recompute the map, KPIs, variant table, and Case drill-down from the same filtered in-memory model.
8. Add a Case path table that shows timestamp, activity, resource, queue/team, transition, and final disposition for the selected Case.
9. Compute independent operational measures from the filtered event model: event coverage, completed-path cycle time, completion rate, straight-through rate, automated-event share, resource/queue handoffs, and bottleneck intervals from each event to its next timestamped event.
10. Rank bottleneck activities by median wait, require positive timestamp intervals, retain observation and affected-Case counts, and show maximum wait as an outlier signal. Do not treat observed wait as a configured SLA breach.
11. Add an idempotent app-navigation script that resolves the existing Earnings Integrity V2 Demo App and web resource, patches only the intended Process Map subarea into the current sitemap XML, publishes, and validates that pre-existing subareas remain.
12. Validate source syntax, exact choice-filter usage, no fallback sample data, paged API handling, deterministic path aggregation, metric calculations, responsive rendering, web-resource solution membership, and app-navigation preservation.

### Process Map completion rules

- A Case is in scope only when `demo_datacustomerapplication = 581180001`.
- A Case has a mapped path only when at least one related `earnint_processevent` row exists.
- A completed path requires a terminal activity matching a stored completion/disposition/closure event or a non-empty stored final disposition on the final event.
- Rework and reassignment counts come from `earnint_reworkindicator` and `earnint_reassignmentindicator`; escalation comes from stored activity, queue/team, or final-disposition text.
- Synthetic and non-synthetic rows remain distinguishable in all summary and drill-down views.
- Cycle time is the elapsed time between the first and last timestamped event of a completed path.
- Straight-through means a completed path with no stored rework or reassignment indicator.
- A handoff occurs when consecutive events change resource, resource type, or queue/team after normalization; blank-to-populated values are not counted as handoffs.
- Bottleneck wait is the positive elapsed time between a timestamped activity and the next timestamped activity on the same Case.

## Earnings Fraud Case Review BPF Design

- Process name: `Earnings Fraud Case Review`
- Base table: OOB Case (`incident`)
- Target solution: `FederalEarningsFraud`
- Target app: Earnings Integrity V2 Demo App
- Completion: manual BPF Finish after a human records case disposition and final determination; do not automatically resolve the Case.

### Stages and routing

1. Intake — review type, referral source, allegation type, and discrepancy type.
2. Risk Triage — risk rating, risk score, confidence level, human-review requirement, and supervisor-review requirement.
3. Evidence Validation — evidence status, identity validation, and beneficiary response status.
4. Earnings Analysis — fraud likelihood and confidence score, with related records reviewed from Case-form subgrids.
5. Conditional Supervisor Review — only when `earnint_supervisorreviewrequired = Yes`; requires `earnint_supervisorapproval`.
6. Disposition — requires `earnint_casedisposition` and `earnint_finaldetermination`.
7. Complete Review — no automation; analyst finishes the BPF.

Use one boolean predicate for the conditional path. Do not add compound AI/risk-score branch logic. AI output fields are informational and cannot be required steps, approval gates, or autonomous decision inputs.

### Installation approach

1. Create the BPF in the Power Apps process designer within `FederalEarningsFraud`, then activate it.
2. Enable it for Case records in the Earnings Integrity V2 Demo App and publish the app.
3. Run `100-install-earnings-fraud-case-bpf.ps1` to verify the activated category-4 workflow is based on `incident` and add it idempotently as solution component type 29.
4. Export/unpack the unmanaged solution so the BPF workflow and process-stage artifacts are versioned; then pack/import for portability validation.

The installer deliberately validates and solution-installs an existing designer-authored process. It does not create unsupported `workflow.clientdata` or process-stage serialization through the Web API.

## Risks to Resolve

- Confirm environment availability and permissions.
- Confirm entity scope and artifact count.
- Confirm whether demo data must be scripted or manual.
- Confirm report scope for critical tables and report placement decisions.
- Keep automation messaging non-adjudicative; avoid implying AI makes final determinations.
- Keep synthetic Process Mining events visibly separated from platform audit history and production telemetry.

## Validation Plan

- Verify artifacts in Maker portal.
- Verify solution export/unpack succeeds.
- Verify git changes are reviewable.
- Verify import into target environment succeeds.
- Verify new option-set values appear on forms and map correctly in web resources.
- Verify AI flow template fields and prompt outputs match payload schema.
- Verify all custom choice options have a non-empty semantic color and that the icon mapping report covers every option.
- Verify the active BPF workflow has category 4, primary entity `incident`, and solution component type 29 membership in `FederalEarningsFraud`.
- Test the Yes route through Supervisor Review and the No route directly to Disposition in the model-driven app.
- Verify BPF completion leaves the Case state unchanged.
- Verify Process Mining table/relationship solution membership and exact explicit-event counts.
- Verify the four new `EIR-PM-*` Cases resolve successfully while all eight selected existing Cases retain their original state, owner, and modified values.
- Verify CSV chronology, required columns, duplicate keys, activity vocabulary, cohort variants, and analysis-capability coverage.
- Verify all three Process Event system views expose the approved primary columns and retain their active/inactive predicates and query types.
