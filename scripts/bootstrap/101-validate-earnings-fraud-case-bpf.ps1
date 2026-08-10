[CmdletBinding()]
param(
    [string]$WorkflowName = 'Earnings Fraud Case Review',
    [string]$SolutionUniqueName = 'FederalEarningsFraud',
    [int]$MinStages = 6,
    [int]$MinConditions = 1,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

function Invoke-DvGet {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][hashtable]$Headers
    )
    Invoke-RestMethod -Method Get -Uri $Uri -Headers $Headers
}

function Count-ProcessNodes {
    param([Parameter(Mandatory = $true)]$Node)

    $result = [ordered]@{
        StageCount = 0
        ConditionCount = 0
        StepCount = 0
    }

    function Walk {
        param($Current)
        if ($null -eq $Current) { return }

        $class = [string]$Current.__class
        if ($class -like 'StageStep*') { $script:stageCount++ }
        if ($class -like 'ConditionStep*') { $script:conditionCount++ }
        if ($class -like 'StepStep*') { $script:stepCount++ }

        if ($Current.steps -and $Current.steps.list) {
            foreach ($child in $Current.steps.list) {
                Walk -Current $child
            }
        }
    }

    $script:stageCount = 0
    $script:conditionCount = 0
    $script:stepCount = 0
    Walk -Current $Node

    $result.StageCount = $script:stageCount
    $result.ConditionCount = $script:conditionCount
    $result.StepCount = $script:stepCount
    [pscustomobject]$result
}

. "$PSScriptRoot\..\..\.env.ps1"

$envUrl = $global:DV_ENVIRONMENT_URL.TrimEnd('/')
$token = az account get-access-token --resource $envUrl --query accessToken -o tsv
if (-not $token) {
    throw 'Could not acquire Azure access token for Dataverse environment.'
}

$headers = @{
    Authorization     = "Bearer $token"
    Accept            = 'application/json'
    'OData-Version'   = '4.0'
    'OData-MaxVersion' = '4.0'
}

$wfNameEscaped = $WorkflowName.Replace("'", "''")
$wfUri = "$envUrl/api/data/v9.2/workflows?`$select=workflowid,name,category,primaryentity,statecode,statuscode,modifiedon,clientdata&`$filter=category eq 4 and name eq '$wfNameEscaped'"
$wf = (Invoke-DvGet -Uri $wfUri -Headers $headers).value | Select-Object -First 1
if (-not $wf) {
    throw "BPF '$WorkflowName' was not found in environment '$envUrl'."
}

$solutionEscaped = $SolutionUniqueName.Replace("'", "''")
$solutionUri = "$envUrl/api/data/v9.2/solutions?`$select=solutionid,uniquename,friendlyname&`$filter=uniquename eq '$solutionEscaped'"
$solution = (Invoke-DvGet -Uri $solutionUri -Headers $headers).value | Select-Object -First 1
if (-not $solution) {
    throw "Solution '$SolutionUniqueName' was not found in environment '$envUrl'."
}

$componentUri = "$envUrl/api/data/v9.2/solutioncomponents?`$select=solutioncomponentid&`$filter=componenttype eq 29 and objectid eq $($wf.workflowid) and _solutionid_value eq $($solution.solutionid)"
$componentCount = @((Invoke-DvGet -Uri $componentUri -Headers $headers).value).Count

$clientData = $wf.clientdata | ConvertFrom-Json
$counts = Count-ProcessNodes -Node $clientData

$isActive = ([int]$wf.statecode -eq 1 -and [int]$wf.statuscode -eq 2)
$inSolution = ($componentCount -gt 0)
$hasMinStages = ($counts.StageCount -ge $MinStages)
$hasMinConditions = ($counts.ConditionCount -ge $MinConditions)

$status = if ($isActive -and $inSolution -and $hasMinStages -and $hasMinConditions) { 'PASS' } else { 'FAIL' }

$report = [ordered]@{
    ValidationStatus = $status
    EnvironmentUrl = $envUrl
    WorkflowName = $wf.name
    WorkflowId = $wf.workflowid
    StateCode = $wf.statecode
    StatusCode = $wf.statuscode
    IsActive = $isActive
    SolutionUniqueName = $solution.uniquename
    InSolution = $inSolution
    StageCount = $counts.StageCount
    ConditionCount = $counts.ConditionCount
    StepCount = $counts.StepCount
    ExpectedMinStages = $MinStages
    ExpectedMinConditions = $MinConditions
    ModifiedOn = $wf.modifiedon
}

if ($AsJson) {
    [pscustomobject]$report | ConvertTo-Json -Depth 5
} else {
    [pscustomobject]$report | Format-List
}

if ($status -eq 'FAIL') {
    exit 2
}