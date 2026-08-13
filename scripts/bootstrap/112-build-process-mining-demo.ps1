<#
.SYNOPSIS
    Builds and seeds additive Process Mining demo instrumentation.

.DESCRIPTION
    Creates the earnint_processevent table from dedicated payloads, adds it to
    FederalEarningsFraud, and seeds deterministic event histories for eight
    existing Cases plus four isolated EIR-PM Cases. Existing Cases and related
    records are read-only; only the four new EIR-PM Cases are resolved.

.EXAMPLE
    pwsh ./scripts/bootstrap/112-build-process-mining-demo.ps1 -WhatIf
    pwsh ./scripts/bootstrap/112-build-process-mining-demo.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$SolutionUniqueName = "FederalEarningsFraud",
    [int]$ApplicationChoiceValue = 581180001,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$repoRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$payloadFolder = Join-Path $repoRoot "scripts/payloads-process-mining"
$token = az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv
if ([string]::IsNullOrWhiteSpace($token)) { throw "Could not acquire a Dataverse token." }
$token = $token.Trim()

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
    Accept = "application/json"
    Prefer = 'return=representation,odata.include-annotations="OData.Community.Display.V1.FormattedValue"'
}

function Invoke-Dv {
    param([string]$Method, [string]$Path, [hashtable]$Body)

    $uri = if ($Path -match '^https://') { $Path } else { "$EnvironmentUrl/api/data/v9.2/$Path" }
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

function Get-DvRows {
    param([string]$Path)

    $rows = [System.Collections.Generic.List[object]]::new()
    $next = $Path
    while ($next) {
        $response = Invoke-Dv Get $next $null
        foreach ($row in @($response.value)) { $rows.Add($row) }
        $property = $response.PSObject.Properties['@odata.nextLink']
        $next = if ($property) { "$($property.Value)" } else { $null }
    }
    return @($rows)
}

function Escape-ODataString([string]$Value) { return $Value.Replace("'", "''") }

function Get-FormattedValue([object]$Row, [string]$Column) {
    $property = $Row.PSObject.Properties["$Column@OData.Community.Display.V1.FormattedValue"]
    if ($property) { return "$($property.Value)" }
    return ""
}

function Get-CaseBusinessId([object]$Case) {
    if ("$($Case.title)" -match '(EIR-(?:PM-)?[0-9]{4}-[A-Z0-9-]+|EIR-[0-9]{4}-BULK-[0-9]{3})') { return $matches[1] }
    if ("$($Case.title)" -match '(EIR-[0-9]{4}-[0-9]{3,4})') { return $matches[1] }
    return "$($Case.incidentid)"
}

function Find-One([string]$EntitySet, [string]$Filter, [string]$Select) {
    $safePath = "${EntitySet}?`$select=$Select&`$filter=$Filter&`$top=1"
    return @(Get-DvRows $safePath | Select-Object -First 1)
}

function Add-PlannedEvent {
    param(
        [System.Collections.Generic.List[object]]$List,
        [object]$Case,
        [int]$Sequence,
        [string]$Activity,
        [datetimeoffset]$Start,
        [string]$Resource,
        [string]$ResourceType,
        [string]$Queue,
        [string]$PreviousStatus,
        [string]$NewStatus,
        [bool]$Reassignment = $false,
        [bool]$Rework = $false,
        [string]$EvidenceType = "",
        [string]$EvidenceStatus = "",
        [string]$FindingType = "",
        [string]$RecommendedDisposition = "",
        [string]$FinalDisposition = "",
        [string]$SupervisorDecision = "",
        [nullable[datetimeoffset]]$End = $null
    )

    $caseId = Get-CaseBusinessId $Case
    $List.Add([pscustomobject]@{
        Key = "$caseId|$($Sequence.ToString('000'))|$Activity"
        Case = $Case
        CaseId = $caseId
        Sequence = $Sequence
        Activity = $Activity
        Start = $Start
        End = $End
        Resource = $Resource
        ResourceType = $ResourceType
        Queue = $Queue
        PreviousStatus = $PreviousStatus
        NewStatus = $NewStatus
        RiskLevel = Get-FormattedValue $Case "earnint_riskrating"
        DiscrepancyAmount = [decimal]$Case.earnint_potentialoverpayment
        EvidenceType = $EvidenceType
        EvidenceStatus = $EvidenceStatus
        FindingType = $FindingType
        RecommendedDisposition = $RecommendedDisposition
        FinalDisposition = $FinalDisposition
        SupervisorDecision = $SupervisorDecision
        Reassignment = $Reassignment
        Rework = $Rework
    })
}

Write-Host ""
Write-Host "=== Process Mining Demo Build ===" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentUrl"
Write-Host "Solution:    $SolutionUniqueName"
Write-Host "Mode:        $(if ($WhatIf) { 'WhatIf' } else { 'Apply' })"

$caseSelect = "incidentid,title,createdon,modifiedon,statecode,statuscode,_ownerid_value,_customerid_value,earnint_riskrating,earnint_queueassignment,earnint_evidencestatus,earnint_casedisposition,earnint_finaldetermination,earnint_potentialoverpayment"
$existingCases = @(Get-DvRows "incidents?`$select=$caseSelect&`$filter=startswith(title,'EIR-2026-BULK-00') and demo_datacustomerapplication eq $ApplicationChoiceValue&`$orderby=title asc&`$top=8")
if ($existingCases.Count -ne 8) { throw "Expected eight existing EIR-2026-BULK-00* Cases; found $($existingCases.Count)." }

$existingSnapshots = @{}
foreach ($case in $existingCases) {
    $existingSnapshots["$($case.incidentid)"] = "$($case.statecode)|$($case.statuscode)|$($case._ownerid_value)|$($case.modifiedon)"
}

$contacts = @(Get-DvRows "contacts?`$select=contactid,fullname&`$filter=contactid eq $($existingCases[0]._customerid_value)&`$top=1")
if ($contacts.Count -ne 1) { throw "The selected existing cohort does not expose a reusable Contact." }
$contact = $contacts[0]

$newProfiles = @(
    @{ Id="EIR-PM-2026-LOW"; Risk=100000000; RiskLabel="Low"; Amount=3200.00; Queue=100000002; QueueLabel="Low-Risk Earnings Review Queue"; Disposition=100000004; Final=100000002; Title="EIR-PM-2026-LOW - Process Mining Straight-Through Review"; Base=[datetimeoffset]"2026-04-06T13:00:00Z" },
    @{ Id="EIR-PM-2026-MEDIUM"; Risk=100000001; RiskLabel="Medium"; Amount=7800.00; Queue=100000004; QueueLabel="Evidence Needed Queue"; Disposition=100000006; Final=100000010; Title="EIR-PM-2026-MEDIUM - Process Mining Evidence Loop"; Base=[datetimeoffset]"2026-04-13T13:00:00Z" },
    @{ Id="EIR-PM-2026-HIGH"; Risk=100000002; RiskLabel="High"; Amount=16400.00; Queue=100000007; QueueLabel="Supervisor Approval Queue"; Disposition=100000002; Final=100000005; Title="EIR-PM-2026-HIGH - Process Mining Supervisor Return"; Base=[datetimeoffset]"2026-04-20T13:00:00Z" },
    @{ Id="EIR-PM-2026-CRITICAL"; Risk=100000003; RiskLabel="Critical"; Amount=28600.00; Queue=100000009; QueueLabel="Fraud Escalation Queue"; Disposition=100000009; Final=100000006; Title="EIR-PM-2026-CRITICAL - Process Mining Escalation"; Base=[datetimeoffset]"2026-04-27T13:00:00Z" }
)

if ($WhatIf) {
    Write-Host ""
    Write-Host "Planned metadata:" -ForegroundColor Yellow
    Write-Host "  Table: earnint_processevent"
    Write-Host "  Columns: 21"
    Write-Host "  Relationships: 1 required Case lookup"
    Write-Host "Planned cohort:" -ForegroundColor Yellow
    Write-Host "  Existing Cases (event rows only): 8"
    $existingCases | ForEach-Object { Write-Host "    $($_.title)" }
    Write-Host "  New isolated Cases: 4"
    $newProfiles | ForEach-Object { Write-Host "    $($_.Title)" }
    Write-Host "  Existing Case updates: 0"
    Write-Host "  Existing record deletes: 0"
    Write-Host "  New Cases resolved: 4"
    Write-Host "  Planned explicit events: approximately 110-125"
    Write-Host ""
    Write-Host "=== Preview Complete: No Records Changed ===" -ForegroundColor Green
    exit 0
}

Write-Host "Building metadata from $payloadFolder ..." -ForegroundColor Yellow
& pwsh (Join-Path $PSScriptRoot "20-build-tables.ps1") -EnvironmentUrl $EnvironmentUrl -AccessToken $token -PayloadsFolder $payloadFolder
if ($LASTEXITCODE -ne 0) { throw "Process event table creation failed." }
& pwsh (Join-Path $PSScriptRoot "30-build-columns.ps1") -EnvironmentUrl $EnvironmentUrl -AccessToken $token -PayloadsFolder $payloadFolder
if ($LASTEXITCODE -ne 0) { throw "Process event column creation failed." }
& pwsh (Join-Path $PSScriptRoot "40-build-relationships.ps1") -EnvironmentUrl $EnvironmentUrl -AccessToken $token -PayloadsFolder $payloadFolder
if ($LASTEXITCODE -ne 0) { throw "Process event relationship creation failed." }
& pwsh (Join-Path $PSScriptRoot "50-add-to-solution.ps1") -EnvironmentUrl $EnvironmentUrl -AccessToken $token -SolutionUniqueName $SolutionUniqueName -PublisherPrefix "earnint" -PayloadsFolder $payloadFolder
if ($LASTEXITCODE -ne 0) { throw "Process event solution membership failed." }

$newCases = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $newProfiles) {
    $safeTitle = Escape-ODataString $profile.Title
    $found = @(Find-One "incidents" "title eq '$safeTitle'" $caseSelect)
    if ($found.Count -eq 1) {
        $newCases.Add($found[0])
        Write-Host "  [SKIP] Case exists: $($profile.Title)" -ForegroundColor DarkGray
        continue
    }
    $body = @{
        title = $profile.Title
        description = "Synthetic Process Mining demonstration Case. No real SSA or beneficiary data."
        prioritycode = if ($profile.Risk -ge 100000002) { 1 } else { 2 }
        statuscode = 1
        casetypecode = 2
        demo_datacustomerapplication = $ApplicationChoiceValue
        earnint_reviewtype = 100000000
        earnint_referralsource = 100000008
        earnint_allegationtype = 100000000
        earnint_discrepancytype = 100000001
        earnint_riskrating = $profile.Risk
        earnint_fraudriskscore = switch ($profile.Risk) { 100000000 { 24 }; 100000001 { 48 }; 100000002 { 76 }; default { 92 } }
        earnint_confidencescore = 82
        earnint_confidencelevel = 100000002
        earnint_potentialoverpayment = $profile.Amount
        earnint_impactedmonthcount = 4
        earnint_largestmonthlyvariance = [math]::Round($profile.Amount / 4, 2)
        earnint_evidencestatus = 100000002
        earnint_beneficiaryresponsestatus = 100000002
        earnint_identityvalidationstatus = 100000002
        earnint_queueassignment = $profile.Queue
        earnint_casedisposition = $profile.Disposition
        earnint_finaldetermination = $profile.Final
        earnint_supervisorreviewrequired = ($profile.Risk -ge 100000002)
        earnint_humanreviewrequired = $true
        earnint_supervisorapproval = ($profile.Risk -lt 100000002)
        overriddencreatedon = $profile.Base.ToString("yyyy-MM-ddTHH:mm:ssZ")
        "customerid_contact@odata.bind" = "/contacts($($contact.contactid))"
    }
    $created = Invoke-Dv Post "incidents" $body
    $newCases.Add($created)
    Write-Host "  [CREATE] Case: $($profile.Title)" -ForegroundColor Green
}

# Refresh the four new Cases to obtain formatted values and all event context.
$refreshedNewCases = [System.Collections.Generic.List[object]]::new()
foreach ($profile in $newProfiles) {
    $safeTitle = Escape-ODataString $profile.Title
    $row = @(Find-One "incidents" "title eq '$safeTitle'" $caseSelect)
    if ($row.Count -ne 1) { throw "Could not resolve new Case '$($profile.Title)'." }
    $refreshedNewCases.Add($row[0])
}
$newCases = $refreshedNewCases

# Supporting records are created only for the four isolated new Cases.
for ($index = 0; $index -lt $newCases.Count; $index++) {
    $case = $newCases[$index]
    $profile = $newProfiles[$index]
    $childName = $profile.Id
    $safe = Escape-ODataString $childName
    if (@(Find-One "earnint_earningsdiscrepancies" "earnint_earningsdiscrepancy_name eq '$safe - Discrepancy'" "earnint_earningsdiscrepancyid").Count -eq 0) {
        Invoke-Dv Post "earnint_earningsdiscrepancies" @{
            earnint_earningsdiscrepancy_name = "$childName - Discrepancy"
            earnint_discrepancytype = 100000001
            earnint_earningsourcetype = 100000002
            earnint_reportedearnings = 0
            earnint_authoritativeearnings = $profile.Amount
            earnint_discrepancyamount = $profile.Amount
            earnint_discrepancypercent = 100
            earnint_earningsperiod = "Synthetic PM cohort"
            earnint_employername = "Process Mining Demo Employer"
            earnint_sourcesystem = "Synthetic Wage Match Workflow"
            earnint_requiresmanualreview = $true
            "earnint_caseid_discrepancy@odata.bind" = "/incidents($($case.incidentid))"
        } | Out-Null
    }
    if (@(Find-One "earnint_evidenceitems" "earnint_evidenceitem_name eq '$safe - Evidence'" "earnint_evidenceitemid").Count -eq 0) {
        Invoke-Dv Post "earnint_evidenceitems" @{
            earnint_evidenceitem_name = "$childName - Evidence"
            earnint_evidencetype = 100000004
            earnint_receiveddate = $profile.Base.AddDays(3).ToString("yyyy-MM-dd")
            earnint_status = 100000003
            earnint_supportsfinding = 100000000
            earnint_evidencedesc = "Synthetic supporting wage evidence for Process Mining."
            earnint_documentname = "$childName-WageEvidence.pdf"
            earnint_verifiedby = "Avery Johnson, Earnings Analyst"
            earnint_notes = "Synthetic demo record."
            "earnint_caseid_evidence@odata.bind" = "/incidents($($case.incidentid))"
        } | Out-Null
    }
    if (@(Find-One "earnint_investigationfindings" "earnint_investigationfinding_name eq '$safe - Finding'" "earnint_investigationfindingid").Count -eq 0) {
        Invoke-Dv Post "earnint_investigationfindings" @{
            earnint_investigationfinding_name = "$childName - Finding"
            earnint_findingtype = if ($profile.Risk -eq 100000003) { 100000007 } else { 100000006 }
            earnint_severity = $profile.Risk
            earnint_findingdetails = "Synthetic analyst finding for Process Mining demonstration."
            earnint_recommendation = "Complete the documented human review path."
            earnint_recddisposition = $profile.Disposition
            earnint_supervisorapprovalstatus = 100000001
            earnint_analystname = "Avery Johnson"
            earnint_supervisorcomments = "Synthetic demonstration approval."
            "earnint_caseid_finding@odata.bind" = "/incidents($($case.incidentid))"
        } | Out-Null
    }
}

$events = [System.Collections.Generic.List[object]]::new()
$analystA = "Avery Johnson"
$analystB = "Morgan Lee"
$supervisor = "Jordan Patel"
$workflow = "Earnings Signal Intake Flow"

# Eight existing active Cases receive only additive explicit event rows.
for ($index = 0; $index -lt $existingCases.Count; $index++) {
    $case = $existingCases[$index]
    $base = [datetimeoffset]::Parse("$($case.createdon)").AddHours(1)
    $queue = Get-FormattedValue $case "earnint_queueassignment"
    $recommended = Get-FormattedValue $case "earnint_casedisposition"
    Add-PlannedEvent $events $case 10 "Earnings Signal Received" $base $workflow "Automated Workflow" $queue "" "Signal Received"
    Add-PlannedEvent $events $case 20 "Risk Triage Started" $base.AddHours(2) $analystA "Human" $queue "Signal Received" "Triage In Progress"
    Add-PlannedEvent $events $case 30 "Case Assigned" $base.AddHours(4) $analystA "Human" $queue "Unassigned" "Assigned"
    Add-PlannedEvent $events $case 40 "Earnings Discrepancy Reviewed" $base.AddDays(1) $analystA "Human" $queue "Triage In Progress" "Evidence Review"
    Add-PlannedEvent $events $case 50 "Evidence Received" $base.AddDays(2) $analystA "Human" $queue "Requested" "Received" $false $false "W-2 / Tax Wage Document" "Received"
    Add-PlannedEvent $events $case 60 "Evidence Validated" $base.AddDays(3) $analystA "Human" $queue "Received" "Verified" $false $false "W-2 / Tax Wage Document" "Verified"

    if ($index -lt 3) {
        Add-PlannedEvent $events $case 70 "Additional Evidence Requested" $base.AddDays(4) $analystA "Human" "Evidence Needed Queue" "Verified" "Additional Evidence Requested" $false $true "Beneficiary Statement" "Requested"
        Add-PlannedEvent $events $case 80 "Evidence Received" $base.AddDays(8) $analystB "Human" "Evidence Needed Queue" "Requested" "Received" $false $true "Beneficiary Statement" "Received"
    }
    if ($index -in @(1, 2, 3)) {
        Add-PlannedEvent $events $case 90 "Case Assigned" $base.AddDays(9) $analystB "Human" $queue "Assigned - Avery Johnson" "Assigned - Morgan Lee" $true
    }
    if ($index -in @(2, 3, 4)) {
        Add-PlannedEvent $events $case 100 "Analyst Finding Submitted" $base.AddDays(10) $analystB "Human" "Supervisor Approval Queue" "Finding Draft" "Pending Supervisor" $false $false "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 110 "Supervisor Review Started" $base.AddDays(11) $supervisor "Human" "Supervisor Approval Queue" "Pending Supervisor" "Supervisor Review" $false $false "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 120 "Case Returned to Analyst" $base.AddDays(12) $supervisor "Human" "Evidence Needed Queue" "Supervisor Review" "Returned to Analyst" $false $true "" "" "Potential Overpayment" $recommended "" "Return for Additional Evidence"
        Add-PlannedEvent $events $case 130 "Finding Revised" $base.AddDays(14) $analystB "Human" "Evidence Needed Queue" "Returned to Analyst" "Finding Revised" $false $true "" "" "Potential Overpayment" $recommended
    }
    if ($index -in @(5, 6)) {
        Add-PlannedEvent $events $case 140 "Case Escalated" $base.AddDays(7) $supervisor "Human" "Fraud Escalation Queue" "Evidence Review" "Escalated" $false $false "" "" "Potential Fraud" "Create Fraud Escalation Package"
    }
}

# Four isolated Cases receive complete start-to-disposition histories.
for ($index = 0; $index -lt $newCases.Count; $index++) {
    $case = $newCases[$index]
    $profile = $newProfiles[$index]
    $base = $profile.Base
    $queue = $profile.QueueLabel
    $recommended = Get-FormattedValue $case "earnint_casedisposition"
    $final = Get-FormattedValue $case "earnint_finaldetermination"
    Add-PlannedEvent $events $case 10 "Earnings Signal Received" $base $workflow "Automated Workflow" "Earnings Review Intake Queue" "" "Signal Received"
    Add-PlannedEvent $events $case 20 "Case Created" $base.AddMinutes(5) "Case Intake Workflow" "Automated Workflow" "Earnings Review Intake Queue" "Signal Received" "New"
    Add-PlannedEvent $events $case 30 "Risk Triage Started" $base.AddHours(3) $analystA "Human" $queue "New" "Triage In Progress"
    Add-PlannedEvent $events $case 40 "Case Assigned" $base.AddHours(5) $analystA "Human" $queue "Unassigned" "Assigned"
    Add-PlannedEvent $events $case 50 "Earnings Discrepancy Reviewed" $base.AddDays(1) $analystA "Human" $queue "Triage In Progress" "Evidence Review"
    Add-PlannedEvent $events $case 60 "Evidence Requested" $base.AddDays(1).AddHours(2) $analystA "Human" "Evidence Needed Queue" "Not Started" "Requested" $false $false "W-2 / Tax Wage Document" "Requested"
    Add-PlannedEvent $events $case 70 "Evidence Received" $base.AddDays(3) "Document Intake Workflow" "Automated Workflow" "Evidence Needed Queue" "Requested" "Received" $false $false "W-2 / Tax Wage Document" "Received"
    Add-PlannedEvent $events $case 80 "Evidence Validated" $base.AddDays(4) $analystA "Human" $queue "Received" "Verified" $false $false "W-2 / Tax Wage Document" "Verified"

    if ($index -eq 1) {
        Add-PlannedEvent $events $case 90 "Additional Evidence Requested" $base.AddDays(5) $analystA "Human" "Evidence Needed Queue" "Verified" "Additional Evidence Requested" $false $true "Beneficiary Statement" "Requested"
        Add-PlannedEvent $events $case 100 "Evidence Received" $base.AddDays(12) $analystB "Human" "Evidence Needed Queue" "Requested" "Received" $false $true "Beneficiary Statement" "Received"
    }
    if ($index -eq 2) {
        Add-PlannedEvent $events $case 90 "Earnings Analysis Completed" $base.AddDays(5) $analystA "Human" $queue "Evidence Review" "Analysis Complete"
        Add-PlannedEvent $events $case 100 "Analyst Finding Drafted" $base.AddDays(6) $analystA "Human" $queue "Analysis Complete" "Finding Draft" $false $false "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 110 "Analyst Finding Submitted" $base.AddDays(7) $analystA "Human" "Supervisor Approval Queue" "Finding Draft" "Pending Supervisor" $false $false "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 120 "Supervisor Review Started" $base.AddDays(8) $supervisor "Human" "Supervisor Approval Queue" "Pending Supervisor" "Supervisor Review"
        Add-PlannedEvent $events $case 130 "Case Returned to Analyst" $base.AddDays(9) $supervisor "Human" "Evidence Needed Queue" "Supervisor Review" "Returned to Analyst" $false $true "" "" "Potential Overpayment" $recommended "" "Return for Additional Evidence"
        Add-PlannedEvent $events $case 140 "Finding Revised" $base.AddDays(11) $analystA "Human" "Evidence Needed Queue" "Returned to Analyst" "Finding Revised" $false $true "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 150 "Analyst Finding Submitted" $base.AddDays(12) $analystA "Human" "Supervisor Approval Queue" "Finding Revised" "Pending Supervisor" $false $true "" "" "Potential Overpayment" $recommended
        Add-PlannedEvent $events $case 160 "Supervisor Approved" $base.AddDays(13) $supervisor "Human" "Supervisor Approval Queue" "Supervisor Review" "Approved" $false $false "" "" "Potential Overpayment" $recommended "" "Approved"
    } else {
        $findingType = if ($index -eq 3) { "Potential Fraud" } else { "Potential Overpayment" }
        Add-PlannedEvent $events $case 110 "Earnings Analysis Completed" $base.AddDays(6) $analystA "Human" $queue "Evidence Review" "Analysis Complete"
        Add-PlannedEvent $events $case 120 "Analyst Finding Drafted" $base.AddDays(7) $analystA "Human" $queue "Analysis Complete" "Finding Draft" $false $false "" "" $findingType $recommended
    }
    if ($index -eq 3) {
        Add-PlannedEvent $events $case 130 "Case Assigned" $base.AddDays(8) $analystB "Human" "High-Risk Fraud Review Queue" "Assigned - Avery Johnson" "Assigned - Morgan Lee" $true
        Add-PlannedEvent $events $case 140 "Analyst Finding Submitted" $base.AddDays(9) $analystB "Human" "Supervisor Approval Queue" "Finding Draft" "Pending Supervisor" $false $false "" "" "Potential Fraud" $recommended
        Add-PlannedEvent $events $case 150 "Supervisor Review Started" $base.AddDays(10) $supervisor "Human" "Supervisor Approval Queue" "Pending Supervisor" "Supervisor Review"
        Add-PlannedEvent $events $case 160 "Supervisor Approved" $base.AddDays(11) $supervisor "Human" "Supervisor Approval Queue" "Supervisor Review" "Approved" $false $false "" "" "Potential Fraud" $recommended "" "Approved"
        Add-PlannedEvent $events $case 170 "Case Escalated" $base.AddDays(12) $supervisor "Human" "Fraud Escalation Queue" "Approved" "Escalated" $false $false "" "" "Potential Fraud" "Create Fraud Escalation Package"
    }
    $lastSequence = if ($index -eq 2) { 170 } elseif ($index -eq 3) { 180 } else { 130 }
    $daysToClose = if ($index -eq 0) { 9 } elseif ($index -eq 1) { 16 } elseif ($index -eq 2) { 15 } else { 14 }
    $closeDate = $base.AddDays($daysToClose)
    $supervisorDecision = if ($index -ge 2) { "Approved" } else { "Not Required" }
    Add-PlannedEvent $events $case $lastSequence "Case Closed / Disposition Completed" $closeDate $supervisor "Human" "Closed / Monitoring Queue" "Disposition Pending" "Closed" $false $false "" "Complete" "" $recommended $final $supervisorDecision
}

Write-Host "Seeding $($events.Count) explicit process events ..." -ForegroundColor Yellow
$createdEvents = 0
$skippedEvents = 0
foreach ($event in $events) {
    $safeKey = Escape-ODataString $event.Key
    $existing = @(Find-One "earnint_processevents" "earnint_processevent_name eq '$safeKey'" "earnint_processeventid")
    if ($existing.Count -eq 1) { $skippedEvents++; continue }
    $body = @{
        earnint_processevent_name = $event.Key
        earnint_activityname = $event.Activity
        earnint_starttimestamp = $event.Start.ToString("yyyy-MM-ddTHH:mm:ssZ")
        earnint_resource = $event.Resource
        earnint_resourcetype = $event.ResourceType
        earnint_previousstatus = $event.PreviousStatus
        earnint_newstatus = $event.NewStatus
        earnint_queueorteam = $event.Queue
        earnint_risklevel = $event.RiskLevel
        earnint_discrepancyamount = $event.DiscrepancyAmount
        earnint_evidencetype = $event.EvidenceType
        earnint_evidencestatus = $event.EvidenceStatus
        earnint_findingtype = $event.FindingType
        earnint_recommendeddisposition = $event.RecommendedDisposition
        earnint_finaldisposition = $event.FinalDisposition
        earnint_supervisordecision = $event.SupervisorDecision
        earnint_reassignmentindicator = $event.Reassignment
        earnint_reworkindicator = $event.Rework
        earnint_sourcesystem = "SYNTHETIC_PROCESS_MINING_DEMO"
        earnint_sourcerecordid = "$($event.Case.incidentid)"
        earnint_issyntheticdemoevent = $true
        "earnint_caseid_processevent@odata.bind" = "/incidents($($event.Case.incidentid))"
    }
    if ($event.End) { $body.earnint_endtimestamp = $event.End.Value.ToString("yyyy-MM-ddTHH:mm:ssZ") }
    Invoke-Dv Post "earnint_processevents" $body | Out-Null
    $createdEvents++
}

# Resolve only the four isolated Cases; existing cohort Cases remain untouched.
foreach ($case in $newCases) {
    $current = Invoke-Dv Get "incidents($($case.incidentid))?`$select=incidentid,statecode" $null
    if ([int]$current.statecode -eq 1) { continue }
    Invoke-Dv Post "CloseIncident" @{
        IncidentResolution = @{
            subject = "Synthetic Process Mining disposition completed"
            description = "Synthetic demo closure; no real beneficiary determination."
            timespent = 0
            "incidentid@odata.bind" = "/incidents($($case.incidentid))"
        }
        Status = 5
    } | Out-Null
}

# Validation: exact cohort, explicit events, variants, and non-modification of existing Cases.
$seededEvents = @(Get-DvRows "earnint_processevents?`$select=earnint_processeventid,earnint_processevent_name,earnint_activityname,earnint_starttimestamp,earnint_resourcetype,earnint_reassignmentindicator,earnint_reworkindicator,earnint_sourcesystem,earnint_issyntheticdemoevent,_earnint_caseid_processevent_value&`$filter=earnint_sourcesystem eq 'SYNTHETIC_PROCESS_MINING_DEMO'&`$top=5000")
$validationErrors = [System.Collections.Generic.List[string]]::new()
if ($seededEvents.Count -ne $events.Count) { $validationErrors.Add("Expected $($events.Count) explicit events; found $($seededEvents.Count).") }
if (@($seededEvents | Group-Object earnint_processevent_name | Where-Object Count -gt 1).Count -gt 0) { $validationErrors.Add("Duplicate deterministic event keys exist.") }
if (@($seededEvents | Where-Object { -not $_.earnint_activityname -or -not $_.earnint_starttimestamp -or -not $_.earnint_resourcetype -or -not $_.earnint_issyntheticdemoevent }).Count -gt 0) { $validationErrors.Add("One or more explicit events is missing a required analytical value.") }
if (@($seededEvents | Where-Object earnint_reassignmentindicator).Count -lt 3) { $validationErrors.Add("Fewer than three reassignment events exist.") }
if (@($seededEvents | Where-Object earnint_reworkindicator).Count -lt 3) { $validationErrors.Add("Fewer than three rework events exist.") }
if (@($seededEvents | Where-Object earnint_activityname -eq "Case Escalated").Count -lt 2) { $validationErrors.Add("Fewer than two escalation events exist.") }
if (@($seededEvents | Where-Object earnint_activityname -eq "Supervisor Review Started").Count -lt 3) { $validationErrors.Add("Fewer than three supervisor handoffs exist.") }
if (@($seededEvents | Where-Object earnint_resourcetype -eq "Automated Workflow").Count -lt 12) { $validationErrors.Add("Not every cohort Case has automated workflow evidence.") }
if (@($seededEvents | Where-Object earnint_resourcetype -eq "AI Agent").Count -gt 0) { $validationErrors.Add("Unsupported AI Agent events were seeded.") }

foreach ($case in $existingCases) {
    $after = Invoke-Dv Get "incidents($($case.incidentid))?`$select=statecode,statuscode,modifiedon,_ownerid_value" $null
    $snapshot = "$($after.statecode)|$($after.statuscode)|$($after._ownerid_value)|$($after.modifiedon)"
    if ($snapshot -ne $existingSnapshots["$($case.incidentid)"]) { $validationErrors.Add("Existing Case '$($case.title)' changed during enrichment.") }
}
foreach ($case in $newCases) {
    $after = Invoke-Dv Get "incidents($($case.incidentid))?`$select=statecode" $null
    if ([int]$after.statecode -ne 1) { $validationErrors.Add("New Case '$($case.title)' was not resolved.") }
}

Write-Host ""
Write-Host "=== Process Mining Demo Validation ===" -ForegroundColor Cyan
Write-Host "  Existing Cases unchanged: 8"
Write-Host "  New isolated Cases:        4"
Write-Host "  Planned events:            $($events.Count)"
Write-Host "  Events created:            $createdEvents"
Write-Host "  Events skipped:            $skippedEvents"
Write-Host "  Explicit events validated: $($seededEvents.Count)"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Process Mining demo validation failed with $($validationErrors.Count) error(s)."
}
Write-Host "  Validation: PASS" -ForegroundColor Green