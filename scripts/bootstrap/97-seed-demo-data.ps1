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
# earnint_reviewtype:        100000001=Suspicious Wage Report Review, 100000002=Unreported Earnings Review, 100000004=Late Wage Reporting Review
# earnint_discrepancytype:   100000001=Unreported Earnings, 100000003=Underreported Earnings, 100000005=Employer Mismatch
# earnint_riskrating:        100000000=Low, 100000001=Medium, 100000002=High, 100000003=Critical
# earnint_fraudlikelihood:   100000000=Low, 100000002=Medium, 100000003=Medium-High
# earnint_confidencelevel:   100000000=Low, 100000001=Moderate, 100000002=High
# earnint_casedisposition:   100000001=Request More Information, 100000002=Create Overpayment Review, 100000006=Contact Employer
# earnint_supervisorapproval: boolean
# demo_datacustomerapplication: 581180001=EarningsFraud (global choice)
$cases = @(
    @{
        title          = "EIR-2025-0041 — Hargrove, Robert — Unreported SSDI Wages Q1-Q2 2025"
        description    = "Beneficiary reported zero earned income for Jan-Jun 2025. IRS W-2 feed from Apex Logistics Inc shows `$24,800 in wages for the same period. Discrepancy flagged by automated wage comparison. Case referred to Program Integrity for review."
        prioritycode   = 1
        statuscode     = 1
        statecode      = 0
        contactName    = "Robert Hargrove"
        reviewtype         = 100000001  # Suspicious Wage Report Review
        referralsource     = 100000000  # Wage Match
        allegationtype     = 100000000  # Unreported Earnings
        discrepancytype    = 100000001  # Unreported Earnings
        riskrating         = 100000002  # High
        fraudlikelihood    = 100000003  # Medium-High
        confidencelevel    = 100000002  # High Confidence
        fraudriskscore     = 75
        confidencescore    = 78
        reviewperiodstart  = "2025-01-01"
        reviewperiodend    = "2025-06-30"
        potentialoverpayment = 12400.00
        impactedmonths       = 6
        largestvariance      = 6200.00
        evidencestatus       = 100000002  # Complete
        beneficiaryresponse  = 100000004  # No Response
        identitystatus       = 100000002  # Validated
        queueassignment      = 100000003  # High-Risk Fraud Review Queue
        casedisposition    = 100000002  # Create Overpayment Review
        finaldetermination = 100000005  # Overpayment Review Required
        supervisorreviewrequired = $true
        humanreviewrequired = $true
        supervisorapproval = $false
    }
    @{
        title          = "EIR-2025-0052 — Castillo, Maria — Dual Employer Earnings Not Reported 2024"
        description    = "SSI beneficiary failed to report part-time earnings from two employers: Sunrise Cleaning Services (`$9,200) and Metro Catering LLC (`$9,200) during tax year 2024. Total unreported wages: `$18,400. Wage statements obtained. Finding in progress."
        prioritycode   = 1
        statuscode     = 4
        statecode      = 0
        contactName    = "Maria Castillo"
        reviewtype         = 100000002  # Unreported Earnings Review
        referralsource     = 100000002  # Employer Report
        allegationtype     = 100000008  # Multiple Employer Discrepancy
        discrepancytype    = 100000001  # Unreported Earnings
        riskrating         = 100000002  # High
        fraudlikelihood    = 100000002  # Medium
        confidencelevel    = 100000001  # Moderate Confidence
        fraudriskscore     = 52
        confidencescore    = 55
        reviewperiodstart  = "2024-01-01"
        reviewperiodend    = "2024-12-31"
        potentialoverpayment = 9800.00
        impactedmonths       = 12
        largestvariance      = 4600.00
        evidencestatus       = 100000001  # In Progress
        beneficiaryresponse  = 100000001  # Requested
        identitystatus       = 100000003  # Validation Incomplete
        queueassignment      = 100000004  # Evidence Needed Queue
        casedisposition    = 100000001  # Request More Information
        finaldetermination = 100000007  # Insufficient Evidence
        supervisorreviewrequired = $false
        humanreviewrequired = $true
        supervisorapproval = $false
    }
    @{
        title          = "EIR-2025-0067 — Whitfield, James — Prior Overpayment / Q3 2025 Wage Discrepancy"
        description    = "Beneficiary has prior overpayment history (2022, `$6,400 recovered). New discrepancy identified for Q3 2025 at employer GreenPath Construction. Employer verification letter sent. Awaiting employer response within 30-day window."
        prioritycode   = 2
        statuscode     = 2
        statecode      = 0
        contactName    = "James Whitfield"
        reviewtype         = 100000005  # Employer Wage Mismatch Review
        referralsource     = 100000009  # Internal Review
        allegationtype     = 100000005  # Employer Wage Mismatch
        discrepancytype    = 100000005  # Employer Mismatch
        riskrating         = 100000001  # Medium
        fraudlikelihood    = 100000002  # Medium
        confidencelevel    = 100000001  # Moderate Confidence
        fraudriskscore     = 48
        confidencescore    = 60
        reviewperiodstart  = "2025-07-01"
        reviewperiodend    = "2025-09-30"
        potentialoverpayment = 4300.00
        impactedmonths       = 3
        largestvariance      = 2916.67
        evidencestatus       = 100000001  # In Progress
        beneficiaryresponse  = 100000001  # Requested
        identitystatus       = 100000003  # Validation Incomplete
        queueassignment      = 100000005  # Employer Verification Queue
        casedisposition    = 100000006  # Contact Employer
        finaldetermination = 100000010  # Referred for Further Review
        supervisorreviewrequired = $false
        humanreviewrequired = $true
        supervisorapproval = $false
    }
    @{
        title          = "EIR-2025-0033 — Nguyen, Patricia — IRS 1099 vs Beneficiary Statement Conflict"
        description    = "IRS 1099 data shows `$11,600 in self-employment income for 2024. Beneficiary statement claims income was a gift/loan, not wages. Field office referred for formal integrity review. Case resolved: overpayment review initiated per supervisor approval."
        prioritycode   = 2
        statuscode     = 5
        statecode      = 1
        contactName    = "Patricia Nguyen"
        reviewtype         = 100000004  # Late Wage Reporting Review
        referralsource     = 100000006  # Field Office
        allegationtype     = 100000002  # Late-Reported Earnings
        discrepancytype    = 100000004  # Late-Reported Earnings
        riskrating         = 100000003  # Critical
        fraudlikelihood    = 100000000  # Low
        confidencelevel    = 100000002  # High Confidence
        fraudriskscore     = 22
        confidencescore    = 82
        reviewperiodstart  = "2024-01-01"
        reviewperiodend    = "2024-12-31"
        potentialoverpayment = 1800.00
        impactedmonths       = 2
        largestvariance      = 900.00
        evidencestatus       = 100000002  # Complete
        beneficiaryresponse  = 100000002  # Received
        identitystatus       = 100000002  # Validated
        queueassignment      = 100000010  # Closed / Monitoring Queue
        casedisposition    = 100000002  # Create Overpayment Review
        finaldetermination = 100000003  # Late Reporting Confirmed
        supervisorreviewrequired = $false
        humanreviewrequired = $true
        supervisorapproval = $true
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
            demo_datacustomerapplication = 581180001
            earnint_reviewtype       = $c.reviewtype
            earnint_referralsource   = $c.referralsource
            earnint_allegationtype   = $c.allegationtype
            earnint_discrepancytype    = $c.discrepancytype
            earnint_riskrating         = $c.riskrating
            earnint_fraudriskscore     = $c.fraudriskscore
            earnint_fraudlikelihood    = $c.fraudlikelihood
            earnint_confidencescore    = $c.confidencescore
            earnint_confidencelevel    = $c.confidencelevel
            earnint_reviewperiodstart  = $c.reviewperiodstart
            earnint_reviewperiodend    = $c.reviewperiodend
            earnint_potentialoverpayment = $c.potentialoverpayment
            earnint_impactedmonthcount   = $c.impactedmonths
            earnint_largestmonthlyvariance = $c.largestvariance
            earnint_evidencestatus      = $c.evidencestatus
            earnint_beneficiaryresponsestatus = $c.beneficiaryresponse
            earnint_identityvalidationstatus = $c.identitystatus
            earnint_queueassignment     = $c.queueassignment
            earnint_casedisposition    = $c.casedisposition
            earnint_finaldetermination = $c.finaldetermination
            earnint_supervisorreviewrequired = $c.supervisorreviewrequired
            earnint_humanreviewrequired      = $c.humanreviewrequired
            earnint_supervisorapproval = $c.supervisorapproval
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
# earnint_evidencetype values: 100000000=Wage Report, 100000001=Suspicious Wage Report,
#                              100000002=Employer Wage Confirmation, 100000004=W-2/Tax Wage,
#                              100000005=Beneficiary Statement, 100000016=Data Match Record
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 4: Evidence Items ---" -ForegroundColor Yellow

$evidenceItems = @(
    @{ contactName="Robert Hargrove";  name="Hargrove — Wage Match Intake";           type=100000001; status=100000003; support=100000005; received="2025-07-09"; doc="WageMatch_Hargrove_2025Q2.xml";             verifiedby="J. Reyes, Analyst"; desc="Suspicious wage report received from automated wage match feed showing unreported wages."; notes="Primary intake artifact for suspicious wage signal." }
    @{ contactName="Robert Hargrove";  name="Hargrove — IRS W-2 2025 Q1-Q2";          type=100000004; status=100000003; support=100000000; received="2025-07-10"; doc="W2_Hargrove_Apex_2025.pdf";                  verifiedby="J. Reyes, Analyst"; desc="IRS W-2 wage record from Apex Logistics Inc. Shows `$24,800 in wages for Jan-Jun 2025."; notes="Supports discrepancy finding." }
    @{ contactName="Robert Hargrove";  name="Hargrove — Employer Confirmation";       type=100000002; status=100000003; support=100000002; received="2025-07-12"; doc="EmployerConf_Apex_Hargrove.pdf";              verifiedby="J. Reyes, Analyst"; desc="Apex Logistics Inc confirmed Robert Hargrove as active employee Jan-Jun 2025."; notes="Corroborates employer wage record." }
    @{ contactName="Robert Hargrove";  name="Hargrove — Beneficiary Statement";       type=100000005; status=100000002; support=100000008; received="2025-07-15"; doc="BeneStatement_Hargrove_Jul2025.pdf";         verifiedby="";                  desc="Beneficiary claims wages belonged to a family member. Under review for credibility."; notes="Contradictory statement, follow-up needed." }
    @{ contactName="Maria Castillo";   name="Castillo — Wage Statement Sunrise";      type=100000000; status=100000003; support=100000000; received="2025-06-10"; doc="WageStmt_Castillo_Sunrise_2024.pdf";          verifiedby="T. Morales, Analyst"; desc="Employer-provided wage statement from Sunrise Cleaning Services. Total: `$9,200."; notes="Verified against employer records." }
    @{ contactName="Maria Castillo";   name="Castillo — Wage Statement Metro";        type=100000000; status=100000003; support=100000000; received="2025-06-11"; doc="WageStmt_Castillo_Metro_2024.pdf";            verifiedby="T. Morales, Analyst"; desc="Employer-provided wage statement from Metro Catering LLC. Total: `$9,200."; notes="Verified against payroll letter." }
    @{ contactName="Maria Castillo";   name="Castillo — Data Match Record 2024";      type=100000016; status=100000001; support=100000009; received="2025-06-12"; doc="DataMatch_Castillo_2024.json";                verifiedby="";                  desc="Third-party data match output confirms dual-employer wages for 2024."; notes="Requires additional beneficiary response." }
    @{ contactName="James Whitfield";  name="Whitfield — IRS W-2 Q3 2025";            type=100000004; status=100000001; support=100000009; received="2025-07-10"; doc="W2_Whitfield_GreenPath_Q3_2025.pdf";          verifiedby="";                  desc="IRS wage feed shows `$8,750 paid by GreenPath Construction Q3 2025."; notes="Waiting on employer confirmation response." }
    @{ contactName="Patricia Nguyen";  name="Nguyen — Corrected Wage Report";         type=100000000; status=100000003; support=100000003; received="2025-06-21"; doc="CorrectedWage_Nguyen_2024.pdf";               verifiedby="S. Kim, Supervisor"; desc="Corrected wage report confirms late-reported income that now matches employer data."; notes="Supports administrative correction path." }
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
            earnint_status                     = $e.status
            earnint_supportsfinding            = $e.support
            earnint_receiveddate               = $e.received
            earnint_documentname               = $e.doc
            earnint_evidencedesc               = $e.desc
            earnint_notes                      = $e.notes
            "earnint_caseid_evidence@odata.bind" = "/incidents($caseId)"
        }
        if ($e.verifiedby) { $body["earnint_verifiedby"] = $e.verifiedby }
        Invoke-Dv -Method "POST" -Path "earnint_evidenceitems" -Body $body | Out-Null
        Write-Result "Evidence" $e.name $true
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — INVESTIGATION FINDINGS
# earnint_findingtype:   100000005=Late Reporting, 100000006=Potential Overpayment,
#                        100000007=Potential Fraud, 100000010=Insufficient Evidence
# earnint_supervisorapprovalstatus: 100000000=Pending, 100000001=Approved
# ══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "--- Step 5: Investigation Findings ---" -ForegroundColor Yellow

$findings = @(
    @{
        contactName   = "Robert Hargrove"
        name          = "Hargrove — Finding: Discrepancy Confirmed — Pending Supervisor"
        findingtype   = 100000007
        disposition   = 100000002
        severity      = 100000002
        approvalstatus = 100000000
        analyst       = "J. Reyes"
        recommendation = "Request beneficiary wage clarification, keep overpayment packet ready, and route to supervisor approval queue."
        supervisorcomments = "Pending supervisor review package."
        details       = "Earnings discrepancy of `$24,800 confirmed across Q1 and Q2 2025. Beneficiary statement not credible. Employer confirmation received and verified. Recommended action: initiate overpayment review for SSDI benefit adjustment. Case ready for supervisor approval."
    }
    @{
        contactName   = "Maria Castillo"
        name          = "Castillo — Finding: Dual Employer Wages — In Progress"
        findingtype   = 100000010
        disposition   = 100000001
        severity      = 100000001
        approvalstatus = 100000000
        analyst       = "T. Morales"
        recommendation = "Collect beneficiary written response and verify identity linkage before final determination."
        supervisorcomments = "Not ready for approval; evidence package still incomplete."
        details       = "Both employer wage statements received and verified. Total unreported earnings for 2024: `$18,400. Tax return confirms dual employment. Analyst is completing evidence package before submitting for supervisor review. RFI may be issued to beneficiary to explain non-reporting."
    }
    @{
        contactName   = "Patricia Nguyen"
        name          = "Nguyen — Finding: Late Reporting Confirmed — Supervisor Approved"
        findingtype   = 100000005
        disposition   = 100000002
        severity      = 100000000
        approvalstatus = 100000001
        analyst       = "S. Kim"
        recommendation = "Close as late-reporting correction with monitoring; overpayment review remains documented for audit history."
        supervisorcomments = "Approved for closure and monitoring queue placement."
        details       = "Earnings were reported late but now match employer data and corrected records. No intentional misrepresentation pattern found. Case resolved with documented review trail."
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
            earnint_severity                  = $f.severity
            earnint_recddisposition           = $f.disposition
            earnint_recommendation            = $f.recommendation
            earnint_supervisorapprovalstatus  = $f.approvalstatus
            earnint_supervisorcomments        = $f.supervisorcomments
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
