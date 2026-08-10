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

# Map cloned twenty4 fields to fraud-case incident fields.
$fieldMap = @{
    'twenty4_missionstatus' = @{ NewField = 'earnint_reviewtype'; NewLabel = 'Review Type' }
    'twenty4_teamstatus' = @{ NewField = 'earnint_referralsource'; NewLabel = 'Referral Source' }
    'twenty4_threatlevel' = @{ NewField = 'earnint_allegationtype'; NewLabel = 'Allegation Type' }
    'twenty4_operationalplantype' = @{ NewField = 'earnint_supervisorreviewrequired'; NewLabel = 'Supervisor Review Required' }
    'twenty4_opspriority' = @{ NewField = 'earnint_riskrating'; NewLabel = 'Risk Level' }
    'twenty4_team' = @{ NewField = 'earnint_fraudlikelihood'; NewLabel = 'Fraud Likelihood' }
    'twenty4_extractionrequestnotes' = @{ NewField = 'earnint_riskexplanation'; NewLabel = 'Risk Explanation' }
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

$updatedClientControls = 0
$updatedUidataControls = 0

# Update clientdata controls and labels.
foreach ($entity in @($clientData.steps.list | Where-Object { $_.__class -like 'EntityStep*' })) {
    foreach ($stage in @($entity.steps.list | Where-Object { $_.__class -like 'StageStep*' })) {
        foreach ($step in @($stage.steps.list | Where-Object { $_.__class -like 'StepStep*' })) {
            $control = $step.steps.list | Where-Object { $_.__class -like 'ControlStep*' } | Select-Object -First 1
            if (-not $control) { continue }

            $oldField = [string]$control.dataFieldName
            if (-not $fieldMap.ContainsKey($oldField)) { continue }

            $map = $fieldMap[$oldField]
            $control.dataFieldName = $map.NewField
            $control.controlId = $map.NewField
            $control.controlDisplayName = $map.NewLabel

            if ($step.stepLabels -and $step.stepLabels.list -and $step.stepLabels.list.Count -gt 0) {
                $step.stepLabels.list[0].description = $map.NewLabel
            }
            $step.description = 'New Step'
            $updatedClientControls++
        }
    }
}

# Update uidata step controls to match field/labels used by the designer.
$uidEntities = @($uidata.BusinessProcessFlowEntities.'$values' | Where-Object { $_.'$type' -like '*BusinessProcessFlowEntity*' })
foreach ($entity in $uidEntities) {
    $stage = $entity.Stage
    if (-not $stage -or -not $stage.Steps -or -not $stage.Steps.'$values') { continue }

    foreach ($stepControl in @($stage.Steps.'$values')) {
        $oldField = [string]$stepControl.Name
        if (-not $fieldMap.ContainsKey($oldField)) { continue }

        $map = $fieldMap[$oldField]
        $stepControl.Name = $map.NewField
        $stepControl.StepControlId = $map.NewField
        $stepControl.Label = $map.NewLabel
        $updatedUidataControls++
    }
}

# Keep XAML in sync for all replaced field logical names.
# Replace longest names first to avoid substring collisions (for example, teamstatus vs team).
foreach ($oldField in ($fieldMap.Keys | Sort-Object { $_.Length } -Descending)) {
    $newField = [string]$fieldMap[$oldField].NewField
    $xaml = $xaml.Replace($oldField, $newField)
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

Write-Host "Updated BPF data steps for '$($verify.name)' ($($verify.workflowid))."
Write-Host "ModifiedOn: $($verify.modifiedon)"
Write-Host "ClientData controls updated: $updatedClientControls"
Write-Host "UIData controls updated: $updatedUidataControls"