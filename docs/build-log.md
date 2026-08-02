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

## Previous run

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
