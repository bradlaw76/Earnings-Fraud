[CmdletBinding()]
param(
    [string]$WorkflowName = 'Earnings Fraud Case Review',
    [string]$PrimaryEntity = 'incident',
    [string]$DataFieldName = 'title',
    [string]$ControlDisplayName = 'Case Title'
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
$wfUri = "$envUrl/api/data/v9.2/workflows?`$select=workflowid,name,clientdata,xaml,modifiedon&`$filter=category eq 4 and primaryentity eq '$PrimaryEntity' and name eq '$wfNameEscaped'&`$orderby=modifiedon desc"
$wf = (Invoke-RestMethod -Method Get -Uri $wfUri -Headers $headers).value | Select-Object -First 1
if (-not $wf) {
    throw "Workflow '$WorkflowName' not found for entity '$PrimaryEntity'."
}

$cd = $wf.clientdata | ConvertFrom-Json

if (-not $cd.steps -or -not $cd.steps.list -or $cd.steps.list.Count -eq 0) {
    throw 'Unexpected clientdata shape: missing root steps list.'
}

$entityNode = $cd.steps.list[0]
if (-not $entityNode.steps -or -not $entityNode.steps.list -or $entityNode.steps.list.Count -eq 0) {
    throw 'Unexpected clientdata shape: missing stage list under entity node.'
}

$stageNode = $entityNode.steps.list[0]
if (-not $stageNode.steps -or -not $stageNode.steps.list -or $stageNode.steps.list.Count -eq 0) {
    throw 'Unexpected clientdata shape: missing step list under stage node.'
}

$oldStep = $stageNode.steps.list[0]
$stepLabelId = if ($oldStep.stepStepId) { [string]$oldStep.stepStepId } else { [guid]::NewGuid().ToString() }

# Replace malformed generic step with a concrete BPF control step bound to a real case field.
$newStep = [ordered]@{
    __class            = 'ControlStep:#Microsoft.Crm.Workflow.ObjectModel'
    id                 = 'ControlStep3'
    description        = ''
    name               = 'Step_3'
    stepLabels         = @{ list = @() }
    controlId          = $DataFieldName
    classId            = '3ef39988-22bb-4f0b-bbbe-64b5a3748aee'
    dataFieldName      = $DataFieldName
    systemStepType     = '0'
    isSystemControl    = $false
    parameters         = ''
    controlDisplayName = $ControlDisplayName
    isUnbound          = $false
    controlType        = '0'
}

$stageNode.description = 'Intake'
if ($stageNode.stepLabels -and $stageNode.stepLabels.list -and $stageNode.stepLabels.list.Count -gt 0) {
    $stageNode.stepLabels.list[0].description = 'Intake'
}

$stageNode.steps.list[0] = [pscustomobject]$newStep

# Keep StepComposite container but inject a concrete mcwb:Control node.
$controlXml = '<sco:Collection x:TypeArguments="Activity" x:Key="Activities"><Sequence DisplayName="ControlStep3"><mcwb:Control ClassId="3ef39988-22bb-4f0b-bbbe-64b5a3748aee" ControlDisplayName="' + $ControlDisplayName + '" ControlId="' + $DataFieldName + '" DataFieldName="' + $DataFieldName + '" IsSystemControl="False" IsUnbound="False" SystemStepType="0"><mcwb:Control.Parameters><InArgument x:TypeArguments="x:String"><Literal x:TypeArguments="x:String" Value="" /></InArgument></mcwb:Control.Parameters></mcwb:Control></Sequence></sco:Collection>'

$xaml = [string]$wf.xaml
$xaml = [regex]::Replace(
    $xaml,
    '<sco:Collection x:TypeArguments="Activity" x:Key="Activities">\s*</sco:Collection>',
    $controlXml,
    1
)

$newClientData = $cd | ConvertTo-Json -Depth 40 -Compress

$body = @{
    clientdata = $newClientData
    xaml       = $xaml
} | ConvertTo-Json -Depth 6

Invoke-RestMethod -Method Patch -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))" -Headers $headers -Body $body | Out-Null

Write-Host "Patched workflow $($wf.workflowid) with ControlStep bound to '$DataFieldName'."

$verify = Invoke-RestMethod -Method Get -Uri "$envUrl/api/data/v9.2/workflows($($wf.workflowid))?`$select=workflowid,name,modifiedon" -Headers $headers
$verify | Format-List