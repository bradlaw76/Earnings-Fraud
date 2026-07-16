# Federal Earnings Fraud Build Guide

This repository contains the full guided build for a Dynamics 365 Customer Service scenario focused on SSA earnings integrity and fraud review.

## Repository Target Check

Before any commit or push, confirm you are in the intended repository and branch.

```powershell
git rev-parse --show-toplevel
git remote -v
git branch --show-current
```

Expected top-level path should end with `Federal Earnings Fraud` for this build guide.

The implementation uses:

- Spec-driven planning in [specs/ssa-earnings-integrity-case-review/spec.md](specs/ssa-earnings-integrity-case-review/spec.md), [specs/ssa-earnings-integrity-case-review/plan.md](specs/ssa-earnings-integrity-case-review/plan.md), and [specs/ssa-earnings-integrity-case-review/tasks.md](specs/ssa-earnings-integrity-case-review/tasks.md)
- Dataverse Web API bootstrap scripts under [scripts/bootstrap](scripts/bootstrap)
- JSON payload-driven metadata under [scripts/payloads](scripts/payloads)

## Build Outcome

The build creates a repeatable, source-controlled baseline for:

- Core custom Dataverse tables for case operations
- Columns and relationships defined in payload files
- Solution assembly in the target Dataverse solution
- Starter forms and active views on custom tables
- A supervisor report HTML web resource packaged into the solution

## Full Build Sequence

Run this sequence exactly.

1. Prerequisites
2. Authentication and local environment config
3. Planning gate (spec/plan/tasks complete)
4. Dataverse schema build (tables, columns, relationships)
5. Add components to solution
6. Build forms and views
7. Build web resources
8. Maker validation
9. Solution export/unpack, Git commit, pack/import

## 1. Prerequisites

Install required tools:

```powershell
winget install Microsoft.PowerShell
winget install Microsoft.AzureCLI
winget install Microsoft.PowerPlatformCLI
winget install Git.Git
```

Verify:

```powershell
pwsh --version; az --version; pac --version; git --version; code --version
```

Run repository prerequisite check:

```powershell
pwsh ./scripts/bootstrap/00-prereq-check.ps1
```

## 2. Authentication and Session Setup

Authenticate and persist local session values:

```powershell
pwsh ./scripts/bootstrap/10-auth-connect.ps1
```

What this does:

- Signs in Azure and PAC profiles for Dataverse
- Generates `.env.ps1` for local script execution
- Captures environment URL, publisher prefix, and solution names

Optional modes:

```powershell
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -UseDeviceCode
pwsh ./scripts/bootstrap/10-auth-connect.ps1 -ServicePrincipal
```

## 3. Planning Gate (Mandatory)

Before build scripts, confirm planning artifacts are complete and reviewed:

- [specs/ssa-earnings-integrity-case-review/spec.md](specs/ssa-earnings-integrity-case-review/spec.md)
- [specs/ssa-earnings-integrity-case-review/plan.md](specs/ssa-earnings-integrity-case-review/plan.md)
- [specs/ssa-earnings-integrity-case-review/tasks.md](specs/ssa-earnings-integrity-case-review/tasks.md)

If you need to regenerate starter planning files:

```powershell
pwsh ./scripts/bootstrap/05-start-wizard.ps1
```

## 4. Payloads Used In This Build

All payloads in this implementation are under [scripts/payloads](scripts/payloads).

Tables:

- [scripts/payloads/table-03.json](scripts/payloads/table-03.json)
- [scripts/payloads/table-04.json](scripts/payloads/table-04.json)
- [scripts/payloads/table-05.json](scripts/payloads/table-05.json)

Columns:

- [scripts/payloads/columns-01-case.json](scripts/payloads/columns-01-case.json)
- [scripts/payloads/columns-02-contact.json](scripts/payloads/columns-02-contact.json)
- [scripts/payloads/columns-03-discrepancy.json](scripts/payloads/columns-03-discrepancy.json)
- [scripts/payloads/columns-04-evidence.json](scripts/payloads/columns-04-evidence.json)
- [scripts/payloads/columns-05-findings.json](scripts/payloads/columns-05-findings.json)

Relationships:

- [scripts/payloads/relationships-core.json](scripts/payloads/relationships-core.json)

Web resources:

- [scripts/payloads/webresource-01-supervisor-summary.json](scripts/payloads/webresource-01-supervisor-summary.json)
- [scripts/payloads/webresources/supervisor-case-summary.html](scripts/payloads/webresources/supervisor-case-summary.html)

## 5. Execute Build Scripts

Run scripts in this exact order:

```powershell
pwsh ./scripts/bootstrap/20-build-tables.ps1
pwsh ./scripts/bootstrap/30-build-columns.ps1
pwsh ./scripts/bootstrap/40-build-relationships.ps1
pwsh ./scripts/bootstrap/50-add-to-solution.ps1
pwsh ./scripts/bootstrap/60-build-forms-views.ps1
pwsh ./scripts/bootstrap/70-build-web-resources.ps1
```

Gate after each script:

- If `failed > 0`, stop and fix before continuing.
- All scripts are intended to be idempotent and safe to rerun.

## 6. Validate In Maker Portal

Open [Power Apps Maker](https://make.powerapps.com) and validate:

- Custom tables exist
- Expected columns exist
- Relationships exist and resolve lookups correctly
- Components are included in target solution
- Starter main forms and active views are present
- Supervisor web resource appears in solution components

## 7. Solution Lifecycle (Source Control)

After validation, export and unpack:

```powershell
pac solution export --name "<SolutionName>" --path "./out/<SolutionName>_unmanaged.zip" --managed false
pac solution unpack --zipfile "./out/<SolutionName>_unmanaged.zip" --folder "./solutions/<SolutionName>" --packagetype Unmanaged
```

Commit to Git:

```powershell
git checkout -b feature/<short-description>
git add .
git commit -m "Build SSA earnings integrity baseline artifacts"
git push -u origin feature/<short-description>
```

Promotion pack/import:

```powershell
pac solution pack --zipfile "./out/<SolutionName>_unmanaged_new.zip" --folder "./solutions/<SolutionName>" --packagetype Unmanaged
pac solution import --path "./out/<SolutionName>_unmanaged_new.zip"
```

## Script Reference

Bootstrap scripts used by this build:

- [scripts/bootstrap/00-prereq-check.ps1](scripts/bootstrap/00-prereq-check.ps1)
- [scripts/bootstrap/01-install-skills.ps1](scripts/bootstrap/01-install-skills.ps1)
- [scripts/bootstrap/05-start-wizard.ps1](scripts/bootstrap/05-start-wizard.ps1)
- [scripts/bootstrap/10-auth-connect.ps1](scripts/bootstrap/10-auth-connect.ps1)
- [scripts/bootstrap/20-build-tables.ps1](scripts/bootstrap/20-build-tables.ps1)
- [scripts/bootstrap/30-build-columns.ps1](scripts/bootstrap/30-build-columns.ps1)
- [scripts/bootstrap/40-build-relationships.ps1](scripts/bootstrap/40-build-relationships.ps1)
- [scripts/bootstrap/50-add-to-solution.ps1](scripts/bootstrap/50-add-to-solution.ps1)
- [scripts/bootstrap/60-build-forms-views.ps1](scripts/bootstrap/60-build-forms-views.ps1)
- [scripts/bootstrap/70-build-web-resources.ps1](scripts/bootstrap/70-build-web-resources.ps1)

## Supporting Documentation

- [docs/onboarding.md](docs/onboarding.md)
- [docs/build-log.md](docs/build-log.md)
- [requirements/how-to-build-dynamics-model-driven-apps-wizard.md](requirements/how-to-build-dynamics-model-driven-apps-wizard.md)
- [requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md](requirements/how-to-build-dynamics-model-driven-apps-in-vscode-with-copilot.md)
