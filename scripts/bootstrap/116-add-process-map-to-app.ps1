<#
.SYNOPSIS
    Adds the Earnings Fraud Process Map to the existing model-driven app navigation.

.DESCRIPTION
    Resolves the target app, sitemap, and web resource dynamically. Preserves an
    existing Process Map placement or appends one to the target group, publishes,
    and proves that all pre-existing navigation entries remain. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/116-add-process-map-to-app.ps1 -WhatIf
    pwsh ./scripts/bootstrap/116-add-process-map-to-app.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$AppName = "Earnings Integrity V2 Demo App",
    [string]$WebResourceName = "earnint_/report/earnings-fraud-process-map.html",
    [string]$TargetGroupId = "Dashboards",
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$token = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw "Could not acquire a Dataverse token." }

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
    Accept = "application/json"
    "OData-Version" = "4.0"
    "OData-MaxVersion" = "4.0"
}

function Invoke-Dv {
    param([string]$Method, [string]$Path, [hashtable]$Body)

    $uri = "$EnvironmentUrl/api/data/v9.2/$Path"
    if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 30)
}

function Escape-ODataString([string]$Value) { return $Value.Replace("'", "''") }

function Get-SubAreaSignatures([xml]$Document) {
    return @($Document.SelectNodes("//SubArea") | ForEach-Object {
        "$($_.GetAttribute('Id'))|$($_.GetAttribute('Entity'))|$($_.GetAttribute('Url'))"
    })
}

$escapedAppName = Escape-ODataString $AppName
$apps = @((Invoke-Dv Get "appmodules?`$select=appmoduleid,appmoduleidunique,name,uniquename&`$filter=name eq '$escapedAppName'" $null).value)
if ($apps.Count -ne 1) { throw "Expected one app named '$AppName'; found $($apps.Count)." }
$app = $apps[0]

$components = @((Invoke-Dv Get "appmodulecomponents?`$select=objectid,componenttype&`$filter=_appmoduleidunique_value eq $($app.appmoduleidunique) and componenttype eq 62&`$top=2" $null).value)
if ($components.Count -ne 1) { throw "Expected one sitemap component for '$AppName'; found $($components.Count)." }
$sitemapId = $components[0].objectid

$escapedResourceName = Escape-ODataString $WebResourceName
$resources = @((Invoke-Dv Get "webresourceset?`$select=webresourceid,name,displayname&`$filter=name eq '$escapedResourceName'" $null).value)
if ($resources.Count -ne 1) { throw "Expected the deployed Process Map web resource '$WebResourceName'; found $($resources.Count). Run 70-build-web-resources.ps1 first." }

$sitemap = Invoke-Dv Get "sitemaps($sitemapId)?`$select=sitemapid,sitemapxml" $null
[xml]$xml = $sitemap.sitemapxml
$originalSignatures = @(Get-SubAreaSignatures $xml)
$targetUrl = "`$webresource:$WebResourceName"
$existing = @($xml.SelectNodes("//SubArea") | Where-Object { $_.GetAttribute('Url') -eq $targetUrl })
$targetGroups = @($xml.SelectNodes("//Group") | Where-Object { $_.GetAttribute('Id') -eq $TargetGroupId })
if ($targetGroups.Count -ne 1) { throw "Expected one sitemap group '$TargetGroupId'; found $($targetGroups.Count)." }

Write-Host ""
Write-Host "=== Add Process Map To Model-Driven App ===" -ForegroundColor Cyan
Write-Host "Environment:  $EnvironmentUrl"
Write-Host "App:          $($app.name) ($($app.appmoduleid))"
Write-Host "Sitemap:      $sitemapId"
Write-Host "Web resource: $WebResourceName ($($resources[0].webresourceid))"
Write-Host "Existing nav: $($originalSignatures.Count) subareas"

$effectiveGroupId = $TargetGroupId
$needsPatch = $false
if ($existing.Count -eq 1) {
    $effectiveGroupId = $existing[0].ParentNode.GetAttribute('Id')
    $titleNode = $existing[0].SelectSingleNode("./Titles/Title[@LCID='1033']")
    if ($null -eq $titleNode) {
        $titlesNode = $existing[0].SelectSingleNode("./Titles")
        if ($null -eq $titlesNode) {
            $titlesNode = $xml.CreateElement("Titles")
            [void]$existing[0].AppendChild($titlesNode)
        }
        $titleNode = $xml.CreateElement("Title")
        $titleNode.SetAttribute("LCID", "1033")
        [void]$titlesNode.AppendChild($titleNode)
    }
    if ($titleNode.GetAttribute('Title') -ne "Earnings Fraud Process Map") {
        $titleNode.SetAttribute("Title", "Earnings Fraud Process Map")
        $needsPatch = $true
        Write-Host "  [PLAN] Correct the existing navigation title in group '$effectiveGroupId'." -ForegroundColor Yellow
    } else {
        Write-Host "  [SKIP] Process Map navigation already exists in group '$effectiveGroupId'." -ForegroundColor DarkGray
    }
} elseif ($existing.Count -gt 1) {
    throw "The sitemap contains duplicate Process Map navigation entries."
} else {
    $subArea = $xml.CreateElement("SubArea")
    $subArea.SetAttribute("Id", "subarea_earnint_process_map")
    $subArea.SetAttribute("Url", $targetUrl)
    $subArea.SetAttribute("PassParams", "1")
    $subArea.SetAttribute("AvailableOffline", "false")
    $titles = $xml.CreateElement("Titles")
    $title = $xml.CreateElement("Title")
    $title.SetAttribute("LCID", "1033")
    $title.SetAttribute("Title", "Earnings Fraud Process Map")
    [void]$titles.AppendChild($title)
    [void]$subArea.AppendChild($titles)
    [void]$targetGroups[0].AppendChild($subArea)
    $needsPatch = $true
    Write-Host "  [PLAN] Add 'Process Map' to group '$TargetGroupId'." -ForegroundColor Yellow
}

if ($WhatIf) {
    Write-Host "=== Preview Complete: No Sitemap Changed ===" -ForegroundColor Green
    exit 0
}

if ($needsPatch) {
    Invoke-Dv Patch "sitemaps($sitemapId)" @{ sitemapxml = $xml.OuterXml } | Out-Null
    Invoke-Dv Post "PublishAllXml" @{} | Out-Null
    Write-Host "  [APPLY] Process Map navigation updated and published." -ForegroundColor Green
}

$published = Invoke-Dv Get "sitemaps($sitemapId)?`$select=sitemapxml" $null
[xml]$publishedXml = $published.sitemapxml
$publishedSignatures = @(Get-SubAreaSignatures $publishedXml)
$missingOriginals = @($originalSignatures | Where-Object { $_ -notin $publishedSignatures })
$processMapEntries = @($publishedXml.SelectNodes("//SubArea") | Where-Object { $_.GetAttribute('Url') -eq $targetUrl })
$validationErrors = [System.Collections.Generic.List[string]]::new()
if ($missingOriginals.Count -gt 0) { $validationErrors.Add("Existing navigation entries were removed or changed: $($missingOriginals -join ', ')") }
if ($processMapEntries.Count -ne 1) { $validationErrors.Add("Expected one Process Map subarea; found $($processMapEntries.Count).") }
if ($processMapEntries.Count -eq 1 -and $processMapEntries[0].ParentNode.GetAttribute('Id') -ne $effectiveGroupId) { $validationErrors.Add("Process Map is not in the expected '$effectiveGroupId' group.") }
if ($processMapEntries.Count -eq 1 -and $processMapEntries[0].SelectSingleNode("./Titles/Title[@LCID='1033']").GetAttribute('Title') -ne "Earnings Fraud Process Map") { $validationErrors.Add("Process Map navigation title is incorrect.") }

Write-Host ""
Write-Host "=== App Navigation Validation ===" -ForegroundColor Cyan
Write-Host "  Original subareas preserved: $($originalSignatures.Count - $missingOriginals.Count)/$($originalSignatures.Count)"
Write-Host "  Published subareas:          $($publishedSignatures.Count)"
Write-Host "  Process Map entries:         $($processMapEntries.Count)"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "App navigation validation failed with $($validationErrors.Count) error(s)."
}
Write-Host "  Validation: PASS" -ForegroundColor Green