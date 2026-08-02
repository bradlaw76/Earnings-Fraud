<#
.SYNOPSIS
    Adds columns to existing Dataverse tables from columns-*.json payload files.
    Safe to rerun — skips columns that already exist on the table.

.PARAMETER EnvironmentUrl  Defaults to $env:DV_ENVIRONMENT_URL (set by 10-auth-connect.ps1).
.PARAMETER AccessToken     Defaults to $env:DV_TOKEN.
.PARAMETER PayloadsFolder  Folder containing columns-*.json. Defaults to ../../payloads.

.EXAMPLE
    pwsh ./scripts/bootstrap/30-build-columns.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken    = $env:DV_TOKEN,
    [string]$PayloadsFolder = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile; $EnvironmentUrl = $global:DV_ENVIRONMENT_URL; $AccessToken = $global:DV_TOKEN
}
if ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken)) {
    Write-Host "Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    $attempt = 0
    $maxAttempts = 6

    while ($attempt -lt $maxAttempts) {
        $attempt++
        try {
            $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
                    "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
            if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
        } catch {
            $status = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $status = [int]$_.Exception.Response.StatusCode
            } elseif ($_.Exception.Message -match "\b(401|429)\b") {
                $status = [int]$matches[1]
            }

            if ($status -eq 401 -and $attempt -lt $maxAttempts) {
                try {
                    $freshToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
                    if (-not [string]::IsNullOrWhiteSpace($freshToken)) {
                        $AccessToken = $freshToken.Trim()
                        continue
                    }
                } catch {
                    throw
                }
            }

            if ($status -eq 429 -and $attempt -lt $maxAttempts) {
                $waitSeconds = [Math]::Min(16, [Math]::Pow(2, $attempt - 1))
                Write-Host "(throttled, retrying in $waitSeconds sec)" -ForegroundColor Yellow
                [System.Threading.Thread]::Sleep([int]($waitSeconds * 1000))
                continue
            }

            throw
        }
    }
}

function Test-ColumnExists([string]$Table, [string]$Column) {
    try { Invoke-Dv "Get" "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$Column')?`$select=LogicalName" | Out-Null; return $true }
    catch { return $false }
}

Write-Host ""
Write-Host "=== Build Columns ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$payloads = @(Get-ChildItem -Path $PayloadsFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue)
if ($payloads.Count -eq 0) {
    Write-Host "No columns-*.json found in: $PayloadsFolder" -ForegroundColor Yellow; exit 0
}

$created = 0; $skipped = 0; $failed = 0

foreach ($file in $payloads) {
    $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $tableName = $doc.TableLogicalName
    if ([string]::IsNullOrWhiteSpace($tableName)) {
        Write-Host "  SKIP $($file.Name) — missing TableLogicalName property" -ForegroundColor Yellow
        $skipped++; continue
    }

    $tableLogicalName = $tableName.ToLower()

    Write-Host "  Table: $tableLogicalName" -ForegroundColor Cyan
    foreach ($col in $doc.Columns) {
        $schema = $col.SchemaName
        $logical = $schema.ToLower()
        Write-Host "    $schema " -NoNewline

        if (Test-ColumnExists $tableLogicalName $logical) {
            Write-Host "(exists — skipped)" -ForegroundColor DarkGray
            $skipped++; continue
        }

        try {
            $body = $col | ConvertTo-Json -Depth 20 -Compress
            Invoke-Dv "Post" "EntityDefinitions(LogicalName='$tableLogicalName')/Attributes" $body | Out-Null
            Write-Host "(created)" -ForegroundColor Green
            $created++
        } catch {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

Write-Host ""
Write-Host "Columns — created: $created  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/40-build-relationships.ps1"

