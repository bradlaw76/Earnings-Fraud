[CmdletBinding()]
param(
    [string]$WorkflowName = 'Earnings Fraud Case Review',
    [string]$PrimaryEntity = 'incident'
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\..\.env.ps1"

$envUrl = $global:DV_ENVIRONMENT_URL.TrimEnd('/')
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
if (-not $token) {
    throw 'Could not acquire Azure access token.'
}

$headers = @{
    Authorization      = "Bearer $token"
    Accept             = 'application/json'
    'OData-Version'    = '4.0'
    'OData-MaxVersion' = '4.0'
    'Content-Type'     = 'application/json'
}

$wfNameEscaped = $WorkflowName.Replace("'", "''")
$wfUri = "$envUrl/api/data/v9.2/workflows?`$select=workflowid,name,clientdata,modifiedon&`$filter=category eq 4 and primaryentity eq '$PrimaryEntity' and name eq '$wfNameEscaped'&`$orderby=modifiedon desc"
$wf = (Invoke-RestMethod -Method Get -Uri $wfUri -Headers $headers).value | Select-Object -First 1
if (-not $wf) {
    throw "Workflow '$WorkflowName' not found for entity '$PrimaryEntity'."
}

$clientData = $wf.clientdata | ConvertFrom-Json
$entityNode = $clientData.steps.list | Where-Object { $_.__class -like 'EntityStep*' } | Select-Object -First 1
if (-not $entityNode) {
    throw 'Unexpected clientdata shape: missing EntityStep node.'
}
if (-not $entityNode.steps -or -not $entityNode.steps.list) {
    throw 'Unexpected clientdata shape: missing stage list under EntityStep.'
}

$stageNames = @(
    'Intake Triage',
    'Identity Verification',
    'Wage Evidence Collection',
    'Cross-Source Reconciliation',
    'Risk Scoring',
    'Supervisor Decision',
    'Case Closure'
)

$existingStages = @($entityNode.steps.list | Where-Object { $_.__class -like 'StageStep*' })
if ($existingStages.Count -eq 0) {
    throw 'Unexpected clientdata shape: no existing StageStep found.'
}

$nextIndex = [int]$clientData.nextStepIndex
if ($nextIndex -lt 10) { $nextIndex = 10 }

function New-StageStep {
    param(
        [Parameter(Mandatory = $true)][string]$StageName,
        [Parameter(Mandatory = $true)][int]$Index
    )

    $stageId = [guid]::NewGuid().ToString()
    [pscustomobject]@{
        __class      = 'StageStep:#Microsoft.Crm.Workflow.ObjectModel'
        id           = "StageStep$Index"
        description  = $StageName
        name         = "Step_$Index"
        stepLabels   = @{ list = @([pscustomobject]@{ labelId = $stageId; languageCode = 1033; description = $StageName }) }
        steps        = @{ list = @() }
        stageId      = $stageId
        nextStageId  = $null
        stageCategory = '-1'
    }
}

$existingByDescription = @{}
foreach ($stage in $existingStages) {
    $existingByDescription[[string]$stage.description] = $stage
}

foreach ($stageName in $stageNames) {
    if (-not $existingByDescription.ContainsKey($stageName)) {
        $entityNode.steps.list += New-StageStep -StageName $stageName -Index $nextIndex
        $nextIndex++
    }
}

$allStages = @($entityNode.steps.list | Where-Object { $_.__class -like 'StageStep*' })
$orderedStages = @()
foreach ($stageName in $stageNames) {
    $match = $allStages | Where-Object { $_.description -eq $stageName } | Select-Object -First 1
    if ($match) { $orderedStages += $match }
}
foreach ($stage in $allStages) {
    if (-not ($orderedStages -contains $stage)) {
        $orderedStages += $stage
    }
}

$entityNode.steps.list = @($orderedStages)

for ($i = 0; $i -lt $entityNode.steps.list.Count; $i++) {
    if ($i -lt ($entityNode.steps.list.Count - 1)) {
        $entityNode.steps.list[$i].nextStageId = [string]$entityNode.steps.list[$i + 1].stageId
    }
    else {
        $entityNode.steps.list[$i].nextStageId = $null
    }
}

$firstStage = $entityNode.steps.list[0]
if (-not $firstStage.steps) {
    $firstStage | Add-Member -NotePropertyName steps -NotePropertyValue @{ list = @() }
}
if (-not $firstStage.steps.list) {
    $firstStage.steps | Add-Member -NotePropertyName list -NotePropertyValue @()
}

$hasCondition = @($firstStage.steps.list | Where-Object { $_.__class -like 'ConditionStep*' }).Count -gt 0
if (-not $hasCondition) {
    $conditionLabelId = [guid]::NewGuid().ToString()
    $conditionNode = [pscustomobject]@{
        __class      = 'ConditionStep:#Microsoft.Crm.Workflow.ObjectModel'
        id           = "ConditionStep$nextIndex"
        description  = 'Escalate when risk score >= 80'
        name         = "Step_$nextIndex"
        stepLabels   = @{ list = @([pscustomobject]@{ labelId = $conditionLabelId; languageCode = 1033; description = 'High Risk Escalation' }) }
        steps        = @{ list = @() }
        conditionExpression = 'risk_score >= 80'
    }
    $firstStage.steps.list += $conditionNode
    $nextIndex++
}

$clientData.nextStepIndex = [string]$nextIndex
$newClientData = $clientData | ConvertTo-Json -Depth 80 -Compress

$patchBody = @{ clientdata = $newClientData } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Patch -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))" -Headers $headers -Body $patchBody | Out-Null

$verify = Invoke-RestMethod -Method Get -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))?`$select=workflowid,name,modifiedon" -Headers $headers

Write-Host "Expanded workflow '$($verify.name)' ($($verify.workflowid))."
Write-Host "ModifiedOn: $($verify.modifiedon)"
Write-Host "Target stages enforced: $($stageNames.Count), condition ensured: true"