<!-- markdownlint-disable MD024 MD028 MD060 -->

# SSA Earnings Integrity Case Review

## 40-Minute Demonstration Talk Track

**Dynamics 365 Customer Service + Dataverse**

**Audience:** SSA program, operations, fraud/integrity, technology, and leadership stakeholders

**Demo scenario:** Earnings Integrity Review using fictional demonstration data

**Hero case:** EIR-2025-0041 - Robert Hargrove - Unreported SSDI Wages Q1-Q2 2025
**Target duration:** 40 minutes, plus questions

## Purpose and Positioning

This demonstration shows one possible configuration of Dynamics 365 and Dataverse for an SSA-style earnings integrity review. It is not intended to prescribe SSA policy, replace SSA's current operating model, or imply that production requirements have already been finalized.

The screens, stages, labels, thresholds, queues, and outcomes reflect design choices made for this demonstration. They can be changed through configuration and governed extensions after discovery with SSA subject-matter experts. The goal is to make the platform capabilities tangible by walking through a complete fictional scenario from workload visibility through human disposition.

### Positioning statement to say near the beginning

> "What I am showing today is not a proposed final SSA process. It is a working example I configured to make the possibilities concrete. The terminology, stages, routing rules, thresholds, forms, and dashboards can all be adapted to SSA's actual policies and operating model. Please focus on the pattern: structured work, connected evidence, guided review, human decisions, and measurable outcomes."

### Demonstration guardrails

- Use fictional demonstration records only. Do not imply that the environment contains real SSA data.
- Describe suspicious wage information as an intake signal, not a fraud determination.
- Describe AI content as triage and summarization assistance. Analysts and supervisors retain decision authority.
- The bulk-case AI content is seeded demonstration analysis; it is labeled `SEEDED_DEMO_ANALYSIS`, and no model was called to generate those seeded values.
- The Process Mining cohort is synthetic demonstration instrumentation, not reconstructed production audit history.
- The Business Process Flow is a visible multi-stage demonstration baseline. Do not claim the final seven-stage branch design has completed production smoke testing.
- Use "demonstrated," "configured for this scenario," "platform-supported," and "could be configured." Avoid "SSA would" or "fully production-ready."

## Timing at a Glance

| Segment | Time | Running Time |
|---|---:|---:|
| Opening and positioning | 2 min | 2 min |
| Agent dashboard | 2 min | 4 min |
| Program dashboard | 2 min | 6 min |
| Workload and case selection | 2 min | 8 min |
| Hero case summary, navigation, and guided process | 5 min | 13 min |
| Risk and confidence review | 3 min | 16 min |
| Evidence and workflow | 4 min | 20 min |
| Analyst case workbench | 3 min | 23 min |
| AI insights and human guardrails | 3 min | 26 min |
| Specialized agent and frontline support | 3 min | 29 min |
| Finding, supervisor review, and disposition | 4 min | 33 min |
| Tasks, scale, and process improvement | 3 min | 36 min |
| Configuration and production path | 2 min | 38 min |
| Closing | 2 min | 40 min |

## Demo Data Reference

| Case | Beneficiary | Scenario | Demonstration state |
|---|---|---|---|
| EIR-2025-0041 | Robert Hargrove | $24,800 in unreported wages across Q1-Q2 2025 | Open hero case; high risk; pending human supervisor action |
| EIR-2025-0052 | Maria Castillo | $18,400 across two employers | Researching; evidence/finding work in progress |
| EIR-2025-0067 | James Whitfield | $8,750 employer mismatch with prior overpayment context | On hold; awaiting employer response |
| EIR-2025-0033 | Patricia Nguyen | $11,600 IRS 1099 versus beneficiary statement | Approved demonstration outcome; use only if the case status is correct |
| EIR-2026-BULK-001 to 050 | Existing demo contacts | Four repeatable earnings-review profiles | Scale, dashboards, tasks, and AI display-data demonstrations |
| EIR-PM-* | Synthetic cohort | Four risk levels and multiple lifecycle variants | Process Mining demonstration only |

## Pre-Demo Setup

- Open **Earnings Integrity V2 Demo App**.
- Confirm **Earnings Integrity - Analyst Dashboard** and the **Earnings Integrity** program dashboard load.
- Pre-open EIR-2025-0041 in a second browser tab.
- Confirm the active form is **Enhanced full case form - Earnings Fraud**.
- Verify the Hargrove case tabs load: Summary, Risk & Confidence, Evidence & Workflow, Workbench, AI Insights, and Review.
- Confirm the embedded Analyst Case Workbench, Fraud AI Insights, and Supervisor Case Brief render.
- Confirm the SSA Agent Support pane opens, the three linked agents appear, and the SSA Agent Fraud Support page loads.
- Keep EIR-2025-0033 as an optional comparison only; do not call it resolved unless its live status shows Resolved.
- Have the Process Events view available as an optional drill-down.
- Do not click **Run AI Analysis** unless the HTTP trigger and browser authentication/CORS configuration have been verified immediately before the demo.

## Opening and Positioning - 2 Minutes

### On screen

- Begin at the top of **Earnings Integrity - Analyst Dashboard**, with the analyst banner, filters, and KPI row visible.
- Leave the filters at their default values and keep the initial **My Investigations** section in its prepared state.
- Do not open Hargrove or any other record while delivering the positioning statement.
- At the transition, move visual focus to the analyst identity banner without clicking; Step 2 begins the dashboard tour.

### What to say

> "Today I will walk through an earnings integrity case review experience that I built in Dynamics 365 Customer Service and Dataverse. The scenario starts with a suspicious wage signal, moves through risk triage and evidence review, and ends with an analyst recommendation and a human supervisor decision."

> "This is intentionally a concrete demonstration, not a claim that I have modeled SSA's final process. I selected the stages, labels, sample thresholds, dashboards, and routing concepts to show what the platform can do. In a production effort, those choices would be validated and configured with SSA program, policy, operations, security, records, and technology stakeholders."

> "The main pattern to watch is how one case connects the workload, beneficiary context, discrepancy records, evidence, tasks, findings, AI-assisted insights, supervisor review, and operational reporting without moving the user across disconnected tools."

### Transition

> "I will begin with the analyst's workload, then zoom out to program oversight, and then follow one case from beginning to end."

## 1. Earnings Integrity - Analyst Dashboard - 2 Minutes

### Purpose

Show the analyst's purpose-built workload command center and establish that the application connects cases, discrepancies, evidence, findings, and tasks rather than presenting a single flat list.

### On screen

- Open **Earnings Integrity - Analyst Dashboard**.
- Point to the signed-in analyst identity, role, operational context, refresh control, and last-updated time.
- Show the six workload filters: Search, Case Age, Risk Level, Review Phase, Evidence Status, and Review Type.
- Scan the eight KPIs: Active Investigations, High/Critical Risk, Earnings Discrepancies, Evidence to Review, Findings Recorded, Pending Supervisor, Open Tasks, and Open Exposure.
- Expand **My Investigations** and point to Case, Beneficiary, Review Type, Risk, Phase, Exposure, and Modified. Identify the Hargrove link but leave it unopened for Step 4.
- Point briefly to the additional sections for Earnings Discrepancies, Evidence Requiring Review, Investigation Findings, My Open Tasks, and Recent Case Activity.

### What to say

> "This new web resource is the analyst's operational command center. It answers three questions immediately: what work is active, what needs attention first, and which related evidence, findings, approvals, or tasks still require action."

> "The filters let the analyst narrow the workload by age, risk, review phase, evidence state, or review type. The KPI row summarizes the same operational records across investigations, discrepancies, evidence, findings, supervisor work, tasks, and estimated exposure. These dimensions are configured for the demonstration and could be aligned to SSA's approved workload model."

> "Below the KPIs, the expandable sections organize the work by what the analyst needs to do, not only by table. My Investigations shows risk, phase, exposure, and recency. The other sections surface discrepancies, evidence requiring review, recorded findings, open tasks, and recent activity. When embedded in Dynamics, the linked rows open the underlying Dataverse records, so this dashboard is a focused entry point rather than a separate system of record."

### Key callout

> "The dashboard brings the connected case workload to the analyst and keeps every summary traceable to the underlying Dataverse record."

### Status language

Demonstrated for live Dataverse workload assembly, filtering, KPI summaries, connected work sections, and record navigation. The directly opened file uses fictional preview data; specialized SSA routing, access scope, workload balancing, notifications, and service-level policies require configuration and validation.

## 2. Earnings Integrity Program Dashboard - 2 Minutes

### Purpose

Move from individual workload to program-level oversight.

### On screen

- Open **Earnings Integrity** under Dashboards.
- Point to Open Cases, Pending Approval, High/Critical Risk, Total Open Exposure, Resolved Cases, and Total Cases.
- Show **Cases by Risk Rating** and **Cases by Disposition**.
- Scan **All Cases - Detail**, including risk, status, exposure, approval, and type.

### What to say

> "This is the program view of the same operational data. Leaders can see open workload, pending approvals, risk concentration, estimated exposure, and disposition patterns without asking analysts to prepare a separate status report."

> "The displayed numbers reflect the demonstration data currently loaded in this environment. They are not SSA production measures and they are not intended as proposed performance targets. The important point is that the metrics trace back to the same case records analysts are working."

> "A program dashboard could be configured around the measures SSA actually governs: timeliness, aging, workload by office, evidence wait time, rework, supervisory returns, disposition mix, or any approved quality measure."

### Key callout

> "The dashboard is not a parallel reporting system. It is a management view over the operational records."

### Transition

> "Now I will move from the portfolio into the specific case that drives today's story."

## 3. Workload and Hero Case Selection - 2 Minutes

### Purpose

Explain intake, scale, and scenario variety before opening EIR-2025-0041.

### On screen

- Open **Cases** and remain in the **Active/My Cases** view while explaining how it organizes the analyst's workload.
- Point out several EIR-2026 bulk cases to show volume and variation. Do not open a record yet.
- After explaining the view, search for **EIR-2025-0041**.
- Open **Hargrove, Robert - Unreported SSDI Wages Q1-Q2 2025** as the final action in this section, arriving on **Summary** for the next step.

### What to say

> "Each row is an out-of-box Dynamics Case extended with earnings-integrity fields. I chose Case as the anchor because it already provides ownership, priority, status, activities, timelines, queues, command actions, and security behavior. The domain-specific information is added around that platform foundation."

> "These additional records demonstrate that the model is repeatable across more than one story. Some cases represent unreported earnings, some multiple-employer reviews, some employer mismatches, and some late reporting. Those are demonstration categories, and SSA could replace or expand them."

> "Our hero record is EIR-2025-0041. A wage-match signal indicates $24,800 from Apex Logistics across two quarters while the beneficiary-reported amount is zero. That signal starts a review; it does not make a fraud, eligibility, or overpayment decision."

### Key callout

> "The suspicious wage signal opens structured work. It does not predetermine the outcome."

### Transition

> "With the workload context established, I will open Hargrove and continue on the case Summary."

## 4. Hero Case Summary, Navigation, and Guided Process - 5 Minutes

### Purpose

Orient the audience to the open hero record, its navigation, and the guided lifecycle before examining the review details.

### On screen

- Begin with the generated **Summary** at the top. Point to the AI-content caution and the Copy, Translate, feedback, and refresh controls.
- Show that Hargrove is open, then point to the case header: title, case number, current status, **High** priority, and owner.
- Point to the visible active-case commands, including Refresh, assignment or routing actions, Add to Queue, the overflow menu, and Share as available.
- Explain that if or when the case is resolved, it becomes read-only; an authorized user can reactivate it if more work is required.
- Orient the audience to the form navigation: Intake, Risk & Confidence, Evidence & Workflow, Workbench, AI Insights, Review, Attachments, and Related.
- Point to the visible **Earnings Fraud Case Review** Business Process Flow stages: Intake Triage, Case Details, Risk Decision, Analysis, and Case Closure.
- On **Intake**, show Intake Classification and use the Timeline to establish the operational record beneath the summary.

### What to say

> "The first thing the user sees is a generated Summary of the case. It gives a concise orientation: Robert Hargrove reported zero earnings for the review period, wage and employer information showed a $24,800 discrepancy, and the available statements and confirmations require structured review. The caution at the top matters: generated content can be incorrect, so staff verify this summary against the underlying record and evidence. Copy, Translate, feedback, and refresh controls make the summary useful without turning it into the system of record."

> "The case header shows that Hargrove is open and available for active review. We can see the title, case number, current status, High priority, and owner. The command bar changes with record state and user permissions; an open case can expose actions for assignment, routing, queues, sharing, and other authorized work. A production design would determine which roles can use each action and what controls apply."

> "If or when the case is resolved, Dynamics makes the record read-only to protect the completed state. If additional work is later required, an authorized user can reactivate the case. That is a lifecycle capability, not the current state of Hargrove in this walkthrough."

> "The form tabs organize the work without moving the user into disconnected applications. Intake establishes the case; Risk and Confidence supports prioritization; Evidence and Workflow connects supporting records and human checkpoints; Workbench assembles the analyst view; AI Insights demonstrates assistive analysis; and Review presents the decision package. Attachments and Related preserve access to supporting platform records."

> "The Business Process Flow provides a stage-oriented guide across Intake Triage, Case Details, Risk Decision, Analysis, and Case Closure. The visible labels are a configured demonstration baseline, not a claim that this is SSA's finalized process. The active-stage indicator and timing show how the platform can orient the worker, while production branch logic and completion behavior would require SSA validation."

> "Below that navigation, Intake Classification explains why the review exists, and the Timeline preserves activities and notes. The generated Summary accelerates orientation, but the case fields, related evidence, findings, activities, and recorded human decision remain the authoritative operational record."

### Key callout

> "The summary accelerates orientation, the record preserves the facts, and the process guide makes the work repeatable."

## 5. Risk and Confidence - 3 Minutes

### Purpose

Show explainable prioritization while drawing a hard line between risk signals and adjudication.

### On screen

- Open **Risk & Confidence**.
- Point to Risk Level, Fraud Risk Score, Fraud Likelihood, and Risk Explanation.
- Point to Confidence Level and Confidence Score.
- Point to Potential Overpayment Estimate, Largest Monthly Variance, and Number of Impacted Months.

### What to say

> "This tab separates risk from confidence. Risk represents why the case may deserve attention. Confidence represents how strongly the available data supports the current assessment. Those concepts should not be collapsed into a single opaque score."

> "For Hargrove, the demonstration risk explanation references two quarters of zero reported earnings, verified wage data, employer confirmation, and a sustained pattern. The financial fields provide operational context for prioritization."

> "These scores and thresholds are examples I selected for the demo. SSA could use different factors, remove a score entirely, or require additional review based on policy. None of these values independently establishes fraud, eligibility, debt, or final disposition."

### Key callout

> "The score helps a person decide what to review first; it does not decide the case."

### Status language

Demonstrated for structured risk/confidence display and explanation. Production scoring would require approved models or rules, validated data, monitoring, bias and performance review, explainability, auditability, and governance.

## 6. Evidence and Workflow - 4 Minutes

### Purpose

Show how conflicting information is organized and how oversight requirements remain visible.

### On screen

- Open **Evidence & Workflow**.
- Show Evidence Status, Identity Validation Status, and Beneficiary Response Status.
- Show Queue Assignment, Supervisor Review Required, Human Review Required, Supervisor Approval, Recommended Outcome, and Final Determination.
- In related records, show the two Hargrove Earnings Discrepancies.
- Show the three Evidence Items: W-2/Tax Wage Document, Beneficiary Statement, and Employer Wage Confirmation.
- Show the Investigation Finding pending supervisor action.

### What to say

> "This is where the review becomes traceable. The top-left fields summarize what is complete and what remains unresolved. The workflow fields make the human checkpoints explicit. Below, the related records preserve the supporting detail."

> "The two discrepancy records each show $12,400 of authoritative earnings and zero reported earnings, creating the $24,800 total gap. Keeping one record per period and employer means the data can support filtering, aggregation, and later analysis."

> "The evidence package contains information that agrees and information that conflicts. The wage record and employer confirmation support the discrepancy. The beneficiary statement remains contradictory and under review. That conflict is visible; it is not hidden inside a single narrative field."

> "The supervisor and human-review flags reflect my chosen open demo workflow. SSA could define different approval paths by risk, dollar amount, evidence state, program, or other approved criteria."

### Key callout

> "The decision is explainable because the discrepancy, evidence, finding, and human checkpoint remain connected to the same case."

## 7. Analyst Case Workbench - 3 Minutes

### Purpose

Show a purpose-built view that assembles the case without replacing the underlying records.

### On screen

- Open **Workbench**.
- Point to the case header, status, type, days open, and total exposure.
- Show the Earnings Discrepancy Comparison.
- Show Evidence Collection and verification details.
- Walk the Case Progress Checklist through supervisor approval.

### What to say

> "The workbench is an embedded web resource I built for this scenario. It reads the related Dataverse records and presents the analyst's most important information in one compact view. The underlying case, discrepancy, evidence, and finding records remain the system of record."

> "This is one example of how the user experience can be tailored without replacing the model-driven application. A different role could receive a different summary, and SSA could change the checklist, wording, order, or level of detail."

> "Notice that the final checklist item is still supervisor approval. The interface can summarize progress, but it does not erase the human control point."

### Key callout

> "The workbench reduces navigation while preserving structured, auditable records underneath."

## 8. AI Insights with Human Guardrails - 3 Minutes

### Purpose

Demonstrate assistive AI patterns with transparent limits.

### On screen

- Open **AI Insights**.
- On the left, show AI Case Summary, Supporting Evidence Summary, Next Best Action, Risk Signal Breakdown, AI Evidence Gaps, AI Confidence Rationale, Human Review Note, and Raw JSON.
- On the right, show the embedded **Fraud AI Insights** display and its status label.
- Point to **Refresh Display**.
- Do not select **Run AI Analysis** unless the trigger was prevalidated.

### What to say

> "This tab demonstrates where AI-assisted summarization and triage can fit. The output is separated into a case summary, supporting evidence, next action, risk signals, evidence gaps, confidence rationale, and a human-review note. That structure makes the assistance easier to inspect than a single unqualified paragraph."

> "For the original Hargrove case, the displayed analysis is based on the prepared demo fields. For the 50 bulk cases, the content is explicitly seeded demonstration analysis and is labeled so it cannot be mistaken for a live model result. The build records `ai_model_called = false` for those seeded values."

> "The most important text on this screen is the human-review note. AI output is triage support only. It does not determine fraud, eligibility, overpayment, escalation, or final disposition."

> "A production capability would require an approved model and prompt, security and privacy review, grounding and source controls, quality evaluation, monitoring, audit history, exception handling, and a clear human approval policy."

### Key callout

> "AI can organize the evidence and suggest the next question; accountable staff make the decision."

### Optional comparison

Open a bulk case only if useful and point to the seeded-demo source label. Use it to explain the distinction between designing the user experience and connecting a production model.

## 9. Specialized Agent and Frontline Support - 3 Minutes

### Purpose

Show how role-specific guidance and authoritative routing can be available at the point of work without turning an agent into a policy authority or decision maker.

### On screen

- Open the **SSA Agent Support** side pane and show **Linked Agents (3)**.
- Explain that the agents can use approved content available from the website to ground assistance and help employees find relevant information.
- Identify the roles: **Federal Earnings Fraud Navigator** for subject-specific earnings-fraud support, **NORA - National Outreach Response Assistant** for broad organizational and general-knowledge support, and **General IT Services & Support Agent** for general technical help.
- Select **Federal Earnings Fraud Navigator** and show the response to the question about a `$24,000` unreported-earnings amount.
- Point out that the response does not invent a special threshold; it directs the user to relevant 20 CFR Parts 404, 416, and 498, current SSA guidance, and OIG or criminal-matter escalation where appropriate.
- Switch to the **SSA Agent Fraud Support** tab and explain that it is a purpose-built page for frontline agents to navigate fraud-related calls. Show **SSA fraud guidance**, **Report fraud to OIG**, **Find an office**, the official-source panel, and the call-triage steps.

### What to say

> "Before the analyst formalizes a finding, I want to show a second assistance pattern: support available to employees at the point of work. These agents can use approved content available from the website to ground their assistance, helping an employee move from a question to relevant information without searching across disconnected pages."

> "The linked agents have intentionally different roles. The Federal Earnings Fraud Navigator is specific to this subject and supports detailed earnings-fraud questions. NORA is the broader assistant, designed for overall organizational guidance and general understanding across topics. The General IT Services and Support Agent handles general technical-support needs. The employee can choose the right level of expertise instead of expecting one assistant to answer everything."

> "Here the earnings fraud navigator was asked whether a `$24,000` amount creates a special process. The useful behavior is restraint: it does not manufacture a threshold. It explains that the amount may affect the investigation but that the governing procedure must come from the relevant regulations and current SSA guidance. It also distinguishes administrative review from matters that may require OIG or criminal referral."

> "The response is not itself policy or legal authority. Staff would follow current approved SSA policy, procedures, and authoritative sources. The agent's role is to help the employee find the right source, frame the next question, and route the issue appropriately."

> "The second tab, SSA Agent Fraud Support, is not another general chat experience. It is a purpose-built page that helps a frontline agent navigate a fraud-related call. It starts with the caller's real need, then provides direct paths to SSA fraud guidance, OIG reporting, office lookup, official source content, and step-by-step call triage. The conversational agents help answer and route questions; this page gives the employee a consistent navigation path through the task."

### Key callout

> "Grounded agents help employees understand and find information; the purpose-built support page helps them navigate the task. Neither creates policy nor decides the case."

### Status language

Demonstrated as a website-grounded, point-of-work guidance and navigation pattern. Production use would require approved website and knowledge sources, content ownership, freshness controls, access rules, evaluation, auditability, and clearly defined escalation boundaries.

### Transition

> "With the evidence organized and the employee connected to the appropriate guidance, I will return to the structured finding and the supervisor's decision surface."

## 10. Investigation Finding and Supervisor Review - 4 Minutes

### Purpose

Complete the human decision path and show the supervisor's concise decision surface.

### On screen

- Close Agent Support, return to Hargrove, open **Evidence & Workflow**, and select the Investigation Finding.
- Show Finding Type, Severity, Recommended Disposition, Supervisor Approval Status, Analyst Name, recommendation, and supporting detail.
- Return to the case and open **Review**.
- Show the Supervisor Case Brief: discrepancy records, evidence package, analyst recommendation, and pending approval.
- Point to the configured supervisor decision options without selecting one.

### What to say

> "The analyst finding is the formal product of the investigation. It records what the analyst concluded, the severity, the recommended disposition, who performed the analysis, and whether a supervisor has approved it. Controlled choices support consistent reporting, while the narrative captures case-specific reasoning."

> "The Review tab gives the supervisor a concise case brief. It brings together the exposure, discrepancy records, evidence verification, and analyst recommendation. The configured options - approve an overpayment review, return for more information, escalate, or close with no action - are demonstration choices, not a statement of SSA's required outcome taxonomy."

> "The supervisor remains responsible for the decision. In a production design, each action would be mapped to SSA authority, security role, segregation-of-duties rules, required rationale, notifications, and downstream integrations."

> "For this walkthrough, Hargrove remains open and pending. That is deliberate: it lets us see the complete package immediately before the accountable human decision rather than pretending the system decided for the supervisor."

### Key callout

> "The system prepares the decision package; the supervisor owns the decision."

## 11. Tasks, Scale, and Process Improvement - 3 Minutes

### Purpose

Show that the solution supports day-to-day follow-up and can produce process-level improvement data.

### On screen

- Return briefly to **Earnings Integrity - Analyst Dashboard** and point to Open Tasks.
- Explain that the 20 newest scoped cases have three open tasks each: Intake and Risk, Evidence Review, and Follow-Up and Disposition.
- Optionally open **Process Events** and show Event Key, Case, Activity, timestamps, resource, queue/team, risk, evidence status, final disposition, and Synthetic Demo indicator.

### What to say

> "A case review is not only a form. It includes follow-up work. The demonstration created 60 open tasks across 20 recent cases, with one task for intake/risk validation, one for evidence review, and one for disposition preparation. Those task categories are configurable."

> "The Process Events area demonstrates how lifecycle data could support process mining and operational improvement. The 12-case cohort includes straight-through, evidence-loop, supervisor-return, reassignment, and escalation variants."

> "These event rows are explicitly synthetic demo instrumentation. They are useful for showing the questions process mining can answer, but they are not presented as reconstructed SSA history or production audit data. A production implementation would define event capture from authoritative transactions and audit sources."

### Key callout

> "The same platform can manage today's work and provide evidence for improving tomorrow's process, as long as the event lineage is trustworthy."

## 12. Configuration and Production Path - 2 Minutes

### Purpose

Make the configurability message explicit and prevent the demonstration from being mistaken for a final solution blueprint.

### What to say

> "The choices you saw today are examples: the current multi-stage process baseline, demonstration risk labels, sample evidence categories, selected supervisor options, custom workbench layouts, and two dashboard perspectives. None of those choices are immovable."

> "Dynamics and Dataverse provide the reusable foundation: cases, contacts, activities, ownership, teams, queues, forms, views, process guidance, relational data, security, auditing, solution packaging, and integration endpoints. SSA discovery would define the domain configuration layered on top."

> "Moving from this demo to production would require requirement-by-requirement validation, data and integration design, records and privacy review, role and access design, accessibility, performance testing, operational support, AI governance where applicable, migration planning, and acceptance testing."

### Key callout

> "What is reusable is the platform pattern. What must be designed with SSA is the policy and operating model."

## Closing - 2 Minutes

### What to say

> "We started with the analyst's workload and program dashboard, then followed a $24,800 wage discrepancy through intake classification, guided review, risk and confidence, related discrepancy records, conflicting evidence, the analyst workbench, AI-assisted insights, point-of-work agent support, a structured finding, and the supervisor decision package."

> "The demonstration shows a connected operational pattern: structured records instead of disconnected notes, visible human checkpoints instead of autonomous decisions, and management measures that trace back to the work itself."

> "This is one configuration I built to make the conversation concrete. The next step is not to assume these screens are the answer. It is to use them to ask better questions: What are SSA's real intake paths? Which evidence is authoritative? What are the required stages and decision rights? Where do cases wait or return? Which measures matter? With those answers, the same foundation can be configured around SSA's actual process."

### Stakeholder question

> "Which part of the current earnings integrity process would be most valuable to map next: intake and routing, evidence collection, supervisor review, or program-level visibility?"

## Capability and Gap Callouts

| Area | What is shown | Positioning |
|---|---|---|
| Case and contact management | OOB Case and Contact extended for the demo | Demonstrated platform foundation; SSA data model requires discovery |
| Workload and dashboards | Agent and program views, filters, KPIs, detail lists | Demonstrated with fictional data; measures and routing are configurable |
| Guided lifecycle | Visible multi-stage BPF | Demonstrated baseline; final seven-stage/branch smoke testing remains incomplete |
| Risk and confidence | Scores, labels, explanations, financial context | Demonstrated display pattern; production logic/model governance not complete |
| Evidence and discrepancies | Related structured records and verification states | Demonstrated for the scenario; source integrations and document governance are partial |
| Analyst workbench | Embedded summary and progress checklist | Demonstrated custom experience; layout and steps are configurable |
| AI insights | Structured summaries, gaps, rationale, human-review note | Demonstrated assistive pattern; bulk values are seeded and production AI is not claimed |
| Agent Support | Website-grounded specialist/general/IT agents plus a purpose-built frontline fraud-navigation page | Demonstrated guidance pattern; agent output is not policy authority, legal advice, or adjudication |
| Supervisor review | Finding record and embedded case brief | Demonstrated decision-support pattern; action authorization/integrations need production design |
| Tasks | 60 open tasks across 20 recent cases | Demonstrated scalable follow-up pattern; task rules are illustrative |
| Process Mining | 128 explicit events across a 12-case cohort; 454-row export across 58 cases | Demonstrated with labeled synthetic instrumentation; production lineage is future work |
| Integration | Dataverse relationships and integration-ready endpoints | Platform-supported; SSA source and downstream integrations are not implemented end to end |
| Security/compliance | Dataverse platform foundation and ownership model | Platform-supported; formal SSA security, privacy, records, and compliance validation is not complete |

## Short Answers for Likely Questions

### Is this the process you recommend SSA adopt?

No. This is one working configuration built to demonstrate capabilities and stimulate process discovery. SSA's actual stages, roles, evidence rules, thresholds, and outcomes would be designed with SSA stakeholders.

### Is this production-ready?

No. It is a functional demonstration environment. Production readiness requires requirements validation, integrations, security and privacy engineering, records management, accessibility, performance, operations, migration, governance, and acceptance testing.

### Is AI making a fraud or overpayment decision?

No. AI is positioned as assistive summarization and triage. Analysts and supervisors retain final authority. Seeded bulk-case analysis is labeled as demo content and was not generated by a live model.

### Is the Agent Support response authoritative policy or legal advice?

No. The agent demonstrates bounded guidance, source discovery, and routing. Staff must rely on current approved SSA policy, procedures, regulations, and authorized escalation channels. The agent does not create policy, adjudicate a case, or replace legal or supervisory review.

### Does the Business Process Flow enforce the final SSA workflow?

No. The current environment demonstrates a multi-stage guided-process baseline. The target branch design and completion behavior still require full smoke testing and SSA policy validation.

### Are the dashboard numbers SSA metrics?

No. They are calculations over fictional demonstration data. The dashboard proves the reporting pattern; SSA would define the approved measures.

### Is Process Mining based on production history?

No. The enriched cohort is explicitly synthetic demonstration instrumentation. It shows the analysis pattern while preserving clear lineage.

### Can the screens and terminology change?

Yes. Forms, views, dashboards, choice labels, stages, queues, security, rules, and embedded experiences can be configured and solution-managed. Changes would still follow governance, testing, and release controls.

## Presenter Recovery Notes

- If a dashboard is slow, use the Cases view and narrate the same workload dimensions.
- If a web resource is blank, return to the underlying related-record grids. The records are the evidence; the web resource is a presentation layer.
- If the BPF does not advance, do not edit the hero case live. Explain the visible stage pattern and continue through the tabs.
- If AI refresh fails, state that the display is available but the live trigger is not configured for the current browser session. Do not imply that analysis completed.
- If Agent Support does not load, use the prepared screenshots and narrate the linked-agent, bounded-response, official-source, and frontline-triage patterns without claiming a live response.
- If EIR-2025-0033 is not resolved, describe it as approved or ready for closure only according to the visible live fields.
- If time runs short, skip the Process Events drill-down and preserve the supervisor review and configuration sections.

## Final Presenter Checklist

- Keep the phrase "one possible configuration" in the opening and closing.
- State that all people, amounts, and events are fictional demonstration data.
- Never call the intake signal a confirmed fraud determination.
- Never describe seeded AI display data as a live model response.
- Never describe Agent Support output as policy authority, legal advice, or an adjudicative decision.
- Never describe synthetic process events as production audit history.
- Preserve at least four minutes for supervisor review and two minutes for configurability/production path.
- End with a discovery question, not a claim of full equivalency.
