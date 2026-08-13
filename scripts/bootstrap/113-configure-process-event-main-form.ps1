<#
.SYNOPSIS
    Adds every user-facing Process Event field to the Information main form.

.DESCRIPTION
    Rebuilds the existing earnint_processevent Information main form in place,
    publishes customizations, and validates the exact control set against live
    Process Event records. Safe to rerun because the form XML is deterministic.

.EXAMPLE
    pwsh ./scripts/bootstrap/113-configure-process-event-main-form.ps1 -WhatIf
    pwsh ./scripts/bootstrap/113-configure-process-event-main-form.ps1
#>

[CmdletBinding()]
param(
    [string]$EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com",
    [string]$FormName = "Information",
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

function Escape-Xml([string]$Value) {
    return [System.Security.SecurityElement]::Escape($Value)
}

function Get-ControlClassId([string]$Kind) {
    switch ($Kind) {
        "Lookup" { return "{270BD3DB-D9AF-4782-9025-509E298DEC0A}" }
        "DateTime" { return "{5B773807-9FB2-42DB-97C3-7A91EFF8ADFF}" }
        "Decimal" { return "{C3EFE0C3-0EC6-42be-8349-CBD9079DFD8E}" }
        "Boolean" { return "{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}" }
        "Choice" { return "{3EF39988-22BB-4F0B-BBBE-64B5A3748AEE}" }
        default { return "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}" }
    }
}

function New-SectionXml {
    param(
        [string]$Name,
        [string]$Label,
        [object[]]$Fields
    )

    $rows = [System.Text.StringBuilder]::new()
    for ($index = 0; $index -lt $Fields.Count; $index += 2) {
        [void]$rows.AppendLine("                <row>")
        for ($column = 0; $column -lt 2; $column++) {
            $fieldIndex = $index + $column
            if ($fieldIndex -ge $Fields.Count) { continue }
            $field = $Fields[$fieldIndex]
            $logicalName = Escape-Xml "$($field.Name)"
            $fieldLabel = Escape-Xml "$($field.Label)"
            $classId = Get-ControlClassId "$($field.Kind)"
            $disabled = if ($field.ReadOnly) { "true" } else { "false" }
            $cellId = [guid]::NewGuid().ToString()
            [void]$rows.AppendLine("                  <cell id=`"{$cellId}`" showlabel=`"true`" locklevel=`"0`">")
            [void]$rows.AppendLine("                    <labels><label description=`"$fieldLabel`" languagecode=`"1033`" /></labels>")
            [void]$rows.AppendLine("                    <control id=`"$logicalName`" classid=`"$classId`" datafieldname=`"$logicalName`" disabled=`"$disabled`" />")
            [void]$rows.AppendLine("                  </cell>")
        }
        [void]$rows.AppendLine("                </row>")
    }

    $sectionId = [guid]::NewGuid().ToString()
    return @"
            <section name="$Name" id="{$sectionId}" showlabel="true" showbar="true" columns="2">
              <labels><label description="$(Escape-Xml $Label)" languagecode="1033" /></labels>
              <rows>
$($rows.ToString())              </rows>
            </section>
"@
}

function New-Field([string]$Name, [string]$Label, [string]$Kind = "Text", [bool]$ReadOnly = $false) {
    return [pscustomobject]@{ Name = $Name; Label = $Label; Kind = $Kind; ReadOnly = $ReadOnly }
}

$sections = @(
    [pscustomobject]@{
        Name = "event_details"
        Label = "Event Details"
        Fields = @(
            (New-Field "earnint_processevent_name" "Event Key"),
            (New-Field "earnint_caseid_processevent" "Case" "Lookup"),
            (New-Field "earnint_activityname" "Activity Name"),
            (New-Field "earnint_risklevel" "Risk Level"),
            (New-Field "earnint_discrepancyamount" "Discrepancy Amount" "Decimal"),
            (New-Field "statecode" "Status" "Choice"),
            (New-Field "statuscode" "Status Reason" "Choice")
        )
    },
    [pscustomobject]@{
        Name = "timing_transition"
        Label = "Timing and Transition"
        Fields = @(
            (New-Field "earnint_starttimestamp" "Start Timestamp" "DateTime"),
            (New-Field "earnint_endtimestamp" "End Timestamp" "DateTime"),
            (New-Field "earnint_previousstatus" "Previous Status"),
            (New-Field "earnint_newstatus" "New Status"),
            (New-Field "earnint_reassignmentindicator" "Reassignment Indicator" "Boolean"),
            (New-Field "earnint_reworkindicator" "Rework Indicator" "Boolean")
        )
    },
    [pscustomobject]@{
        Name = "resource_routing"
        Label = "Resource and Routing"
        Fields = @(
            (New-Field "earnint_resource" "Resource"),
            (New-Field "earnint_resourcetype" "Resource Type"),
            (New-Field "earnint_queueorteam" "Queue or Team"),
            (New-Field "ownerid" "Owner" "Lookup")
        )
    },
    [pscustomobject]@{
        Name = "evidence_disposition"
        Label = "Evidence and Disposition"
        Fields = @(
            (New-Field "earnint_evidencetype" "Evidence Type"),
            (New-Field "earnint_evidencestatus" "Evidence Status"),
            (New-Field "earnint_findingtype" "Finding Type"),
            (New-Field "earnint_recommendeddisposition" "Recommended Disposition"),
            (New-Field "earnint_finaldisposition" "Final Disposition"),
            (New-Field "earnint_supervisordecision" "Supervisor Decision")
        )
    },
    [pscustomobject]@{
        Name = "lineage_audit"
        Label = "Lineage and Audit"
        Fields = @(
            (New-Field "earnint_sourcesystem" "Source System"),
            (New-Field "earnint_sourcerecordid" "Source Record ID"),
            (New-Field "earnint_issyntheticdemoevent" "Is Synthetic Demo Event" "Boolean"),
            (New-Field "createdon" "Created On" "DateTime" $true),
            (New-Field "createdby" "Created By" "Lookup" $true),
            (New-Field "modifiedon" "Modified On" "DateTime" $true),
            (New-Field "modifiedby" "Modified By" "Lookup" $true)
        )
    }
)

$expectedFields = @($sections | ForEach-Object { $_.Fields } | ForEach-Object { $_.Name })
if (@($expectedFields | Sort-Object -Unique).Count -ne $expectedFields.Count) {
    throw "The form definition contains duplicate field controls."
}

$escapedFormName = $FormName.Replace("'", "''")
$forms = @((Invoke-Dv Get "systemforms?`$select=formid,name,formxml,type&`$filter=objecttypecode eq 'earnint_processevent' and type eq 2 and name eq '$escapedFormName'" $null).value)
if ($forms.Count -ne 1) { throw "Expected one '$FormName' main form for earnint_processevent; found $($forms.Count)." }
$form = $forms[0]

$sectionXml = [System.Text.StringBuilder]::new()
foreach ($section in $sections) {
    [void]$sectionXml.Append((New-SectionXml -Name $section.Name -Label $section.Label -Fields $section.Fields))
}
$tabId = [guid]::NewGuid().ToString()
$formXml = @"
<form>
  <tabs>
    <tab name="general" id="{$tabId}" showlabel="true" expanded="true">
      <labels><label description="General" languagecode="1033" /></labels>
      <columns>
        <column width="100%">
          <sections>
$($sectionXml.ToString())          </sections>
        </column>
      </columns>
    </tab>
  </tabs>
</form>
"@

Write-Host ""
Write-Host "=== Configure Process Event Main Form ===" -ForegroundColor Cyan
Write-Host "Environment: $EnvironmentUrl"
Write-Host "Form:        $FormName ($($form.formid))"
Write-Host "Controls:    $($expectedFields.Count)"

if ($WhatIf) {
    foreach ($section in $sections) {
        Write-Host ("  {0,-28}: {1}" -f $section.Label, (($section.Fields | ForEach-Object Label) -join ", "))
    }
    Write-Host ""
    Write-Host "=== Preview Complete: No Form Changed ===" -ForegroundColor Green
    exit 0
}

Invoke-Dv Patch "systemforms($($form.formid))" @{ formxml = $formXml } | Out-Null
Invoke-Dv Post "PublishXml" @{ ParameterXml = "<importexportxml><entities><entity>earnint_processevent</entity></entities></importexportxml>" } | Out-Null

$published = @((Invoke-Dv Get "systemforms?`$select=formid,name,formxml,type&`$filter=formid eq $($form.formid)" $null).value | Select-Object -First 1)
if ($published.Count -ne 1) { throw "Could not reload the published Process Event form." }
[xml]$publishedXml = $published[0].formxml
$actualFields = @($publishedXml.SelectNodes("//control[@datafieldname]") | ForEach-Object { $_.datafieldname })
$missingFields = @($expectedFields | Where-Object { $_ -notin $actualFields })
$duplicateFields = @($actualFields | Group-Object | Where-Object Count -gt 1)
$actualSections = @($publishedXml.SelectNodes("//section") | ForEach-Object { $_.name })

$records = @((Invoke-Dv Get "earnint_processevents?`$select=earnint_processeventid,earnint_processevent_name,earnint_activityname,earnint_starttimestamp,earnint_resource,earnint_resourcetype,earnint_sourcesystem,_earnint_caseid_processevent_value&`$filter=earnint_sourcesystem eq 'SYNTHETIC_PROCESS_MINING_DEMO'&`$top=5000" $null).value)
$sample = @($records | Where-Object { $_.earnint_processevent_name -like "EIR-PM-2026-MEDIUM*" } | Select-Object -First 1)
$validationErrors = [System.Collections.Generic.List[string]]::new()
if ($actualFields.Count -ne $expectedFields.Count) { $validationErrors.Add("Expected $($expectedFields.Count) controls; found $($actualFields.Count).") }
if ($missingFields.Count -gt 0) { $validationErrors.Add("Missing controls: $($missingFields -join ', ').") }
if ($duplicateFields.Count -gt 0) { $validationErrors.Add("Duplicate field controls exist.") }
foreach ($section in $sections) {
    if ($section.Name -notin $actualSections) { $validationErrors.Add("Missing section '$($section.Name)'.") }
}
if ($records.Count -ne 128) { $validationErrors.Add("Expected 128 synthetic Process Event records; found $($records.Count).") }
if ($sample.Count -ne 1 -or -not $sample[0].earnint_activityname -or -not $sample[0].earnint_starttimestamp -or -not $sample[0]._earnint_caseid_processevent_value) {
    $validationErrors.Add("The EIR-PM-2026-MEDIUM sample record is missing expected stored values.")
}

Write-Host ""
Write-Host "=== Main Form Validation ===" -ForegroundColor Cyan
Write-Host "  Published controls: $($actualFields.Count)"
Write-Host "  Form sections:      $($actualSections.Count)"
Write-Host "  Existing records:   $($records.Count)"
if ($sample.Count -eq 1) { Write-Host "  Sample record:      $($sample[0].earnint_processevent_name)" }
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Process Event main-form validation failed with $($validationErrors.Count) error(s)."
}
Write-Host "  Validation:         PASS" -ForegroundColor Green