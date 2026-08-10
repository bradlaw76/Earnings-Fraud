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
$wfUri = "$envUrl/api/data/v9.2/workflows?`$select=workflowid,name,clientdata,uidata,xaml,modifiedon&`$filter=category eq 4 and primaryentity eq '$PrimaryEntity' and name eq '$wfNameEscaped'&`$orderby=modifiedon desc"
$wf = (Invoke-RestMethod -Method Get -Uri $wfUri -Headers $headers).value | Select-Object -First 1
if (-not $wf) {
    throw "Workflow '$WorkflowName' not found for entity '$PrimaryEntity'."
}

$clientData = $wf.clientdata | ConvertFrom-Json
$uidata = $wf.uidata | ConvertFrom-Json
$xaml = [string]$wf.xaml

$stageNameByOrder = @(
    'Intake Triage',
    'Case Details',
    'Risk Decision',
    'Evidence Collection',
    'Analysis',
    'Case Closure'
)

$stepLabelByField = @{
    'earnint_reviewtype' = 'Review Type'
    'earnint_referralsource' = 'Referral Source'
    'earnint_allegationtype' = 'Allegation Type'
    'title' = 'Case Title'
    'customerid' = 'Beneficiary'
    'prioritycode' = 'Priority'
    'twenty4_operationalplantype' = 'Supervisor Review Required'
    'earnint_riskrating' = 'Risk Level'
    'earnint_fraudlikelihood' = 'Fraud Likelihood'
    'earnint_riskexplanation' = 'Risk Explanation'
    'statuscode' = 'Status Reason'
}

$displayNameByField = @{
    'earnint_reviewtype' = 'Review Type'
    'earnint_referralsource' = 'Referral Source'
    'earnint_allegationtype' = 'Allegation Type'
    'title' = 'Case Title'
    'customerid' = 'Beneficiary'
    'prioritycode' = 'Priority'
    'twenty4_operationalplantype' = 'Supervisor Review Required'
    'earnint_riskrating' = 'Risk Level'
    'earnint_fraudlikelihood' = 'Fraud Likelihood'
    'earnint_riskexplanation' = 'Risk Explanation'
    'statuscode' = 'Status Reason'
}

$xamlTextReplacements = @{
    'Status Overview' = 'Intake Triage'
    'Operational Plan Type' = 'Risk Decision'
    'Extraction Plan' = 'Evidence Collection'
    'Execution' = 'Analysis'
    'Closure' = 'Case Closure'
    'Mission Status' = 'Review Type'
    'Team Status' = 'Referral Source'
    'Threat Level' = 'Allegation Type'
    'Ops Priority' = 'Risk Level'
    'Team' = 'Fraud Likelihood'
    'Existing Contact?' = 'Risk Explanation'
    'Extraction Request Notes (Multi)' = 'Risk Explanation'
    'Customer' = 'Beneficiary'
}

$updatedStages = 0
$updatedStepLabels = 0
$updatedStepDisplays = 0
$updatedConditions = 0

$entityIndex = 0
foreach ($entity in @($clientData.steps.list | Where-Object { $_.__class -like 'EntityStep*' })) {
    $entityIndex++
    $stage = $entity.steps.list | Where-Object { $_.__class -like 'StageStep*' } | Select-Object -First 1
    if (-not $stage) { continue }

    if ($entityIndex -le $stageNameByOrder.Count) {
        $newStageName = $stageNameByOrder[$entityIndex - 1]
        $stage.description = $newStageName
        if ($stage.stepLabels -and $stage.stepLabels.list -and $stage.stepLabels.list.Count -gt 0) {
            $stage.stepLabels.list[0].description = $newStageName
        }
        $updatedStages++
    }

    foreach ($step in @($stage.steps.list | Where-Object { $_.__class -like 'StepStep*' })) {
        $control = $step.steps.list | Where-Object { $_.__class -like 'ControlStep*' } | Select-Object -First 1
        if (-not $control) { continue }

        $field = [string]$control.dataFieldName
        if ($stepLabelByField.ContainsKey($field)) {
            $newLabel = $stepLabelByField[$field]
            if ($step.stepLabels -and $step.stepLabels.list -and $step.stepLabels.list.Count -gt 0) {
                $step.stepLabels.list[0].description = $newLabel
                $updatedStepLabels++
            }
        }

        if ($displayNameByField.ContainsKey($field)) {
            $control.controlDisplayName = $displayNameByField[$field]
            $updatedStepDisplays++
        }
    }

    foreach ($cond in @($stage.steps.list | Where-Object { $_.__class -like 'ConditionStep*' })) {
        $cond.description = 'Supervisor Review Required'
        if ($cond.stepLabels -and $cond.stepLabels.list -and $cond.stepLabels.list.Count -gt 0) {
            $cond.stepLabels.list[0].description = 'Supervisor Review Required'
        }
        $updatedConditions++
    }
}

# Update UIDATA stage/step labels used by the designer.
$uidEntities = @($uidata.BusinessProcessFlowEntities.'$values' | Where-Object { $_.'$type' -like '*BusinessProcessFlowEntity*' })
for ($i = 0; $i -lt $uidEntities.Count; $i++) {
    $uidEntity = $uidEntities[$i]
    $uidStage = $uidEntity.Stage
    if (-not $uidStage) { continue }

    if ($i -lt $stageNameByOrder.Count) {
        $uidStage.StageDisplayName = $stageNameByOrder[$i]
    }

    if ($uidStage.Steps -and $uidStage.Steps.'$values') {
        foreach ($uidStep in @($uidStage.Steps.'$values')) {
            $field = [string]$uidStep.Name
            if ($stepLabelByField.ContainsKey($field)) {
                $uidStep.Label = $stepLabelByField[$field]
            }
        }
    }
}

# Keep XAML control display names aligned so property/editor labels are coherent.
foreach ($field in $displayNameByField.Keys) {
    $newDisplay = $displayNameByField[$field]
    $pattern1 = '(DataFieldName="' + [regex]::Escape($field) + '"[^>]*ControlDisplayName=")[^"]*(")'
    $pattern2 = '(ControlDisplayName=")[^"]*("[^>]*DataFieldName="' + [regex]::Escape($field) + '")'
    $xaml = [regex]::Replace($xaml, $pattern1, ('$1' + $newDisplay + '$2'), 'IgnoreCase')
    $xaml = [regex]::Replace($xaml, $pattern2, ('$1' + $newDisplay + '$2'), 'IgnoreCase')
}

foreach ($oldText in ($xamlTextReplacements.Keys | Sort-Object { $_.Length } -Descending)) {
    $newText = $xamlTextReplacements[$oldText]
    $xaml = $xaml.Replace($oldText, $newText)
}

$newClientData = $clientData | ConvertTo-Json -Depth 100 -Compress
$newUidata = $uidata | ConvertTo-Json -Depth 100 -Compress

$patchBody = @{
    clientdata = $newClientData
    uidata = $newUidata
    xaml = $xaml
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Patch -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))" -Headers $headers -Body $patchBody | Out-Null

$verify = Invoke-RestMethod -Method Get -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))?`$select=workflowid,name,modifiedon" -Headers $headers

Write-Host "Updated live BPF labels for '$($verify.name)' ($($verify.workflowid))."
Write-Host "ModifiedOn: $($verify.modifiedon)"
Write-Host "Stages updated: $updatedStages"
Write-Host "Step labels updated: $updatedStepLabels"
Write-Host "Step display names updated: $updatedStepDisplays"
Write-Host "Condition labels updated: $updatedConditions"