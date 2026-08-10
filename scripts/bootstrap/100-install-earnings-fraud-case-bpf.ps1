<#
.SYNOPSIS
    Validates and solution-installs the designer-authored Earnings Fraud Case Review BPF.

.DESCRIPTION
    The Power Apps process designer owns Business Process Flow stage and branch serialization.
    This script deliberately does not create or patch workflow.clientdata. It verifies that an
    existing active category-4 workflow is based on the Case table (`incident`), then adds the
    workflow to the configured unmanaged solution as component type 29. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/100-install-earnings-fraud-case-bpf.ps1 -Publish
#>

param(
    [string]$ProcessName = "Earnings Fraud Case Review",
    [string]$BaseEntityLogicalName = "incident",
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if (Test-Path $envFile) {
    . $envFile
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
}
if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
    $SolutionUniqueName = $global:DV_SOLUTION_NAME
}
if (-not [string]::IsNullOrWhiteSpace($EnvironmentUrl) -and $null -ne (Get-Command az -ErrorAction SilentlyContinue)) {
    $freshAccessToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
    if (-not [string]::IsNullOrWhiteSpace($freshAccessToken)) {
        $AccessToken = $freshAccessToken.Trim()
    }
}

foreach ($required in @(
    @{ Name = "Environment URL"; Value = $EnvironmentUrl },
    @{ Name = "Access token"; Value = $AccessToken },
    @{ Name = "Solution unique name"; Value = $SolutionUniqueName }
)) {
    if ([string]::IsNullOrWhiteSpace($required.Value)) {
        throw "$($required.Name) is required. Run 10-auth-connect.ps1 first."
    }
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

function Add-SolutionComponent {
    param(
        [Guid]$ComponentId,
        [int]$ComponentType,
        [string]$TargetSolutionUniqueName
    )

    $body = @{
        ComponentId = $ComponentId
        ComponentType = $ComponentType
        SolutionUniqueName = $TargetSolutionUniqueName
        AddRequiredComponents = $false
    } | ConvertTo-Json -Compress

    Invoke-Dv -Method "Post" -Path "AddSolutionComponent" -Body $body | Out-Null
}

Write-Host ""
Write-Host "=== Install Earnings Fraud Case Review BPF ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Process:     $ProcessName"
Write-Host "  Base table:  $BaseEntityLogicalName"
Write-Host ""

$escapedSolution = $SolutionUniqueName.Replace("'", "''")
$solution = @((Invoke-Dv -Method "Get" -Path "solutions?`$select=solutionid,uniquename&`$filter=uniquename eq '$escapedSolution'").value | Select-Object -First 1)
if ($solution.Count -eq 0) {
    throw "Solution '$SolutionUniqueName' was not found in this environment."
}

$escapedProcessName = $ProcessName.Replace("'", "''")
$workflows = @((Invoke-Dv -Method "Get" -Path "workflows?`$select=workflowid,name,category,primaryentity,statecode,statuscode,createdon,modifiedon&`$filter=category eq 4 and name eq '$escapedProcessName'&`$orderby=modifiedon desc").value)
if ($workflows.Count -eq 0) {
    throw "Business Process Flow '$ProcessName' was not found. Create it in the Power Apps process designer on '$BaseEntityLogicalName', activate it, then rerun this script."
}

$process = $workflows | Where-Object { $_.primaryentity -eq $BaseEntityLogicalName } | Select-Object -First 1
if ($null -eq $process) {
    $foundEntities = @($workflows | ForEach-Object { $_.primaryentity } | Sort-Object -Unique) -join ", "
    throw "Business Process Flow '$ProcessName' exists but is not based on '$BaseEntityLogicalName'. Found base entity values: $foundEntities"
}

if ([int]$process.statecode -ne 1) {
    throw "Business Process Flow '$ProcessName' is not active (statecode $($process.statecode)). Activate it in the process designer, then rerun this script."
}

Write-Host "  Workflow ID: $($process.workflowid)" -ForegroundColor DarkGray
Write-Host "  State:       active" -ForegroundColor Green

try {
    Add-SolutionComponent -ComponentId ([Guid]$process.workflowid) -ComponentType 29 -TargetSolutionUniqueName $SolutionUniqueName
    Write-Host "  Solution membership: added" -ForegroundColor Green
}
catch {
    $message = $_.Exception.Message
    if ($message -match "already|duplicate|exists") {
        Write-Host "  Solution membership: already present" -ForegroundColor DarkGray
    }
    else {
        throw "Could not add BPF to solution '$SolutionUniqueName': $message"
    }
}

if ($Publish) {
    Write-Host "  Publishing all customizations..." -NoNewline
    Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null
    Write-Host " done." -ForegroundColor Green
}

Write-Host ""
Write-Host "BPF validation/install complete." -ForegroundColor Green
Write-Host "Next: enable the active BPF for Case in Earnings Integrity V2 Demo App, publish the app, then test both branch paths." -ForegroundColor Yellow