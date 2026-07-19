<#
.SYNOPSIS
    Creates or updates Dataverse web resources from payload definitions,
    optionally adds them to the target solution, and publishes customizations.

.PARAMETER EnvironmentUrl     Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken        Defaults to $env:DV_TOKEN.
.PARAMETER SolutionUniqueName Defaults to $env:DV_SOLUTION_NAME.
.PARAMETER PublisherPrefix    Defaults to $env:DV_PUBLISHER_PREFIX.
.PARAMETER PayloadsFolder     Defaults to scripts/payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/70-build-web-resources.ps1
#>

param(
    [string]$EnvironmentUrl     = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken        = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix    = $env:DV_PUBLISHER_PREFIX,
    [string]$PayloadsFolder     = "",
    [int]$PublishTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"

if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl     = $global:DV_ENVIRONMENT_URL
    $AccessToken        = $global:DV_TOKEN
    $SolutionUniqueName = $SolutionUniqueName -ne "" ? $SolutionUniqueName : $global:DV_SOLUTION_NAME
    $PublisherPrefix    = $PublisherPrefix    -ne "" ? $PublisherPrefix    : $global:DV_PUBLISHER_PREFIX
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
        exit 1
    }
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "", [int]$TimeoutSeconds = 0) {
    $h = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept" = "application/json"
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    $invokeArgs = @{
        Method = $Method
        Uri = $uri
        Headers = $h
    }

    if ($Body) {
        $invokeArgs["Body"] = $Body
    }

    if ($TimeoutSeconds -gt 0) {
        $invokeArgs["TimeoutSec"] = $TimeoutSeconds
    }

    return Invoke-RestMethod @invokeArgs
}

function Add-SolutionComponent([Guid]$ComponentId, [int]$ComponentType, [string]$SolutionName) {
    $body = @{
        ComponentId = $ComponentId
        ComponentType = $ComponentType
        SolutionUniqueName = $SolutionName
        AddRequiredComponents = $false
    } | ConvertTo-Json -Compress

    Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
}

function Resolve-SourcePath([string]$PayloadPath, [string]$SourcePath) {
    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($SourcePath)) {
        return $SourcePath
    }

    $payloadDir = Split-Path $PayloadPath -Parent
    return [System.IO.Path]::GetFullPath((Join-Path $payloadDir $SourcePath))
}

function Convert-PayloadToItems([string]$PayloadFile, [object]$Doc) {
    if ($Doc -is [array]) {
        return @($Doc)
    }

    if ($Doc.PSObject.Properties.Name -contains "WebResources") {
        return @($Doc.WebResources)
    }

    return @($Doc)
}

Write-Host ""
Write-Host "=== Build Web Resources ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Prefix:      $PublisherPrefix"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

$solution = (Invoke-Dv "Get" "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
if ($null -eq $solution) {
    Write-Host "Solution '$SolutionUniqueName' not found in this environment." -ForegroundColor Red
    exit 1
}

$payloadFiles = @(Get-ChildItem -Path $PayloadsFolder -Filter "webresource-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)
if ($payloadFiles.Count -eq 0) {
    Write-Host "No web resource payload files found (webresource-*.json)." -ForegroundColor Yellow
    Write-Host "Nothing to build."
    exit 0
}

$created = 0
$updated = 0
$addedToSolution = 0
$skipped = 0
$failed = 0

$prefixLower = $PublisherPrefix.ToLowerInvariant()

foreach ($payloadFile in $payloadFiles) {
    $doc = Get-Content $payloadFile.FullName -Raw | ConvertFrom-Json
    $items = @(Convert-PayloadToItems -PayloadFile $payloadFile.FullName -Doc $doc)

    foreach ($item in $items) {
        $name = "$($item.Name)"
        if ([string]::IsNullOrWhiteSpace($name)) {
            Write-Host "  SKIP  payload missing Name in $($payloadFile.Name)" -ForegroundColor Yellow
            $skipped++
            continue
        }

        $name = $name.Replace("{prefix}", $prefixLower)

        $sourcePath = Resolve-SourcePath -PayloadPath $payloadFile.FullName -SourcePath "$($item.SourcePath)"
        if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path $sourcePath)) {
            Write-Host "  FAIL  $name (source file missing: $sourcePath)" -ForegroundColor Red
            $failed++
            continue
        }

        $displayName = "$($item.DisplayName)"
        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = $name
        }

        $description = "$($item.Description)"
        $type = if ($null -ne $item.WebResourceType) { [int]$item.WebResourceType } else { 1 }
        $addToSolution = if ($null -ne $item.AddToSolution) { [bool]$item.AddToSolution } else { $true }

        $contentBytes = [System.IO.File]::ReadAllBytes($sourcePath)
        $base64 = [System.Convert]::ToBase64String($contentBytes)

        $safeName = $name.Replace("'", "''")
        $existing = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1

        $body = @{
            "name" = $name
            "displayname" = $displayName
            "description" = $description
            "webresourcetype" = $type
            "content" = $base64
        } | ConvertTo-Json -Compress -Depth 10

        try {
            if ($null -eq $existing) {
                Invoke-Dv "Post" "webresourceset" $body | Out-Null
                Write-Host "  $name (created)" -ForegroundColor Green
                $created++
                $createdLookup = (Invoke-Dv "Get" "webresourceset?`$select=webresourceid,name&`$filter=name eq '$safeName'").value | Select-Object -First 1
                if ($null -eq $createdLookup) {
                    throw "Created web resource could not be reloaded by name."
                }
                $webResourceId = [Guid]$createdLookup.webresourceid
            } else {
                Invoke-Dv "Patch" "webresourceset($($existing.webresourceid))" $body | Out-Null
                Write-Host "  $name (updated)" -ForegroundColor Green
                $updated++
                $webResourceId = [Guid]$existing.webresourceid
            }

            if ($addToSolution) {
                try {
                    Add-SolutionComponent -ComponentId $webResourceId -ComponentType 61 -SolutionName $SolutionUniqueName
                    Write-Host "    added to solution" -ForegroundColor DarkGray
                    $addedToSolution++
                } catch {
                    if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                        Write-Host "    already in solution" -ForegroundColor DarkGray
                    } else {
                        Write-Host "    add-to-solution failed: $($_.Exception.Message)" -ForegroundColor Yellow
                        $failed++
                    }
                }
            }
        } catch {
            Write-Host "  FAIL  $name ($($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Publishing all customizations..." -NoNewline
try {
    Invoke-Dv "Post" "PublishAllXml" "{}" $PublishTimeoutSeconds | Out-Null
    Write-Host " done." -ForegroundColor Green
} catch {
    Write-Host " warning: publish failed or timed out after $PublishTimeoutSeconds seconds ($($_.Exception.Message))" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Web resources — created: $created  updated: $updated  added to solution: $addedToSolution  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Running post-build analysis and optional README update..."
$postBuildScript = Join-Path $PSScriptRoot "80-post-build-analysis.ps1"
if (Test-Path $postBuildScript) {
    try {
        & $postBuildScript
    } catch {
        Write-Host "Post-build analysis warning: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Post-build analysis script not found: $postBuildScript" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next step: verify web resources and form placement in Power Apps Maker."
