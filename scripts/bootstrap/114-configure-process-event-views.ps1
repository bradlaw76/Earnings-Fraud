<#
.SYNOPSIS
    Adds the primary Process Mining fields to the Process Event system views.

.DESCRIPTION
    Patches the existing Active Process Events, Inactive Process Events, and
    Process Event Associated View in place, preserving their IDs, query types,
    and state filters. Publishes the Process Event table and validates the exact
    column order and active/inactive predicates.

.EXAMPLE
    pwsh ./scripts/bootstrap/114-configure-process-event-views.ps1 -WhatIf
    pwsh ./scripts/bootstrap/114-configure-process-event-views.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [switch]$WhatIf,
    [switch]$PublishOnly
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
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 20)
}

function Publish-ProcessEventTable {
    $maximumAttempts = 6
    for ($attempt = 1; $attempt -le $maximumAttempts; $attempt++) {
        try {
            Invoke-Dv Post "PublishXml" @{ ParameterXml = "<importexportxml><entities><entity>earnint_processevent</entity></entities></importexportxml>" } | Out-Null
            return
        } catch {
            $isCustomizationLock = $_.ErrorDetails.Message -match "0x80071151|another \[EntityCustomization\]"
            if (-not $isCustomizationLock -or $attempt -eq $maximumAttempts) { throw }

            $delaySeconds = 5 * $attempt
            Write-Host "  Publish locked; retrying in $delaySeconds seconds (attempt $($attempt + 1)/$maximumAttempts)..." -ForegroundColor Yellow
            [System.Threading.Tasks.Task]::Delay([TimeSpan]::FromSeconds($delaySeconds)).GetAwaiter().GetResult()
        }
    }
}

$columns = @(
    [pscustomobject]@{ Name = "earnint_processevent_name"; Width = 300 },
    [pscustomobject]@{ Name = "earnint_caseid_processevent"; Width = 180 },
    [pscustomobject]@{ Name = "earnint_activityname"; Width = 220 },
    [pscustomobject]@{ Name = "earnint_starttimestamp"; Width = 150 },
    [pscustomobject]@{ Name = "earnint_endtimestamp"; Width = 150 },
    [pscustomobject]@{ Name = "earnint_resource"; Width = 180 },
    [pscustomobject]@{ Name = "earnint_resourcetype"; Width = 140 },
    [pscustomobject]@{ Name = "earnint_queueorteam"; Width = 190 },
    [pscustomobject]@{ Name = "earnint_risklevel"; Width = 120 },
    [pscustomobject]@{ Name = "earnint_evidencestatus"; Width = 150 },
    [pscustomobject]@{ Name = "earnint_finaldisposition"; Width = 190 },
    [pscustomobject]@{ Name = "earnint_issyntheticdemoevent"; Width = 150 }
)
$expectedColumns = @($columns.Name)
$viewDefinitions = @(
    [pscustomobject]@{ Name = "Active Process Events"; QueryType = 0; StateCode = 0 },
    [pscustomobject]@{ Name = "Inactive Process Events"; QueryType = 0; StateCode = 1 },
    [pscustomobject]@{ Name = "Process Event Associated View"; QueryType = 2; StateCode = 0 }
)

$attributeXml = ($expectedColumns | ForEach-Object { "    <attribute name=`"$_`" />" }) -join "`n"
$cellXml = ($columns | ForEach-Object { "    <cell name=`"$($_.Name)`" width=`"$($_.Width)`" />" }) -join "`n"

function New-FetchXml([int]$StateCode) {
    return @"
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
  <entity name="earnint_processevent">
$attributeXml
    <order attribute="earnint_starttimestamp" descending="true" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="$StateCode" />
    </filter>
  </entity>
</fetch>
"@
}

function New-LayoutXml {
    return @"
<grid name="resultset" object="1" jump="earnint_processevent_name" select="1" icon="1" preview="1">
  <row name="result" id="earnint_processeventid">
$cellXml
  </row>
</grid>
"@
}

$escapedNames = $viewDefinitions.Name | ForEach-Object { "name eq '$($_.Replace("'", "''"))'" }
$filter = [uri]::EscapeDataString("returnedtypecode eq 'earnint_processevent' and (" + ($escapedNames -join " or ") + ")")
$views = @((Invoke-Dv Get "savedqueries?`$select=savedqueryid,name,querytype,fetchxml,layoutxml&`$filter=$filter" $null).value)

Write-Host ""
Write-Host "=== Configure Process Event Views ===" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentUrl"
Write-Host "Columns:     $($expectedColumns.Count)"
Write-Host "Mode:        $(if ($PublishOnly) { 'Publish and validate only' } else { 'Patch, publish, and validate' })"

foreach ($definition in $viewDefinitions) {
    $matches = @($views | Where-Object name -eq $definition.Name)
    if ($matches.Count -ne 1) { throw "Expected one '$($definition.Name)' system view; found $($matches.Count)." }
    if ([int]$matches[0].querytype -ne $definition.QueryType) {
        throw "Expected '$($definition.Name)' query type $($definition.QueryType); found $($matches[0].querytype)."
    }
    Write-Host "  $($definition.Name): $($matches[0].savedqueryid) (querytype=$($definition.QueryType); statecode=$($definition.StateCode))"
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "Column order: $($expectedColumns -join ', ')"
    Write-Host ""
    Write-Host "=== Preview Complete: No Views Changed ===" -ForegroundColor Green
    exit 0
}

$layoutXml = New-LayoutXml
if (-not $PublishOnly) {
    foreach ($definition in $viewDefinitions) {
        $view = @($views | Where-Object name -eq $definition.Name)[0]
        Invoke-Dv Patch "savedqueries($($view.savedqueryid))" @{
            fetchxml = New-FetchXml $definition.StateCode
            layoutxml = $layoutXml
        } | Out-Null
    }
}

Publish-ProcessEventTable

$publishedViews = @((Invoke-Dv Get "savedqueries?`$select=savedqueryid,name,querytype,fetchxml,layoutxml&`$filter=$filter" $null).value)
$validationErrors = [System.Collections.Generic.List[string]]::new()

Write-Host ""
Write-Host "=== Process Event View Validation ===" -ForegroundColor Cyan
foreach ($definition in $viewDefinitions) {
    $view = @($publishedViews | Where-Object name -eq $definition.Name)
    if ($view.Count -ne 1) {
        $validationErrors.Add("Could not reload exactly one '$($definition.Name)' view.")
        continue
    }

    [xml]$fetchXml = $view[0].fetchxml
    [xml]$publishedLayout = $view[0].layoutxml
    $actualAttributes = @($fetchXml.SelectNodes("/fetch/entity/attribute") | ForEach-Object { $_.name })
    $actualColumns = @($publishedLayout.SelectNodes("/grid/row/cell") | ForEach-Object { $_.name })
    $stateConditions = @($fetchXml.SelectNodes("/fetch/entity/filter/condition[@attribute='statecode' and @operator='eq']"))
    $stateValue = if ($stateConditions.Count -eq 1) { [int]$stateConditions[0].value } else { -1 }

    if (($actualAttributes -join "|") -ne ($expectedColumns -join "|")) {
        $validationErrors.Add("$($definition.Name) FetchXML attributes do not match the approved column order.")
    }
    if (($actualColumns -join "|") -ne ($expectedColumns -join "|")) {
        $validationErrors.Add("$($definition.Name) layout columns do not match the approved column order.")
    }
    if (@($actualColumns | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
        $validationErrors.Add("$($definition.Name) contains duplicate columns.")
    }
    if ($stateValue -ne $definition.StateCode) {
        $validationErrors.Add("$($definition.Name) expected statecode $($definition.StateCode); found $stateValue.")
    }
    if ([int]$view[0].querytype -ne $definition.QueryType) {
        $validationErrors.Add("$($definition.Name) expected query type $($definition.QueryType); found $($view[0].querytype).")
    }

    Write-Host "  $($definition.Name): $($actualColumns.Count) columns; querytype=$($view[0].querytype); statecode=$stateValue"
}

if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Process Event view validation failed with $($validationErrors.Count) error(s)."
}

Write-Host "  Validation: PASS" -ForegroundColor Green