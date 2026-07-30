<#
.SYNOPSIS
    Builds Dataverse web resources from webresource-*.json payload files.

.DESCRIPTION
    Creates or updates web resources, optionally adds them to the target
    solution, and publishes customizations.

.PARAMETER ScenarioSlug
    Optional scenario identifier used to infer payload folder defaults.

.PARAMETER EnvironmentUrl
    Dataverse environment URL. Defaults to DV_ENVIRONMENT_URL.

.PARAMETER AccessToken
    Dataverse access token. Defaults to DV_TOKEN.

.PARAMETER SolutionUniqueName
    Target solution unique name for AddToSolution entries.

.PARAMETER PublisherPrefix
    Publisher prefix used when replacing {prefix} in resource names.

.PARAMETER PayloadsFolder
    Folder containing webresource-*.json and source files.
#>

param(
    [string]$ScenarioSlug = "",
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
    [string]$PayloadsFolder = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
    . $envFile
    $EnvironmentUrl = if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { $global:DV_ENVIRONMENT_URL } else { $EnvironmentUrl }
    $AccessToken = if ([string]::IsNullOrWhiteSpace($AccessToken)) { $global:DV_TOKEN } else { $AccessToken }
    $SolutionUniqueName = if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $global:DV_SOLUTION_NAME } else { $SolutionUniqueName }
    $PublisherPrefix = if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { $global:DV_PUBLISHER_PREFIX } else { $PublisherPrefix }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
    exit 1
}

function Resolve-PayloadRoot {
    param(
        [string]$RequestedPath,
        [string]$Scenario
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path $RequestedPath)) {
            throw "Payload folder not found: $RequestedPath"
        }
        return (Resolve-Path $RequestedPath).Path
    }

    $preferred = @()
    if ($Scenario -match "-v2$") {
        $preferred += (Join-Path $repoRoot "scripts\payloads-v2")
    }
    $preferred += (Join-Path $repoRoot "scripts\payloads")
    $preferred += (Join-Path $repoRoot "payloads")

    foreach ($path in $preferred) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }

    throw "No payload folder found. Checked: $($preferred -join ', ')"
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ""
    )

    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept" = "application/json"
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body $Body
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

function Try-RefreshAccessToken {
    param([string]$TargetUrl)

    try {
        $newToken = (& az account get-access-token --resource $TargetUrl --query accessToken -o tsv 2>$null)
        if (-not [string]::IsNullOrWhiteSpace($newToken)) {
            $script:AccessToken = $newToken.Trim()
            return $true
        }
    } catch {
        return $false
    }

    return $false
}

function Escape-ODataString {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Add-SolutionComponent {
    param(
        [Guid]$ComponentId,
        [int]$ComponentType,
        [string]$SolutionName
    )

    $body = @{
        ComponentId = $ComponentId
        ComponentType = $ComponentType
        SolutionUniqueName = $SolutionName
        AddRequiredComponents = $false
    } | ConvertTo-Json -Compress

    Invoke-Dv -Method "Post" -Path "AddSolutionComponent" -Body $body | Out-Null
}

$payloadRoot = Resolve-PayloadRoot -RequestedPath $PayloadsFolder -Scenario $ScenarioSlug
$payloadFiles = @(Get-ChildItem -Path $payloadRoot -Filter "webresource-*.json" -File -ErrorAction SilentlyContinue)

$connectionReady = $false
try {
    Invoke-Dv -Method "Get" -Path "WhoAmI" | Out-Null
    $connectionReady = $true
} catch {
    if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*Unauthorized*") {
        if (Try-RefreshAccessToken -TargetUrl $EnvironmentUrl) {
            try {
                Invoke-Dv -Method "Get" -Path "WhoAmI" | Out-Null
                $connectionReady = $true
            } catch {
                $connectionReady = $false
            }
        }
    }

    if (-not $connectionReady) {
        throw
    }
}

Write-Host ""
Write-Host "=== Build Web Resources ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Prefix:      $PublisherPrefix"
Write-Host "  Payloads:    $payloadRoot"
Write-Host ""

if ($payloadFiles.Count -eq 0) {
    Write-Host "No webresource-*.json payloads found in: $payloadRoot" -ForegroundColor Yellow
    exit 0
}

$created = 0
$updated = 0
$solutionAdded = 0
$skipped = 0
$failed = 0

$normalizedPrefix = if ([string]::IsNullOrWhiteSpace($PublisherPrefix)) { "" } else { $PublisherPrefix.ToLower() }

foreach ($payloadFile in $payloadFiles) {
    $doc = Get-Content $payloadFile.FullName -Raw | ConvertFrom-Json
    $entries = @($doc.WebResources)

    if ($entries.Count -eq 0) {
        Write-Host "  $($payloadFile.Name): no WebResources entries" -ForegroundColor Yellow
        $skipped++
        continue
    }

    Write-Host "  Payload: $($payloadFile.Name)" -ForegroundColor Cyan

    foreach ($entry in $entries) {
        try {
            $name = "$($entry.Name)"
            if ([string]::IsNullOrWhiteSpace($name)) {
                Write-Host "    SKIP missing Name" -ForegroundColor Yellow
                $skipped++
                continue
            }

            if ($name.Contains("{prefix}")) {
                if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) {
                    throw "Name '$name' requires {prefix}, but PublisherPrefix is empty."
                }
                $name = $name.Replace("{prefix}", $normalizedPrefix)
            }

            $sourcePath = "$($entry.SourcePath)"
            if ([string]::IsNullOrWhiteSpace($sourcePath)) {
                throw "SourcePath missing for web resource '$name'."
            }

            $sourceFullPath = Join-Path $payloadRoot $sourcePath
            if (-not (Test-Path $sourceFullPath)) {
                throw "Source file not found: $sourceFullPath"
            }

            $contentBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($sourceFullPath))
            $displayName = "$($entry.DisplayName)"
            $description = "$($entry.Description)"
            $resourceType = [int]$entry.WebResourceType
            $escapedName = Escape-ODataString -Value $name

            $existing = (Invoke-Dv -Method "Get" -Path "webresourceset?`$select=webresourceid,name&`$filter=name eq '$escapedName'").value | Select-Object -First 1

            if ($null -eq $existing) {
                $createBody = @{
                    name = $name
                    displayname = $displayName
                    description = $description
                    webresourcetype = $resourceType
                    content = $contentBase64
                } | ConvertTo-Json -Compress

                Invoke-Dv -Method "Post" -Path "webresourceset" -Body $createBody | Out-Null
                $created++
                Write-Host "    $name (created)" -ForegroundColor Green

                $existing = (Invoke-Dv -Method "Get" -Path "webresourceset?`$select=webresourceid,name&`$filter=name eq '$escapedName'").value | Select-Object -First 1
            } else {
                $updateBody = @{
                    displayname = $displayName
                    description = $description
                    webresourcetype = $resourceType
                    content = $contentBase64
                } | ConvertTo-Json -Compress

                Invoke-Dv -Method "Patch" -Path "webresourceset($($existing.webresourceid))" -Body $updateBody | Out-Null
                $updated++
                Write-Host "    $name (updated)" -ForegroundColor Green
            }

            $shouldAdd = $false
            if ($entry.PSObject.Properties.Name -contains "AddToSolution") {
                $shouldAdd = [bool]$entry.AddToSolution
            }

            if ($shouldAdd) {
                if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
                    Write-Host "      AddToSolution skipped: SolutionUniqueName is empty" -ForegroundColor Yellow
                    $skipped++
                } elseif ($null -eq $existing) {
                    Write-Host "      AddToSolution skipped: webresource id not available" -ForegroundColor Yellow
                    $skipped++
                } else {
                    try {
                        # ComponentType 61 = Web Resource.
                        Add-SolutionComponent -ComponentId ([Guid]$existing.webresourceid) -ComponentType 61 -SolutionName $SolutionUniqueName
                        $solutionAdded++
                        Write-Host "      added to solution" -ForegroundColor DarkGray
                    } catch {
                        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
                            Write-Host "      already in solution" -ForegroundColor DarkGray
                            $skipped++
                        } else {
                            throw
                        }
                    }
                }
            }
        } catch {
            Write-Host "    FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Web resources — created: $created  updated: $updated  solution-added: $solutionAdded  skipped: $skipped  failed: $failed"

if ($failed -gt 0) {
    exit 1
}

Write-Host ""
Write-Host "Publishing all customizations..." -NoNewline
try {
    Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null
    Write-Host " done." -ForegroundColor Green
} catch {
    Write-Host " warning: publish failed. $($_.Exception.Message)" -ForegroundColor Yellow
}

exit 0