<#
.SYNOPSIS
    Populates AI display fields on the deterministic bulk demo Cases.

.DESCRIPTION
    Generates transparent seeded-demo analysis from each Case's review profile
    and linked discrepancy, evidence, and finding records. This does not call an
    AI model. Raw JSON is marked SEEDED_DEMO_ANALYSIS. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/110-enrich-bulk-case-ai-fields.ps1 -WhatIf
    pwsh ./scripts/bootstrap/110-enrich-bulk-case-ai-fields.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [int]$ApplicationChoiceValue = 581180001,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Environment URL required. Run 10-auth-connect.ps1 first."
}

$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$token = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Could not get a Dataverse access token. Re-run 10-auth-connect.ps1."
}

$headers = @{
    Authorization      = "Bearer $($token.Trim())"
    "Content-Type"     = "application/json"
    "OData-Version"    = "4.0"
    "OData-MaxVersion" = "4.0"
    Accept              = "application/json"
}

function Invoke-Dv {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )

    $uri = "$EnvironmentUrl/api/data/v9.2/$Path"
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 20)
}

function Get-DvRows {
    param([Parameter(Mandatory)][string]$Path)

    $rows = @()
    $nextPath = $Path
    while ($nextPath) {
        $response = if ($nextPath -like "http*") {
            Invoke-RestMethod -Method Get -Uri $nextPath -Headers $headers
        } else {
            Invoke-Dv -Method Get -Path $nextPath
        }
        $rows += @($response.value)
        $nextLinkProperty = $response.PSObject.Properties["@odata.nextLink"]
        $nextPath = if ($null -ne $nextLinkProperty) { $nextLinkProperty.Value } else { $null }
    }
    return @($rows)
}

function Get-Profile {
    param([Parameter(Mandatory)][int]$ReviewType)

    switch ($ReviewType) {
        100000001 {
            return @{
                Label = "unreported earnings"
                Summary = "This Case presents an unreported-earnings signal requiring comparison of beneficiary reporting with authoritative wage data. The material variance and sustained reporting period support continued analyst review."
                NextAction = "Verify the wage source and beneficiary response, complete the evidence package, and prepare the proposed overpayment review for human approval."
                Risk = "Material wage variance; sustained impacted period; authoritative wage source conflicts with beneficiary reporting; high-risk review profile."
                Gaps = "Confirm the beneficiary response, payment history, and current identity validation before final determination."
                Confidence = "Confidence is high where wage and employer records corroborate the discrepancy, but remains subject to beneficiary-response review."
            }
        }
        100000002 {
            return @{
                Label = "multiple-employer earnings"
                Summary = "This Case presents a multiple-employer earnings discrepancy. Separate wage sources must be reconciled before the combined variance and beneficiary reporting can be evaluated."
                NextAction = "Complete employer-by-employer reconciliation, obtain the beneficiary response, and prepare a focused request for any missing wage or identity documentation."
                Risk = "Multiple employer sources; combined annual variance; incomplete evidence package; identity linkage requires confirmation."
                Gaps = "Beneficiary written response and complete employer-by-employer identity linkage remain necessary for a final human determination."
                Confidence = "Confidence is moderate because multiple wage sources support the signal while beneficiary explanation and some linkage evidence remain incomplete."
            }
        }
        100000004 {
            return @{
                Label = "late wage reporting"
                Summary = "This Case presents a late-reporting pattern rather than a confirmed intentional-misrepresentation pattern. Corrected wage information should be reconciled with the affected benefit period."
                NextAction = "Verify the corrected wage record, document the reporting delay and impacted months, and prepare the corrected-data disposition for human review."
                Risk = "Late wage reporting; limited impacted period; corrected record available; lower intentional-misrepresentation signal."
                Gaps = "Confirm that the corrected wage record fully reconciles and that any benefit-adjustment or monitoring action is documented."
                Confidence = "Confidence is high when corrected records match authoritative data; the final administrative action remains a human decision."
            }
        }
        100000005 {
            return @{
                Label = "employer wage mismatch"
                Summary = "This Case presents an employer wage mismatch that requires direct comparison of employer, beneficiary, and wage-source information. The current signal is not a final fraud determination."
                NextAction = "Contact the employer with the precise wage-period and identity questions, document the response, and reassess the proposed disposition through human review."
                Risk = "Employer record mismatch; verification pending; beneficiary identity and reporting period require reconciliation."
                Gaps = "Employer confirmation and refreshed identity validation are needed before the discrepancy can be resolved."
                Confidence = "Confidence is moderate because a mismatch is present, but employer verification and beneficiary context are not yet complete."
            }
        }
        default {
            return @{
                Label = "earnings integrity"
                Summary = "This Case contains an earnings-integrity signal requiring analyst review of Case, wage, and beneficiary information."
                NextAction = "Review linked records, document evidence gaps, and prepare the next human-owned Case action."
                Risk = "Earnings discrepancy and incomplete review context require analyst assessment."
                Gaps = "Confirm all wage, identity, and beneficiary-response evidence before final determination."
                Confidence = "Confidence depends on corroboration across linked evidence and remains subject to human review."
            }
        }
    }
}

$aiFields = @(
    "earnfrau_aisummary",
    "earnfrau_supportingevidencesummary",
    "earnfrau_nextbestaction",
    "earnfrau_risksignalbreakdown",
    "earnfrau_evidencegaps",
    "earnfrau_confidencerationale",
    "earnfrau_humanreviewnote",
    "earnfrau_airawjson"
)

$caseSelect = @(
    "incidentid", "title", "ticketnumber", "_customerid_value",
    "earnint_reviewtype", "earnint_riskrating", "earnint_fraudriskscore",
    "earnint_confidencescore", "earnint_potentialoverpayment",
    "earnint_evidencestatus", "earnint_casedisposition"
) + $aiFields
$cases = @(Get-DvRows -Path "incidents?`$select=$($caseSelect -join ',')&`$filter=demo_datacustomerapplication eq $ApplicationChoiceValue and startswith(title,'EIR-2026-BULK-')&`$orderby=title")
if ($cases.Count -ne 50) {
    throw "Expected 50 bulk Cases but found $($cases.Count). No records were changed."
}

$discrepancies = @(Get-DvRows -Path "earnint_earningsdiscrepancies?`$select=earnint_earningsdiscrepancy_name,earnint_discrepancyamount,_earnint_caseid_discrepancy_value")
$evidence = @(Get-DvRows -Path "earnint_evidenceitems?`$select=earnint_evidenceitem_name,earnint_status,_earnint_caseid_evidence_value")
$findings = @(Get-DvRows -Path "earnint_investigationfindings?`$select=earnint_investigationfinding_name,earnint_findingtype,_earnint_caseid_finding_value")

Write-Host ""
Write-Host "=== Enrich Bulk Case AI Display Fields ===" -ForegroundColor Cyan
Write-Host "  Environment : $EnvironmentUrl"
Write-Host "  Bulk Cases  : $($cases.Count)"
Write-Host "  Source      : SEEDED_DEMO_ANALYSIS (no AI model call)"
if ($WhatIf) { Write-Host "  Mode        : WhatIf (no writes)" -ForegroundColor Yellow }
Write-Host ""

$updated = 0
$skipped = 0
foreach ($case in $cases) {
    $caseId = $case.incidentid.ToString()
    $profile = Get-Profile -ReviewType $case.earnint_reviewtype
    $caseDiscrepancies = @($discrepancies | Where-Object { $_._earnint_caseid_discrepancy_value -and $_._earnint_caseid_discrepancy_value.ToString() -eq $caseId })
    $caseEvidence = @($evidence | Where-Object { $_._earnint_caseid_evidence_value -and $_._earnint_caseid_evidence_value.ToString() -eq $caseId })
    $caseFindings = @($findings | Where-Object { $_._earnint_caseid_finding_value -and $_._earnint_caseid_finding_value.ToString() -eq $caseId })
    $discrepancyTotal = if ($caseDiscrepancies.Count -gt 0) {
        [decimal](($caseDiscrepancies | Measure-Object earnint_discrepancyamount -Sum).Sum)
    } else {
        [decimal]0
    }

    $evidenceSummary = if ($caseEvidence.Count -gt 0) {
        "$($caseEvidence.Count) linked evidence item(s), $($caseDiscrepancies.Count) earnings discrepancy record(s), and $($caseFindings.Count) investigation finding(s) are available. The linked discrepancy total is `$$($discrepancyTotal.ToString('N2')). Review record status and source authenticity before relying on the package."
    } else {
        "No linked evidence item is currently available. The Case requires evidence collection and source verification before a supported determination can be recorded."
    }

    $rawObject = [ordered]@{
        source = "SEEDED_DEMO_ANALYSIS"
        generated_for_demo_date = "2026-08-10"
        ai_model_called = $false
        incident_id = $caseId
        title = $case.title
        review_profile = $profile.Label
        risk_score = $case.earnint_fraudriskscore
        confidence_score = $case.earnint_confidencescore
        discrepancy_count = $caseDiscrepancies.Count
        discrepancy_total = $discrepancyTotal
        evidence_count = $caseEvidence.Count
        finding_count = $caseFindings.Count
        human_review_required = $true
    }

    $target = @{
        earnfrau_aisummary = "$($profile.Summary) Case: $($case.title)."
        earnfrau_supportingevidencesummary = $evidenceSummary
        earnfrau_nextbestaction = $profile.NextAction
        earnfrau_risksignalbreakdown = "$($profile.Risk) Current seeded risk score: $($case.earnint_fraudriskscore)."
        earnfrau_evidencegaps = $profile.Gaps
        earnfrau_confidencerationale = "$($profile.Confidence) Current seeded confidence score: $($case.earnint_confidencescore)."
        earnfrau_humanreviewnote = "Seeded demo analysis only; no AI model was called. AI-style output is triage support and must not be used as an automated fraud, eligibility, overpayment, or escalation determination. Analyst and supervisor review remain required."
        earnfrau_airawjson = ($rawObject | ConvertTo-Json -Depth 6 -Compress)
    }

    $matches = $true
    foreach ($field in $aiFields) {
        if ([string]$case.$field -cne [string]$target[$field]) {
            $matches = $false
            break
        }
    }

    if ($matches) {
        Write-Host "  [SKIPPED] $($case.title)" -ForegroundColor DarkGray
        $skipped++
    } elseif ($WhatIf) {
        Write-Host "  [WHATIF] Would populate $($case.title)" -ForegroundColor Yellow
    } else {
        Invoke-Dv -Method Patch -Path "incidents($caseId)" -Body $target | Out-Null
        Write-Host "  [UPDATED] $($case.title)" -ForegroundColor Green
        $updated++
    }
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "Preview complete. No records changed." -ForegroundColor Cyan
    exit 0
}

$validated = @(Get-DvRows -Path "incidents?`$select=incidentid,title,$($aiFields -join ',')&`$filter=demo_datacustomerapplication eq $ApplicationChoiceValue and startswith(title,'EIR-2026-BULK-')")
$validationErrors = @()
if ($validated.Count -ne 50) {
    $validationErrors += "Expected 50 enriched Cases; found $($validated.Count)."
}
foreach ($case in $validated) {
    foreach ($field in $aiFields) {
        if ([string]::IsNullOrWhiteSpace([string]$case.$field)) {
            $validationErrors += "$($case.title) has an empty $field value."
        }
    }
    try {
        $raw = $case.earnfrau_airawjson | ConvertFrom-Json
        if ($raw.source -ne "SEEDED_DEMO_ANALYSIS" -or $raw.ai_model_called -ne $false) {
            $validationErrors += "$($case.title) raw JSON does not identify seeded demo analysis."
        }
    } catch {
        $validationErrors += "$($case.title) raw JSON is invalid."
    }
}

Write-Host ""
Write-Host "=== Bulk Case AI Enrichment Complete ===" -ForegroundColor Cyan
Write-Host "  Updated    : $updated"
Write-Host "  Skipped    : $skipped"
Write-Host "  Validated  : $($validated.Count)"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Bulk Case AI enrichment validation failed with $($validationErrors.Count) error(s)."
}

Write-Host "  Validation : PASS" -ForegroundColor Green
Write-Host "  App URL    : $EnvironmentUrl/main.aspx" -ForegroundColor Cyan