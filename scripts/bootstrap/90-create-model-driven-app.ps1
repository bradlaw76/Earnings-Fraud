<#
.SYNOPSIS
    Creates or configures a model-driven app and adds forms/views for target tables.

.DESCRIPTION
    Uses pac model create for app creation (or reuses an existing app by name), then
    calls AddAppComponents to add system forms and saved queries for configured tables.
    Web resources are included indirectly via forms that host them.
#>

param(
    [string]$AppName = "Earnings Integrity V2 Demo App",
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AppId = "",
    [switch]$CreateIfMissing,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
        $SolutionUniqueName = $global:DV_SOLUTION_NAME
    }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Environment URL is required. Run 10-auth-connect.ps1 first or pass -EnvironmentUrl."
}

if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
    $SolutionUniqueName = "Default"
}

function Get-AccessToken([string]$ResourceUrl) {
    $token = (& az account get-access-token --resource $ResourceUrl --query accessToken -o tsv 2>$null)
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Unable to get Dataverse access token from Azure CLI."
    }
    return $token.Trim()
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Token
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

function Get-AppIdByName {
    param(
        [string]$Name,
        [string]$Token
    )

    $escaped = $Name.Replace("'", "''")
    $apps = (Invoke-Dv -Method "Get" -Path "appmodules?`$select=appmoduleid,name,createdon&`$filter=name eq '$escaped'&`$orderby=createdon desc" -Token $Token).value
    if ($apps.Count -eq 0) {
        return ""
    }

    return "$($apps[0].appmoduleid)"
}

function Create-App {
    param([string]$Name)

    Write-Host "Creating model-driven app '$Name' in solution '$SolutionUniqueName'..." -ForegroundColor Cyan
    $out = (& pac model create --name $Name --description "Model-driven demo app for earnings integrity" --solution $SolutionUniqueName --publish 2>&1)
    $text = ($out | Out-String)
    $match = [regex]::Match($text, "App ID:\s*([0-9a-fA-F-]{36})")
    if (-not $match.Success) {
        throw "pac model create did not return an App ID. Output: $text"
    }

    return $match.Groups[1].Value
}

function Add-AppComponentsInBatches {
    param(
        [string]$TargetAppId,
        [object[]]$Components,
        [string]$Token
    )

    if ($Components.Count -eq 0) {
        Write-Host "No components resolved to add." -ForegroundColor Yellow
        return
    }

    $batchSize = 10
    for ($i = 0; $i -lt $Components.Count; $i += $batchSize) {
        $take = [Math]::Min($batchSize, $Components.Count - $i)
        $batch = @($Components[$i..($i + $take - 1)])
        $body = @{
            AppId = $TargetAppId
            Components = $batch
        }

        Invoke-Dv -Method "Post" -Path "AddAppComponents" -Body $body -Token $Token | Out-Null
        Write-Host "  Added batch: $($i + 1)-$($i + $take)" -ForegroundColor DarkGray
    }
}

function Set-AppSitemapNavigation {
        param(
                [string]$TargetAppId,
                [string]$Token
        )

        $app = Invoke-Dv -Method "Get" -Path "appmodules($TargetAppId)?`$select=appmoduleidunique,uniquename" -Token $Token
        $appUniqueId = $app.appmoduleidunique
        $appUniqueName = $app.uniquename

        $siteComponent = (Invoke-Dv -Method "Get" -Path "appmodulecomponents?`$select=objectid,componenttype,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $appUniqueId and componenttype eq 62&`$top=1" -Token $Token).value | Select-Object -First 1
        if ($null -eq $siteComponent) {
                Write-Host "No sitemap component found for app; skipping nav patch." -ForegroundColor Yellow
                return
        }

        $sitemapId = $siteComponent.objectid
        $sitemapXml = @"
<SiteMap IntroducedVersion="7.0.0.0">
    <Area Id="area_$appUniqueName" ShowGroups="true" ResourceId="SitemapDesigner.NewArea" IntroducedVersion="7.0.0.0">
        <Titles>
            <Title Title="Main" LCID="1033" />
        </Titles>
        <Group Id="group_$appUniqueName" IsProfile="false" ResourceId="SitemapDesigner.NewGroup" IntroducedVersion="7.0.0.0">
            <Titles>
                <Title Title="Fraud Case Review" LCID="1033" />
            </Titles>
            <SubArea Id="subarea_incident" Entity="incident" PassParams="1" />
            <SubArea Id="subarea_contact" Entity="contact" PassParams="1" />
            <SubArea Id="subarea_earnfrd2_case" Entity="earnfrd2_case" PassParams="1" />
            <SubArea Id="subarea_earnfrd2_discrepancy" Entity="earnfrd2_discrepancy" PassParams="1" />
            <SubArea Id="subarea_earnfrd2_finding" Entity="earnfrd2_finding" PassParams="1" />
            <SubArea Id="subarea_earnint_earningsdiscrepancy" Entity="earnint_earningsdiscrepancy" PassParams="1" />
            <SubArea Id="subarea_earnint_evidenceitem" Entity="earnint_evidenceitem" PassParams="1" />
            <SubArea Id="subarea_earnint_investigationfinding" Entity="earnint_investigationfinding" PassParams="1" />
        </Group>
    </Area>
</SiteMap>
"@

        Invoke-Dv -Method "Patch" -Path "sitemaps($sitemapId)" -Body @{ sitemapxml = $sitemapXml } -Token $Token | Out-Null
        Write-Host "Updated sitemap navigation for app." -ForegroundColor Green
}

$token = Get-AccessToken -ResourceUrl $EnvironmentUrl

if ([string]::IsNullOrWhiteSpace($AppId)) {
    $AppId = Get-AppIdByName -Name $AppName -Token $token
}

if ([string]::IsNullOrWhiteSpace($AppId)) {
    if (-not $CreateIfMissing) {
        throw "App '$AppName' not found. Re-run with -CreateIfMissing to create it."
    }
    $AppId = Create-App -Name $AppName
}

Write-Host "Using app id: $AppId" -ForegroundColor Green

$targetEntities = @(
    "incident",
    "contact",
    "earnfrd2_case",
    "earnfrd2_discrepancy",
    "earnfrd2_finding",
    "earnint_earningsdiscrepancy",
    "earnint_evidenceitem",
    "earnint_investigationfinding"
)

$allForms = (Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=type eq 2" -Token $token).value
$allViews = (Invoke-Dv -Method "Get" -Path "savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype&`$filter=querytype eq 0" -Token $token).value

$preferredForms = @{
    "incident" = @("Case", "Information")
    "contact" = @("Information")
    "earnfrd2_case" = @("Starter Main Form", "Information")
    "earnfrd2_discrepancy" = @("Starter Main Form", "Information")
    "earnfrd2_finding" = @("Starter Main Form", "Information")
    "earnint_earningsdiscrepancy" = @("Starter Main Form", "Information")
    "earnint_evidenceitem" = @("Starter Main Form", "Information")
    "earnint_investigationfinding" = @("Starter Main Form", "Information")
}

$components = New-Object System.Collections.Generic.List[object]
$seen = New-Object System.Collections.Generic.HashSet[string]

$preferredViews = @{
    "incident" = @("Active Cases", "My Active Cases", "Inactive Cases")
    "contact" = @("Active Contacts", "My Active Contacts", "Inactive Contacts")
}

foreach ($entity in $targetEntities) {
    $formNames = if ($preferredForms.ContainsKey($entity)) { $preferredForms[$entity] } else { @("Information") }
    foreach ($formName in $formNames) {
        $f = $allForms | Where-Object { $_.objecttypecode -eq $entity -and $_.name -eq $formName } | Select-Object -First 1
        if ($null -ne $f) {
            $key = "form:$($f.formid)"
            if ($seen.Add($key)) {
                $components.Add(@{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $f.formid }) | Out-Null
            }
        }
    }

    if ($preferredViews.ContainsKey($entity)) {
        $entityViews = foreach ($vn in $preferredViews[$entity]) {
            $allViews | Where-Object { $_.returnedtypecode -eq $entity -and $_.name -eq $vn } | Select-Object -First 1
        }
        $entityViews = @($entityViews | Where-Object { $null -ne $_ })
    }
    else {
        $entityViews = $allViews | Where-Object {
            $_.returnedtypecode -eq $entity -and (
                $_.name -like "Active*" -or $_.name -like "My Active*" -or $_.name -like "Inactive*"
            )
        } | Select-Object -First 3
    }

    foreach ($v in $entityViews) {
        $key = "view:$($v.savedqueryid)"
        if ($seen.Add($key)) {
            $components.Add(@{ "@odata.type" = "Microsoft.Dynamics.CRM.savedquery"; savedqueryid = $v.savedqueryid }) | Out-Null
        }
    }
}

Write-Host "Resolved components to add: $($components.Count)" -ForegroundColor Cyan
$componentArray = $components.ToArray()
Add-AppComponentsInBatches -TargetAppId $AppId -Components $componentArray -Token $token
Set-AppSitemapNavigation -TargetAppId $AppId -Token $token

if ($Publish) {
    Write-Host "Publishing app..." -ForegroundColor Cyan
    Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body @{} -Token $token | Out-Null
}

$app = Invoke-Dv -Method "Get" -Path "appmodules($AppId)?`$select=name,uniquename,appmoduleid" -Token $token
Write-Host ""
Write-Host "App ready:" -ForegroundColor Green
Write-Host "  Name:       $($app.name)"
Write-Host "  UniqueName: $($app.uniquename)"
Write-Host "  AppId:      $($app.appmoduleid)"
Write-Host ""
Write-Host "Note: web resources are not directly addable to app components; they are surfaced through included forms that host them." -ForegroundColor Yellow
