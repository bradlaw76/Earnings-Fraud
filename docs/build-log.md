# Build Log

Record each build run here. One row per execution.

Use this to document what was planned, built, validated, and promoted.

## Run summary template

Copy this block for each run:

```text
Date:
Runner:
Environment URL: https://<org>.crm.dynamics.com
Build Type (Demo/Prod):
Scripts Run (20,30,40,50,60):
Post-Build Analysis Run (80): yes/no
Tables (created/skipped/failed):
Columns (created/skipped/failed):
Relationships (created/skipped/failed):
Forms (created/skipped/failed):
Views (created/skipped/failed):
Apps (created/updated/skipped/failed):
Web Resources (created/updated/skipped/failed):
Sitemap Updates (updated/skipped/failed):
Inventory Generated (yes/no):
Solution Sync Run (yes/no):
Solution Membership Check (pass/fail):
Missing Components After Sync:
Solution Exported (yes/no):
Solution Unpacked (yes/no):
Solution Packed (yes/no):
Solution Imported (yes/no):
Git Branch:
Commit ID:
Notes:
```

## Latest run

```text
Date: 2026-08-06
Runner: GitHub Copilot
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Build Activity: Earnings Fraud Case Review BPF structural remediation and validation
Changes:
  - Added structural validator script 101-validate-earnings-fraud-case-bpf.ps1 to assert active state, solution membership, and minimum process shape
  - Added repair script 102-repair-bpf-control-step.ps1 to normalize malformed starter ControlStep payload
  - Added expansion script 103-expand-earnings-fraud-case-bpf.ps1 to enforce stage-chain/condition expectations in clientdata
  - Repaired process internals by cloning a known-good incident BPF payload with GUID remapping into Earnings Fraud Case Review
  - Retargeted cloned payload to workflow aa834710-ec90-f111-8077-000d3a189124 and renamed stage labels to fraud-review terminology
Status:
  - BPF remains active and in FederalEarningsFraud solution (component type 29)
  - Structural validation now reports StageCount=6, ConditionCount=1, StepCount=14, IsActive=True, InSolution=True
  - Unified Process Designer now renders a full multi-stage flow with a visible condition node (no longer single-stage minimal payload)
  - Current validator default threshold expects 7 stages, so default run remains FAIL until threshold or stage target is adjusted
Known Issues:
  - Unified designer page intermittently fails to load unifiedprocessdesignereventhandler.js (404/MIME mismatch), causing unstable toolbar interactions
Next Steps:
  - Decide whether the target baseline is 6 stages (current persisted shape) or 7 stages, then align validator threshold and design spec
  - If 7 stages are required, add the seventh stage through a stable designer session and re-run 101 validation
  - Enable the BPF in Earnings Integrity V2 Demo App and publish the app
  - Smoke test Yes/No branch behavior and manual completion behavior on demo cases
```

## Previous run (2026-08-05)

```text
Date: 2026-08-05
Runner: GitHub Copilot
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Build Activity: Earnings Fraud Case Review BPF implementation planning and installer preparation
Changes:
  - Approved a Case (`incident`) Business Process Flow named Earnings Fraud Case Review for the FederalEarningsFraud unmanaged solution
  - Defined Intake, Risk Triage, Evidence Validation, Earnings Analysis, conditional Supervisor Review, Disposition, and Complete Review stages
  - Defined the single conditional route: earnint_supervisorreviewrequired = Yes requires Supervisor Review; No continues to Disposition
  - Preserved human-decision guardrails: AI outputs are informational only, final disposition/determination are human-owned, and BPF Finish does not resolve a Case
  - Added 100-install-earnings-fraud-case-bpf.ps1 to validate an activated designer-authored BPF and add it idempotently to the target solution as workflow component type 29
Status:
  - PowerShell syntax validation passed for 100-install-earnings-fraud-case-bpf.ps1
  - Target metadata validation passed for all 17 planned Case fields
  - BPF exists: workflow aa834710-ec90-f111-8077-000d3a189124 on incident
  - Activation initially failed with platform validation error: "Attribute - datafieldname of ControlStep cannot be null or empty"
  - Repaired malformed starter definition by removing the invalid empty ControlStep payload and activating the workflow
  - Activation succeeded: statecode=1, statuscode=2
  - Installer succeeded: added workflow component type 29 to FederalEarningsFraud and published
  - Verified solution membership via solutioncomponents query: componenttype=29 count=1 for workflow aa834710-ec90-f111-8077-000d3a189124
  - App exposure pending: AddAppComponents did not create an appmodulecomponent link for workflow; process must be enabled from model-driven app designer
  - Full stage/branch enrichment pending: current active BPF is minimal-valid and does not yet contain the full seven-stage conditional design
Next Steps:
  - Open the BPF designer and configure the approved seven-stage path and conditional supervisor branch
  - Enable the BPF in Earnings Integrity V2 Demo App and publish the app
  - Test Yes/No supervisor branch behavior and manual completion behavior on demo cases
  - Export/unpack the solution to version the generated BPF workflow and process-stage artifacts
```

```text
Date: 2026-08-04
Runner: GitHub Copilot
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Scripts Run: 85-apply-choice-visuals.ps1
Changes:
  - Identified 22 custom Picklist choice columns across incident, earnint_earningsdiscrepancy, earnint_evidenceitem, and earnint_investigationfinding
  - Applied semantic Dataverse colors to every deployed payload choice option
  - Prefixed choice labels with visible Unicode glyph icons, for example ✓, ▲, ⚠, ◷, ℹ, and ◆
  - Replaced the original dark semantic colors with pastel green (#B7E4C7), yellow (#FFF3B0), peach (#FFD6A5), blush (#FFC2C7), powder blue (#BDE0FE), and lavender (#D8C4F1)
  - Inserted 40 missing payload option values that were not added by the original column build skip logic
  - Published metadata for incident, earnint_earningsdiscrepancy, earnint_evidenceitem, and earnint_investigationfinding
Validation:
  - 85-apply-choice-visuals.ps1 -ApplyIconLabels -VerifyOnly confirmed 207 choice options verified, 0 missing colors, 0 mismatched labels, 0 failed columns
Notes:
  - Dataverse choice metadata supports option colors natively.
  - Dataverse does not expose a native per-option icon property, so visible icons are stored in the choice label text.
```

## Previous run (2026-08-03)

```text
Date: 2026-08-03
Runner: brla
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Scripts Run: payload/schema/docs alignment updates (no bootstrap execution)
Changes:
  - Expanded case/discrepancy/evidence/finding/AI payload fields for suspicious wage intake and human-reviewed disposition model
  - Updated flow-ai-summary-template.json to align selects, prompt guardrails, parse schema, and case writeback fields
  - Updated fraud AI insights web resource to render risk breakdown, evidence gaps, confidence rationale, and human review note
  - Updated form layout and demo seed script to use expanded taxonomy and triage fields
  - Updated V2 spec/plan/tasks/demo docs and onboarding notes to reflect case-anchor + AI guardrails
Git Branch: current working branch (ahead, local changes pending commit)
Notes:
  - Git fetch completed; no pull/rebase due dirty working tree
  - Validation scripts not yet re-run after this alignment pass
```

## Previous run (2026-08-02)

```text
Date: 2026-08-02
Runner: brla
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Scripts Run: 06-demo-script-wizard.ps1 (updated)
Changes: Added Copilot Studio agent draft section to demo script wizard output
  - $copilotStudioSection appended to demo-walkthrough.md (agent setup, instructions, test prompts, checklist)
  - $copilotStudioTalkTrack appended to demo-talk-track.md (presenter transition, talking points, closing bridge)
  - Agent: SSA Earnings Integrity Advisor — grounded in 20 CFR Title 20 (Parts 404, 416, 498)
  - Knowledge source: https://www.ssa.gov/OP_Home/cfr20/cfrdoc.htm
Git Branch: chore/wizard-refinement-starter-port
Notes:
- Section is marked [DRAFT] — agent not yet deployed in Copilot Studio
- Remove draft markers and update setup checklist once agent is published
```

## Previous run (2026-07-30)

```text
Date: 2026-07-30
Runner: brla
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Scripts Run: 97-seed-demo-data.ps1 (demo data seed)
Relationships fixed: earnint_case_evidence, earnint_case_finding (created); earnint_case_discrepancy (already existed)
Contacts (created/skipped/failed): 4/0/0
Cases (created/skipped/failed): 4/0/0
Earnings Discrepancies (created/skipped/failed): 6/0/0
Evidence Items (created/skipped/failed): 9/0/0
Investigation Findings (created/skipped/failed): 3/0/0
Total records seeded: 26
Git Branch: main
Notes:
- Seeded 4 beneficiary contacts: Robert Hargrove, Maria Castillo, James Whitfield, Patricia Nguyen
- Seeded 4 cases at different lifecycle stages (In Progress, Researching, On Hold, Active-needs-resolve)
- Hargrove case: EIR-2025-0041, unreported SSDI wages Q1-Q2 2025, discrepancy $24,800, pending supervisor
- Castillo case: EIR-2025-0052, dual employer unreported 2024, discrepancy $18,400, finding in progress
- Whitfield case: EIR-2025-0067, prior overpayment history + Q3 2025 wage discrepancy, on hold for employer reply
- Nguyen case: EIR-2025-0033, IRS 1099 vs beneficiary statement, fraud indicator finding, supervisor approved
- Nguyen case requires manual resolve in portal (CloseIncident action skipped due to API constraint)
- Script 97-seed-demo-data.ps1 is idempotent — safe to rerun
```

## Previous run (2026-07-23)

```text
Date: 2026-07-23
Runner: brla
Environment URL: https://healthconnectcenter.crm.dynamics.com
Build Type (Demo/Prod): Demo
Scripts Run (20,30,40,50,60): 20,30,40,50,60
Post-Build Analysis Run (80): yes (PreviewOnly)
Tables (created/skipped/failed): 2/1/0
Columns (created/skipped/failed): 5/5/0
Relationships (created/skipped/failed): 0/2/0
Forms (created/skipped/failed): 3/3/0
Views (created/skipped/failed): 0/6/0
Solution Exported (yes/no): no
Solution Unpacked (yes/no): no
Solution Packed (yes/no): no
Solution Imported (yes/no): no
Git Branch: not captured
Commit ID: not captured
Notes:
- Added missing web resources implementation script 65-build-web-resources.ps1 and fixed 70 wrapper passthrough.
- Added 429/401 resilience for 30-build-columns.ps1 and automatic token refresh in 65-build-web-resources.ps1.
- V2 web resource earnint_/report/supervisor-case-summary-v2.html created/updated and added to solution.
- One PublishAll call returned 429 earlier; later reruns published successfully.
```

## Planning checkpoint (Spec Kit)

Complete this before implementation:

- Spec file complete: yes/no
- Plan file complete: yes/no
- Tasks file complete: yes/no
- Discovery questions answered: yes/no
- Scenario owner sign-off: yes/no

## Validation checkpoint

- Maker portal verification complete: yes/no
- Required tasks from `tasks.md` complete: yes/no
- README generated summary reviewed/updated: yes/no
- Known issues captured with owner/date: yes/no
