<#
.SYNOPSIS
    Applies accessible semantic colors to every custom Picklist choice option in the
    Federal Earnings Fraud payloads and can prefix choice labels with icon glyphs.

.DESCRIPTION
    Dataverse choice metadata natively supports an option Color, which this script
    deploys through UpdateOptionValue. Dataverse does not expose an icon property
    for choice options; use -ApplyIconLabels to prefix the visible label with a
    stable Unicode icon glyph.

.EXAMPLE
    pwsh ./scripts/bootstrap/85-apply-choice-visuals.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$PayloadsFolder = "",
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [switch]$VerifyOnly,
    [switch]$ApplyIconLabels
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and ([string]::IsNullOrWhiteSpace($EnvironmentUrl) -or [string]::IsNullOrWhiteSpace($AccessToken))) {
    . $envFile
    if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) { $EnvironmentUrl = $global:DV_ENVIRONMENT_URL }
    if ([string]::IsNullOrWhiteSpace($AccessToken)) { $AccessToken = $global:DV_TOKEN }
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) { $SolutionUniqueName = $global:DV_SOLUTION_NAME }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Run 10-auth-connect.ps1 first. DV_ENVIRONMENT_URL is not available."
}
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    $AccessToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null).Trim()
}
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "No Dataverse access token is available. Run 10-auth-connect.ps1 first."
}
if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
    $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}
if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
    $SolutionUniqueName = "FederalEarningsFraud"
}

function Get-Visual([string]$Label, [string]$AttributeLogicalName) {
    $normalized = $Label.ToLowerInvariant()
    $attribute = $AttributeLogicalName.ToLowerInvariant()

    if ($normalized -match '^no discrepancy$|^no issue|close - no issue|closed without action|corrected|validated|verified|approved|received|complete$') {
        return [PSCustomObject]@{ Color = "#B7E4C7"; Icon = "CompletedSolid"; Meaning = "Resolved or low risk" }
    }
    if ($attribute -match 'confidence') {
        if ($normalized -match 'high confidence') {
            return [PSCustomObject]@{ Color = "#B7E4C7"; Icon = "CompletedSolid"; Meaning = "High confidence" }
        }
        if ($normalized -match 'low confidence|conflicting evidence') {
            return [PSCustomObject]@{ Color = "#FFD6A5"; Icon = "AlertSolid"; Meaning = "Low confidence" }
        }
        return [PSCustomObject]@{ Color = "#FFF3B0"; Icon = "Clock"; Meaning = "Needs review" }
    }
    if ($attribute -match 'riskrating|fraudlikelihood|severity') {
        if ($normalized -match 'critical') {
            return [PSCustomObject]@{ Color = "#FFC2C7"; Icon = "Warning"; Meaning = "Critical attention" }
        }
        if ($normalized -match 'high') {
            return [PSCustomObject]@{ Color = "#FFD6A5"; Icon = "AlertSolid"; Meaning = "Elevated risk" }
        }
        if ($normalized -match 'medium|insufficient|requires') {
            return [PSCustomObject]@{ Color = "#FFF3B0"; Icon = "Clock"; Meaning = "Needs review" }
        }
        if ($normalized -match 'low') {
            return [PSCustomObject]@{ Color = "#B7E4C7"; Icon = "CompletedSolid"; Meaning = "Resolved or low risk" }
        }
    }

    if ($normalized -match 'critical|fraud|escalation|oig|high-risk|mismatch|missing|overdue|rejected|contradictory|false|identity') {
        return [PSCustomObject]@{ Color = "#FFC2C7"; Icon = "Warning"; Meaning = "Critical attention" }
    }
    if ($normalized -match 'high|overpayment|discrepancy|underreported|unreported|duplicate|error|incomplete|no response') {
        return [PSCustomObject]@{ Color = "#FFD6A5"; Icon = "AlertSolid"; Meaning = "Elevated risk" }
    }
    if ($normalized -match 'medium|progress|pending|review|requested|request|contact|follow-up|requires|insufficient|unknown|neutral|inconclusive') {
        return [PSCustomObject]@{ Color = "#FFF3B0"; Icon = "Clock"; Meaning = "Needs review" }
    }
    if ($normalized -match 'low|no issue|complete|received|verified|validated|approved|corrected|close|closed|beneficiary explanation') {
        return [PSCustomObject]@{ Color = "#B7E4C7"; Icon = "CompletedSolid"; Meaning = "Resolved or low risk" }
    }
    if ($normalized -match 'wage|employer|beneficiary|representative|call|portal|batch|manual|internal|system|document|statement|note|record|letter') {
        return [PSCustomObject]@{ Color = "#BDE0FE"; Icon = "Info"; Meaning = "Information or source" }
    }

    return [PSCustomObject]@{ Color = "#D8C4F1"; Icon = "Tag"; Meaning = "Classification" }
}

function Get-IconGlyph([string]$Icon) {
    switch ($Icon) {
        "Warning" { return "⚠" }
        "AlertSolid" { return "▲" }
        "Clock" { return "◷" }
        "CompletedSolid" { return "✓" }
        "Info" { return "ℹ" }
        default { return "◆" }
    }
}

function Get-DisplayLabel([string]$Label, [object]$Visual) {
    if (-not $ApplyIconLabels) { return $Label }
    return "$(Get-IconGlyph $Visual.Icon) $Label"
}

function Invoke-Dv([string]$Method, [string]$Path, [object]$Body = $null) {
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    $headers = @{
        Authorization = "Bearer $AccessToken"
        Accept = "application/json"
        "Content-Type" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
    }

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
        }
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10 -Compress)
    }
    catch {
        if ($_.Exception.Message -match '\b401\b') {
            $AccessToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null).Trim()
            if (-not [string]::IsNullOrWhiteSpace($AccessToken)) {
                return Invoke-Dv $Method $Path $Body
            }
        }
        throw
    }
}

function Get-DeployedPicklist([string]$TableLogicalName, [string]$AttributeLogicalName) {
    $path = "EntityDefinitions(LogicalName='$TableLogicalName')/Attributes(LogicalName='$AttributeLogicalName')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?`$select=LogicalName&`$expand=OptionSet"
    return Invoke-Dv "Get" $path
}

function Publish-Tables([System.Collections.Generic.HashSet[string]]$Tables) {
    if ($Tables.Count -eq 0) { return }

    $entities = ($Tables | Sort-Object | ForEach-Object { "<entity>$_</entity>" }) -join ""
    $publishXml = "<importexportxml><entities>$entities</entities><nodes/><securityroles/><settings/><workflows/></importexportxml>"

    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            Invoke-Dv "Post" "PublishXml" @{ ParameterXml = $publishXml } | Out-Null
            Write-Host "`nPublished choice metadata for: $(($Tables | Sort-Object) -join ', ')" -ForegroundColor Green
            return
        }
        catch {
            if ($_.Exception.Message -notmatch '0x80071151|another \[PublishAll\] running|try again later' -or $attempt -eq 6) {
                throw
            }
            $waitSeconds = 5 * $attempt
            Write-Host "Publish is locked by another operation; retrying in $waitSeconds seconds..." -ForegroundColor Yellow
            [System.Threading.Thread]::Sleep($waitSeconds * 1000)
        }
    }
}

$payloadFiles = @(Get-ChildItem -Path $PayloadsFolder -Filter "columns-*.json" -ErrorAction Stop)
if ($payloadFiles.Count -eq 0) { throw "No column payloads found in $PayloadsFolder." }

$updated = 0
$inserted = 0
$skipped = 0
$failed = 0
$verified = 0
$missingColors = 0
$mismatchedLabels = 0
$touchedTables = [System.Collections.Generic.HashSet[string]]::new()
$processedTables = [System.Collections.Generic.HashSet[string]]::new()
$visuals = [System.Collections.Generic.List[object]]::new()

Write-Host "`n=== Apply Choice Visuals ===" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentUrl"
Write-Host "Solution:    $SolutionUniqueName`n"

foreach ($file in $payloadFiles) {
    $document = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $table = $document.TableLogicalName.ToLowerInvariant()

    foreach ($column in $document.Columns | Where-Object { $_.'@odata.type' -eq "Microsoft.Dynamics.CRM.PicklistAttributeMetadata" }) {
        $attribute = $column.SchemaName.ToLowerInvariant()
        [void]$processedTables.Add($table)
        Write-Host "$table.$attribute" -ForegroundColor Cyan

        try {
            $deployed = Get-DeployedPicklist $table $attribute
            $deployedOptions = @{};
            foreach ($option in $deployed.OptionSet.Options) { $deployedOptions[[int]$option.Value] = $option }

            foreach ($payloadOption in $column.OptionSet.Options) {
                $value = [int]$payloadOption.Value
                $label = $payloadOption.Label.LocalizedLabels[0].Label
                $visual = Get-Visual $label $attribute
                $displayLabel = Get-DisplayLabel $label $visual
                $current = $deployedOptions[$value]

                $visuals.Add([PSCustomObject]@{
                    Table = $table
                    Column = $attribute
                    Value = $value
                    Choice = $label
                    DisplayLabel = $displayLabel
                    Color = $visual.Color
                    Icon = $visual.Icon
                    IconGlyph = Get-IconGlyph $visual.Icon
                    Meaning = $visual.Meaning
                })

                if ($null -eq $current) {
                    if ($VerifyOnly) {
                        Write-Host "  $value $label (not deployed - skipped)" -ForegroundColor Yellow
                        $skipped++
                        continue
                    }

                    $request = @{
                        EntityLogicalName = $table
                        AttributeLogicalName = $attribute
                        Value = $value
                        Label = @{
                            LocalizedLabels = @(
                                @{
                                    Label = $displayLabel
                                    LanguageCode = 1033
                                }
                            )
                        }
                        Color = $visual.Color
                        SolutionUniqueName = $SolutionUniqueName
                    }
                    Invoke-Dv "Post" "InsertOptionValue" $request | Out-Null
                    [void]$touchedTables.Add($table)
                    Write-Host "  $value $label ($($visual.Color), $($visual.Icon), inserted)" -ForegroundColor Green
                    $inserted++
                    continue
                }
                if ($VerifyOnly) {
                    $currentLabel = $current.Label.UserLocalizedLabel.Label
                    if ([string]::IsNullOrWhiteSpace($current.Color)) {
                        Write-Host "  $value $label (missing color)" -ForegroundColor Red
                        $missingColors++
                    }
                    elseif ($ApplyIconLabels -and $currentLabel -ne $displayLabel) {
                        Write-Host "  $value $label (label is '$currentLabel', expected '$displayLabel')" -ForegroundColor Red
                        $mismatchedLabels++
                    }
                    else {
                        $verified++
                    }
                    continue
                }
                $currentLabel = $current.Label.UserLocalizedLabel.Label
                if ($current.Color -eq $visual.Color -and ((-not $ApplyIconLabels) -or $currentLabel -eq $displayLabel)) {
                    Write-Host "  $value $label ($($visual.Color), unchanged)" -ForegroundColor DarkGray
                    $skipped++
                    continue
                }

                $request = @{
                    EntityLogicalName = $table
                    AttributeLogicalName = $attribute
                    Value = $value
                    Color = $visual.Color
                    MergeLabels = $true
                    SolutionUniqueName = $SolutionUniqueName
                }
                if ($ApplyIconLabels) {
                    $request.Label = @{
                        LocalizedLabels = @(
                            @{
                                Label = $displayLabel
                                LanguageCode = 1033
                            }
                        )
                    }
                }
                Invoke-Dv "Post" "UpdateOptionValue" $request | Out-Null
                [void]$touchedTables.Add($table)
                Write-Host "  $value $displayLabel ($($visual.Color), $($visual.Icon))" -ForegroundColor Green
                $updated++
            }
        }
        catch {
            Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
}

if ($VerifyOnly) {
    Write-Host "`nChoice options verified: $verified, missing colors: $missingColors, mismatched labels: $mismatchedLabels, failed columns: $failed" -ForegroundColor Cyan
}
else {
    if (($updated + $inserted) -gt 0 -or $ApplyIconLabels) {
        if ($ApplyIconLabels) {
            Publish-Tables $processedTables
        }
        else {
            Publish-Tables $touchedTables
        }
    }

    Write-Host "`nChoice options: inserted $inserted, updated $updated, unchanged/skipped $skipped, failed columns $failed" -ForegroundColor Cyan
    Write-Host "Icon mappings (for custom grid/web-resource rendering):" -ForegroundColor Cyan
    $visuals | Sort-Object Table, Column, Value | Format-Table Table, Column, Value, DisplayLabel, Color, IconGlyph, Icon, Meaning -AutoSize -Wrap
}

if ($failed -gt 0 -or $missingColors -gt 0 -or $mismatchedLabels -gt 0) { exit 1 }