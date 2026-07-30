# tasks.md

## Ordered Tasks
- [ ] Review nswers.md with stakeholder
- [ ] Finalize spec.md
- [ ] Finalize plan.md
- [ ] Approve build environment and permissions
- [ ] Define Dataverse tables and columns for: incident, contact, earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- [ ] Define required app artifacts for: Case form updates, discrepancy/evidence/finding forms, active views, supervisor summary web resource, executive mode report
- [ ] Build report mapping matrix for tables: earnint_earningsdiscrepancy, earnint_evidenceitem, earnint_investigationfinding
- [ ] Confirm report types/placement: web resource, dashboard KPI, queue/view summary
- [x] Decide demo data approach: Yes
- [x] Run pwsh ./scripts/bootstrap/00-prereq-check.ps1
- [x] Run pwsh ./scripts/bootstrap/10-auth-connect.ps1
- [x] Build tables with 20-build-tables.ps1
- [x] Build columns with 30-build-columns.ps1
- [x] Build relationships with 40-build-relationships.ps1
- [x] Add components to solution with 50-add-to-solution.ps1
- [x] Build starter forms/views with 60-build-forms-views.ps1
- [x] Build report/web resources with 70-build-web-resources.ps1 (when applicable)
- [x] Seed demo data with 97-seed-demo-data.ps1 (2026-07-30)
- [ ] Manually resolve Nguyen case (EIR-2025-0033) in Maker portal
- [ ] Export and unpack solution
- [x] Commit changes to git
- [ ] Pack and import solution
- [x] Update docs/build-log.md

