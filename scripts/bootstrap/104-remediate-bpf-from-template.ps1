[CmdletBinding()]
param(
    [string]$TargetWorkflowName = 'Earnings Fraud Case Review',
    [string]$TemplateWorkflowId = '1cee08c1-031b-f011-9989-000d3a8dbc1c',
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

$targetEscaped = $TargetWorkflowName.Replace("'", "''")
$targetUri = "$envUrl/api/data/v9.2/workflows?`$select=workflowid,name,uniquename,primaryentity&`$filter=category eq 4 and primaryentity eq '$PrimaryEntity' and name eq '$targetEscaped'"
$target = (Invoke-RestMethod -Method Get -Uri $targetUri -Headers $headers).value | Select-Object -First 1
if (-not $target) {
    throw "Target workflow '$TargetWorkflowName' on '$PrimaryEntity' was not found."
}

$templateUri = "$envUrl/api/data/v9.2/workflows($TemplateWorkflowId)?`$select=workflowid,name,uniquename,clientdata,xaml,uidata"
$template = Invoke-RestMethod -Method Get -Uri $templateUri -Headers $headers

$clientDataObject = $template.clientdata | ConvertFrom-Json
$protectedGuids = New-Object 'System.Collections.Generic.HashSet[string]'

function Add-ClassIdGuids {
    param($Node)

    if ($null -eq $Node) { return }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in $Node) {
            Add-ClassIdGuids -Node $item
        }
        return
    }

    foreach ($prop in $Node.PSObject.Properties) {
        if ($prop.Name -eq 'classId' -and $prop.Value -is [string] -and $prop.Value -match '^[0-9a-fA-F-]{36}$') {
            [void]$protectedGuids.Add($prop.Value.ToLower())
        }

        if ($prop.Value -is [psobject] -or ($prop.Value -is [System.Collections.IEnumerable] -and -not ($prop.Value -is [string]))) {
            Add-ClassIdGuids -Node $prop.Value
        }
    }
}

Add-ClassIdGuids -Node $clientDataObject

$guidRegex = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
$allTemplateText = @($template.clientdata, $template.uidata, $template.xaml) -join "`n"
$templateGuids = [regex]::Matches($allTemplateText, $guidRegex) | ForEach-Object { $_.Value.ToLower() } | Select-Object -Unique

$guidMap = @{}
foreach ($guid in $templateGuids) {
    if ($guid -eq $template.workflowid.ToLower()) { continue }
    if ($guid -eq $target.workflowid.ToLower()) { continue }
    if ($protectedGuids.Contains($guid)) { continue }
    $guidMap[$guid] = [guid]::NewGuid().ToString()
}

function Convert-GuidsInText {
    param([Parameter(Mandatory = $true)][string]$Text)

    $out = $Text
    foreach ($old in $guidMap.Keys) {
        $out = [regex]::Replace($out, [regex]::Escape($old), $guidMap[$old], 'IgnoreCase')
    }
    $out
}

$newClientDataText = Convert-GuidsInText -Text $template.clientdata
$newUidataText = Convert-GuidsInText -Text $template.uidata
$newXaml = Convert-GuidsInText -Text $template.xaml

$newClientData = $newClientDataText | ConvertFrom-Json
$newClientData.workflowEntityId = $target.workflowid
$newClientData.primaryEntityName = $target.primaryentity
$newClientData.title = $target.name
$newClientData.description = 'Earnings fraud review process'

$preferredStageNames = @(
    'Intake Triage',
    'Identity Verification',
    'Wage Evidence Collection',
    'Cross-Source Reconciliation',
    'Risk Scoring',
    'Supervisor Decision'
)

$entityNode = $newClientData.steps.list | Where-Object { $_.__class -like 'EntityStep*' } | Select-Object -First 1
if ($entityNode -and $entityNode.steps -and $entityNode.steps.list) {
    $stages = @($entityNode.steps.list | Where-Object { $_.__class -like 'StageStep*' })
    for ($i = 0; $i -lt $stages.Count -and $i -lt $preferredStageNames.Count; $i++) {
        $stages[$i].description = $preferredStageNames[$i]
        if ($stages[$i].stepLabels -and $stages[$i].stepLabels.list -and $stages[$i].stepLabels.list.Count -gt 0) {
            $stages[$i].stepLabels.list[0].description = $preferredStageNames[$i]
        }
    }
}

$newUidata = $newUidataText | ConvertFrom-Json
$newUidata.BusinessProcessFlowId = $target.workflowid
$newUidata.BusinessProcessFlowName = $target.name
$newUidata.BusinessProcessFlowUniqueName = $target.uniquename
$newUidata.LabelId = $target.workflowid

$newXaml = [regex]::Replace($newXaml, [regex]::Escape($template.uniquename), $target.uniquename, 'IgnoreCase')
$newXaml = [regex]::Replace($newXaml, [regex]::Escape($template.workflowid), $target.workflowid, 'IgnoreCase')

$patchBody = @{
    clientdata = ($newClientData | ConvertTo-Json -Depth 100 -Compress)
    uidata = ($newUidata | ConvertTo-Json -Depth 100 -Compress)
    xaml = $newXaml
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Patch -Uri "$envUrl/api/data/v9.2/workflows($($target.workflowid))" -Headers $headers -Body $patchBody | Out-Null

$verify = Invoke-RestMethod -Method Get -Uri "$envUrl/api/data/v9.2/workflows($($target.workflowid))?`$select=workflowid,name,modifiedon" -Headers $headers

Write-Host "Remediation applied to '$($verify.name)' ($($verify.workflowid))."
Write-Host "ModifiedOn: $($verify.modifiedon)"
Write-Host "Template source: $($template.name) ($TemplateWorkflowId)"
Write-Host "GUIDs remapped: $($guidMap.Count)"