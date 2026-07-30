<#
.SYNOPSIS
    Generates a readable component report for a model-driven app.

.DESCRIPTION
    Resolves appmodulecomponents into form/view names and entities, then writes
    a markdown report that can be used as implementation evidence.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AppId,
    [string]$OutputPath = "specs/ssa-earnings-integrity-case-review-v2/app-components-report.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $envFile = Join-Path $repoRoot ".env.ps1"
    if (Test-Path $envFile) {
        . $envFile
        $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Environment URL is required. Pass -EnvironmentUrl or run 10-auth-connect.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($AppId)) {
    throw "AppId is required."
}

function Get-Token([string]$ResourceUrl) {
    $token = (& az account get-access-token --resource $ResourceUrl --query accessToken -o tsv 2>$null)
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Unable to acquire access token from Azure CLI."
    }
    return $token.Trim()
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Token
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

$token = Get-Token -ResourceUrl $EnvironmentUrl
$app = Invoke-Dv -Method "Get" -Path "appmodules($AppId)?`$select=appmoduleid,name,uniquename,appmoduleidunique" -Token $token
$appUniqueId = $app.appmoduleidunique

$components = (Invoke-Dv -Method "Get" -Path "appmodulecomponents?`$select=componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $appUniqueId&`$top=5000" -Token $token).value

$formIds = @($components | Where-Object { $_.componenttype -eq 60 } | Select-Object -ExpandProperty objectid -Unique)
$viewIds = @($components | Where-Object { $_.componenttype -eq 26 } | Select-Object -ExpandProperty objectid -Unique)

$forms = @()
if ($formIds.Count -gt 0) {
    $allForms = (Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=type eq 2&`$top=5000" -Token $token).value
    $forms = $allForms | Where-Object { $formIds -contains $_.formid } | Sort-Object objecttypecode, name
}

$views = @()
if ($viewIds.Count -gt 0) {
    $allViews = (Invoke-Dv -Method "Get" -Path "savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype&`$filter=querytype eq 0&`$top=5000" -Token $token).value
    $views = $allViews | Where-Object { $viewIds -contains $_.savedqueryid } | Sort-Object returnedtypecode, name
}

$typeCounts = $components | Group-Object componenttype | Sort-Object Name

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$resolvedOutput = Join-Path $repoRoot $OutputPath
$outDir = Split-Path $resolvedOutput -Parent
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Model-Driven App Component Report") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')") | Out-Null
$lines.Add("- App Name: $($app.name)") | Out-Null
$lines.Add("- App Unique Name: $($app.uniquename)") | Out-Null
$lines.Add("- App ID: $($app.appmoduleid)") | Out-Null
$lines.Add("- Total Components: $($components.Count)") | Out-Null
$lines.Add("") | Out-Null

$lines.Add("## Component Type Counts") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Component Type | Count |") | Out-Null
$lines.Add("|---|---:|") | Out-Null
foreach ($g in $typeCounts) {
    $lines.Add("| $($g.Name) | $($g.Count) |") | Out-Null
}
$lines.Add("") | Out-Null

$lines.Add("## Forms In App") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Table | Form Name | Form ID |") | Out-Null
$lines.Add("|---|---|---|") | Out-Null
if ($forms.Count -eq 0) {
    $lines.Add("| (none) | (none) | (none) |") | Out-Null
} else {
    foreach ($f in $forms) {
        $lines.Add("| $($f.objecttypecode) | $($f.name) | $($f.formid) |") | Out-Null
    }
}
$lines.Add("") | Out-Null

$lines.Add("## Views In App") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("| Table | View Name | View ID |") | Out-Null
$lines.Add("|---|---|---|") | Out-Null
if ($views.Count -eq 0) {
    $lines.Add("| (none) | (none) | (none) |") | Out-Null
} else {
    foreach ($v in $views) {
        $lines.Add("| $($v.returnedtypecode) | $($v.name) | $($v.savedqueryid) |") | Out-Null
    }
}
$lines.Add("") | Out-Null

$lines.Add("## Notes") | Out-Null
$lines.Add("") | Out-Null
$lines.Add("- Web resources are not added as direct app components in this flow.") | Out-Null
$lines.Add("- Web resources become visible through forms/pages that host them.") | Out-Null

Set-Content -Path $resolvedOutput -Value $lines -Encoding UTF8
Write-Host "Report written to: $OutputPath" -ForegroundColor Green
