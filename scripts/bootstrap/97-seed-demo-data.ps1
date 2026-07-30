<#
.SYNOPSIS
    Seeds realistic SSA Earnings Integrity demo data into Dataverse.
    Safe to rerun — checks for existing records by title/name before creating.

.DESCRIPTION
    Creates:
      - 4 Contact records (beneficiaries)
      - 4 Case (incident) records at different lifecycle stages
      - Earnings Discrepancy records per case
      - Evidence Item records per case
      - Investigation Finding records per case (staged for demo)

.EXAMPLE
    pwsh ./scripts/bootstrap/97-seed-demo-data.ps1
    pwsh ./scripts/bootstrap/97-seed-demo-data.ps1 -WhatIf
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Load session env ────────────────────────────────────────────────────────
$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    Write-Host "Environment URL required. Run 10-auth-connect.ps1 first." -ForegroundColor Red
    exit 1
}

# ── Token helper ─────────────────────────────────────────────────────────────
function Get-Token {
    $t = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
    if ([string]::IsNullOrWhiteSpace($t)) { throw "Could not get access token. Re-run 10-auth-connect.ps1." }
    return $t.Trim()
}

# ── REST helper ───────────────────────────────────────────────────────────────
function Invoke-Dv {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $token = Get-Token
    $headers = @{
        "Authorization"    = "Bearer $token"
        "Content-Type"     = "application/json"
        "OData-Version"    = "4.0"
        "OData-MaxVersion" = "4.0"
        "Prefer"           = "return=representation"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
}

# ── Idempotent lookup helper ──────────────────────────────────────────────────
function Find-Record {
    param([string]$Entity, [string]$Filter, [string]$Select)
    $result = Invoke-Dv -Method "GET" -Path "${Entity}?`$filter=${Filter}&`$select=${Select}&`$top=1"
    if ($result.value.Count -gt 0) { return $result.value[0] }
    return $null
}

# ── Counters ──────────────────────────────────────────────────────────────────
$created = 0; $skipped = 0; $failed = 0

function Write-Result([string]$Type, [string]$Label, [bool]$IsNew) {
    if ($IsNew) {
        Write-Host "  [CREATED] $Type - $Label" -ForegroundColor Green
        $script:created++
    } else {
        Write-Host "  [SKIPPED] $Type - $Label (already exists)" -ForegroundColor DarkGray
        $script:skipped++
    }
}

# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "=== SSA Earnings Integrity — Demo Data Seed ===" -ForegroundColor Cyan
Write-Host "  Environment : $EnvironmentUrl"
if ($WhatIf) { Write-Host "  Mode        : WhatIf (no writes)" -ForegroundColor Yellow }
Write-Host ""

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — CONTACTS (beneficiaries)
# ══════════════════════════════════════════════════════════════════════════════
Write-Host "--- Step 1: Contacts (Beneficiaries) ---" -ForegroundColor Yellow

$contacts = @(
    @{ firstname="Robert";   lastname="Hargrove";  email="r.hargrove@demo.ssa.gov";  phone="(202) 555-0101"; description="SSDI beneficiary. Reported zero earnings Jan–Jun 2025. W-2 from employer conflicts with SSA wage feed." }
    @{ firstname="Maria";    lastname="Castillo";  email="m.castillo@demo.ssa.gov";  phone="(202) 555-0142"; description="SSI beneficiary. Wage statements from two part-time employers show `$18,400 unreported for tax year 2024." }
    @{ firstname="James";    lastname="Whitfield"; email="j.whitfield@demo.ssa.gov"; phone="(202) 555-0178"; description="SSDI beneficiary. Prior overpayment 2022. Employer verification pending for Q3 2025 wage discrepancy." }
    @{ firstname="Patricia"; lastname="Nguyen";    email="p.nguyen@demo.ssa.gov";    phone="(202) 555-0215"; description="SSI beneficiary. Beneficiary statement conflicts with IRS 1099 data. Case referred by field office." }
)

$contactIds = @{}
foreach ($c in $contacts) {
    $fullName = "$($c.firstname) $($c.lastname)"
    if ($WhatIf) { Write-Host "  [WHATIF] Would create Contact: $fullName"; continue }
    $existing = Find-Record -Entity "contacts" -Filter "firstname eq '$($c.firstname)' and lastname eq '$($c.lastname)'" -Select "contactid,fullname"
    if ($null -ne $existing) {
        $contactIds[$fullName] = $existing.contactid
        Write-Result "Contact" $fullName $false
    } else {
        $body = @{
            firstname   = $c.firstname
            lastname    = $c.lastname
            emailaddress1 = $c.email
            telephone1  = $c.phone
            description = $c.description
        }
        $rec = Invoke-Dv -Method "POST" -Path "contacts" -Body $body
        $contactIds[$fullName] = $rec.contactid
        Write-Result "Contact" $fullName $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — CASES (incident)
# Stage mapping:
#   Case 1: Active / In Progress         – Hargrove       – full evidence, finding pending supervisor
#   Case 2: Active / Researching         – Castillo       – evidence collected, finding in progress
#   Case 3: Active / On Hold             – Whitfield      – triage complete, awaiting employer reply
#   Case 4: Resolved / Problem Solved    – Nguyen         – closed with overpayment review initiated
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 2: Cases (Incidents) ---" -ForegroundColor Yellow

# statuscode: 1=In Progress, 2=On Hold, 4=Researching, 5=Problem Solved
# statecode:  0=Active, 1=Resolved
# prioritycode: 1=High, 2=Normal, 3=Low
$cases = @(
    @{
        title        = "EIR-2025-0041 — Hargrove, Robert — Unreported SSDI Wages Q1-Q2 2025"
        description  = "Beneficiary reported zero earned income for Jan-Jun 2025. IRS W-2 feed from Apex Logistics Inc shows `$24,800 in wages for the same period. Discrepancy flagged by automated wage comparison. Case referred to Program Integrity for review."
        prioritycode = 1
        statuscode   = 1
        statecode    = 0
        contactName  = "Robert Hargrove"
    }
    @{
        title        = "EIR-2025-0052 — Castillo, Maria — Dual Employer Earnings Not Reported 2024"
        description  = "SSI beneficiary failed to report part-time earnings from two employers: Sunrise Cleaning Services (`$9,200) and Metro Catering LLC (`$9,200) during tax year 2024. Total unreported wages: `$18,400. Wage statements obtained. Finding in progress."
        prioritycode = 1
        statuscode   = 4
        statecode    = 0
        contactName  = "Maria Castillo"
    }
    @{
        title        = "EIR-2025-0067 — Whitfield, James — Prior Overpayment / Q3 2025 Wage Discrepancy"
        description  = "Beneficiary has prior overpayment history (2022, `$6,400 recovered). New discrepancy identified for Q3 2025 at employer GreenPath Construction. Employer verification letter sent. Awaiting employer response within 30-day window."
        prioritycode = 2
        statuscode   = 2
        statecode    = 0
        contactName  = "James Whitfield"
    }
    @{
        title        = "EIR-2025-0033 — Nguyen, Patricia — IRS 1099 vs Beneficiary Statement Conflict"
        description  = "IRS 1099 data shows `$11,600 in self-employment income for 2024. Beneficiary statement claims income was a gift/loan, not wages. Field office referred for formal integrity review. Case resolved: overpayment review initiated per supervisor approval."
        prioritycode = 2
        statuscode   = 5
        statecode    = 1
        contactName  = "Patricia Nguyen"
    }
)

$caseIds = @{}
foreach ($c in $cases) {
    if ($WhatIf) { Write-Host "  [WHATIF] Would create Case: $($c.title)"; continue }
    $safeTitle = $c.title.Replace("'", "''")
    $existing = Find-Record -Entity "incidents" -Filter "title eq '$safeTitle'" -Select "incidentid,title"
    if ($null -ne $existing) {
        $caseIds[$c.contactName] = $existing.incidentid
        Write-Result "Case" $c.title $false
    } else {
        # Always create active; resolve separately if needed
        $createStatusCode = if ($c.statecode -eq 1) { 1 } else { $c.statuscode }
        $body = @{
            title        = $c.title
            description  = $c.description
            prioritycode = $c.prioritycode
            statuscode   = $createStatusCode
            casetypecode = 2   # Problem
        }
        if ($contactIds.ContainsKey($c.contactName)) {
            $body["customerid_contact@odata.bind"] = "/contacts($($contactIds[$c.contactName]))"
        }
        $rec = Invoke-Dv -Method "POST" -Path "incidents" -Body $body
        $caseIds[$c.contactName] = $rec.incidentid
        Write-Result "Case" $c.title $true

        # Resolve case 4 immediately after creation
        if ($c.statecode -eq 1) {
            $resolution = @{
                incidentresolution = @{
                    subject = "Overpayment Review Initiated"
                    "incidentid@odata.bind" = "/incidents($($rec.incidentid))"
                }
                status = 5
                billedtime = 0
                timespent  = 0
            }
            try { Invoke-Dv -Method "POST" -Path "incidents($($rec.incidentid))/Microsoft.Dynamics.CRM.CloseIncident" -Body $resolution | Out-Null }
            catch { Write-Host "    (Note: resolve step skipped - may need manual resolve in portal)" -ForegroundColor DarkYellow }
        }
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — EARNINGS DISCREPANCIES
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 3: Earnings Discrepancies ---" -ForegroundColor Yellow

$discrepancies = @(
    @{ contactName="Robert Hargrove";  name="Hargrove — Q1 2025 Wage Discrepancy";    reported=0;      authoritative=12400.00; discrepancy=12400.00; period="Q1 2025"; employer="Apex Logistics Inc";       source="IRS Wage Feed W-2" }
    @{ contactName="Robert Hargrove";  name="Hargrove — Q2 2025 Wage Discrepancy";    reported=0;      authoritative=12400.00; discrepancy=12400.00; period="Q2 2025"; employer="Apex Logistics Inc";       source="IRS Wage Feed W-2" }
    @{ contactName="Maria Castillo";   name="Castillo — 2024 Employer 1 Discrepancy"; reported=0;      authoritative=9200.00;  discrepancy=9200.00;  period="CY 2024"; employer="Sunrise Cleaning Services"; source="Employer Wage Statement" }
    @{ contactName="Maria Castillo";   name="Castillo — 2024 Employer 2 Discrepancy"; reported=0;      authoritative=9200.00;  discrepancy=9200.00;  period="CY 2024"; employer="Metro Catering LLC";        source="Employer Wage Statement" }
    @{ contactName="James Whitfield";  name="Whitfield — Q3 2025 Wage Discrepancy";   reported=0;      authoritative=8750.00;  discrepancy=8750.00;  period="Q3 2025"; employer="GreenPath Construction";    source="IRS Wage Feed W-2" }
    @{ contactName="Patricia Nguyen";  name="Nguyen — 2024 Self-Employment Income";   reported=0;      authoritative=11600.00; discrepancy=11600.00; period="CY 2024"; employer="Self-employed";             source="IRS 1099-NEC" }
)

foreach ($d in $discrepancies) {
    if ($WhatIf) { Write-Host "  [WHATIF] Would create Discrepancy: $($d.name)"; continue }
    if (-not $caseIds.ContainsKey($d.contactName)) { Write-Host "  [SKIP] No case found for $($d.contactName)" -ForegroundColor DarkYellow; continue }
    $safeName = $d.name.Replace("'", "''")
    $caseId   = $caseIds[$d.contactName]
    $existing = Find-Record -Entity "earnint_earningsdiscrepancies" -Filter "earnint_earningsdiscrepancy_name eq '$safeName'" -Select "earnint_earningsdiscrepancyid"
    if ($null -ne $existing) {
        Write-Result "Discrepancy" $d.name $false
    } else {
        $body = @{
            earnint_earningsdiscrepancy_name               = $d.name
            earnint_reportedearnings               = $d.reported
            earnint_authoritativeearnings          = $d.authoritative
            earnint_discrepancyamount              = $d.discrepancy
            earnint_earningsperiod                 = $d.period
            earnint_employername                   = $d.employer
            earnint_sourcesystem                   = $d.source
            "earnint_caseid_discrepancy@odata.bind" = "/incidents($caseId)"
        }
        Invoke-Dv -Method "POST" -Path "earnint_earningsdiscrepancies" -Body $body | Out-Null
        Write-Result "Discrepancy" $d.name $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — EVIDENCE ITEMS
# earnint_evidencetype values: 100000000=Tax Return, 100000001=W-2, 100000002=1099,
#                              100000003=Wage Statement, 100000004=Beneficiary Statement,
#                              100000005=Employer Confirmation, 100000006=Other
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 4: Evidence Items ---" -ForegroundColor Yellow

$evidenceItems = @(
    @{ contactName="Robert Hargrove";  name="Hargrove — IRS W-2 2025 Q1-Q2";        type=100000001; doc="W2_Hargrove_Apex_2025.pdf";            verifiedby="J. Reyes, Analyst"; desc="IRS W-2 wage record from Apex Logistics Inc. Shows `$24,800 in wages for Jan-Jun 2025. Conflicts with zero-income SSA report." }
    @{ contactName="Robert Hargrove";  name="Hargrove — Beneficiary Statement";       type=100000004; doc="BeneStatement_Hargrove_Jul2025.pdf";   verifiedby="";                  desc="Written statement submitted by beneficiary claiming wages belonged to a family member. Under review for credibility." }
    @{ contactName="Robert Hargrove";  name="Hargrove — Employer Confirmation";       type=100000005; doc="EmployerConf_Apex_Hargrove.pdf";        verifiedby="J. Reyes, Analyst"; desc="Apex Logistics Inc confirmed Robert Hargrove as active employee Jan–Jun 2025. Confirms W-2 wage amounts." }
    @{ contactName="Maria Castillo";   name="Castillo — Wage Statement Sunrise";      type=100000003; doc="WageStmt_Castillo_Sunrise_2024.pdf";    verifiedby="T. Morales, Analyst"; desc="Employer-provided wage statement from Sunrise Cleaning Services. Covers all four quarters 2024. Total: `$9,200." }
    @{ contactName="Maria Castillo";   name="Castillo — Wage Statement Metro";        type=100000003; doc="WageStmt_Castillo_Metro_2024.pdf";      verifiedby="T. Morales, Analyst"; desc="Employer-provided wage statement from Metro Catering LLC. Covers Q2-Q4 2024. Total: `$9,200." }
    @{ contactName="Maria Castillo";   name="Castillo — Tax Return 2024 (1040)";      type=100000000; doc="TaxReturn_Castillo_2024_1040.pdf";      verifiedby="";                  desc="IRS 1040 return for 2024 obtained via third-party data match. Wage income line confirms `$18,400 from dual employment." }
    @{ contactName="James Whitfield";  name="Whitfield — IRS W-2 Q3 2025";           type=100000001; doc="W2_Whitfield_GreenPath_Q3_2025.pdf";    verifiedby="";                  desc="IRS wage feed shows `$8,750 paid by GreenPath Construction Q3 2025. Employer verification letter sent 2025-07-10. Response pending." }
    @{ contactName="Patricia Nguyen";  name="Nguyen — IRS 1099-NEC 2024";            type=100000002; doc="1099NEC_Nguyen_2024.pdf";               verifiedby="S. Kim, Supervisor"; desc="IRS 1099-NEC shows `$11,600 in nonemployee compensation for 2024. Source: field services contractor." }
    @{ contactName="Patricia Nguyen";  name="Nguyen — Beneficiary Written Statement"; type=100000004; doc="BeneStatement_Nguyen_Jun2025.pdf";      verifiedby="S. Kim, Supervisor"; desc="Beneficiary claims 1099 income was a personal loan repayment, not earned wages. Statement not credible per supervisor review." }
)

foreach ($e in $evidenceItems) {
    if ($WhatIf) { Write-Host "  [WHATIF] Would create Evidence: $($e.name)"; continue }
    if (-not $caseIds.ContainsKey($e.contactName)) { Write-Host "  [SKIP] No case for $($e.contactName)" -ForegroundColor DarkYellow; continue }
    $safeName = $e.name.Replace("'", "''")
    $caseId   = $caseIds[$e.contactName]
    $existing = Find-Record -Entity "earnint_evidenceitems" -Filter "earnint_evidenceitem_name eq '$safeName'" -Select "earnint_evidenceitemid"
    if ($null -ne $existing) {
        Write-Result "Evidence" $e.name $false
    } else {
        $body = @{
            earnint_evidenceitem_name                  = $e.name
            earnint_evidencetype               = $e.type
            earnint_documentname               = $e.doc
            earnint_evidencedesc               = $e.desc
            "earnint_caseid_evidence@odata.bind" = "/incidents($caseId)"
        }
        if ($e.verifiedby) { $body["earnint_verifiedby"] = $e.verifiedby }
        Invoke-Dv -Method "POST" -Path "earnint_evidenceitems" -Body $body | Out-Null
        Write-Result "Evidence" $e.name $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — INVESTIGATION FINDINGS
# earnint_findingtype:   100000000=Discrepancy Confirmed, 100000001=Resolved,
#                        100000002=Unresolved, 100000003=Possible Fraud, 100000004=No Issue
# earnint_recddisposition: 100000000=Close, 100000001=RFI, 100000002=Overpayment Review,
#                          100000003=Escalate Fraud
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 5: Investigation Findings ---" -ForegroundColor Yellow

$findings = @(
    @{
        contactName   = "Robert Hargrove"
        name          = "Hargrove — Finding: Discrepancy Confirmed — Pending Supervisor"
        findingtype   = 100000000
        disposition   = 100000002
        analyst       = "J. Reyes"
        details       = "Earnings discrepancy of `$24,800 confirmed across Q1 and Q2 2025. Beneficiary statement not credible. Employer confirmation received and verified. Recommended action: initiate overpayment review for SSDI benefit adjustment. Case ready for supervisor approval."
    }
    @{
        contactName   = "Maria Castillo"
        name          = "Castillo — Finding: Dual Employer Wages — In Progress"
        findingtype   = 100000000
        disposition   = 100000001
        analyst       = "T. Morales"
        details       = "Both employer wage statements received and verified. Total unreported earnings for 2024: `$18,400. Tax return confirms dual employment. Analyst is completing evidence package before submitting for supervisor review. RFI may be issued to beneficiary to explain non-reporting."
    }
    @{
        contactName   = "Patricia Nguyen"
        name          = "Nguyen — Finding: Fraud Indicator — Supervisor Approved"
        findingtype   = 100000003
        disposition   = 100000002
        analyst       = "S. Kim"
        details       = "Beneficiary claim that 1099 income was a loan repayment is not substantiated. IRS 1099-NEC confirmed as valid income. Pattern consistent with prior SSI underreporting. Supervisor approved overpayment review. Case resolved and overpayment review initiated. Benefit adjustment pending."
    }
)

foreach ($f in $findings) {
    if ($WhatIf) { Write-Host "  [WHATIF] Would create Finding: $($f.name)"; continue }
    if (-not $caseIds.ContainsKey($f.contactName)) { Write-Host "  [SKIP] No case for $($f.contactName)" -ForegroundColor DarkYellow; continue }
    $safeName = $f.name.Replace("'", "''")
    $caseId   = $caseIds[$f.contactName]
    $existing = Find-Record -Entity "earnint_investigationfindings" -Filter "earnint_investigationfinding_name eq '$safeName'" -Select "earnint_investigationfindingid"
    if ($null -ne $existing) {
        Write-Result "Finding" $f.name $false
    } else {
        $body = @{
            earnint_investigationfinding_name         = $f.name
            earnint_findingtype               = $f.findingtype
            earnint_recddisposition           = $f.disposition
            earnint_analystname               = $f.analyst
            earnint_findingdetails            = $f.details
            "earnint_caseid_finding@odata.bind" = "/incidents($caseId)"
        }
        Invoke-Dv -Method "POST" -Path "earnint_investigationfindings" -Body $body | Out-Null
        Write-Result "Finding" $f.name $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "=== Seed Complete ===" -ForegroundColor Cyan
Write-Host ("  Created : {0}" -f $created) -ForegroundColor Green
Write-Host ("  Skipped : {0}" -f $skipped) -ForegroundColor DarkGray
Write-Host ("  Failed  : {0}" -f $failed) -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "DarkGray" })
Write-Host ""
if (-not $WhatIf) {
    Write-Host "App URL: $($EnvironmentUrl.TrimEnd('/'))/main.aspx" -ForegroundColor Cyan
    Write-Host "Open the 'Earnings Integrity V2 Demo App' from the app switcher." -ForegroundColor Cyan
}
Write-Host ""
