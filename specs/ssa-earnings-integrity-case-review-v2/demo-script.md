# Demo Talk Track: SSA Earnings Integrity Case Review V2

## Presenter Brief
- Audience: Fraud analysts and supervisors
- Duration: 15 minutes
- Style: verbose
- Story anchor: incident
- Core workflow: Run suspicious wage report intake through earnings integrity case resolution with analyst and supervisor checkpoints.

## Opening (30-45 sec)
"Today I am showing how SSA Earnings Integrity Case Review V2 handles suspicious wage reports as intake signals into a broader earnings integrity process." "The system provides explainable triage support, but all findings and final outcomes remain with SSA analysts and supervisors." "I will anchor the walkthrough on the Case record and follow the case from intake to disposition."

## Talk Track Steps
### Step 1: Open with the business problem (3 min)
**Narrative**
Explain how suspicious wage reports, wage matches, and employer mismatches are routed into one standardized case lifecycle.

**Actions**
- Open Active Cases and pick the suspicious wage intake scenario (Hargrove).
- Show case taxonomy fields: Review Type, Referral Source, Allegation Type, and Review Period.
- Confirm case anchor and linked beneficiary profile.

**Key Points**
- Suspicious wage report is an intake signal, not a final determination.
- One case record unifies triage, evidence, findings, and supervisor decision.
- The same structure handles high, medium, and low-risk scenarios.

### Step 2: Start from the hero record (3 min)
**Narrative**
Show how the case captures risk and confidence context before any disposition.

**Actions**
- On the case form, review Fraud Risk Score, Fraud Likelihood, Confidence Score, Confidence Level, and Risk Explanation.
- Show Supervisor Review Required and Human Review Required flags.
- Open AI Insights web resource and explain summary, risk drivers, evidence gaps, and human-review note.

**Key Points**
- AI supports triage prioritization only.
- Human review remains mandatory for final outcomes.

### Step 3: Walk through the core workflow (3 min)
**Narrative**
Demonstrate discrepancy and evidence review, then show recommended outcome progression.

**Actions**
- Open discrepancy records and show source type, discrepancy type, and variance metrics.
- Open evidence records and show status, supports-finding category, and verification.
- Show analyst finding with recommendation and supervisor approval status.

**Key Points**
- Case state is explainable: discrepancy + evidence + finding + supervisor checkpoint.
- Recommended outcomes are structured and auditable.

### Step 4: Show supporting experience (3 min)
**Narrative**
Use dashboard and summary artifacts to prove queue-level visibility and oversight.

**Actions**
- Show Supervisor Case Summary and Executive dashboard web resources.
- Show queue assignment values and stage-oriented views.
- Reference the flow template and prompt structure used for AI analysis refresh.

**Key Points**
- Supervisors see risk concentration and pending approvals quickly.
- Analysts can identify missing evidence before escalation.

### Step 5: Close with success and next step (3 min)
**Narrative**
Close by contrasting high-risk and low-risk demo scenarios and confirming human-reviewed outcomes.

**Actions**
- Compare Hargrove (medium-high risk) and Nguyen (late-reporting low risk) dispositions.
- Restate that final determination is analyst/supervisor owned.
- Capture follow-up asks for additional automation or data scenarios.

**Key Points**
- Review request: confirm expanded case taxonomy and suspicious wage story framing.
- Data approach: prepared sample data plus one live field update.


## Key Phrases To Use
- "Suspicious wage reports are intake signals into a broader earnings integrity lifecycle."
- "AI provides a likelihood indicator and confidence score, not a final determination."
- "We can trace this outcome directly to the scenario requirements and mapping."
- "What you are seeing aligns to the defined success measure."
- "The implementation stays aligned to the scenario files and explicit mapping."


## Closing (20-30 sec)
"To recap, we demonstrated suspicious wage intake through structured, explainable, and human-reviewed earnings integrity resolution." "Dynamics 365 Customer Service provides auditability and repeatability while SSA staff retain decision authority." "Next, we can tune queue routing, expand prompt outputs, or add new demo scenarios."

## Presenter Checklist
- [ ] Keep language outcome-first, not implementation-heavy.
- [ ] Call out the hero record and business impact clearly.
- [ ] End by restating measurable success criteria.
