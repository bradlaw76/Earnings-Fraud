<#
.SYNOPSIS
    Exports an SSA Earnings Integrity Process Mining event log and supporting assessments.

.DESCRIPTION
    Reads scoped Dataverse Cases and related discrepancies, evidence, findings,
    activities, queue items, resolutions, audit rows, and Business Process Flow
    instances. The script does not write to Dataverse.

    Events backed only by current state are kept out of the event log unless the
    state itself is useful evidence. Those rows are identified as inferred in the
    data-quality report. Scheduled activities are named as scheduled work and are
    never represented as completed work.
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [int]$ApplicationChoiceValue = 581180001,
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "artifacts")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$token = az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Azure CLI did not return a Dataverse access token for $EnvironmentUrl."
}

$headers = @{
    Authorization = "Bearer $token"
    Accept = "application/json"
    Prefer = 'odata.include-annotations="OData.Community.Display.V1.FormattedValue"'
}

function Get-DvRows {
    param([Parameter(Mandatory)][string]$Path)

    $rows = [System.Collections.Generic.List[object]]::new()
    $uri = if ($Path -match '^https://') { $Path } else { "$EnvironmentUrl/api/data/v9.2/$Path" }
    do {
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        foreach ($row in @($response.value)) {
            $rows.Add($row)
        }
        $nextLink = $response.PSObject.Properties['@odata.nextLink']
        $uri = if ($null -ne $nextLink) { "$($nextLink.Value)" } else { $null }
    } while ($uri)
    return @($rows)
}

function Get-FormattedValue {
    param([object]$Row, [string]$Column)

    if ($null -eq $Row) { return "" }
    $property = "$Column@OData.Community.Display.V1.FormattedValue"
    $value = $Row.PSObject.Properties[$property].Value
    if ($null -eq $value) { return "" }
    return "$value"
}

function Get-IsoTimestamp {
    param([object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) { return "" }
    $parsed = [datetimeoffset]::Parse("$Value", [Globalization.CultureInfo]::InvariantCulture)
    return $parsed.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

function Get-DateOnlyTimestamp {
    param([object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) { return "" }
    $text = "$Value"
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsed)) {
        if (-not [datetime]::TryParse($text, [Globalization.CultureInfo]::CurrentCulture, [Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsed)) {
            throw "Unable to parse Dataverse date-only value '$text'."
        }
    }
    return $parsed.ToString("yyyy-MM-ddT00:00:00.000Z")
}

function Get-CaseId {
    param([object]$Case)

    if ("$($Case.title)" -match '(EIR-PM-[0-9]{4}-[A-Z]+)') {
        return $matches[1]
    }
    if ("$($Case.title)" -match '(EIR-[0-9]{4}-(?:BULK-)?[0-9]{3,4})') {
        return $matches[1]
    }
    if (-not [string]::IsNullOrWhiteSpace("$($Case.ticketnumber)")) {
        return "$($Case.ticketnumber)"
    }
    return "$($Case.incidentid)"
}

function Get-ResourceType {
    param([string]$Resource, [string]$Default = "Human")

    if ([string]::IsNullOrWhiteSpace($Resource)) { return $Default }
    if ($Resource -match '(?i)AI|Copilot|agent') { return "AI Agent" }
    if ($Resource -match '(?i)system|workflow|flow|automation|synthetic wage feed|data match|import|script') { return "Automated Workflow" }
    return $Default
}

$qualityRows = [System.Collections.Generic.List[object]]::new()
function Add-QualityIssue {
    param(
        [string]$IssueType,
        [string]$Severity,
        [string]$CaseId,
        [string]$ActivityName,
        [string]$Timestamp,
        [string]$Details,
        [int]$RecordCount = 1,
        [string]$Recommendation = ""
    )

    $qualityRows.Add([pscustomobject][ordered]@{
        IssueType = $IssueType
        Severity = $Severity
        CaseId = $CaseId
        ActivityName = $ActivityName
        Timestamp = $Timestamp
        Details = $Details
        RecordCount = $RecordCount
        Recommendation = $Recommendation
    })
}

Write-Host "Reading scoped Dataverse records from $EnvironmentUrl ..." -ForegroundColor Cyan

$caseSelect = @(
    "incidentid", "ticketnumber", "title", "createdon", "modifiedon", "statecode", "statuscode",
    "_ownerid_value", "_createdby_value", "_modifiedby_value", "earnint_riskrating",
    "earnint_queueassignment", "earnint_casedisposition", "earnint_finaldetermination",
    "earnint_evidencestatus", "earnint_supervisorreviewrequired", "earnint_supervisorapproval",
    "earnint_referralsource", "earnfrau_aisummary", "earnfrau_airawjson"
) -join ','
$cases = @(Get-DvRows "incidents?`$select=$caseSelect&`$filter=demo_datacustomerapplication eq $ApplicationChoiceValue&`$orderby=createdon asc")
if ($cases.Count -eq 0) {
    throw "No scoped Earnings Integrity Cases were found."
}

$caseByGuid = @{}
$caseBusinessIdByGuid = @{}
foreach ($case in $cases) {
    $guid = "$($case.incidentid)".ToLowerInvariant()
    $caseByGuid[$guid] = $case
    $caseBusinessIdByGuid[$guid] = Get-CaseId $case
}

$discrepancies = @(Get-DvRows "earnint_earningsdiscrepancies?`$select=earnint_earningsdiscrepancyid,earnint_earningsdiscrepancy_name,createdon,modifiedon,_createdby_value,_ownerid_value,_earnint_caseid_discrepancy_value,earnint_discrepancyamount,earnint_sourcesystem,earnint_discrepancytype&`$top=5000" | Where-Object { $_._earnint_caseid_discrepancy_value -and $caseByGuid.ContainsKey("$($_._earnint_caseid_discrepancy_value)".ToLowerInvariant()) })
$evidence = @(Get-DvRows "earnint_evidenceitems?`$select=earnint_evidenceitemid,earnint_evidenceitem_name,createdon,modifiedon,_createdby_value,_ownerid_value,_earnint_caseid_evidence_value,earnint_evidencetype,earnint_receiveddate,earnint_status,earnint_verifiedby&`$top=5000" | Where-Object { $_._earnint_caseid_evidence_value -and $caseByGuid.ContainsKey("$($_._earnint_caseid_evidence_value)".ToLowerInvariant()) })
$findings = @(Get-DvRows "earnint_investigationfindings?`$select=earnint_investigationfindingid,earnint_investigationfinding_name,createdon,modifiedon,_createdby_value,_ownerid_value,_earnint_caseid_finding_value,earnint_findingtype,earnint_recddisposition,earnint_supervisorapprovalstatus,earnint_analystname&`$top=5000" | Where-Object { $_._earnint_caseid_finding_value -and $caseByGuid.ContainsKey("$($_._earnint_caseid_finding_value)".ToLowerInvariant()) })
$tasks = @(Get-DvRows "tasks?`$select=activityid,subject,category,subcategory,description,createdon,modifiedon,scheduledstart,scheduledend,actualstart,actualend,statecode,statuscode,_createdby_value,_ownerid_value,_regardingobjectid_value&`$top=5000" | Where-Object { $_._regardingobjectid_value -and $caseByGuid.ContainsKey("$($_._regardingobjectid_value)".ToLowerInvariant()) })
$appointments = @(Get-DvRows "appointments?`$select=activityid,subject,createdon,modifiedon,scheduledstart,scheduledend,actualstart,actualend,statecode,statuscode,_createdby_value,_ownerid_value,_regardingobjectid_value&`$top=5000" | Where-Object { $_._regardingobjectid_value -and $caseByGuid.ContainsKey("$($_._regardingobjectid_value)".ToLowerInvariant()) })
$resolutions = @(Get-DvRows "incidentresolutions?`$select=activityid,subject,createdon,modifiedon,actualend,statecode,statuscode,_createdby_value,_ownerid_value,_incidentid_value&`$top=5000" | Where-Object { $_._incidentid_value -and $caseByGuid.ContainsKey("$($_._incidentid_value)".ToLowerInvariant()) })
$queueItems = @(Get-DvRows "queueitems?`$select=queueitemid,createdon,enteredon,modifiedon,_objectid_value,_queueid_value,_workerid_value&`$top=5000" | Where-Object { $_._objectid_value -and $caseByGuid.ContainsKey("$($_._objectid_value)".ToLowerInvariant()) })
$audits = @(Get-DvRows "audits?`$select=auditid,createdon,action,operation,_objectid_value,_userid_value,objecttypecode&`$filter=objecttypecode eq 'incident'&`$top=5000" | Where-Object { $_._objectid_value -and $caseByGuid.ContainsKey("$($_._objectid_value)".ToLowerInvariant()) })
$bpfInstances = @(Get-DvRows "earnfrau_earningsfraudcasereviews?`$select=businessprocessflowinstanceid,bpf_name,createdon,modifiedon,activestagestartedon,completedon,traversedpath,_activestageid_value,_bpf_incidentid_value,_createdby_value,_modifiedby_value,statecode,statuscode&`$top=5000" | Where-Object { $_._bpf_incidentid_value -and $caseByGuid.ContainsKey("$($_._bpf_incidentid_value)".ToLowerInvariant()) })
$explicitProcessEvents = @(Get-DvRows "earnint_processevents?`$select=earnint_processeventid,earnint_processevent_name,earnint_activityname,earnint_starttimestamp,earnint_endtimestamp,earnint_resource,earnint_resourcetype,earnint_queueorteam,earnint_risklevel,earnint_discrepancyamount,earnint_evidencestatus,earnint_recommendeddisposition,earnint_finaldisposition,earnint_sourcesystem,earnint_sourcerecordid,earnint_issyntheticdemoevent,_earnint_caseid_processevent_value&`$top=5000" | Where-Object { $_._earnint_caseid_processevent_value -and $caseByGuid.ContainsKey("$($_._earnint_caseid_processevent_value)".ToLowerInvariant()) })
$explicitCaseGuids = @{}
foreach ($row in $explicitProcessEvents) { $explicitCaseGuids["$($row._earnint_caseid_processevent_value)".ToLowerInvariant()] = $true }
$processStages = @(Get-DvRows "processstages?`$select=processstageid,stagename,stagecategory,_processid_value&`$filter=_processid_value eq aa834710-ec90-f111-8077-000d3a189124")
$stageByGuid = @{}
foreach ($stage in $processStages) { $stageByGuid["$($stage.processstageid)".ToLowerInvariant()] = "$($stage.stagename)" }

$amountByCase = @{}
foreach ($group in @($discrepancies | Group-Object { "$($_._earnint_caseid_discrepancy_value)".ToLowerInvariant() })) {
    $amountByCase[$group.Name] = [decimal](($group.Group | Measure-Object -Property earnint_discrepancyamount -Sum).Sum)
}

$events = [System.Collections.Generic.List[object]]::new()
$eventEvidence = [System.Collections.Generic.List[object]]::new()
function Add-Event {
    param(
        [string]$CaseGuid,
        [string]$ActivityName,
        [string]$StartTimestamp,
        [string]$EndTimestamp,
        [string]$Resource,
        [string]$ResourceType,
        [string]$QueueOrTeam,
        [string]$EvidenceStatus,
        [string]$RecommendedDisposition,
        [string]$FinalDisposition,
        [string]$EvidenceKind,
        [string]$SourceTable,
        [string]$SourceRecordId,
        [bool]$Inferred = $false
    )

    if ([string]::IsNullOrWhiteSpace($StartTimestamp)) {
        Add-QualityIssue "MissingTimestamp" "High" $caseBusinessIdByGuid[$CaseGuid] $ActivityName "" "Source record $SourceRecordId has no usable event timestamp." 1 "Populate a business event timestamp or enable auditing."
        return
    }
    $case = $caseByGuid[$CaseGuid]
    $risk = Get-FormattedValue $case "earnint_riskrating"
    $queue = if ($QueueOrTeam) { $QueueOrTeam } else { Get-FormattedValue $case "earnint_queueassignment" }
    $amount = if ($amountByCase.ContainsKey($CaseGuid)) { $amountByCase[$CaseGuid] } else { $null }
    $events.Add([pscustomobject][ordered]@{
        CaseId = $caseBusinessIdByGuid[$CaseGuid]
        ActivityName = $ActivityName
        StartTimestamp = $StartTimestamp
        EndTimestamp = $EndTimestamp
        Resource = $Resource
        ResourceType = $ResourceType
        QueueOrTeam = $queue
        RiskLevel = $risk
        DiscrepancyAmount = $amount
        EvidenceStatus = $EvidenceStatus
        RecommendedDisposition = $RecommendedDisposition
        FinalDisposition = $FinalDisposition
    })
    $eventEvidence.Add([pscustomobject]@{
        CaseId = $caseBusinessIdByGuid[$CaseGuid]
        ActivityName = $ActivityName
        StartTimestamp = $StartTimestamp
        EvidenceKind = $EvidenceKind
        SourceTable = $SourceTable
        SourceRecordId = $SourceRecordId
        Inferred = $Inferred
    })
    if ($Inferred) {
        Add-QualityIssue "InferredEvent" "Medium" $caseBusinessIdByGuid[$CaseGuid] $ActivityName $StartTimestamp "Event is derived from current state and $EvidenceKind; no dated transition or audit detail exists." 1 "Enable Dataverse auditing or create an immutable process-event table."
    }
}

foreach ($case in $cases) {
    $guid = "$($case.incidentid)".ToLowerInvariant()
    $createdBy = Get-FormattedValue $case "_createdby_value"
    $owner = Get-FormattedValue $case "_ownerid_value"
    $recommended = Get-FormattedValue $case "earnint_casedisposition"
    $final = Get-FormattedValue $case "earnint_finaldetermination"
    $evidenceStatus = Get-FormattedValue $case "earnint_evidencestatus"
    Add-Event $guid "Case Created" (Get-IsoTimestamp $case.createdon) "" $createdBy (Get-ResourceType $createdBy "Human") "" $evidenceStatus $recommended $final "incident.createdon" "incident" "$($case.incidentid)"
    if ($owner) {
        Add-Event $guid "Case Assigned" (Get-IsoTimestamp $case.createdon) "" $owner (Get-ResourceType $owner "Human") "" $evidenceStatus $recommended $final "initial owner assigned at Case creation" "incident" "$($case.incidentid)"
    }
    if (-not [string]::IsNullOrWhiteSpace("$($case.earnfrau_aisummary)")) {
        $modelCalled = "$($case.earnfrau_airawjson)" -match '(?i)"?ai_model_called"?\s*:\s*true'
        $resource = if ($modelCalled) { "Earnings Integrity AI Agent" } else { "Seeded Demo Analysis Workflow" }
        $resourceType = if ($modelCalled) { "AI Agent" } else { "Automated Workflow" }
        Add-Event $guid "AI Analysis Result Recorded" (Get-IsoTimestamp $case.modifiedon) "" $resource $resourceType "" $evidenceStatus $recommended $final "AI summary fields and incident.modifiedon" "incident" "$($case.incidentid)" $true
    }
}

foreach ($row in $discrepancies) {
    $guid = "$($row._earnint_caseid_discrepancy_value)".ToLowerInvariant()
    $resource = Get-FormattedValue $row "_createdby_value"
    $source = "$($row.earnint_sourcesystem)"
    if ($source -match '(?i)feed|match|import|system|synthetic') { $resource = $source }
    Add-Event $guid "Earnings Discrepancy Recorded" (Get-IsoTimestamp $row.createdon) "" $resource (Get-ResourceType $resource "Human") "" "" "" "" "earnings discrepancy record creation" "earnint_earningsdiscrepancy" "$($row.earnint_earningsdiscrepancyid)"
    if ($source -match '(?i)feed|match|import|system|synthetic') {
        Add-Event $guid "Earnings Signal Received" (Get-IsoTimestamp $row.createdon) "" $source "Automated Workflow" "" "" "" "" "automated discrepancy source recorded" "earnint_earningsdiscrepancy" "$($row.earnint_earningsdiscrepancyid)"
    }
}

foreach ($row in $evidence) {
    $guid = "$($row._earnint_caseid_evidence_value)".ToLowerInvariant()
    $status = Get-FormattedValue $row "earnint_status"
    $type = Get-FormattedValue $row "earnint_evidencetype"
    $createdBy = Get-FormattedValue $row "_createdby_value"
    $receivedTimestamp = Get-DateOnlyTimestamp $row.earnint_receiveddate
    if ($status -eq "Requested") {
        Add-Event $guid "Evidence Requested" (Get-IsoTimestamp $row.createdon) "" $createdBy (Get-ResourceType $createdBy "Human") "" $status "" "" "evidence record created with Requested status" "earnint_evidenceitem" "$($row.earnint_evidenceitemid)"
    }
    if ($receivedTimestamp) {
        $sourceResource = if ($type -match '(?i)Wage Report|Data Match') { $type } else { $createdBy }
        Add-Event $guid "Evidence Received" $receivedTimestamp "" $sourceResource (Get-ResourceType $sourceResource "Human") "" $status "" "" "evidence received-date field ($type)" "earnint_evidenceitem" "$($row.earnint_evidenceitemid)"
        Add-QualityIssue "DateOnlyTimestamp" "Low" $caseBusinessIdByGuid[$guid] "Evidence Received" $receivedTimestamp "earnint_receiveddate stores a date without time; midnight is a normalization placeholder." 1 "Capture an event date-time for sequencing within a day."
    } elseif ($status -in @("Received", "Under Review", "Verified")) {
        Add-Event $guid "Evidence Received" (Get-IsoTimestamp $row.createdon) "" $createdBy (Get-ResourceType $createdBy "Human") "" $status "" "" "evidence record creation and current status" "earnint_evidenceitem" "$($row.earnint_evidenceitemid)" $true
    }
    if ($status -eq "Verified") {
        $verifiedBy = if (-not [string]::IsNullOrWhiteSpace("$($row.earnint_verifiedby)")) { "$($row.earnint_verifiedby)" } else { Get-FormattedValue $row "_ownerid_value" }
        Add-Event $guid "Evidence Validated" (Get-IsoTimestamp $row.modifiedon) "" $verifiedBy (Get-ResourceType $verifiedBy "Human") "" $status "" "" "current Verified status and evidence.modifiedon" "earnint_evidenceitem" "$($row.earnint_evidenceitemid)" $true
    }
}

foreach ($row in $findings) {
    $guid = "$($row._earnint_caseid_finding_value)".ToLowerInvariant()
    $analyst = if (-not [string]::IsNullOrWhiteSpace("$($row.earnint_analystname)")) { "$($row.earnint_analystname)" } else { Get-FormattedValue $row "_createdby_value" }
    $recommended = Get-FormattedValue $row "earnint_recddisposition"
    Add-Event $guid "Analyst Finding Drafted" (Get-IsoTimestamp $row.createdon) "" $analyst (Get-ResourceType $analyst "Human") "" "" $recommended "" "investigation finding record creation" "earnint_investigationfinding" "$($row.earnint_investigationfindingid)"
    $approval = Get-FormattedValue $row "earnint_supervisorapprovalstatus"
    if ($approval -eq "Approved") {
        $supervisor = Get-FormattedValue $row "_ownerid_value"
        Add-Event $guid "Supervisor Approved" (Get-IsoTimestamp $row.modifiedon) "" $supervisor (Get-ResourceType $supervisor "Human") "Supervisor Approval Queue" "" $recommended "" "current Approved status and finding.modifiedon" "earnint_investigationfinding" "$($row.earnint_investigationfindingid)" $true
    }
}

foreach ($row in $tasks) {
    $guid = "$($row._regardingobjectid_value)".ToLowerInvariant()
    $owner = Get-FormattedValue $row "_ownerid_value"
    $category = "$($row.category)"
    if (-not [string]::IsNullOrWhiteSpace("$($row.actualstart)")) {
        $activity = switch ($category) {
            "Intake and Risk" { "Risk Triage Started" }
            "Evidence Review" { "Evidence Review Started" }
            "Follow-Up and Disposition" { "Disposition Preparation Started" }
            default { "Task Started" }
        }
        Add-Event $guid $activity (Get-IsoTimestamp $row.actualstart) (Get-IsoTimestamp $row.actualend) $owner (Get-ResourceType $owner "Human") "" "" "" "" "task actual start/end" "task" "$($row.activityid)"
    } elseif (-not [string]::IsNullOrWhiteSpace("$($row.scheduledstart)")) {
        $activity = switch ($category) {
            "Intake and Risk" { "Risk Triage Work Item Scheduled" }
            "Evidence Review" { "Evidence Review Work Item Scheduled" }
            "Follow-Up and Disposition" { "Disposition Work Item Scheduled" }
            default { "Task Scheduled" }
        }
        Add-Event $guid $activity (Get-IsoTimestamp $row.scheduledstart) (Get-IsoTimestamp $row.scheduledend) $owner (Get-ResourceType $owner "Human") "" "" "" "" "task scheduled start/end" "task" "$($row.activityid)"
    }
}

foreach ($row in $appointments) {
    $guid = "$($row._regardingobjectid_value)".ToLowerInvariant()
    $owner = Get-FormattedValue $row "_ownerid_value"
    $activity = if (-not [string]::IsNullOrWhiteSpace("$($row.actualstart)")) { "Beneficiary Clarification Completed" } else { "Beneficiary Clarification Scheduled" }
    $start = if ($activity -eq "Beneficiary Clarification Completed") { Get-IsoTimestamp $row.actualstart } else { Get-IsoTimestamp $row.scheduledstart }
    $end = if ($activity -eq "Beneficiary Clarification Completed") { Get-IsoTimestamp $row.actualend } else { Get-IsoTimestamp $row.scheduledend }
    Add-Event $guid $activity $start $end $owner (Get-ResourceType $owner "Human") "" "" "" "" "appointment timing" "appointment" "$($row.activityid)"
}

foreach ($row in $queueItems) {
    $guid = "$($row._objectid_value)".ToLowerInvariant()
    $queue = Get-FormattedValue $row "_queueid_value"
    $worker = Get-FormattedValue $row "_workerid_value"
    $resource = if ($worker) { $worker } else { $queue }
    $timestamp = if ($row.enteredon) { Get-IsoTimestamp $row.enteredon } else { Get-IsoTimestamp $row.createdon }
    Add-Event $guid "Case Assigned" $timestamp "" $resource (Get-ResourceType $resource "Human") $queue "" "" "" "queue item entry" "queueitem" "$($row.queueitemid)"
}

foreach ($row in $resolutions) {
    $guid = "$($row._incidentid_value)".ToLowerInvariant()
    $resource = Get-FormattedValue $row "_createdby_value"
    $timestamp = if ($row.actualend) { Get-IsoTimestamp $row.actualend } else { Get-IsoTimestamp $row.createdon }
    $case = $caseByGuid[$guid]
    Add-Event $guid "Case Closed / Disposition Completed" $timestamp "" $resource (Get-ResourceType $resource "Human") "" (Get-FormattedValue $case "earnint_evidencestatus") (Get-FormattedValue $case "earnint_casedisposition") (Get-FormattedValue $case "earnint_finaldetermination") "incident resolution creation" "incidentresolution" "$($row.activityid)"
}

$stageActivityMap = @{
    "Intake Triage" = "Risk Triage Started"
    "Case Details" = "Case Details Review Started"
    "Risk Decision" = "Risk Decision Stage Entered"
    "Evidence Collection" = "Evidence Gathering Started"
    "Analysis" = "Earnings Analysis Started"
    "Case Closure" = "Disposition Stage Started"
}
foreach ($row in $bpfInstances) {
    $guid = "$($row._bpf_incidentid_value)".ToLowerInvariant()
    $createdBy = Get-FormattedValue $row "_createdby_value"
    Add-Event $guid "Business Process Started" (Get-IsoTimestamp $row.createdon) "" $createdBy (Get-ResourceType $createdBy "Human") "" "" "" "" "BPF instance creation" "earnfrau_earningsfraudcasereview" "$($row.businessprocessflowinstanceid)"
    $stageId = "$($row._activestageid_value)".ToLowerInvariant()
    if ($stageByGuid.ContainsKey($stageId) -and $row.activestagestartedon) {
        $stageName = $stageByGuid[$stageId]
        $activity = if ($stageActivityMap.ContainsKey($stageName)) { $stageActivityMap[$stageName] } else { "$stageName Stage Entered" }
        $modifiedBy = Get-FormattedValue $row "_modifiedby_value"
        Add-Event $guid $activity (Get-IsoTimestamp $row.activestagestartedon) "" $modifiedBy (Get-ResourceType $modifiedBy "Human") "" "" "" "" "BPF active-stage start" "earnfrau_earningsfraudcasereview" "$($row.businessprocessflowinstanceid)"
    }
    if (-not [string]::IsNullOrWhiteSpace("$($row.traversedpath)")) {
        $traversedCount = @("$($row.traversedpath)" -split ',' | Where-Object { $_ }).Count
        if ($traversedCount -gt 1) {
            Add-QualityIssue "BpfStageTimestampGap" "Medium" $caseBusinessIdByGuid[$guid] "" "" "BPF traversedpath contains $traversedCount stages, but Dataverse exposes no per-stage timestamps for prior stages." $traversedCount "Instrument stage transitions in an immutable event table or enable audit history before stage movement."
        }
    }
}

# Explicit event histories are authoritative for their Cases. Remove evidence-derived
# rows for those Cases before adding the immutable process events to avoid duplication.
if ($explicitCaseGuids.Count -gt 0) {
    $explicitBusinessIds = @{}
    foreach ($guid in $explicitCaseGuids.Keys) { $explicitBusinessIds[$caseBusinessIdByGuid[$guid]] = $true }
    $legacyEvents = @($events | Where-Object { -not $explicitBusinessIds.ContainsKey($_.CaseId) })
    $legacyEvidence = @($eventEvidence | Where-Object { -not $explicitBusinessIds.ContainsKey($_.CaseId) })
    $events = [System.Collections.Generic.List[object]]::new()
    $eventEvidence = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $legacyEvents) { $events.Add($row) }
    foreach ($row in $legacyEvidence) { $eventEvidence.Add($row) }
}

foreach ($row in $explicitProcessEvents) {
    $guid = "$($row._earnint_caseid_processevent_value)".ToLowerInvariant()
    $events.Add([pscustomobject][ordered]@{
        CaseId = $caseBusinessIdByGuid[$guid]
        ActivityName = "$($row.earnint_activityname)"
        StartTimestamp = Get-IsoTimestamp $row.earnint_starttimestamp
        EndTimestamp = Get-IsoTimestamp $row.earnint_endtimestamp
        Resource = "$($row.earnint_resource)"
        ResourceType = "$($row.earnint_resourcetype)"
        QueueOrTeam = "$($row.earnint_queueorteam)"
        RiskLevel = "$($row.earnint_risklevel)"
        DiscrepancyAmount = $row.earnint_discrepancyamount
        EvidenceStatus = "$($row.earnint_evidencestatus)"
        RecommendedDisposition = "$($row.earnint_recommendeddisposition)"
        FinalDisposition = "$($row.earnint_finaldisposition)"
    })
    $eventEvidence.Add([pscustomobject]@{
        CaseId = $caseBusinessIdByGuid[$guid]
        ActivityName = "$($row.earnint_activityname)"
        StartTimestamp = Get-IsoTimestamp $row.earnint_starttimestamp
        EvidenceKind = if ($row.earnint_issyntheticdemoevent) { "explicit synthetic demo event" } else { "explicit process event" }
        SourceTable = "earnint_processevent"
        SourceRecordId = "$($row.earnint_processeventid)"
        Inferred = $false
    })
}

if ($audits.Count -eq 0) {
    Add-QualityIssue "AuditHistoryUnavailable" "High" "ALL" "" "" "No incident audit rows exist for the scoped Cases. Explicit event history is available for $($explicitCaseGuids.Count) enriched Cases; other historical transitions cannot be reconstructed." $cases.Count "Enable auditing for incident and process-critical columns before future demonstrations."
}

$resolvedCaseCount = @($cases | Where-Object { [int]$_.statecode -eq 1 }).Count
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Process variants" "" "Supported for the $($explicitCaseGuids.Count)-Case explicit cohort; existing-only Cases still contain scheduled or inferred events." $cases.Count "Use the explicit cohort for variant analysis and label conclusions as demonstration results."
Add-QualityIssue "AnalysisCapability" "Medium" "ALL" "Average case duration" "" "Supported for $resolvedCaseCount completed synthetic Cases; not representative of production performance." $resolvedCaseCount "Filter to completed EIR-PM Cases and label durations as synthetic demonstration data."
Add-QualityIssue "AnalysisCapability" "Medium" "ALL" "Waiting time between activities" "" "Partially supported: business and scheduled timestamps provide intervals, but most activities lack actual completion timestamps." $cases.Count "Capture actual start/end or immutable occurrence timestamps."
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Analyst versus supervisor handoffs" "" "Supported for the explicit cohort through dated submission, review-start, return, and approval events." $explicitCaseGuids.Count "Filter to explicit process events for defensible handoff analysis."
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Reassignment" "" "Supported for the explicit cohort; unavailable historically for other Cases because incident audit rows are absent." $explicitCaseGuids.Count "Filter to explicit process events or enable owner auditing for future Cases."
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Rework and returns" "" "Supported for the explicit cohort through dated additional-evidence, return, and revision events." $explicitCaseGuids.Count "Filter to explicit process events for rework analysis."
Add-QualityIssue "AnalysisCapability" "Medium" "ALL" "Bottlenecks" "" "Partially supported for scheduled work only; actual queue and activity waiting times are not reliable." $cases.Count "Capture queue entry/exit and actual activity start/end timestamps."
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Risk-level differences" "" "Supported for descriptive comparison: all four risk levels are represented, but Critical has only one Case and longitudinal timing is weak." $cases.Count "Add more Critical cases and completed histories for balanced duration comparisons."
Add-QualityIssue "AnalysisCapability" "Low" "ALL" "Human versus automated activity" "" "Supported for human and automated workflow events. No live event proves that an AI model was called; seeded AI summaries are correctly classified as Automated Workflow." $cases.Count "Instrument actual AI invocation/completion events if AI-agent comparison is required."

$sortedEvents = @($events | Sort-Object CaseId, @{Expression={ [datetimeoffset]::Parse($_.StartTimestamp) }}, ActivityName)
$duplicates = @($sortedEvents | Group-Object CaseId, ActivityName, StartTimestamp | Where-Object Count -gt 1)
foreach ($duplicate in $duplicates) {
    $sample = $duplicate.Group[0]
    Add-QualityIssue "DuplicateEvent" "Medium" $sample.CaseId $sample.ActivityName $sample.StartTimestamp "Multiple source records normalize to the same Case, activity, and timestamp." $duplicate.Count "Retain source record IDs in staging and define a deduplication key before import."
}

foreach ($group in @($sortedEvents | Group-Object CaseId)) {
    $sameTimes = @($group.Group | Group-Object StartTimestamp | Where-Object Count -gt 1)
    foreach ($sameTime in $sameTimes) {
        Add-QualityIssue "IdenticalTimestampSequenceUncertain" "Medium" $group.Name "" $sameTime.Name "$($sameTime.Count) events share an identical timestamp; source data does not establish a reliable within-timestamp order." $sameTime.Count "Add an event sequence number or higher precision event timestamp."
    }
    if ($group.Count -lt 4) {
        Add-QualityIssue "InsufficientHistory" "High" $group.Name "" "" "Case has only $($group.Count) usable event rows." $group.Count "Add explicit task completions, transitions, or immutable process events."
    }
    $ordered = @($group.Group | Sort-Object { [datetimeoffset]::Parse($_.StartTimestamp) })
    $created = @($ordered | Where-Object ActivityName -eq "Case Created" | Select-Object -First 1)
    if ($created.Count -eq 1) {
        $caseCreatedAt = [datetimeoffset]::Parse($created[0].StartTimestamp)
        foreach ($early in @($ordered | Where-Object { [datetimeoffset]::Parse($_.StartTimestamp) -lt $caseCreatedAt })) {
            Add-QualityIssue "EventPredatesCaseCreation" "High" $group.Name $early.ActivityName $early.StartTimestamp "Business event timestamp predates the Dataverse Case creation timestamp, consistent with late-loaded demo history." 1 "Preserve as business history but document synthetic loading; use overriddencreatedon or a dedicated occurrence timestamp for future seeds."
        }
    }
}

$sourceAssessment = @(
    [pscustomobject]@{ Field="CaseId"; Table="incident"; Column="title (parsed EIR ID), ticketnumber, incidentid"; Availability="Available"; Derivation="Parse EIR-* identifier from title; fallback to ticketnumber then incidentid"; Gap="Business ID is embedded in title rather than a dedicated alternate-key column" },
    [pscustomobject]@{ Field="ActivityName"; Table="Multiple"; Column="record type, state, category, BPF stage"; Availability="Derived"; Derivation="Controlled event rules in this export"; Gap="No canonical process-event table" },
    [pscustomobject]@{ Field="StartTimestamp"; Table="Multiple"; Column="createdon, actualstart, scheduledstart, enteredon, activestagestartedon, earnint_receiveddate"; Availability="Partially available"; Derivation="Use explicit occurrence timestamp, otherwise system creation/modification timestamp"; Gap="Evidence received date is date-only; prior BPF stage timestamps absent" },
    [pscustomobject]@{ Field="EndTimestamp"; Table="task, appointment, BPF"; Column="actualend, scheduledend, completedon"; Availability="Partially available"; Derivation="Use actual end when present; scheduled end only for explicitly scheduled activities"; Gap="Most records have no actual duration" },
    [pscustomobject]@{ Field="Resource"; Table="All user-owned tables"; Column="createdby, modifiedby, ownerid, verifiedby, analystname, queue worker"; Availability="Partially available"; Derivation="Prefer event actor, then owner or named analyst"; Gap="Free-text analyst/verified-by values are not stable user keys" },
    [pscustomobject]@{ Field="ResourceType"; Table="Derived"; Column="actor/source name and AI raw JSON"; Availability="Derived"; Derivation="Human, Automated Workflow, or AI Agent based on source evidence"; Gap="No explicit resource-type column" },
    [pscustomobject]@{ Field="PreviousStatus"; Table="audit"; Column="AuditDetail old value"; Availability="Unavailable"; Derivation="Would require RetrieveAuditDetails"; Gap="No incident audit rows exist" },
    [pscustomobject]@{ Field="NewStatus"; Table="incident, evidence, finding, task"; Column="statuscode/statecode/custom status"; Availability="Current state only"; Derivation="Formatted current status"; Gap="Transition timestamp and prior value unavailable without audit" },
    [pscustomobject]@{ Field="QueueOrTeam"; Table="incident, queueitem"; Column="earnint_queueassignment, queueid, workerid, ownerid"; Availability="Available/current"; Derivation="Queue item where present; otherwise current Case queue choice"; Gap="Queue choice is not historical" },
    [pscustomobject]@{ Field="RiskLevel"; Table="incident"; Column="earnint_riskrating"; Availability="Available/current"; Derivation="Formatted choice label"; Gap="Historical risk changes unavailable" },
    [pscustomobject]@{ Field="DiscrepancyAmount"; Table="earnint_earningsdiscrepancy"; Column="earnint_discrepancyamount"; Availability="Available"; Derivation="Sum related discrepancy rows by Case"; Gap="Amount effective date not separately captured" },
    [pscustomobject]@{ Field="EvidenceType"; Table="earnint_evidenceitem"; Column="earnint_evidencetype"; Availability="Available"; Derivation="Formatted choice label"; Gap="Not included in requested flat import schema" },
    [pscustomobject]@{ Field="EvidenceStatus"; Table="earnint_evidenceitem, incident"; Column="earnint_status, earnint_evidencestatus"; Availability="Available/current"; Derivation="Event-level evidence status where applicable; otherwise Case summary status"; Gap="Status transition history unavailable" },
    [pscustomobject]@{ Field="FindingType"; Table="earnint_investigationfinding"; Column="earnint_findingtype"; Availability="Available"; Derivation="Formatted choice label"; Gap="Not included in requested flat import schema" },
    [pscustomobject]@{ Field="RecommendedDisposition"; Table="earnint_investigationfinding, incident"; Column="earnint_recddisposition, earnint_casedisposition"; Availability="Available/current"; Derivation="Finding recommendation when available; otherwise Case recommendation"; Gap="Submission timestamp not explicit" },
    [pscustomobject]@{ Field="FinalDisposition"; Table="incident, incidentresolution"; Column="earnint_finaldetermination, resolution subject/status"; Availability="Current state only for scoped Cases"; Derivation="Current final determination; explicit close event requires a scoped resolution"; Gap="All 54 scoped Cases are active and no scoped resolution records exist" },
    [pscustomobject]@{ Field="SupervisorDecision"; Table="earnint_investigationfinding, incident"; Column="earnint_supervisorapprovalstatus, earnint_supervisorapproval"; Availability="Available/current"; Derivation="Current approval state"; Gap="Decision transition timestamp and actor are not explicitly captured" },
    [pscustomobject]@{ Field="ReassignmentIndicator"; Table="audit, queueitem"; Column="ownerid transition or repeated queue entries"; Availability="Mostly unavailable"; Derivation="Would compare historical owner/queue changes"; Gap="No audit rows; current owner alone cannot prove reassignment" },
    [pscustomobject]@{ Field="ReworkIndicator"; Table="audit, BPF, findings/evidence"; Column="backward stage/status changes or return disposition"; Availability="Mostly unavailable"; Derivation="Would detect return-to-analyst or additional-evidence loops"; Gap="Prior stage timestamps and field transitions are absent" },
    [pscustomobject]@{ Field="SourceSystem"; Table="earnint_earningsdiscrepancy and event source"; Column="earnint_sourcesystem"; Availability="Partially available"; Derivation="Discrepancy source or Dataverse source table"; Gap="Not populated consistently and not included in requested flat import schema" }
)

$eventRules = @(
    [pscustomobject]@{ ActivityName="Earnings Signal Received"; Evidence="Automated discrepancy record with feed/match/import/system source"; Timestamp="discrepancy.createdon"; Availability="Available for automated-source discrepancies"; Inference="No" },
    [pscustomobject]@{ ActivityName="Case Created"; Evidence="Scoped incident record created"; Timestamp="incident.createdon"; Availability="Available for all Cases"; Inference="No" },
    [pscustomobject]@{ ActivityName="Risk Triage Started"; Evidence="Task actualstart in Intake and Risk category, or BPF Intake Triage active-stage start"; Timestamp="task.actualstart or BPF.activestagestartedon"; Availability="Sparse"; Inference="No" },
    [pscustomobject]@{ ActivityName="Case Assigned"; Evidence="Initial incident owner at creation or queueitem entry"; Timestamp="incident.createdon or queueitem.enteredon"; Availability="Initial assignment available; reassignment sparse"; Inference="No" },
    [pscustomobject]@{ ActivityName="Earnings Discrepancy Reviewed"; Evidence="No explicit review/completion record"; Timestamp=""; Availability="Unavailable"; Inference="Would be forced; not generated" },
    [pscustomobject]@{ ActivityName="Evidence Requested"; Evidence="Evidence row created with Requested status"; Timestamp="evidence.createdon"; Availability="Available where status is Requested"; Inference="No" },
    [pscustomobject]@{ ActivityName="Evidence Received"; Evidence="Evidence received-date, or received/current status fallback"; Timestamp="earnint_receiveddate; fallback createdon"; Availability="Available"; Inference="Fallback only" },
    [pscustomobject]@{ ActivityName="Evidence Validated"; Evidence="Evidence current status is Verified"; Timestamp="evidence.modifiedon"; Availability="Available as current-state evidence"; Inference="Yes without audit transition" },
    [pscustomobject]@{ ActivityName="Additional Evidence Requested"; Evidence="Second/subsequent explicit Requested evidence row or return transition"; Timestamp="evidence.createdon or audit time"; Availability="Not reliably derivable"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Earnings Analysis Completed"; Evidence="Completed analysis task or explicit completion event"; Timestamp="task.actualend"; Availability="Unavailable in current open tasks"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Analyst Finding Drafted"; Evidence="Investigation finding record created"; Timestamp="finding.createdon"; Availability="Available"; Inference="No" },
    [pscustomobject]@{ ActivityName="Analyst Finding Submitted"; Evidence="Finding status transition to submitted or BPF handoff"; Timestamp="audit/BPF transition"; Availability="Unavailable"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Supervisor Review Started"; Evidence="Supervisor-review task actualstart or dated BPF stage entry"; Timestamp="task.actualstart/BPF stage time"; Availability="Unavailable in current data"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Case Returned to Analyst"; Evidence="Rejected supervisor transition or backward BPF movement"; Timestamp="audit/event timestamp"; Availability="Unavailable"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Finding Revised"; Evidence="Finding revision audit or new version linked to prior finding"; Timestamp="audit/version timestamp"; Availability="Unavailable"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Supervisor Approved"; Evidence="Current finding approval status is Approved"; Timestamp="finding.modifiedon"; Availability="Available as current-state evidence"; Inference="Yes without audit transition" },
    [pscustomobject]@{ ActivityName="Case Escalated"; Evidence="Explicit fraud escalation queue/item/disposition transition"; Timestamp="queue/audit timestamp"; Availability="Not present as dated event"; Inference="Not generated" },
    [pscustomobject]@{ ActivityName="Case Closed / Disposition Completed"; Evidence="Incident resolution record created/completed"; Timestamp="incidentresolution.actualend or createdon"; Availability="No scoped resolution records currently exist"; Inference="No" },
    [pscustomobject]@{ ActivityName="Earnings Discrepancy Recorded"; Evidence="Related discrepancy record created"; Timestamp="discrepancy.createdon"; Availability="Available"; Inference="No; additional vocabulary" },
    [pscustomobject]@{ ActivityName="Business Process Started"; Evidence="Earnings Fraud Case Review BPF instance created"; Timestamp="BPF.createdon"; Availability="Two instances"; Inference="No; additional vocabulary" },
    [pscustomobject]@{ ActivityName="* Work Item Scheduled"; Evidence="Open task with scheduledstart/scheduledend"; Timestamp="task scheduled interval"; Availability="Available for generated tasks"; Inference="No; explicitly scheduled, not completed" },
    [pscustomobject]@{ ActivityName="Beneficiary Clarification Scheduled/Completed"; Evidence="Case appointment scheduled or actual times"; Timestamp="appointment scheduled/actual interval"; Availability="Available where appointments exist"; Inference="No; additional vocabulary" },
    [pscustomobject]@{ ActivityName="AI Analysis Result Recorded"; Evidence="AI summary field populated"; Timestamp="incident.modifiedon"; Availability="Available for enriched Cases"; Inference="Yes; field-level update time unavailable" }
)

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$eventPath = Join-Path $OutputDirectory "process-mining-event-log.csv"
$sourcePath = Join-Path $OutputDirectory "process-mining-source-assessment.csv"
$rulesPath = Join-Path $OutputDirectory "process-mining-event-rules.csv"
$qualityPath = Join-Path $OutputDirectory "process-mining-data-quality.csv"

$sortedEvents | Select-Object CaseId,ActivityName,StartTimestamp,EndTimestamp,Resource,ResourceType,QueueOrTeam,RiskLevel,DiscrepancyAmount,EvidenceStatus,RecommendedDisposition,FinalDisposition | Export-Csv -Path $eventPath -NoTypeInformation -Encoding utf8
$sourceAssessment | Export-Csv -Path $sourcePath -NoTypeInformation -Encoding utf8
$eventRules | Export-Csv -Path $rulesPath -NoTypeInformation -Encoding utf8
@($qualityRows | Sort-Object Severity,IssueType,CaseId,Timestamp) | Export-Csv -Path $qualityPath -NoTypeInformation -Encoding utf8

$caseCounts = @($sortedEvents | Group-Object CaseId)
$variantCount = @($caseCounts | ForEach-Object { ($_.Group.ActivityName -join ' > ') } | Sort-Object -Unique).Count
$inferredCount = @($eventEvidence | Where-Object Inferred).Count

Write-Host ""
Write-Host "=== Process Mining Export Complete ===" -ForegroundColor Green
Write-Host "Cases:              $($cases.Count)"
Write-Host "Events:             $($sortedEvents.Count)"
Write-Host "Observed variants:  $variantCount"
Write-Host "Inferred events:    $inferredCount"
Write-Host "Quality findings:   $($qualityRows.Count)"
Write-Host "Audit rows:         $($audits.Count)"
Write-Host "BPF instances:      $($bpfInstances.Count)"
Write-Host "Event log:          $eventPath"
Write-Host "Source assessment:  $sourcePath"
Write-Host "Event rules:        $rulesPath"
Write-Host "Data quality:       $qualityPath"