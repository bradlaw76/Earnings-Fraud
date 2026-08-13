<#
.SYNOPSIS
    Creates a deterministic bulk demo-data batch for the Earnings Fraud app.

.DESCRIPTION
    Reuses Contacts already linked to EIR Cases. Creates 50 Cases by default and
    adds one discrepancy, evidence item, and finding to the final 25 Cases.
    Safe to rerun because every generated record has a deterministic unique name.

.EXAMPLE
    pwsh ./scripts/bootstrap/107-seed-bulk-demo-data.ps1 -WhatIf
    pwsh ./scripts/bootstrap/107-seed-bulk-demo-data.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [ValidateRange(1, 500)]
    [int]$CaseCount = 50,
    [ValidateRange(0, 500)]
    [int]$ChildCaseCount = 25,
    [int]$ApplicationChoiceValue = 581180001,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($ChildCaseCount -gt $CaseCount) {
    throw "ChildCaseCount cannot exceed CaseCount."
}

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
    Prefer             = "return=representation"
}

function Invoke-Dv {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )

    $uri = "$EnvironmentUrl/api/data/v9.2/$Path"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if ($null -eq $Body) {
                return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
            }
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
        } catch {
            $statusCode = [int]$_.Exception.Response.StatusCode
            if ($attempt -eq 5 -or $statusCode -notin @(429, 502, 503, 504)) {
                throw
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
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

function Escape-ODataString {
    param([Parameter(Mandatory)][string]$Value)
    return $Value.Replace("'", "''")
}

function Find-Record {
    param(
        [Parameter(Mandatory)][string]$EntitySet,
        [Parameter(Mandatory)][string]$Filter,
        [Parameter(Mandatory)][string]$Select
    )

    $result = Invoke-Dv -Method Get -Path "${EntitySet}?`$filter=${Filter}&`$select=${Select}&`$top=1"
    return @($result.value | Select-Object -First 1)
}

function Write-Action {
    param([string]$Action, [string]$Type, [string]$Label)
    Write-Host ("  [{0}] {1} - {2}" -f $Action, $Type, $Label) -ForegroundColor $(
        if ($Action -eq "CREATED" -or $Action -eq "UPDATED") { "Green" }
        elseif ($Action -eq "WHATIF") { "Yellow" }
        else { "DarkGray" }
    )
}

$batchPrefix = "EIR-2026-BULK-"
$childStartIndex = $CaseCount - $ChildCaseCount + 1
$counts = [ordered]@{
    CasesCreated = 0
    CasesSkipped = 0
    CasesUpdated = 0
    DiscrepanciesCreated = 0
    DiscrepanciesSkipped = 0
    EvidenceCreated = 0
    EvidenceSkipped = 0
    FindingsCreated = 0
    FindingsSkipped = 0
}

Write-Host ""
Write-Host "=== Earnings Fraud Bulk Demo Data ===" -ForegroundColor Cyan
Write-Host "  Environment       : $EnvironmentUrl"
Write-Host "  Cases             : $CaseCount"
Write-Host "  Cases with children: $ChildCaseCount"
Write-Host "  Application choice: $ApplicationChoiceValue"
if ($WhatIf) {
    Write-Host "  Mode              : WhatIf (no writes)" -ForegroundColor Yellow
}

# Reuse only Contacts that are already linked to existing EIR Cases.
$existingEirCases = @(Get-DvRows -Path "incidents?`$select=incidentid,title,_customerid_value,demo_datacustomerapplication&`$filter=startswith(title,'EIR-')")
$contactIds = @($existingEirCases |
    Where-Object { $null -ne $_._customerid_value } |
    ForEach-Object { $_._customerid_value.ToString() } |
    Sort-Object -Unique)

if ($contactIds.Count -eq 0) {
    throw "No Contacts are linked to existing EIR Cases. No records were changed."
}

$contacts = foreach ($contactId in $contactIds) {
    $result = Invoke-Dv -Method Get -Path "contacts($contactId)?`$select=contactid,fullname,firstname,lastname"
    [pscustomobject]@{
        contactid = $result.contactid
        fullname = $result.fullname
        firstname = $result.firstname
        lastname = $result.lastname
    }
}
$contacts = @($contacts | Sort-Object fullname)

Write-Host ""
Write-Host "Existing Contacts selected ($($contacts.Count)):" -ForegroundColor Yellow
$contacts | ForEach-Object { Write-Host "  $($_.fullname)" }

# Correct the previously seeded Patricia Nguyen Case, as approved.
$patriciaTitle = "EIR-2025-0033 - Nguyen, Patricia - IRS 1099 vs Beneficiary Statement Conflict"
$patricia = @($existingEirCases | Where-Object { $_.title -like "EIR-2025-0033*Nguyen, Patricia*" } | Select-Object -First 1)
if ($patricia.Count -eq 1 -and $patricia[0].demo_datacustomerapplication -ne $ApplicationChoiceValue) {
    if ($WhatIf) {
        Write-Action -Action "WHATIF" -Type "Case correction" -Label $patricia[0].title
    } else {
        Invoke-Dv -Method Patch -Path "incidents($($patricia[0].incidentid))" -Body @{
            demo_datacustomerapplication = $ApplicationChoiceValue
        } | Out-Null
        Write-Action -Action "UPDATED" -Type "Case correction" -Label $patricia[0].title
        $counts.CasesUpdated++
    }
}

$profiles = @(
    @{
        label = "Unreported Earnings Review"; priority = 1; status = 1
        review = 100000001; referral = 100000000; allegation = 100000000; discrepancy = 100000001
        risk = 100000002; likelihood = 100000003; confidence = 100000002; riskScore = 76; confidenceScore = 82
        evidenceStatus = 100000002; beneficiaryResponse = 100000004; identityStatus = 100000002
        queue = 100000003; disposition = 100000002; determination = 100000005
        supervisorRequired = $true; supervisorApproval = $false; amount = 12400.00; months = 6
    },
    @{
        label = "Multiple Employer Review"; priority = 1; status = 4
        review = 100000002; referral = 100000002; allegation = 100000008; discrepancy = 100000001
        risk = 100000002; likelihood = 100000002; confidence = 100000001; riskScore = 58; confidenceScore = 64
        evidenceStatus = 100000001; beneficiaryResponse = 100000001; identityStatus = 100000003
        queue = 100000004; disposition = 100000001; determination = 100000007
        supervisorRequired = $false; supervisorApproval = $false; amount = 9200.00; months = 12
    },
    @{
        label = "Employer Wage Mismatch Review"; priority = 2; status = 2
        review = 100000005; referral = 100000009; allegation = 100000005; discrepancy = 100000002
        risk = 100000001; likelihood = 100000002; confidence = 100000001; riskScore = 46; confidenceScore = 61
        evidenceStatus = 100000001; beneficiaryResponse = 100000001; identityStatus = 100000003
        queue = 100000005; disposition = 100000006; determination = 100000010
        supervisorRequired = $false; supervisorApproval = $false; amount = 8750.00; months = 3
    },
    @{
        label = "Late Wage Reporting Review"; priority = 2; status = 1
        review = 100000004; referral = 100000006; allegation = 100000002; discrepancy = 100000004
        risk = 100000000; likelihood = 100000000; confidence = 100000002; riskScore = 24; confidenceScore = 84
        evidenceStatus = 100000002; beneficiaryResponse = 100000002; identityStatus = 100000002
        queue = 100000010; disposition = 100000004; determination = 100000003
        supervisorRequired = $false; supervisorApproval = $true; amount = 3600.00; months = 2
    }
)

$batchCases = @()
Write-Host ""
Write-Host "Cases:" -ForegroundColor Yellow
for ($index = 1; $index -le $CaseCount; $index++) {
    $sequence = $index.ToString("000")
    $contact = $contacts[($index - 1) % $contacts.Count]
    $profile = $profiles[($index - 1) % $profiles.Count]
    $title = "$batchPrefix$sequence - $($contact.lastname), $($contact.firstname) - $($profile.label)"
    $safeTitle = Escape-ODataString -Value $title
    $existing = @(Find-Record -EntitySet "incidents" -Filter "title eq '$safeTitle'" -Select "incidentid,title,demo_datacustomerapplication")

    if ($existing.Count -eq 1) {
        $caseId = $existing[0].incidentid
        if ($existing[0].demo_datacustomerapplication -ne $ApplicationChoiceValue -and -not $WhatIf) {
            Invoke-Dv -Method Patch -Path "incidents($caseId)" -Body @{
                demo_datacustomerapplication = $ApplicationChoiceValue
            } | Out-Null
            $counts.CasesUpdated++
        }
        Write-Action -Action "SKIPPED" -Type "Case" -Label $title
        $counts.CasesSkipped++
    } elseif ($WhatIf) {
        $caseId = $null
        Write-Action -Action "WHATIF" -Type "Case" -Label $title
    } else {
        $periodStart = (Get-Date "2025-01-01").AddMonths((($index - 1) % 12)).ToString("yyyy-MM-dd")
        $periodEnd = (Get-Date $periodStart).AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
        $body = @{
            title = $title
            description = "Synthetic demo Case $sequence for $($contact.fullname). Human review is required before any determination or escalation."
            prioritycode = $profile.priority
            statuscode = $profile.status
            casetypecode = 2
            demo_datacustomerapplication = $ApplicationChoiceValue
            earnint_reviewtype = $profile.review
            earnint_referralsource = $profile.referral
            earnint_allegationtype = $profile.allegation
            earnint_discrepancytype = $profile.discrepancy
            earnint_riskrating = $profile.risk
            earnint_fraudriskscore = $profile.riskScore
            earnint_fraudlikelihood = $profile.likelihood
            earnint_confidencescore = $profile.confidenceScore
            earnint_confidencelevel = $profile.confidence
            earnint_reviewperiodstart = $periodStart
            earnint_reviewperiodend = $periodEnd
            earnint_potentialoverpayment = $profile.amount
            earnint_impactedmonthcount = $profile.months
            earnint_largestmonthlyvariance = [math]::Round($profile.amount / $profile.months, 2)
            earnint_evidencestatus = $profile.evidenceStatus
            earnint_beneficiaryresponsestatus = $profile.beneficiaryResponse
            earnint_identityvalidationstatus = $profile.identityStatus
            earnint_queueassignment = $profile.queue
            earnint_casedisposition = $profile.disposition
            earnint_finaldetermination = $profile.determination
            earnint_supervisorreviewrequired = $profile.supervisorRequired
            earnint_humanreviewrequired = $true
            earnint_supervisorapproval = $profile.supervisorApproval
            "customerid_contact@odata.bind" = "/contacts($($contact.contactid))"
        }
        $createdCase = Invoke-Dv -Method Post -Path "incidents" -Body $body
        $caseId = $createdCase.incidentid
        Write-Action -Action "CREATED" -Type "Case" -Label $title
        $counts.CasesCreated++
    }

    $batchCases += [pscustomobject]@{
        Index = $index
        Id = $caseId
        Title = $title
        Contact = $contact
        Profile = $profile
    }
}

Write-Host ""
Write-Host "Custom-table records for Cases $childStartIndex through $CaseCount`:" -ForegroundColor Yellow
foreach ($case in @($batchCases | Where-Object Index -ge $childStartIndex)) {
    $sequence = $case.Index.ToString("000")
    $profile = $case.Profile
    $caseId = $case.Id

    $discrepancyName = "$batchPrefix$sequence - Earnings Discrepancy"
    $safeName = Escape-ODataString -Value $discrepancyName
    $existing = @(Find-Record -EntitySet "earnint_earningsdiscrepancies" -Filter "earnint_earningsdiscrepancy_name eq '$safeName'" -Select "earnint_earningsdiscrepancyid")
    if ($existing.Count -eq 1) {
        Write-Action -Action "SKIPPED" -Type "Discrepancy" -Label $discrepancyName
        $counts.DiscrepanciesSkipped++
    } elseif ($WhatIf) {
        Write-Action -Action "WHATIF" -Type "Discrepancy" -Label $discrepancyName
    } else {
        Invoke-Dv -Method Post -Path "earnint_earningsdiscrepancies" -Body @{
            earnint_earningsdiscrepancy_name = $discrepancyName
            earnint_discrepancytype = $profile.discrepancy
            earnint_earningsourcetype = 100000002
            earnint_reportedearnings = 0
            earnint_authoritativeearnings = $profile.amount
            earnint_discrepancyamount = $profile.amount
            earnint_discrepancypercent = 100
            earnint_earningsperiod = "Synthetic 2025 period $sequence"
            earnint_employername = "Demo Employer $sequence"
            earnint_sourcesystem = "Synthetic Wage Feed"
            earnint_requiresmanualreview = $true
            "earnint_caseid_discrepancy@odata.bind" = "/incidents($caseId)"
        } | Out-Null
        Write-Action -Action "CREATED" -Type "Discrepancy" -Label $discrepancyName
        $counts.DiscrepanciesCreated++
    }

    $evidenceName = "$batchPrefix$sequence - Wage Evidence"
    $safeName = Escape-ODataString -Value $evidenceName
    $existing = @(Find-Record -EntitySet "earnint_evidenceitems" -Filter "earnint_evidenceitem_name eq '$safeName'" -Select "earnint_evidenceitemid")
    if ($existing.Count -eq 1) {
        Write-Action -Action "SKIPPED" -Type "Evidence" -Label $evidenceName
        $counts.EvidenceSkipped++
    } elseif ($WhatIf) {
        Write-Action -Action "WHATIF" -Type "Evidence" -Label $evidenceName
    } else {
        Invoke-Dv -Method Post -Path "earnint_evidenceitems" -Body @{
            earnint_evidenceitem_name = $evidenceName
            earnint_evidencetype = 100000004
            earnint_receiveddate = (Get-Date "2026-07-01").AddDays($case.Index).ToString("yyyy-MM-dd")
            earnint_status = 100000003
            earnint_supportsfinding = 100000000
            earnint_evidencedesc = "Synthetic wage evidence supporting demo Case $sequence."
            earnint_documentname = "WageEvidence_$sequence.pdf"
            earnint_verifiedby = "Demo Data Analyst"
            earnint_notes = "Generated for demonstration and testing only."
            "earnint_caseid_evidence@odata.bind" = "/incidents($caseId)"
        } | Out-Null
        Write-Action -Action "CREATED" -Type "Evidence" -Label $evidenceName
        $counts.EvidenceCreated++
    }

    $findingName = "$batchPrefix$sequence - Investigation Finding"
    $safeName = Escape-ODataString -Value $findingName
    $existing = @(Find-Record -EntitySet "earnint_investigationfindings" -Filter "earnint_investigationfinding_name eq '$safeName'" -Select "earnint_investigationfindingid")
    if ($existing.Count -eq 1) {
        Write-Action -Action "SKIPPED" -Type "Finding" -Label $findingName
        $counts.FindingsSkipped++
    } elseif ($WhatIf) {
        Write-Action -Action "WHATIF" -Type "Finding" -Label $findingName
    } else {
        Invoke-Dv -Method Post -Path "earnint_investigationfindings" -Body @{
            earnint_investigationfinding_name = $findingName
            earnint_findingtype = 100000006
            earnint_severity = $profile.risk
            earnint_findingdetails = "Synthetic finding for demo Case $sequence. Final action remains subject to human review."
            earnint_recommendation = "Review the linked discrepancy and evidence before recording a final determination."
            earnint_recddisposition = $profile.disposition
            earnint_supervisorapprovalstatus = 100000000
            earnint_analystname = "Demo Data Analyst"
            earnint_supervisorcomments = "Pending human review."
            "earnint_caseid_finding@odata.bind" = "/incidents($caseId)"
        } | Out-Null
        Write-Action -Action "CREATED" -Type "Finding" -Label $findingName
        $counts.FindingsCreated++
    }
}

Write-Host ""
if ($WhatIf) {
    Write-Host "=== Preview Complete: No Records Changed ===" -ForegroundColor Cyan
    Write-Host "  Planned Cases         : $CaseCount"
    Write-Host "  Planned discrepancies : $ChildCaseCount"
    Write-Host "  Planned evidence items: $ChildCaseCount"
    Write-Host "  Planned findings      : $ChildCaseCount"
    Write-Host "  Planned total records : $($CaseCount + (3 * $ChildCaseCount))"
    exit 0
}

# Validate the exact generated batch and relationship coverage.
$createdCases = @(Get-DvRows -Path "incidents?`$select=incidentid,title,_customerid_value,demo_datacustomerapplication&`$filter=startswith(title,'$batchPrefix')")
$createdCaseIds = @{}
$createdCases | ForEach-Object { $createdCaseIds[$_.incidentid.ToString()] = $true }
$expectedChildCaseIds = @{}
$createdCases |
    Where-Object { [int]([regex]::Match($_.title, "BULK-(\d{3})").Groups[1].Value) -ge $childStartIndex } |
    ForEach-Object { $expectedChildCaseIds[$_.incidentid.ToString()] = $true }

$createdDiscrepancies = @(Get-DvRows -Path "earnint_earningsdiscrepancies?`$select=earnint_earningsdiscrepancyid,earnint_earningsdiscrepancy_name,_earnint_caseid_discrepancy_value&`$filter=startswith(earnint_earningsdiscrepancy_name,'$batchPrefix')")
$createdEvidence = @(Get-DvRows -Path "earnint_evidenceitems?`$select=earnint_evidenceitemid,earnint_evidenceitem_name,_earnint_caseid_evidence_value&`$filter=startswith(earnint_evidenceitem_name,'$batchPrefix')")
$createdFindings = @(Get-DvRows -Path "earnint_investigationfindings?`$select=earnint_investigationfindingid,earnint_investigationfinding_name,_earnint_caseid_finding_value&`$filter=startswith(earnint_investigationfinding_name,'$batchPrefix')")

$validationErrors = @()
if ($createdCases.Count -ne $CaseCount) { $validationErrors += "Expected $CaseCount Cases; found $($createdCases.Count)." }
if (@($createdCases | Where-Object demo_datacustomerapplication -ne $ApplicationChoiceValue).Count -gt 0) { $validationErrors += "One or more Cases has the wrong application choice." }
if (@($createdCases | Where-Object { -not $_._customerid_value -or $_._customerid_value.ToString() -notin $contactIds }).Count -gt 0) { $validationErrors += "One or more Cases is not linked to an approved existing Contact." }
if (@($createdCases | Group-Object title | Where-Object Count -gt 1).Count -gt 0) { $validationErrors += "Duplicate Case titles found." }
if ($expectedChildCaseIds.Count -ne $ChildCaseCount) { $validationErrors += "Expected $ChildCaseCount child-enabled Cases; found $($expectedChildCaseIds.Count)." }

$childChecks = @(
    @{ Label = "discrepancies"; Rows = $createdDiscrepancies; Lookup = "_earnint_caseid_discrepancy_value"; Name = "earnint_earningsdiscrepancy_name" },
    @{ Label = "evidence items"; Rows = $createdEvidence; Lookup = "_earnint_caseid_evidence_value"; Name = "earnint_evidenceitem_name" },
    @{ Label = "findings"; Rows = $createdFindings; Lookup = "_earnint_caseid_finding_value"; Name = "earnint_investigationfinding_name" }
)
foreach ($check in $childChecks) {
    if ($check.Rows.Count -ne $ChildCaseCount) { $validationErrors += "Expected $ChildCaseCount $($check.Label); found $($check.Rows.Count)." }
    if (@($check.Rows | Where-Object { -not $_.($check.Lookup) -or -not $expectedChildCaseIds.ContainsKey($_.($check.Lookup).ToString()) }).Count -gt 0) { $validationErrors += "One or more $($check.Label) is linked to the wrong Case." }
    if (@($check.Rows | Group-Object -Property $check.Name | Where-Object Count -gt 1).Count -gt 0) { $validationErrors += "Duplicate $($check.Label) names found." }
}

$patriciaAfter = @(Get-DvRows -Path "incidents?`$select=title,demo_datacustomerapplication&`$filter=startswith(title,'EIR-2025-0033')" | Select-Object -First 1)
if ($patriciaAfter.Count -ne 1 -or $patriciaAfter[0].demo_datacustomerapplication -ne $ApplicationChoiceValue) {
    $validationErrors += "The Patricia Nguyen Case application choice was not corrected."
}

Write-Host "=== Seed and Validation Complete ===" -ForegroundColor Cyan
$counts.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-24}: {1}" -f $_.Key, $_.Value) }
Write-Host "  Validated Cases         : $($createdCases.Count)"
Write-Host "  Validated discrepancies : $($createdDiscrepancies.Count)"
Write-Host "  Validated evidence items: $($createdEvidence.Count)"
Write-Host "  Validated findings      : $($createdFindings.Count)"

if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Bulk demo data validation failed with $($validationErrors.Count) error(s)."
}

Write-Host "  Validation              : PASS" -ForegroundColor Green
Write-Host "  App URL                 : $EnvironmentUrl/main.aspx" -ForegroundColor Cyan