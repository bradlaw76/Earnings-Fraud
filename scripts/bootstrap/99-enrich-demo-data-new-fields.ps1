<#
.SYNOPSIS
    Populates newly added case, AI, discrepancy, evidence, and finding fields.

.DESCRIPTION
    Updates the existing seeded SSA Earnings Integrity demo records in place.
    This is intentionally separate from the create-only seed script so it can
    be rerun safely after new columns are added.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { throw "Environment URL required." }

function Invoke-Dv {
    param([string]$Method, [string]$Path, [hashtable]$Body = $null)
    $token = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
    if ([string]::IsNullOrWhiteSpace($token)) { throw "Could not acquire Dataverse token." }
    $headers = @{
        Authorization = "Bearer $($token.Trim())"
        "Content-Type" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        Accept = "application/json"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 20)
}

function Get-All([string]$Entity, [string]$Select) {
    return @((Invoke-Dv -Method GET -Path "${Entity}?`$select=$Select").value)
}

function Update-Record([string]$Entity, [string]$Id, [hashtable]$Values, [string]$Label) {
    if ($WhatIf) {
        Write-Host "  [WHATIF] Would update $Label ($($Values.Count) fields)" -ForegroundColor Yellow
        return
    }
    Invoke-Dv -Method PATCH -Path "$Entity($Id)" -Body $Values | Out-Null
    Write-Host "  [UPDATED] $Label ($($Values.Count) fields)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Enrich Existing Demo Data ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
if ($WhatIf) { Write-Host "  Mode: WhatIf" -ForegroundColor Yellow }
Write-Host ""

$caseData = @{
  "EIR-2025-0041" = @{
        reviewtype = 100000001; referralsource = 100000000; allegationtype = 100000000; discrepancytype = 100000001; fraudlikelihood = 100000003; confidencelevel = 100000002; finaldetermination = 100000005; evidencestatus = 100000002; beneficiaryresponsestatus = 100000004; identityvalidationstatus = 100000002; queueassignment = 100000003; reviewperiodstart = "2025-01-01"; reviewperiodend = "2025-06-30"; fraudriskscore = 75; confidencescore = 78; impactedmonthcount = 6; potentialoverpayment = 12400.00; largestmonthlyvariance = 6200.00; supervisorreviewrequired = $true; humanreviewrequired = $true; supervisorapproval = $false; casedisposition = 100000002
    riskExplanation = "High risk: two quarters of zero reported earnings conflict with verified W-2 wages totaling `$24,800. The wage-match intake, employer confirmation, and sustained six-month pattern require supervisor review."
    aiSummary = "The case presents a sustained earnings discrepancy for Robert Hargrove. Employer and tax wage records corroborate `$24,800 in unreported wages for Q1-Q2 2025."
    evidenceSummary = "Verified evidence includes the wage-match intake, IRS W-2, and employer confirmation. The beneficiary statement is contradictory and remains unresolved."
    nextBestAction = "Obtain supervisor approval for the overpayment review packet, document the beneficiary response deadline, and retain the case in human review until disposition."
    riskBreakdown = "Large wage variance (+20); multiple months impacted (+20); suspicious wage report intake (+10); employer confirmation corroborates wage feed (+15); contradictory beneficiary statement (+10)."
    evidenceGaps = "Beneficiary response remains unresolved. Payment-history record and refreshed identity validation should be attached before final determination."
    confidenceRationale = "Confidence is High because employer confirmation and IRS wage records corroborate the wage-match signal. Confidence is reduced by the contradictory beneficiary statement."
    humanReviewNote = "AI output is triage support only. Analyst and supervisor must make the final determination and approve any escalation or overpayment action."
        rawJson = '{"riskLevel":"High","fraudLikelihood":"Medium-High","confidenceScore":78,"humanReviewRequired":true}'
  }
  "EIR-2025-0052" = @{
        reviewtype = 100000002; referralsource = 100000002; allegationtype = 100000008; discrepancytype = 100000001; fraudlikelihood = 100000002; confidencelevel = 100000001; finaldetermination = 100000007; evidencestatus = 100000001; beneficiaryresponsestatus = 100000001; identityvalidationstatus = 100000003; queueassignment = 100000004; reviewperiodstart = "2024-01-01"; reviewperiodend = "2024-12-31"; fraudriskscore = 52; confidencescore = 55; impactedmonthcount = 12; potentialoverpayment = 9800.00; largestmonthlyvariance = 4600.00; supervisorreviewrequired = $false; humanreviewrequired = $true; supervisorapproval = $false; casedisposition = 100000001
    riskExplanation = "High risk: two employers report a combined `$18,400 in earnings not reflected in the beneficiary record. Evidence is incomplete and identity linkage remains unfinished."
    aiSummary = "The case involves potential unreported earnings from two employers during 2024. Employer wage statements are available, but beneficiary response and identity validation are incomplete."
    evidenceSummary = "Two employer wage statements are available and a data-match record is under review. A written beneficiary response is still required."
    nextBestAction = "Issue a request for information, complete identity validation, and route the evidence package for supervisor review after the response is received."
    riskBreakdown = "Multiple employer discrepancy (+20); material annual variance (+15); incomplete evidence package (+10); identity validation incomplete (+10)."
    evidenceGaps = "Beneficiary written response is missing. Identity linkage and supporting payment history require verification."
    confidenceRationale = "Confidence is Moderate because two employer records corroborate the discrepancy, but the beneficiary explanation and identity validation are incomplete."
    humanReviewNote = "AI output is triage support only. Do not make a final determination until the beneficiary response and identity review are complete."
        rawJson = '{"riskLevel":"High","fraudLikelihood":"Medium","confidenceScore":55,"humanReviewRequired":true}'
  }
  "EIR-2025-0067" = @{
        reviewtype = 100000005; referralsource = 100000009; allegationtype = 100000005; discrepancytype = 100000002; fraudlikelihood = 100000002; confidencelevel = 100000001; finaldetermination = 100000010; evidencestatus = 100000001; beneficiaryresponsestatus = 100000001; identityvalidationstatus = 100000003; queueassignment = 100000005; reviewperiodstart = "2025-07-01"; reviewperiodend = "2025-09-30"; fraudriskscore = 48; confidencescore = 60; impactedmonthcount = 3; potentialoverpayment = 4300.00; largestmonthlyvariance = 2916.67; supervisorreviewrequired = $false; humanreviewrequired = $true; supervisorapproval = $false; casedisposition = 100000001
    riskExplanation = "Medium risk: a Q3 employer wage mismatch is identified against a beneficiary with prior overpayment history, but employer verification is still pending."
    aiSummary = "The case contains a `$8,750 Q3 2025 wage discrepancy and prior overpayment history. The current signal is plausible but requires employer confirmation."
    evidenceSummary = "An IRS W-2 wage record is available. Employer confirmation has been requested and is not yet received."
    nextBestAction = "Follow up with GreenPath Construction, preserve the employer-verification request, and reassess risk after the response."
    riskBreakdown = "Prior overpayment history (+15); employer mismatch (+15); verification pending (+10); limited impacted period (+5)."
    evidenceGaps = "Employer confirmation is missing. Identity validation and final beneficiary response should be refreshed before disposition."
    confidenceRationale = "Confidence is Moderate because the wage record identifies a discrepancy, but employer verification is not complete."
    humanReviewNote = "AI output is triage support only. Keep the case on hold until employer verification is reviewed by an analyst."
        rawJson = '{"riskLevel":"Medium","fraudLikelihood":"Medium","confidenceScore":60,"humanReviewRequired":true}'
  }
  "EIR-2025-0033" = @{
        reviewtype = 100000004; referralsource = 100000006; allegationtype = 100000002; discrepancytype = 100000004; fraudlikelihood = 100000000; confidencelevel = 100000002; finaldetermination = 100000003; evidencestatus = 100000002; beneficiaryresponsestatus = 100000002; identityvalidationstatus = 100000002; queueassignment = 100000010; reviewperiodstart = "2024-01-01"; reviewperiodend = "2024-12-31"; fraudriskscore = 22; confidencescore = 82; impactedmonthcount = 2; potentialoverpayment = 1800.00; largestmonthlyvariance = 900.00; supervisorreviewrequired = $false; humanreviewrequired = $true; supervisorapproval = $true; casedisposition = 100000002
    riskExplanation = "Low fraud likelihood with high confidence: corrected wage data now aligns with employer records and supports a late-reporting correction path."
    aiSummary = "The case reflects late-reported self-employment income that was corrected and reconciled with supporting records. No intentional misrepresentation pattern was identified."
    evidenceSummary = "Corrected wage report and related records support the late-reporting determination. Supervisor approval is recorded."
    nextBestAction = "Maintain the audit trail, close the active review work, and monitor for future reporting inconsistencies."
    riskBreakdown = "Late reporting (+10); corrected record received (-10); records reconciled (-10); no intentional pattern identified (-10)."
    evidenceGaps = "No material evidence gap remains for the documented late-reporting outcome. Continue routine monitoring."
    confidenceRationale = "Confidence is High because corrected wage data matches employer records and the supervisor approved the disposition."
    humanReviewNote = "AI output supported triage and explanation. The recorded outcome was reviewed and approved by a supervisor."
        rawJson = '{"riskLevel":"Critical","fraudLikelihood":"Low","confidenceScore":82,"humanReviewRequired":true}'
  }
}

$cases = Get-All -Entity incidents -Select "incidentid,title"
foreach ($case in $cases) {
    $match = [regex]::Match("$($case.title)", '^(EIR-\d{4}-\d{4})')
    if (-not $match.Success -or -not $caseData.ContainsKey($match.Groups[1].Value)) { continue }
    $d = $caseData[$match.Groups[1].Value]
    $values = @{
        demo_datacustomerapplication = 581180001
        earnint_reviewtype = $d.reviewtype
        earnint_referralsource = $d.referralsource
        earnint_allegationtype = $d.allegationtype
        earnint_discrepancytype = $d.discrepancytype
        earnint_fraudlikelihood = $d.fraudlikelihood
        earnint_confidencelevel = $d.confidencelevel
        earnint_finaldetermination = $d.finaldetermination
        earnint_evidencestatus = $d.evidencestatus
        earnint_beneficiaryresponsestatus = $d.beneficiaryresponsestatus
        earnint_identityvalidationstatus = $d.identityvalidationstatus
        earnint_queueassignment = $d.queueassignment
        earnint_reviewperiodstart = $d.reviewperiodstart
        earnint_reviewperiodend = $d.reviewperiodend
        earnint_fraudriskscore = $d.fraudriskscore
        earnint_confidencescore = $d.confidencescore
        earnint_impactedmonthcount = $d.impactedmonthcount
        earnint_potentialoverpayment = $d.potentialoverpayment
        earnint_largestmonthlyvariance = $d.largestmonthlyvariance
        earnint_supervisorreviewrequired = $d.supervisorreviewrequired
        earnint_humanreviewrequired = $d.humanreviewrequired
        earnint_supervisorapproval = $d.supervisorapproval
        earnint_casedisposition = $d.casedisposition
        earnint_riskexplanation = $d.riskExplanation
        earnfrau_aisummary = $d.aiSummary
        earnfrau_supportingevidencesummary = $d.evidenceSummary
        earnfrau_nextbestaction = $d.nextBestAction
        earnfrau_risksignalbreakdown = $d.riskBreakdown
        earnfrau_evidencegaps = $d.evidenceGaps
        earnfrau_confidencerationale = $d.confidenceRationale
        earnfrau_humanreviewnote = $d.humanReviewNote
        earnfrau_airawjson = $d.rawJson
    }
    Update-Record -Entity incidents -Id $case.incidentid -Values $values -Label $match.Groups[1].Value
}

$discrepancyUpdates = @(
  @{ Pattern='Hargrove'; Type=100000001; Source=100000003; Percent=100.00; Manual=$true },
  @{ Pattern='Castillo'; Type=100000001; Source=100000001; Percent=100.00; Manual=$true },
  @{ Pattern='Whitfield'; Type=100000005; Source=100000002; Percent=100.00; Manual=$true },
  @{ Pattern='Nguyen'; Type=100000003; Source=100000011; Percent=100.00; Manual=$false }
)
$discrepancies = Get-All -Entity earnint_earningsdiscrepancies -Select "earnint_earningsdiscrepancyid,earnint_earningsdiscrepancy_name"
foreach ($record in $discrepancies) {
    $rule = $discrepancyUpdates | Where-Object { "$($record.earnint_earningsdiscrepancy_name)" -like "*$($_.Pattern)*" } | Select-Object -First 1
    if ($null -eq $rule) { continue }
    Update-Record -Entity earnint_earningsdiscrepancies -Id $record.earnint_earningsdiscrepancyid -Values @{
        earnint_discrepancytype = $rule.Type
        earnint_earningsourcetype = $rule.Source
        earnint_discrepancypercent = $rule.Percent
        earnint_requiresmanualreview = $rule.Manual
    } -Label "$($record.earnint_earningsdiscrepancy_name)"
}

$evidenceUpdates = @(
    @{ Pattern='Wage Match Intake'; Type=100000001; Status=100000003; Supports=100000005; Received='2025-07-09'; Verified='J. Reyes, Analyst'; Notes='Primary suspicious wage intake signal; retain as the originating referral artifact.' },
    @{ Pattern='IRS W-2'; Type=100000004; Status=100000003; Supports=100000000; Received='2025-07-10'; Verified='J. Reyes, Analyst'; Notes='Verified tax wage evidence supporting the earnings discrepancy.' },
    @{ Pattern='Employer Confirmation'; Type=100000002; Status=100000003; Supports=100000002; Received='2025-07-12'; Verified='J. Reyes, Analyst'; Notes='Employer-confirmed record corroborating the authoritative wage amount.' },
    @{ Pattern='Beneficiary Statement'; Type=100000005; Status=100000002; Supports=100000008; Received='2025-07-15'; Verified='J. Reyes, Analyst'; Notes='Contradictory beneficiary explanation; requires analyst follow-up.' },
    @{ Pattern='Wage Statement'; Type=100000000; Status=100000003; Supports=100000000; Received='2025-06-10'; Verified='T. Morales, Analyst'; Notes='Employer wage statement verified against the earnings record.' },
    @{ Pattern='Data Match Record'; Type=100000016; Status=100000002; Supports=100000009; Received='2025-06-12'; Verified='T. Morales, Analyst'; Notes='Third-party data-match evidence requiring additional review.' },
    @{ Pattern='Corrected Wage Report'; Type=100000005; Status=100000003; Supports=100000003; Received='2025-06-21'; Verified='S. Kim, Supervisor'; Notes='Corrected record supports the administrative late-reporting resolution.' },
    @{ Pattern='Tax Return'; Type=100000004; Status=100000003; Supports=100000000; Received='2025-06-13'; Verified='T. Morales, Analyst'; Notes='Tax return evidence corroborates the reported earnings period and discrepancy review.' },
    @{ Pattern='IRS 1099'; Type=100000004; Status=100000003; Supports=100000000; Received='2025-06-20'; Verified='S. Kim, Supervisor'; Notes='IRS 1099 evidence supports the self-employment earnings discrepancy.' },
    @{ Pattern='Beneficiary Written Statement'; Type=100000005; Status=100000002; Supports=100000008; Received='2025-06-22'; Verified='S. Kim, Supervisor'; Notes='Beneficiary explanation is documented and requires analyst comparison with authoritative records.' }
)
$evidence = Get-All -Entity earnint_evidenceitems -Select "earnint_evidenceitemid,earnint_evidenceitem_name"
foreach ($record in $evidence) {
    $rule = $evidenceUpdates | Where-Object { "$($record.earnint_evidenceitem_name)" -like "*$($_.Pattern)*" } | Select-Object -First 1
    if ($null -eq $rule) { continue }
    Update-Record -Entity earnint_evidenceitems -Id $record.earnint_evidenceitemid -Values @{
        earnint_evidencetype = $rule.Type
        earnint_status = $rule.Status
        earnint_supportsfinding = $rule.Supports
        earnint_receiveddate = $rule.Received
        earnint_verifiedby = $rule.Verified
        earnint_notes = $rule.Notes
    } -Label "$($record.earnint_evidenceitem_name)"
}

$findingUpdates = @(
    @{ Pattern='Hargrove'; Type=100000000; Severity=100000002; Disposition=100000002; Approval=100000000; Analyst='J. Reyes'; Recommendation='Request beneficiary wage clarification, keep overpayment packet ready, and route to supervisor approval queue.'; Comments='Pending supervisor review package.' },
    @{ Pattern='Castillo'; Type=100000002; Severity=100000001; Disposition=100000001; Approval=100000000; Analyst='T. Morales'; Recommendation='Collect beneficiary written response and verify identity linkage before final determination.'; Comments='Not ready for approval; evidence package still incomplete.' },
    @{ Pattern='Nguyen'; Type=100000003; Severity=100000000; Disposition=100000002; Approval=100000001; Analyst='S. Kim'; Recommendation='Close as late-reporting correction with monitoring; overpayment review remains documented for audit history.'; Comments='Approved for closure and monitoring queue placement.' }
)
$findings = Get-All -Entity earnint_investigationfindings -Select "earnint_investigationfindingid,earnint_investigationfinding_name"
foreach ($record in $findings) {
    $rule = $findingUpdates | Where-Object { "$($record.earnint_investigationfinding_name)" -like "*$($_.Pattern)*" } | Select-Object -First 1
    if ($null -eq $rule) { continue }
    Update-Record -Entity earnint_investigationfindings -Id $record.earnint_investigationfindingid -Values @{
        earnint_findingtype = $rule.Type
        earnint_severity = $rule.Severity
        earnint_recddisposition = $rule.Disposition
        earnint_supervisorapprovalstatus = $rule.Approval
        earnint_analystname = $rule.Analyst
        earnint_recommendation = $rule.Recommendation
        earnint_supervisorcomments = $rule.Comments
    } -Label "$($record.earnint_investigationfinding_name)"
}

Write-Host ""
Write-Host "Enrichment complete." -ForegroundColor Cyan
