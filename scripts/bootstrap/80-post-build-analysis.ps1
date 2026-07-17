<#
.SYNOPSIS
    Generates an end-of-build summary and optionally updates README markers,
    then prompts for optional commit/push.

.PARAMETER ScenarioSlug
    Scenario folder under specs/. Defaults to ssa-earnings-integrity-case-review.

.PARAMETER PreviewOnly
    Prints the generated summary and exits without editing README or running git.

.EXAMPLE
    pwsh ./scripts/bootstrap/80-post-build-analysis.ps1

.EXAMPLE
    pwsh ./scripts/bootstrap/80-post-build-analysis.ps1 -PreviewOnly
#>

param(
    [string]$ScenarioSlug = "ssa-earnings-integrity-case-review",
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$readmePath = Join-Path $repoRoot "README.md"
$specPath = Join-Path $repoRoot (Join-Path "specs" (Join-Path $ScenarioSlug "spec.md"))
$planPath = Join-Path $repoRoot (Join-Path "specs" (Join-Path $ScenarioSlug "plan.md"))
$tasksPath = Join-Path $repoRoot (Join-Path "specs" (Join-Path $ScenarioSlug "tasks.md"))
$payloadFolder = Join-Path $repoRoot "scripts\payloads"

$beginMarker = "<!-- BEGIN GENERATED BUILD SUMMARY -->"
$endMarker = "<!-- END GENERATED BUILD SUMMARY -->"

function Assert-PathExists([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path)) {
        throw "Missing required ${Label}: $Path"
    }
}

function Read-YesNo([string]$Prompt, [bool]$DefaultNo = $true) {
    $suffix = if ($DefaultNo) { " (y/N)" } else { " (Y/n)" }
    $answer = Read-Host "$Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return -not $DefaultNo
    }
    return $answer.Trim().ToLowerInvariant() -in @("y", "yes")
}

function Convert-ToBullets([string[]]$Items) {
    if ($null -eq $Items -or $Items.Count -eq 0) {
        return "- None"
    }

    $lines = @()
    foreach ($item in $Items) {
        if (-not [string]::IsNullOrWhiteSpace($item)) {
            $lines += "- $item"
        }
    }

    if ($lines.Count -eq 0) {
        return "- None"
    }

    return ($lines -join "`r`n")
}

function Get-RegexValue([string]$Content, [string]$Pattern) {
    $m = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success -and $m.Groups.Count -gt 1) {
        return $m.Groups[1].Value.Trim()
    }
    return ""
}

Assert-PathExists -Path $readmePath -Label "README"
Assert-PathExists -Path $specPath -Label "spec"
Assert-PathExists -Path $planPath -Label "plan"
Assert-PathExists -Path $tasksPath -Label "tasks"
Assert-PathExists -Path $payloadFolder -Label "payload folder"

$readme = Get-Content $readmePath -Raw
if (($readme -notmatch [regex]::Escape($beginMarker)) -or ($readme -notmatch [regex]::Escape($endMarker))) {
    throw "README markers missing. Add both markers: $beginMarker and $endMarker"
}

$spec = Get-Content $specPath -Raw
$plan = Get-Content $planPath -Raw
$null = $plan
$tasks = Get-Content $tasksPath -Raw
$null = $tasks

$appType = Get-RegexValue -Content $spec -Pattern "(?m)^-\s*App type:\s*(.+)$"
$platformArea = Get-RegexValue -Content $spec -Pattern "(?m)^-\s*Platform area:\s*(.+)$"
$solutionUnique = Get-RegexValue -Content $spec -Pattern '(?m)^-\s*\*\*Solution unique name:\*\*\s*`?(.+?)`?\s*$'
$publisherPrefix = Get-RegexValue -Content $spec -Pattern '(?m)^-\s*\*\*Publisher prefix:\*\*\s*`?(.+?)`?\s*$'

$solutionUnique = $solutionUnique.Trim().Trim([char]96)
$publisherPrefix = $publisherPrefix -replace '\(new\)', ''
$publisherPrefix = $publisherPrefix.Trim().Trim([char]96)

$tablePayloads = @(Get-ChildItem -Path $payloadFolder -Filter "table-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)
$columnPayloads = @(Get-ChildItem -Path $payloadFolder -Filter "columns-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)
$relationshipPayloads = @(Get-ChildItem -Path $payloadFolder -Filter "relationships-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)
$webResourcePayloads = @(Get-ChildItem -Path $payloadFolder -Filter "webresource-*.json" -ErrorAction SilentlyContinue | Sort-Object Name)

$customTables = New-Object System.Collections.Generic.List[string]
foreach ($p in $tablePayloads) {
    $doc = Get-Content $p.FullName -Raw | ConvertFrom-Json
    $schema = if ($doc.PSObject.Properties.Name -contains "EntityDefinition") { "$($doc.EntityDefinition.SchemaName)" } else { "$($doc.SchemaName)" }
    if (-not [string]::IsNullOrWhiteSpace($schema)) {
        $customTables.Add($schema)
    }
}

$standardExtended = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
foreach ($p in $columnPayloads) {
    $doc = Get-Content $p.FullName -Raw | ConvertFrom-Json
    $table = "$($doc.TableLogicalName)"
    if ([string]::IsNullOrWhiteSpace($table)) { continue }
    if (-not ($customTables -contains $table)) {
        [void]$standardExtended.Add($table)
    }
}

$relationshipSummaries = New-Object System.Collections.Generic.List[string]
foreach ($p in $relationshipPayloads) {
    $doc = Get-Content $p.FullName -Raw | ConvertFrom-Json
    $rels = if ($doc -is [array]) { $doc } elseif ($doc.PSObject.Properties.Name -contains "Relationships") { @($doc.Relationships) } else { @($doc) }
    foreach ($r in $rels) {
        $parent = "$($r.ReferencedEntity)"
        $child = "$($r.ReferencingEntity)"
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not [string]::IsNullOrWhiteSpace($child)) {
            $relationshipSummaries.Add("$parent -> $child")
        }
    }
}

$webResourceNames = New-Object System.Collections.Generic.List[string]
foreach ($p in $webResourcePayloads) {
    $doc = Get-Content $p.FullName -Raw | ConvertFrom-Json
    $items = if ($doc -is [array]) { $doc } elseif ($doc.PSObject.Properties.Name -contains "WebResources") { @($doc.WebResources) } else { @($doc) }
    foreach ($item in $items) {
        $name = "$($item.Name)"
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $webResourceNames.Add($name)
        }
    }
}

$generatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm zzz")
$summary = @"
### Generated Build Summary

Generated on: $generatedOn

#### Scenario and Solution Metadata

- App type: $appType
- Platform area: $platformArea
- Solution unique name: $solutionUnique
- Publisher prefix: $publisherPrefix

#### Tables Built

Standard tables extended:
$(Convert-ToBullets -Items @($standardExtended | Sort-Object))

Custom tables created:
$(Convert-ToBullets -Items @($customTables | Sort-Object -Unique))

#### Relationship Map

$(Convert-ToBullets -Items @($relationshipSummaries | Sort-Object -Unique))

#### Forms and Views

- Starter Main Form created or updated for custom tables via script 60
- Active Records view created where missing for custom tables via script 60

#### Web Resources

$(Convert-ToBullets -Items @($webResourceNames | Sort-Object -Unique))

#### Demo Talk Track

1. Create or open a case and set discrepancy type and risk rating.
2. Add discrepancy, evidence, and findings child records tied to the case.
3. Show recommended disposition and supervisor approval path.
4. Open supervisor summary web resource and narrate status, risk, and next action.
5. Close with script-driven repeatability and source-control traceability.

#### Recommended Next Enhancements

- Bind supervisor summary to live Dataverse fields or flow outputs.
- Add queue and triage views for analyst workload routing.
- Add automation for escalation and approval transitions.
- Seed realistic demo data for repeatable walkthroughs.
"@

Write-Host ""
Write-Host "=== Post-Build Analysis Preview ===" -ForegroundColor Cyan
Write-Host $summary

if ($PreviewOnly) {
    Write-Host "Preview only mode enabled. No files were modified." -ForegroundColor Yellow
    exit 0
}

if (-not (Read-YesNo -Prompt "Update README generated summary section now?" -DefaultNo $true)) {
    Write-Host "README update skipped by user." -ForegroundColor Yellow
    exit 0
}

$escapedSummary = [System.Text.RegularExpressions.Regex]::Escape($summary)
$replacement = "$beginMarker`r`n$summary`r`n$endMarker"
$updatedReadme = [regex]::Replace(
    $readme,
    "(?s)" + [regex]::Escape($beginMarker) + ".*?" + [regex]::Escape($endMarker),
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement },
    1
)

if ($updatedReadme -eq $readme) {
    throw "README update failed: marker replacement produced no changes."
}

Set-Content -Path $readmePath -Value $updatedReadme -Encoding UTF8
Write-Host "README generated summary section updated." -ForegroundColor Green

Write-Host ""
Write-Host "Repository Target Check" -ForegroundColor Cyan
& git -C $repoRoot rev-parse --show-toplevel
& git -C $repoRoot remote -v
& git -C $repoRoot branch --show-current

if (-not (Read-YesNo -Prompt "Stage and commit README update now?" -DefaultNo $true)) {
    Write-Host "Commit skipped by user." -ForegroundColor Yellow
    exit 0
}

& git -C $repoRoot add README.md
& git -C $repoRoot commit -m "docs: refresh generated build summary in README"

if (Read-YesNo -Prompt "Push to origin/main now?" -DefaultNo $true) {
    & git -C $repoRoot push origin main
} else {
    Write-Host "Push skipped by user." -ForegroundColor Yellow
}
