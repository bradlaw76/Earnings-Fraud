<#
.SYNOPSIS
    Completes the Hargrove hero Case and seeds its Process Event history.

.DESCRIPTION
    Populates every custom field shown on the Fraud Case Form, approves the
    linked finding, creates or repairs a deterministic 17-event history, and
    resolves EIR-2025-0041. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/115-complete-hargrove-case.ps1 -WhatIf
    pwsh ./scripts/bootstrap/115-complete-hargrove-case.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$caseBusinessId = "EIR-2025-0041"
$token = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw "Could not acquire a Dataverse token." }

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
    Accept = "application/json"
    Prefer = 'return=representation,odata.include-annotations="OData.Community.Display.V1.FormattedValue"'
    "OData-Version" = "4.0"
    "OData-MaxVersion" = "4.0"
}

function Invoke-Dv {
    param([string]$Method, [string]$Path, [hashtable]$Body)

    $uri = "$EnvironmentUrl/api/data/v9.2/$Path"
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers }
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 20)
        } catch {
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            if ($attempt -eq 5 -or $status -notin @(429, 502, 503, 504)) { throw }
            [System.Threading.Thread]::Sleep([int]([math]::Pow(2, $attempt) * 1000))
        }
    }
}

function Get-Rows([string]$Path) {
    return @((Invoke-Dv Get $Path $null).value)
}

function Escape-ODataString([string]$Value) {
    return $Value.Replace("'", "''")
}

function Get-FormattedValue([object]$Row, [string]$Column) {
    $property = $Row.PSObject.Properties["$Column@OData.Community.Display.V1.FormattedValue"]
    if ($property) { return "$($property.Value)" }
    return ""
}

function New-Event {
    param(
        [int]$Sequence,
        [string]$Activity,
        [datetimeoffset]$Start,
        [string]$Resource,
        [string]$ResourceType,
        [string]$Queue,
        [string]$PreviousStatus,
        [string]$NewStatus,
        [string]$EvidenceType = "Not Applicable",
        [string]$EvidenceStatus = "Not Applicable",
        [string]$FindingType = "Potential Overpayment",
        [string]$RecommendedDisposition = "Create Overpayment Review",
        [string]$FinalDisposition = "Pending",
        [string]$SupervisorDecision = "Pending"
    )

    return [pscustomobject]@{
        Key = "$caseBusinessId|$($Sequence.ToString('000'))|$Activity"
        Activity = $Activity
        Start = $Start
        End = $Start.AddMinutes(30)
        Resource = $Resource
        ResourceType = $ResourceType
        Queue = $Queue
        PreviousStatus = $PreviousStatus
        NewStatus = $NewStatus
        EvidenceType = $EvidenceType
        EvidenceStatus = $EvidenceStatus
        FindingType = $FindingType
        RecommendedDisposition = $RecommendedDisposition
        FinalDisposition = $FinalDisposition
        SupervisorDecision = $SupervisorDecision
    }
}

$visibleCaseFields = @(
    "earnint_reviewtype", "earnint_referralsource", "earnint_allegationtype", "earnint_discrepancytype",
    "earnint_reviewperiodstart", "earnint_reviewperiodend", "earnint_riskrating", "earnint_fraudlikelihood",
    "earnint_fraudriskscore", "earnint_riskexplanation", "earnint_confidencelevel", "earnint_confidencescore",
    "earnint_potentialoverpayment", "earnint_impactedmonthcount", "earnint_largestmonthlyvariance",
    "earnint_evidencestatus", "earnint_beneficiaryresponsestatus", "earnint_identityvalidationstatus",
    "earnint_queueassignment", "earnint_humanreviewrequired", "earnint_supervisorreviewrequired",
    "earnint_supervisorapproval", "earnint_casedisposition", "earnint_finaldetermination",
    "earnfrau_aisummary", "earnfrau_supportingevidencesummary", "earnfrau_nextbestaction",
    "earnfrau_risksignalbreakdown", "earnfrau_evidencegaps", "earnfrau_confidencerationale",
    "earnfrau_humanreviewnote", "earnfrau_airawjson"
)
$caseSelect = @("incidentid", "title", "statecode", "statuscode") + $visibleCaseFields
$cases = @(Get-Rows "incidents?`$select=$($caseSelect -join ',')&`$filter=startswith(title,'$caseBusinessId')")
if ($cases.Count -ne 1) { throw "Expected one $caseBusinessId Case; found $($cases.Count)." }
$case = $cases[0]

$caseValues = @{
    description = "Beneficiary reported zero earned income for January through June 2025. IRS W-2 data and Apex Logistics employer confirmation establish `$24,800 in wages. The beneficiary statement was reviewed, the discrepancy was sustained, and the supervisor approved an overpayment review."
    prioritycode = 1
    demo_datacustomerapplication = 581180001
    earnint_reviewtype = 100000001
    earnint_referralsource = 100000000
    earnint_allegationtype = 100000000
    earnint_discrepancytype = 100000001
    earnint_reviewperiodstart = "2025-01-01"
    earnint_reviewperiodend = "2025-06-30"
    earnint_riskrating = 100000002
    earnint_fraudlikelihood = 100000003
    earnint_fraudriskscore = 75
    earnint_riskexplanation = "High risk: two quarters of zero reported earnings conflict with verified W-2 wages totaling `$24,800. Wage-match intake, employer confirmation, and the six-month pattern were reviewed and sustained through supervisor approval."
    earnint_confidencelevel = 100000002
    earnint_confidencescore = 90
    earnint_potentialoverpayment = 12400.00
    earnint_impactedmonthcount = 6
    earnint_largestmonthlyvariance = 6200.00
    earnint_evidencestatus = 100000002
    earnint_beneficiaryresponsestatus = 100000002
    earnint_identityvalidationstatus = 100000002
    earnint_queueassignment = 100000010
    earnint_humanreviewrequired = $true
    earnint_supervisorreviewrequired = $true
    earnint_supervisorapproval = $true
    earnint_casedisposition = 100000002
    earnint_finaldetermination = 100000005
    earnfrau_aisummary = "The completed review sustained a `$24,800 unreported-wage discrepancy for Robert Hargrove across Q1-Q2 2025. IRS wage data, employer confirmation, and the beneficiary response were evaluated before supervisor approval."
    earnfrau_supportingevidencesummary = "The completed package includes the wage-match intake, IRS W-2, Apex Logistics employer confirmation, and reviewed beneficiary statement. The authoritative sources corroborate the wage discrepancy."
    earnfrau_nextbestaction = "Maintain the approved overpayment-review package and completed audit trail in accordance with program policy."
    earnfrau_risksignalbreakdown = "Large wage variance (+20); multiple months impacted (+20); suspicious wage-report intake (+10); employer confirmation (+15); contradictory beneficiary statement (+10). Completed human review sustained the signal."
    earnfrau_evidencegaps = "No material evidence gaps remain for the approved overpayment-review disposition."
    earnfrau_confidencerationale = "Confidence is High because IRS wage records and employer confirmation corroborate the wage-match signal, and the beneficiary response was reviewed before approval. Completed confidence score: 90."
    earnfrau_humanreviewnote = "Seeded demo analysis only; no AI model was called. Analyst J. Reyes completed the evidence review, and supervisor S. Kim approved the overpayment-review disposition."
    earnfrau_airawjson = '{"source":"SEEDED_DEMO_ANALYSIS","ai_model_called":false,"case_id":"EIR-2025-0041","review_status":"completed","risk_level":"High","confidence_score":90,"human_review_completed":true,"supervisor_approved":true,"final_determination":"Overpayment Review Required"}'
}

$base = [datetimeoffset]"2025-07-09T13:00:00Z"
$events = @(
    (New-Event 10 "Earnings Signal Received" $base "Earnings Signal Intake Flow" "Automated Workflow" "Earnings Review Intake Queue" "Not Started" "Signal Received" "Wage Match Record" "Received"),
    (New-Event 20 "Case Created" $base.AddMinutes(15) "Case Intake Workflow" "Automated Workflow" "Earnings Review Intake Queue" "Signal Received" "New"),
    (New-Event 30 "Risk Triage Started" $base.AddHours(2) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "New" "Triage In Progress"),
    (New-Event 40 "Case Assigned" $base.AddHours(3) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Unassigned" "Assigned"),
    (New-Event 50 "Earnings Discrepancy Reviewed" $base.AddDays(1) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Triage In Progress" "Evidence Review" "IRS W-2" "Received"),
    (New-Event 60 "Evidence Received" $base.AddDays(1).AddHours(2) "Document Intake Workflow" "Automated Workflow" "Evidence Needed Queue" "Requested" "Received" "IRS W-2" "Received"),
    (New-Event 70 "Evidence Validated" $base.AddDays(2) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Received" "Verified" "IRS W-2" "Verified"),
    (New-Event 80 "Employer Confirmation Received" $base.AddDays(3) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Requested" "Received" "Employer Confirmation" "Verified"),
    (New-Event 90 "Beneficiary Statement Received" $base.AddDays(6) "J. Reyes" "Human" "Evidence Needed Queue" "Requested" "Received" "Beneficiary Statement" "Received"),
    (New-Event 100 "Beneficiary Response Reviewed" $base.AddDays(7) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Received" "Reviewed" "Beneficiary Statement" "Reviewed"),
    (New-Event 110 "Earnings Analysis Completed" $base.AddDays(8) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Evidence Review" "Analysis Complete" "Complete Evidence Package" "Complete"),
    (New-Event 120 "Analyst Finding Drafted" $base.AddDays(9) "J. Reyes" "Human" "High-Risk Fraud Review Queue" "Analysis Complete" "Finding Draft" "Complete Evidence Package" "Complete"),
    (New-Event 130 "Analyst Finding Submitted" $base.AddDays(10) "J. Reyes" "Human" "Supervisor Approval Queue" "Finding Draft" "Pending Supervisor" "Complete Evidence Package" "Complete"),
    (New-Event 140 "Supervisor Review Started" $base.AddDays(12) "S. Kim" "Human" "Supervisor Approval Queue" "Pending Supervisor" "Supervisor Review" "Complete Evidence Package" "Complete"),
    (New-Event 150 "Supervisor Approved" $base.AddDays(13) "S. Kim" "Human" "Supervisor Approval Queue" "Supervisor Review" "Approved" "Complete Evidence Package" "Complete" "Potential Overpayment" "Create Overpayment Review" "Overpayment Review Required" "Approved"),
    (New-Event 160 "Disposition Completed" $base.AddDays(14) "S. Kim" "Human" "Closed / Monitoring Queue" "Approved" "Disposition Completed" "Complete Evidence Package" "Complete" "Potential Overpayment" "Create Overpayment Review" "Overpayment Review Required" "Approved"),
    (New-Event 170 "Case Closed / Disposition Completed" $base.AddDays(15) "S. Kim" "Human" "Closed / Monitoring Queue" "Disposition Completed" "Closed" "Complete Evidence Package" "Complete" "Potential Overpayment" "Create Overpayment Review" "Overpayment Review Required" "Approved")
)

Write-Host ""
Write-Host "=== Complete Hargrove Case ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Case:        $($case.title)"
Write-Host "  Events:      $($events.Count)"
Write-Host "  Mode:        $(if ($WhatIf) { 'WhatIf' } else { 'Apply' })"

if ($WhatIf) {
    Write-Host "  Would populate $($visibleCaseFields.Count) visible custom Case fields."
    Write-Host "  Would approve the linked finding and create or repair $($events.Count) Process Events."
    Write-Host "  Would resolve the Case with status reason Problem Solved."
    Write-Host ""
    Write-Host "=== Preview Complete: No Records Changed ===" -ForegroundColor Green
    exit 0
}

if ([int]$case.statecode -eq 0) {
    Invoke-Dv Patch "incidents($($case.incidentid))" $caseValues | Out-Null
} else {
    Write-Host "  [SKIP] Case is already resolved; validating stored completion values." -ForegroundColor DarkGray
}

$findings = @(Get-Rows "earnint_investigationfindings?`$select=earnint_investigationfindingid,earnint_investigationfinding_name&`$filter=_earnint_caseid_finding_value eq $($case.incidentid)")
if ($findings.Count -lt 1) { throw "No linked Hargrove investigation finding was found." }
foreach ($finding in $findings) {
    Invoke-Dv Patch "earnint_investigationfindings($($finding.earnint_investigationfindingid))" @{
        earnint_findingtype = 100000000
        earnint_severity = 100000002
        earnint_findingdetails = "The completed review sustained `$24,800 in unreported wages for Q1-Q2 2025. IRS wage data and employer confirmation corroborate the discrepancy; the beneficiary response was reviewed and did not resolve it."
        earnint_recommendation = "Create and retain the approved overpayment-review package with the complete evidence and decision trail."
        earnint_recddisposition = 100000002
        earnint_supervisorapprovalstatus = 100000001
        earnint_analystname = "J. Reyes"
        earnint_supervisorcomments = "Approved by S. Kim after complete evidence and beneficiary-response review."
    } | Out-Null
}

$riskLabel = Get-FormattedValue $case "earnint_riskrating"
if ([string]::IsNullOrWhiteSpace($riskLabel)) { $riskLabel = "High" }
$createdEvents = 0
$updatedEvents = 0
foreach ($event in $events) {
    $body = @{
        earnint_processevent_name = $event.Key
        earnint_activityname = $event.Activity
        earnint_starttimestamp = $event.Start.ToString("yyyy-MM-ddTHH:mm:ssZ")
        earnint_endtimestamp = $event.End.ToString("yyyy-MM-ddTHH:mm:ssZ")
        earnint_resource = $event.Resource
        earnint_resourcetype = $event.ResourceType
        earnint_previousstatus = $event.PreviousStatus
        earnint_newstatus = $event.NewStatus
        earnint_queueorteam = $event.Queue
        earnint_risklevel = $riskLabel
        earnint_discrepancyamount = 12400.00
        earnint_evidencetype = $event.EvidenceType
        earnint_evidencestatus = $event.EvidenceStatus
        earnint_findingtype = $event.FindingType
        earnint_recommendeddisposition = $event.RecommendedDisposition
        earnint_finaldisposition = $event.FinalDisposition
        earnint_supervisordecision = $event.SupervisorDecision
        earnint_reassignmentindicator = $false
        earnint_reworkindicator = $false
        earnint_sourcesystem = "SYNTHETIC_PROCESS_MINING_DEMO"
        earnint_sourcerecordid = "$($case.incidentid)"
        earnint_issyntheticdemoevent = $true
        "earnint_caseid_processevent@odata.bind" = "/incidents($($case.incidentid))"
    }
    $safeKey = Escape-ODataString $event.Key
    $existing = @(Get-Rows "earnint_processevents?`$select=earnint_processeventid&`$filter=earnint_processevent_name eq '$safeKey'")
    if ($existing.Count -gt 1) { throw "Duplicate Process Event key '$($event.Key)' exists." }
    if ($existing.Count -eq 1) {
        Invoke-Dv Patch "earnint_processevents($($existing[0].earnint_processeventid))" $body | Out-Null
        $updatedEvents++
    } else {
        Invoke-Dv Post "earnint_processevents" $body | Out-Null
        $createdEvents++
    }
}

$current = Invoke-Dv Get "incidents($($case.incidentid))?`$select=incidentid,statecode" $null
if ([int]$current.statecode -eq 0) {
    Invoke-Dv Post "CloseIncident" @{
        IncidentResolution = @{
            subject = "Hargrove earnings-integrity review completed"
            description = "Evidence review completed and supervisor approved the overpayment-review disposition."
            timespent = 0
            "incidentid@odata.bind" = "/incidents($($case.incidentid))"
        }
        Status = 5
    } | Out-Null
}

$validatedCases = @(Get-Rows "incidents?`$select=incidentid,title,statecode,statuscode,$($visibleCaseFields -join ',')&`$filter=incidentid eq $($case.incidentid)")
$validatedEvents = @(Get-Rows "earnint_processevents?`$select=earnint_processevent_name,earnint_activityname,earnint_starttimestamp,earnint_endtimestamp,earnint_resource,earnint_resourcetype,earnint_previousstatus,earnint_newstatus,earnint_queueorteam,earnint_risklevel,earnint_discrepancyamount,earnint_evidencetype,earnint_evidencestatus,earnint_findingtype,earnint_recommendeddisposition,earnint_finaldisposition,earnint_supervisordecision,earnint_sourcesystem,earnint_sourcerecordid,earnint_issyntheticdemoevent&`$filter=_earnint_caseid_processevent_value eq $($case.incidentid)")
$validatedFindings = @(Get-Rows "earnint_investigationfindings?`$select=earnint_investigationfinding_name,earnint_supervisorapprovalstatus,earnint_supervisorcomments&`$filter=_earnint_caseid_finding_value eq $($case.incidentid)")
$validationErrors = [System.Collections.Generic.List[string]]::new()
if ($validatedCases.Count -ne 1) { $validationErrors.Add("Expected one Hargrove Case after completion.") }
if ($validatedCases.Count -eq 1) {
    if ([int]$validatedCases[0].statecode -ne 1 -or [int]$validatedCases[0].statuscode -ne 5) { $validationErrors.Add("The Hargrove Case is not resolved as Problem Solved.") }
    foreach ($field in $visibleCaseFields) {
        if ($null -eq $validatedCases[0].$field -or [string]::IsNullOrWhiteSpace([string]$validatedCases[0].$field)) {
            $validationErrors.Add("Visible Case field '$field' is empty.")
        }
    }
    if (-not [bool]$validatedCases[0].earnint_supervisorapproval) { $validationErrors.Add("Supervisor approval is not recorded on the Case.") }
}
if ($validatedEvents.Count -ne $events.Count) { $validationErrors.Add("Expected $($events.Count) linked Process Events; found $($validatedEvents.Count).") }
if (@($validatedEvents | Group-Object earnint_processevent_name | Where-Object Count -gt 1).Count -gt 0) { $validationErrors.Add("Duplicate deterministic Process Event keys exist.") }
$requiredEventFields = @("earnint_activityname", "earnint_starttimestamp", "earnint_endtimestamp", "earnint_resource", "earnint_resourcetype", "earnint_previousstatus", "earnint_newstatus", "earnint_queueorteam", "earnint_risklevel", "earnint_discrepancyamount", "earnint_evidencetype", "earnint_evidencestatus", "earnint_findingtype", "earnint_recommendeddisposition", "earnint_finaldisposition", "earnint_supervisordecision", "earnint_sourcesystem", "earnint_sourcerecordid")
foreach ($event in $validatedEvents) {
    foreach ($field in $requiredEventFields) {
        if ($null -eq $event.$field -or [string]::IsNullOrWhiteSpace([string]$event.$field)) { $validationErrors.Add("Process Event '$($event.earnint_processevent_name)' has an empty '$field'.") }
    }
    if (-not [bool]$event.earnint_issyntheticdemoevent) { $validationErrors.Add("Process Event '$($event.earnint_processevent_name)' is not marked synthetic.") }
}
if (@($validatedFindings | Where-Object { $_.earnint_supervisorapprovalstatus -ne 100000001 -or [string]::IsNullOrWhiteSpace($_.earnint_supervisorcomments) }).Count -gt 0) {
    $validationErrors.Add("One or more linked findings is not fully approved.")
}

Write-Host ""
Write-Host "=== Hargrove Completion Validation ===" -ForegroundColor Cyan
Write-Host "  Visible Case fields: $($visibleCaseFields.Count)"
Write-Host "  Events created:      $createdEvents"
Write-Host "  Events repaired:     $updatedEvents"
Write-Host "  Events validated:    $($validatedEvents.Count)"
Write-Host "  Findings approved:   $($validatedFindings.Count)"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Hargrove completion validation failed with $($validationErrors.Count) error(s)."
}
Write-Host "  Validation:           PASS" -ForegroundColor Green
Write-Host "  App URL:              $EnvironmentUrl/main.aspx" -ForegroundColor Cyan