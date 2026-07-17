<#
.SYNOPSIS
    Creates a starter Main form and Active view for every custom table that
    does not already have one. Publishes all customizations when done.

.PARAMETER EnvironmentUrl   Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken      Defaults to $env:DV_TOKEN.
.PARAMETER PublisherPrefix  Defaults to $env:DV_PUBLISHER_PREFIX.

.EXAMPLE
    pwsh ./scripts/bootstrap/60-build-forms-views.ps1
#>

param(
    [string]$EnvironmentUrl  = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken     = $env:DV_TOKEN,
  [string]$PublisherPrefix = $env:DV_PUBLISHER_PREFIX,
  [string]$PayloadsFolder  = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl  = $global:DV_ENVIRONMENT_URL
    $AccessToken     = $global:DV_TOKEN
    $PublisherPrefix = $PublisherPrefix -ne "" ? $PublisherPrefix : $global:DV_PUBLISHER_PREFIX
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red; exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($PayloadsFolder)) {
  $PayloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Get-FriendlyLabel([string]$LogicalName, [string]$PrefixLower) {
  $label = $LogicalName
  if ($label -like "$($PrefixLower)_*") {
    $label = $label.Substring($PrefixLower.Length + 1)
  }
  $label = ($label -replace "_", " ").Trim()
  if ([string]::IsNullOrWhiteSpace($label)) { return $LogicalName }
  $ti = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo
  return $ti.ToTitleCase($label)
}

function Get-FormFieldMap([string]$Folder, [string]$PrefixLower) {
  $fieldMap = @{}
  $payloads = @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue)

  foreach ($p in $payloads) {
    $doc = Get-Content $p.FullName -Raw | ConvertFrom-Json
    $tableLogical = "$($doc.TableLogicalName)".ToLower()
    if ([string]::IsNullOrWhiteSpace($tableLogical)) { continue }

    if (-not $fieldMap.ContainsKey($tableLogical)) {
      $fieldMap[$tableLogical] = New-Object System.Collections.Generic.List[object]
    }

    foreach ($col in $doc.Columns) {
      $logical = "$($col.SchemaName)".ToLower()
      if ([string]::IsNullOrWhiteSpace($logical)) { continue }
      if ($logical -notlike "$($PrefixLower)_*") { continue }

      $displayLabel = ""
      if ($null -ne $col.DisplayName -and $null -ne $col.DisplayName.LocalizedLabels) {
        $labelNode = @($col.DisplayName.LocalizedLabels | Where-Object { $_.LanguageCode -eq 1033 } | Select-Object -First 1)
        if ($labelNode.Count -eq 0) {
          $labelNode = @($col.DisplayName.LocalizedLabels | Select-Object -First 1)
        }
        if ($labelNode.Count -gt 0) {
          $displayLabel = "$($labelNode[0].Label)"
        }
      }
      if ([string]::IsNullOrWhiteSpace($displayLabel)) {
        $displayLabel = Get-FriendlyLabel -LogicalName $logical -PrefixLower $PrefixLower
      }

      $alreadyExists = @($fieldMap[$tableLogical] | Where-Object { $_.LogicalName -eq $logical }).Count -gt 0
      if (-not $alreadyExists) {
        [void]$fieldMap[$tableLogical].Add([pscustomobject]@{
          LogicalName = $logical
          Label = $displayLabel
        })
      }
    }
  }

  return $fieldMap
}

function New-StarterFormXml([string]$PrimaryField, [object[]]$Fields, [string]$PrefixLower) {
  $allFields = New-Object System.Collections.Generic.List[object]
  $seen = @{}

  if (-not [string]::IsNullOrWhiteSpace($PrimaryField)) {
    $primaryLogical = $PrimaryField.ToLower()
    [void]$allFields.Add([pscustomobject]@{
      LogicalName = $primaryLogical
      Label = Get-FriendlyLabel -LogicalName $primaryLogical -PrefixLower $PrefixLower
    })
    $seen[$primaryLogical] = $true
  }

  foreach ($f in $Fields) {
    $logical = "$($f.LogicalName)".ToLower()
    if ([string]::IsNullOrWhiteSpace($logical)) { continue }
    if (-not $seen.ContainsKey($logical)) {
      [void]$allFields.Add([pscustomobject]@{
        LogicalName = $logical
        Label = "$($f.Label)"
      })
      $seen[$logical] = $true
    }
  }

  $rows = New-Object System.Text.StringBuilder
  for ($i = 0; $i -lt $allFields.Count; $i += 2) {
    [void]$rows.AppendLine("                <row>")

    for ($j = 0; $j -lt 2; $j++) {
      $index = $i + $j
      if ($index -ge $allFields.Count) { continue }

      $fieldLogical = "$($allFields[$index].LogicalName)"
      $fieldLabel = "$($allFields[$index].Label)"
      $cellId = [guid]::NewGuid().ToString()
      # Standard Dataverse textbox control type; works for starter layout generation.
      $classId = "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}"

      [void]$rows.AppendLine("                  <cell id=`"{$cellId}`" showlabel=`"true`" locklevel=`"0`">")
      [void]$rows.AppendLine("                    <labels><label description=`"$fieldLabel`" languagecode=`"1033`"/></labels>")
      [void]$rows.AppendLine("                    <control id=`"$fieldLogical`" classid=`"$classId`" datafieldname=`"$fieldLogical`" disabled=`"false`"/>")
      [void]$rows.AppendLine("                  </cell>")
    }

    [void]$rows.AppendLine("                </row>")
  }

    return @"
<form>
  <tabs>
    <tab name="general" id="{00000000-0000-0000-0000-000000000001}" showlabel="true" expanded="true">
      <labels><label description="General" languagecode="1033"/></labels>
      <columns>
        <column width="100%">
          <sections>
            <section name="general_section" showlabel="false" showbar="false">
              <labels><label description="General" languagecode="1033"/></labels>
              <rows>
$($rows.ToString())
              </rows>
            </section>
          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
"@
}

function New-StarterViewFetchXml([string]$TableLogical, [string]$PrimaryField) {
    return @"
<fetch version="1.0" output-format="xml-platform" mapping="logical" distinct="false">
  <entity name="$TableLogical">
    <attribute name="$PrimaryField" />
    <attribute name="createdon" />
    <attribute name="modifiedon" />
    <order attribute="$PrimaryField" descending="false" />
    <filter type="and">
      <condition attribute="statecode" operator="eq" value="0" />
    </filter>
  </entity>
</fetch>
"@
}

function New-StarterViewLayoutXml([string]$PrimaryField) {
    return @"
<grid name="resultset" object="1" jump="$PrimaryField" select="1" icon="1" preview="1">
  <row name="result" id="$($PrimaryField)id">
    <cell name="$PrimaryField" width="300" />
    <cell name="createdon" width="150" />
    <cell name="modifiedon" width="150" />
  </row>
</grid>
"@
}

Write-Host ""
Write-Host "=== Build Forms and Views ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Prefix:      $PublisherPrefix"
Write-Host "  Payloads:    $PayloadsFolder"
Write-Host ""

$publisherLogicalPrefix = $PublisherPrefix.ToLower()
$tableFieldMap = Get-FormFieldMap -Folder $PayloadsFolder -PrefixLower $publisherLogicalPrefix
$tables = @((Invoke-Dv "Get" "EntityDefinitions?`$select=LogicalName,PrimaryNameAttribute,MetadataId&`$filter=IsCustomEntity eq true").value |
  Where-Object { $_.LogicalName -like "$($publisherLogicalPrefix)_*" })

Write-Host "  Custom tables found: $($tables.Count)"
Write-Host ""

$formsCreated = 0; $formsUpdated = 0; $viewsCreated = 0; $failed = 0

foreach ($t in $tables) {
    $logical  = $t.LogicalName
    $primary  = $t.PrimaryNameAttribute
    Write-Host "  $logical" -ForegroundColor Cyan

    # ── Form ──────────────────────────────────────────────────────────────
    $existingForms = @((Invoke-Dv "Get" "systemforms?`$select=formid,name,type&`$filter=objecttypecode eq '$logical' and type eq 2").value)
    $mainForms = @($existingForms | Where-Object { $_.type -eq 2 -and $_.name -like "*Main*" })
    $starterMain = @($mainForms | Where-Object { $_.name -eq "Starter Main Form" } | Select-Object -First 1)

    $fieldList = @()
    $logicalKey = [string]$logical
    if ($tableFieldMap.ContainsKey($logicalKey)) {
      $fieldList = @($tableFieldMap[$logicalKey] | ForEach-Object { $_ })
    }

    if ($starterMain.Count -gt 0) {
        try {
        $formXml = New-StarterFormXml $primary $fieldList $publisherLogicalPrefix
        $patchBody = @{ "formxml" = $formXml } | ConvertTo-Json -Compress -Depth 10
            Invoke-Dv "Patch" "systemforms($($starterMain[0].formid))" $patchBody | Out-Null
        Write-Host "    Form (starter updated with payload fields)" -ForegroundColor Green
        $formsUpdated++
        } catch {
        Write-Host "    Form (FAILED update: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    } elseif ($mainForms.Count -gt 0) {
      Write-Host "    Form (custom main exists — skipped)" -ForegroundColor DarkGray
    } else {
      try {
        $formXml = New-StarterFormXml $primary $fieldList $publisherLogicalPrefix
        $formBody = @{
          "name"            = "Starter Main Form"
          "objecttypecode"  = $logical
          "type"            = 2
          "formxml"         = $formXml
        } | ConvertTo-Json -Compress -Depth 10
        Invoke-Dv "Post" "systemforms" $formBody | Out-Null
        Write-Host "    Form (created with payload fields)" -ForegroundColor Green
        $formsCreated++
      } catch {
        Write-Host "    Form (FAILED create: $($_.Exception.Message))" -ForegroundColor Red
        $failed++
      }
    }

    # ── View ──────────────────────────────────────────────────────────────
    $existingViews = @((Invoke-Dv "Get" "savedqueries?`$select=name&`$filter=returnedtypecode eq '$logical' and querytype eq 0").value)
    $hasActive = $existingViews | Where-Object { $_.name -like "Active*" }
    if ($hasActive) {
        Write-Host "    View  (exists — skipped)" -ForegroundColor DarkGray
    } else {
        try {
            $fetchXml  = New-StarterViewFetchXml $logical $primary
            $layoutXml = New-StarterViewLayoutXml $primary
            $viewBody = @{
                "name"               = "Active Records"
                "returnedtypecode"   = $logical
                "querytype"          = 0
                "fetchxml"           = $fetchXml
                "layoutxml"          = $layoutXml
            } | ConvertTo-Json -Compress -Depth 10
            Invoke-Dv "Post" "savedqueries" $viewBody | Out-Null
            Write-Host "    View  (created)" -ForegroundColor Green
            $viewsCreated++
        } catch {
            Write-Host "    View  (FAILED: $($_.Exception.Message))" -ForegroundColor Red
            $failed++
        }
    }
}

# ── Publish all ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Publishing all customizations..." -NoNewline
try {
    Invoke-Dv "Post" "PublishAllXml" "{}" | Out-Null
    Write-Host " done." -ForegroundColor Green
} catch {
    Write-Host " WARNING: publish failed. Publish manually in maker portal. $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Forms created: $formsCreated  Forms updated: $formsUpdated  Views created: $viewsCreated  Failures: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Build complete. Verify in Power Apps Maker at:"
Write-Host "  https://make.powerapps.com"

