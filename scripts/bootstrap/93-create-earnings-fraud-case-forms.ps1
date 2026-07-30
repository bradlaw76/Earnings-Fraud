<#
.SYNOPSIS
    Creates dedicated earnings-fraud case forms for the earnfrd2_case table.

.DESCRIPTION
    Clones the existing Starter Main Form (or Information as fallback) for
    earnfrd2_case into role-focused forms, then optionally adds them to the
    model-driven app.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$AppId = "",
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $global:DV_TOKEN
    }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Environment URL is required."
}

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    $AccessToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
}

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Access token is required. Run 10-auth-connect.ps1 or login with az."
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ""
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Accept" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        "Content-Type" = "application/json"
    }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
}

function Ensure-Form {
    param(
        [string]$TableLogicalName,
        [string]$NewFormName,
        [string]$SourceFormXml
    )

    $existing = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,type&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$($NewFormName.Replace("'","''"))'").value)
    if ($existing.Count -gt 0) {
        Write-Host "  $NewFormName (already exists)" -ForegroundColor DarkGray
        return "$($existing[0].formid)"
    }

    $body = @{
        name = $NewFormName
        objecttypecode = $TableLogicalName
        type = 2
        formxml = $SourceFormXml
    } | ConvertTo-Json -Compress -Depth 20

    Invoke-Dv -Method "Post" -Path "systemforms" -Body $body | Out-Null
    $created = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,type&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$($NewFormName.Replace("'","''"))'").value | Select-Object -First 1)
    if ($created.Count -eq 0) {
        throw "Form '$NewFormName' creation could not be verified."
    }
    Write-Host "  $NewFormName (created)" -ForegroundColor Green
    return "$($created[0].formid)"
}

function Add-FormsToApp {
    param(
        [string]$TargetAppId,
        [string]$TargetSolutionName,
        [string[]]$FormIds
    )

    if ([string]::IsNullOrWhiteSpace($TargetAppId) -or $FormIds.Count -eq 0) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetSolutionName)) {
        foreach ($fid in $FormIds) {
            $solutionBody = @{
                ComponentId = $fid
                ComponentType = 60
                SolutionUniqueName = $TargetSolutionName
                AddRequiredComponents = $false
            } | ConvertTo-Json -Compress

            try {
                Invoke-Dv -Method "Post" -Path "AddSolutionComponent" -Body $solutionBody | Out-Null
            }
            catch {
                # Ignore already-in-solution errors.
            }
        }
    }

    $components = @()
    foreach ($fid in $FormIds) {
        $components += @{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $fid }
    }

    $body = @{
        AppId = $TargetAppId
        Components = $components
    } | ConvertTo-Json -Compress -Depth 20

    Invoke-Dv -Method "Post" -Path "AddAppComponents" -Body $body | Out-Null
    Write-Host "  Added $($FormIds.Count) forms to app $TargetAppId" -ForegroundColor Green

    $app = Invoke-Dv -Method "Get" -Path "appmodules($TargetAppId)?`$select=appmoduleidunique"
    $appUniqueId = $app.appmoduleidunique
    foreach ($fid in $FormIds) {
        $link = @((Invoke-Dv -Method "Get" -Path "appmodulecomponents?`$select=componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $appUniqueId and objectid eq $fid&`$top=1").value)
        if ($link.Count -eq 0) {
            Write-Host "  WARN: form $fid not returned as direct appmodulecomponent link; form is still created on table." -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== Create Earnings Fraud Case Forms ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$table = "earnfrd2_case"
$forms = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,formxml,type&`$filter=objecttypecode eq '$table' and type eq 2").value)

$source = @($forms | Where-Object { $_.name -eq "Starter Main Form" } | Select-Object -First 1)
if ($source.Count -eq 0) {
    $source = @($forms | Where-Object { $_.name -eq "Information" } | Select-Object -First 1)
}
if ($source.Count -eq 0) {
    throw "No source form found on $table. Expected Starter Main Form or Information."
}

$sourceXml = "$($source[0].formxml)"

$targetFormNames = @(
    "Fraud Analyst Case Form",
    "Supervisor Review Case Form"
)

$createdOrExistingIds = New-Object System.Collections.Generic.List[string]
foreach ($name in $targetFormNames) {
    $fid = Ensure-Form -TableLogicalName $table -NewFormName $name -SourceFormXml $sourceXml
    if (-not [string]::IsNullOrWhiteSpace($fid)) {
        [void]$createdOrExistingIds.Add($fid)
    }
}

if (-not [string]::IsNullOrWhiteSpace($AppId)) {
    Add-FormsToApp -TargetAppId $AppId -TargetSolutionName $SolutionUniqueName -FormIds @($createdOrExistingIds)
}

if ($Publish) {
    Write-Host "  Publishing all customizations..." -NoNewline
    Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null
    Write-Host " done." -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Created/validated forms on earnfrd2_case:" -ForegroundColor Green
foreach ($name in $targetFormNames) {
    Write-Host "  - $name"
}
