<#
.SYNOPSIS
    Removes non-fraud app components from a model-driven app.

.DESCRIPTION
    Deletes form/view components for generic tables (`incident`, `contact`) from the
    target app, then publishes customizations.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AppId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "EnvironmentUrl is required."
}
if ([string]::IsNullOrWhiteSpace($AppId)) {
    throw "AppId is required."
}

function Get-Token([string]$ResourceUrl) {
    $token = (& az account get-access-token --resource $ResourceUrl --query accessToken -o tsv 2>$null)
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Unable to acquire Dataverse access token."
    }
    return $token.Trim()
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Token,
        [object]$Body = $null
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }

    $headers["Content-Type"] = "application/json"
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
}

$token = Get-Token -ResourceUrl $EnvironmentUrl

$app = Invoke-Dv -Method "Get" -Path "appmodules($AppId)?`$select=appmoduleidunique,name" -Token $token
$appUniqueId = $app.appmoduleidunique

$allComponents = (Invoke-Dv -Method "Get" -Path "appmodulecomponents?`$select=appmodulecomponentid,componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $appUniqueId&`$top=5000" -Token $token).value

$formRows = @($allComponents | Where-Object { $_.componenttype -eq 60 })
$viewRows = @($allComponents | Where-Object { $_.componenttype -eq 26 })
$formObjectIds = @($formRows | Select-Object -ExpandProperty objectid -Unique)
$viewObjectIds = @($viewRows | Select-Object -ExpandProperty objectid -Unique)

$allForms = (Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=type eq 2&`$top=5000" -Token $token).value
$allViews = (Invoke-Dv -Method "Get" -Path "savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype&`$filter=querytype eq 0&`$top=5000" -Token $token).value

$nonFraudFormIds = @(
    $allForms |
        Where-Object { $formObjectIds -contains $_.formid -and ($_.objecttypecode -eq "incident" -or $_.objecttypecode -eq "contact") } |
        Select-Object -ExpandProperty formid -Unique
)

$nonFraudViewIds = @(
    $allViews |
        Where-Object { $viewObjectIds -contains $_.savedqueryid -and ($_.returnedtypecode -eq "incident" -or $_.returnedtypecode -eq "contact") } |
        Select-Object -ExpandProperty savedqueryid -Unique
)

$targets = @(
    $allComponents |
        Where-Object {
            ($_.componenttype -eq 60 -and $nonFraudFormIds -contains $_.objectid) -or
            ($_.componenttype -eq 26 -and $nonFraudViewIds -contains $_.objectid)
        }
)

Write-Host "App: $($app.name)" -ForegroundColor Cyan
Write-Host "Non-fraud components to delete: $($targets.Count)" -ForegroundColor Cyan

$deleted = 0
$failed = 0
foreach ($t in $targets) {
    try {
        Invoke-Dv -Method "Delete" -Path "appmodulecomponents($($t.appmodulecomponentid))" -Token $token | Out-Null
        $deleted++
    }
    catch {
        $failed++
        Write-Host "Delete failed: $($t.appmodulecomponentid) type=$($t.componenttype) object=$($t.objectid)" -ForegroundColor Yellow
    }
}

Invoke-Dv -Method "Post" -Path "PublishAllXml" -Token $token -Body @{} | Out-Null
Write-Host "Deleted: $deleted, Failed: $failed" -ForegroundColor Green
