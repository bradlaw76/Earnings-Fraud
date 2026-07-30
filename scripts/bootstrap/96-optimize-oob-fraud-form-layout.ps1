<#
.SYNOPSIS
    Optimizes layout and labels for OOB fraud forms.

.DESCRIPTION
    Rebuilds the fraud sections on:
    - incident form named "Fraud Case Form"
    - contact form named "Fraud Contact Form"

    Uses payload DisplayName labels (not schema names) and a stable field order.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$CaseFormName = "Fraud Case Form",
    [string]$ContactFormName = "Fraud Contact Form",
    [string]$CasePayloadPath = "",
    [string]$ContactPayloadPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        $AccessToken = $global:DV_TOKEN
    }
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "EnvironmentUrl is required."
}
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    $AccessToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
}
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "AccessToken not found."
}

if ([string]::IsNullOrWhiteSpace($CasePayloadPath)) {
    $CasePayloadPath = Join-Path $repoRoot "scripts/payloads/columns-01-case.json"
}
if ([string]::IsNullOrWhiteSpace($ContactPayloadPath)) {
    $ContactPayloadPath = Join-Path $repoRoot "scripts/payloads/columns-02-contact.json"
}

function Invoke-Dv {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Body = ""
    )

    $h = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type" = "application/json"
        "OData-Version" = "4.0"
        "OData-MaxVersion" = "4.0"
        "Accept" = "application/json"
    }

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Get-FieldDefsFromPayload {
    param(
        [string]$PayloadPath,
        [string[]]$Order
    )

    $doc = Get-Content $PayloadPath -Raw | ConvertFrom-Json
    $all = @{}

    foreach ($col in $doc.Columns) {
        $logical = ("$($col.SchemaName)").ToLower()
        if ([string]::IsNullOrWhiteSpace($logical)) { continue }

        $label = ""
        if ($null -ne $col.DisplayName -and $null -ne $col.DisplayName.LocalizedLabels) {
            $labelNode = @($col.DisplayName.LocalizedLabels | Where-Object { $_.LanguageCode -eq 1033 } | Select-Object -First 1)
            if ($labelNode.Count -eq 0) {
                $labelNode = @($col.DisplayName.LocalizedLabels | Select-Object -First 1)
            }
            if ($labelNode.Count -gt 0) {
                $label = "$($labelNode[0].Label)"
            }
        }
        if ([string]::IsNullOrWhiteSpace($label)) {
            $label = $logical
        }

        $all[$logical] = [pscustomobject]@{
            LogicalName = $logical
            Label = $label
        }
    }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($o in $Order) {
        $k = $o.ToLower()
        if ($all.ContainsKey($k)) {
            [void]$out.Add($all[$k])
        }
    }
    return $out.ToArray()
}

function Rebuild-FraudSectionXml {
    param(
        [string]$FormXml,
        [object[]]$FieldDefs,
        [string]$SectionName,
        [string]$SectionLabel
    )

    [xml]$xml = $FormXml
    $sectionsNode = $xml.SelectSingleNode("/form/tabs/tab/columns/column/sections")
    if ($null -eq $sectionsNode) {
        throw "Sections node not found in form xml."
    }

    # Remove both the target section and the legacy section from earlier runs.
    $sectionsToRemove = @($SectionName, "fraud_section") | Select-Object -Unique
    foreach ($sectionNameToRemove in $sectionsToRemove) {
        $existingSection = $xml.SelectSingleNode("/form/tabs/tab/columns/column/sections/section[@name='$sectionNameToRemove']")
        if ($null -ne $existingSection) {
            [void]$sectionsNode.RemoveChild($existingSection)
        }
    }

    $section = $xml.CreateElement("section")
    $section.SetAttribute("name", $SectionName)
    $section.SetAttribute("showlabel", "true")
    $section.SetAttribute("showbar", "true")

    $labels = $xml.CreateElement("labels")
    $label = $xml.CreateElement("label")
    $label.SetAttribute("description", $SectionLabel)
    $label.SetAttribute("languagecode", "1033")
    [void]$labels.AppendChild($label)
    [void]$section.AppendChild($labels)

    $rows = $xml.CreateElement("rows")
    for ($i = 0; $i -lt $FieldDefs.Count; $i += 2) {
        $row = $xml.CreateElement("row")

        for ($j = 0; $j -lt 2; $j++) {
            $idx = $i + $j
            if ($idx -ge $FieldDefs.Count) { continue }

            $f = $FieldDefs[$idx]
            $cell = $xml.CreateElement("cell")
            $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
            $cell.SetAttribute("showlabel", "true")
            $cell.SetAttribute("locklevel", "0")

            $cellLabels = $xml.CreateElement("labels")
            $cellLabel = $xml.CreateElement("label")
            $cellLabel.SetAttribute("description", "$($f.Label)")
            $cellLabel.SetAttribute("languagecode", "1033")
            [void]$cellLabels.AppendChild($cellLabel)
            [void]$cell.AppendChild($cellLabels)

            $control = $xml.CreateElement("control")
            $control.SetAttribute("id", "$($f.LogicalName)")
            $control.SetAttribute("classid", "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}")
            $control.SetAttribute("datafieldname", "$($f.LogicalName)")
            $control.SetAttribute("disabled", "false")
            [void]$cell.AppendChild($control)

            [void]$row.AppendChild($cell)
        }

        [void]$rows.AppendChild($row)
    }

    [void]$section.AppendChild($rows)
    [void]$sectionsNode.AppendChild($section)

    return $xml.OuterXml
}

function Update-Form {
    param(
        [string]$Table,
        [string]$FormName,
        [object[]]$FieldDefs,
        [string]$SectionName,
        [string]$SectionLabel
    )

    $escaped = $FormName.Replace("'", "''")
    $form = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,formxml,type&`$filter=objecttypecode eq '$Table' and type eq 2 and name eq '$escaped'").value | Select-Object -First 1)
    if ($form.Count -eq 0) {
        throw "Form '$FormName' not found on '$Table'."
    }

    $updatedXml = Rebuild-FraudSectionXml -FormXml "$($form[0].formxml)" -FieldDefs $FieldDefs -SectionName $SectionName -SectionLabel $SectionLabel
    $patch = @{ formxml = $updatedXml } | ConvertTo-Json -Compress -Depth 20
    Invoke-Dv -Method "Patch" -Path "systemforms($($form[0].formid))" -Body $patch | Out-Null

    Write-Host "  Updated form '$FormName' on '$Table'" -ForegroundColor Green
    return "$($form[0].formid)"
}

Write-Host ""
Write-Host "=== Optimize OOB Fraud Form Layout ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host ""

$caseOrder = @(
    "earnint_discrepancytype",
    "earnint_riskrating",
    "earnint_casedisposition",
    "earnint_supervisorapproval"
)
$contactOrder = @("earnint_ssn")

$caseDefs = Get-FieldDefsFromPayload -PayloadPath $CasePayloadPath -Order $caseOrder
$contactDefs = Get-FieldDefsFromPayload -PayloadPath $ContactPayloadPath -Order $contactOrder

$caseFormId = Update-Form -Table "incident" -FormName $CaseFormName -FieldDefs $caseDefs -SectionName "fraud_review_section" -SectionLabel "Fraud Review"
$contactFormId = Update-Form -Table "contact" -FormName $ContactFormName -FieldDefs $contactDefs -SectionName "fraud_profile_section" -SectionLabel "Fraud Profile"

Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Case form id:    $caseFormId"
Write-Host "  Contact form id: $contactFormId"
