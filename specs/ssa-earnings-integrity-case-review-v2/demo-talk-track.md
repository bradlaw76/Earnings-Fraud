# Demo Talk Track: SSA Earnings Integrity Case Review V2

## Presenter Brief
- Audience: Fraud analysts and supervisors
- Duration: 15 minutes
- Style: verbose
- Story anchor: incident (OOB Case)
- Core workflow: Run suspicious wage report intake through earnings integrity resolution using OOB incident and contact with fraud-specific forms.

## Form Names To Use
- incident (OOB): Fraud Case Form (primary for demo)
- contact (OOB): Fraud Contact Form (primary for demo)
- Fallback only if needed: Case (incident), Information (contact)

## Menu Click Path
- Left navigation group: Fraud Case Review
- Click **Cases**
- Open view **Active Cases**
- Open the prepared demo case record
- In the command bar, click **Switch form** and select **Fraud Case Form**
- Click **Contacts**
- Open view **Active Contacts**
- Open the prepared demo contact record
- In the command bar, click **Switch form** and select **Fraud Contact Form**

## Demo Data Reference (seeded 2026-07-30)

| Case ID | Beneficiary | Scenario | Stage | Key Discrepancy |
|---|---|---|---|---|
| EIR-2025-0041 | Robert Hargrove | Unreported SSDI wages Q1-Q2 2025 | **In Progress — Pending Supervisor** | $24,800 from Apex Logistics Inc |
| EIR-2025-0052 | Maria Castillo | Dual employer wages unreported 2024 | **Researching — Finding In Progress** | $18,400 (Sunrise + Metro Catering) |
| EIR-2025-0067 | James Whitfield | Prior overpayment + Q3 2025 discrepancy | **On Hold — Awaiting Employer Reply** | $8,750 from GreenPath Construction |
| EIR-2025-0033 | Patricia Nguyen | IRS 1099 vs beneficiary statement | **Resolved — Overpayment Initiated** | $11,600 self-employment income |

**Hero case for demo:** EIR-2025-0041 (Hargrove) — has all evidence collected and a finding pending supervisor approval. Best for showing the full lifecycle.

## Opening (30-45 sec)
"Today I am showing how SSA Earnings Integrity Case Review V2 uses suspicious wage reports as intake signals into a consistent, auditable review process." "I will walk through the Hargrove case — a live record in this environment — showing triage, evidence review, analyst finding, and supervisor approval." "AI supports prioritization, but final decisions remain with SSA staff."

## Talk Track Steps
### Step 1: Open with the business problem (3 min)
**Narrative**
Set the stage: SSA receives thousands of earnings reports and wage-feed records that must be reconciled. Discrepancies require consistent human-led review, not black-box automation. This app structures that process.

**Actions**
- In the app selector, open **Earnings Integrity V2 Demo App**.
- In left navigation, click **Cases**, then open **Active Cases - DATA** view.
- Show 3–4 cases in the queue — point out the EIR case numbers and stages visible in the list.
- Open **EIR-2025-0041 — Hargrove, Robert** as the hero case.

**Key Points**
- Explain: "Every case is a structured work item with an audit trail from the moment it's created."
- Note the case description already references the wage feed source and discrepancy amount ($24,800)
- The queue shows cases at different stages — Hargrove is the most advanced and will anchor the walkthrough
- Emphasize that suspicious wage report is an intake path, not an automatic fraud determination

### Step 2: Case workspace and earnings discrepancies (3 min)
**Narrative**
Show the Hargrove case as a complete workspace — description, linked beneficiary, and the earnings records that triggered the review.

**Actions**
- On the open Hargrove case, read the description aloud: wage feed from Apex Logistics, zero-income report, $24,800 gap.
- In the left nav, click **Earnings Discrepancies**, then open **Active Earnings Discrepancies** view.
- Show both Hargrove discrepancy records (Q1 and Q2 2025): reported=0, authoritative=$12,400 each, source=IRS Wage Feed W-2.
- Point out Employer Name and Earnings Period columns.

**Key Points**
- "The discrepancy records are created automatically from wage-feed comparison — the analyst doesn't have to calculate the gap."
- Two records covering two quarters = $24,800 total exposure
- Every record links back to the parent case, so closing the case cascades
- Review Type, Referral Source, and Allegation Type keep scenario classification consistent

### Step 3: Evidence review (3 min)
**Narrative**
Show the evidence package assembled for the Hargrove case. This is what the analyst reviews before writing a finding.

**Actions**
- In left nav click **Evidence Items**, open **Active Evidence Items** view.
- Filter or scroll to show Hargrove's 3 evidence records: W-2 (verified), Beneficiary Statement (under review), Employer Confirmation (verified).
- Open the **IRS W-2** record: point out Document Name, Evidence Type, Evidence Description, Verified By.
- Open the **Beneficiary Statement**: note Verified By is blank — statement is not yet credible.
- Open the **Employer Confirmation**: Apex Logistics confirmed employment. This is the decisive evidence.

**Key Points**
- "Three evidence types are already in the system — the analyst didn't have to chase documents manually."
- The beneficiary statement and employer confirmation tell opposite stories — this is exactly the conflict that triggers supervisor review.
- Evidence is attached to the case and visible in the case timeline
- Missing or contradictory evidence is surfaced in AI Evidence Gaps output for analyst follow-up

### Step 4: Analyst finding and supervisor approval (3 min)
**Narrative**
Show the finding the analyst wrote for Hargrove, then show what the supervisor sees and decides.

**Actions**
- In left nav click **Investigation Findings**, open **Active Investigation Findings** view.
- Open **Hargrove — Finding: Discrepancy Confirmed — Pending Supervisor**.
- Read the key fields: Finding Type = Discrepancy Confirmed, Recommended Disposition = Create Overpayment Review, Analyst Name = J. Reyes.
- Read the Finding Details field — it summarizes the full evidence picture for the supervisor.
- Say: "This is what goes to the supervisor. No phone call, no email — the record speaks for itself."
- Optional: click back to the Hargrove case and show the **Supervisor Case Summary Report V2** web resource tab.

**Key Points**
- Finding Type and Recommended Disposition are controlled vocabularies — no free-text decisions
- The supervisor sees: what was found, who found it, what action is recommended, and the evidence behind it
- "Copilot provides fraud likelihood and confidence rationale for triage; analysts and supervisors make final determinations."

### Step 5: Close with the resolved case and the queue (3 min)
**Narrative**
End with the Nguyen case as the resolved example, then zoom out to show the full queue — demonstrating that this is a system for managing many cases, not just one.

**Actions**
- In left nav click **Cases**, open **Active Cases - DATA** view.
- Point out all four cases and their stages: one resolved (Nguyen), one pending supervisor (Hargrove), one on hold (Whitfield), one researching (Castillo).
- Open **EIR-2025-0033 — Nguyen, Patricia** (the resolved case).
- Show the finding: Finding Type = Possible Fraud Indicator, Disposition = Create Overpayment Review, Supervisor = S. Kim, Approved.
- Say: "This case is closed. The audit trail — every discrepancy record, every evidence item, every finding — is preserved and cannot be altered."

**Key Points**
- The queue gives supervisors full visibility into workload and stage
- Resolution paths are explicit: Close, RFI, Overpayment Review, Fraud Escalation
- Every case produces the same artifact structure — consistency is the product
- Final determination remains human-reviewed and auditable


## Key Phrases To Use
- "defaults plus benefits of how this tool can be used for a variety of use cases and can be configured to support future scopes"
- "We can trace this outcome directly to the scenario requirements and mapping."
- "What you are seeing aligns to the defined success measure."
- "The implementation stays aligned to the scenario files and explicit mapping."


## Closing (20-30 sec)
"We just walked four live cases — from suspicious wage intake to final disposition — using structured Dataverse records, explainable AI-assisted triage, and a controlled analyst-to-supervisor approval path." "Dynamics 365 Customer Service structures the work while SSA staff retain control of every finding, approval, and outcome." "Next, we can review pacing, expand AI insight visuals, or tailor the talk track for a specific audience."

## Presenter Checklist
- [ ] Keep language outcome-first, not implementation-heavy.
- [ ] Call out the hero record and business impact clearly.
- [ ] End by restating measurable success criteria.
