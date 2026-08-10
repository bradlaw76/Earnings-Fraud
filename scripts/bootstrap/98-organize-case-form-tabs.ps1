<#
.SYNOPSIS
    Reorganizes case fields into tab-specific sections for the enhanced fraud case form.

.DESCRIPTION
    Moves configured incident fields into sections under existing tabs:
    - Intake
    - Risk & Confidence
    - Evidence & Workflow
    - Ai Insights

    Preserves existing non-field controls (for example web resources) by only
    removing controls that have a datafieldname matching configured fields.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$CaseFormName = "Enhanced full case form - Earnings Fraud",
    [string]$CasePayloadPath = "",
    [string]$AiPayloadPath = ""
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
if ([string]::IsNullOrWhiteSpace($AiPayloadPath)) {
    $AiPayloadPath = Join-Path $repoRoot "scripts/payloads/columns-06-case-ai.json"
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

function Find-TabByLabel {
    param(
        [xml]$Xml,
        [string]$TabLabel
    )

    $tabs = $Xml.SelectNodes('/form/tabs/tab')
    foreach ($tab in $tabs) {
        $labels = @($tab.SelectNodes('./labels/label'))
        foreach ($label in $labels) {
            if (("$($label.description)").Trim().ToLower() -eq $TabLabel.Trim().ToLower()) {
                return $tab
            }
        }
    }

    return $null
}

function Ensure-Section {
    param(
        [xml]$Xml,
        [System.Xml.XmlElement]$Tab,
        [string]$SectionName,
        [string]$SectionLabel
    )

    $sectionsNode = $Tab.SelectSingleNode('./columns/column/sections')
    if ($null -eq $sectionsNode) {
        throw "Sections node missing for tab '$SectionLabel'."
    }

    $existing = $sectionsNode.SelectSingleNode("./section[@name='$SectionName']")
    if ($null -ne $existing) {
        $rowsNode = $existing.SelectSingleNode('./rows')
        if ($null -ne $rowsNode) {
            while ($rowsNode.SelectSingleNode('./row')) {
                [void]$rowsNode.RemoveChild($rowsNode.SelectSingleNode('./row'))
            }
        }
        return $existing
    }

    $section = $Xml.CreateElement('section')
    $section.SetAttribute('name', $SectionName)
    $section.SetAttribute('showlabel', 'true')
    $section.SetAttribute('showbar', 'true')

    $labels = $Xml.CreateElement('labels')
    $label = $Xml.CreateElement('label')
    $label.SetAttribute('description', $SectionLabel)
    $label.SetAttribute('languagecode', '1033')
    [void]$labels.AppendChild($label)
    [void]$section.AppendChild($labels)

    $rows = $Xml.CreateElement('rows')
    [void]$section.AppendChild($rows)
    [void]$sectionsNode.AppendChild($section)

    return $section
}

function Add-FieldRows {
    param(
        [xml]$Xml,
        [System.Xml.XmlElement]$Section,
        [string[]]$Fields,
        [hashtable]$FieldLabelMap
    )

    $rowsNode = $Section.SelectSingleNode('./rows')
    if ($null -eq $rowsNode) {
        $rowsNode = $Xml.CreateElement('rows')
        [void]$Section.AppendChild($rowsNode)
    }

    for ($i = 0; $i -lt $Fields.Count; $i += 2) {
        $row = $Xml.CreateElement('row')

        for ($j = 0; $j -lt 2; $j++) {
            $idx = $i + $j
            if ($idx -ge $Fields.Count) { continue }

            $logical = $Fields[$idx]

            $cell = $Xml.CreateElement('cell')
            $cell.SetAttribute('id', "{$([guid]::NewGuid().ToString())}")
            $cell.SetAttribute('showlabel', 'true')
            $cell.SetAttribute('locklevel', '0')

            $labels = $Xml.CreateElement('labels')
            $label = $Xml.CreateElement('label')
            $displayLabel = $logical
            if ($FieldLabelMap.ContainsKey($logical)) {
                $displayLabel = "$($FieldLabelMap[$logical])"
            }
            $label.SetAttribute('description', $displayLabel)
            $label.SetAttribute('languagecode', '1033')
            [void]$labels.AppendChild($label)
            [void]$cell.AppendChild($labels)

            $control = $Xml.CreateElement('control')
            $control.SetAttribute('id', $logical)
            $control.SetAttribute('classid', '{4273EDBD-AC1D-40d3-9FB2-095C621B552D}')
            $control.SetAttribute('datafieldname', $logical)
            $control.SetAttribute('disabled', 'false')
            [void]$cell.AppendChild($control)

            [void]$row.AppendChild($cell)
        }

        [void]$rowsNode.AppendChild($row)
    }
}

function Get-FieldLabelMapFromPayloads {
    param([string[]]$PayloadPaths)

    $map = @{}
    foreach ($path in $PayloadPaths) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) {
            continue
        }

        $doc = Get-Content $path -Raw | ConvertFrom-Json
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
                continue
            }

            if (-not $map.ContainsKey($logical)) {
                $map[$logical] = $label
            }
        }
    }

    return $map
}

Write-Host ""
Write-Host "=== Organize Case Form Tabs ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Form:        $CaseFormName"
Write-Host ""

$layout = @(
    @{ Tab='Intake'; SectionName='intake_classification_section'; SectionLabel='Intake Classification'; Fields=@('earnint_reviewtype','earnint_referralsource','earnint_allegationtype','earnint_discrepancytype') },
    @{ Tab='Intake'; SectionName='review_period_section'; SectionLabel='Review Period'; Fields=@('earnint_reviewperiodstart','earnint_reviewperiodend') },

    @{ Tab='Risk & Confidence'; SectionName='risk_scoring_section'; SectionLabel='Risk Scoring'; Fields=@('earnint_riskrating','earnint_fraudlikelihood','earnint_fraudriskscore','earnint_riskexplanation') },
    @{ Tab='Risk & Confidence'; SectionName='confidence_section'; SectionLabel='Confidence'; Fields=@('earnint_confidencelevel','earnint_confidencescore') },
    @{ Tab='Risk & Confidence'; SectionName='financial_impact_section'; SectionLabel='Financial Impact'; Fields=@('earnint_potentialoverpayment','earnint_impactedmonthcount','earnint_largestmonthlyvariance') },

    @{ Tab='Evidence & Workflow'; SectionName='evidence_validation_section'; SectionLabel='Evidence and Validation Status'; Fields=@('earnint_evidencestatus','earnint_beneficiaryresponsestatus','earnint_identityvalidationstatus') },
    @{ Tab='Evidence & Workflow'; SectionName='workflow_oversight_section'; SectionLabel='Workflow and Oversight'; Fields=@('earnint_queueassignment','earnint_humanreviewrequired','earnint_supervisorreviewrequired','earnint_supervisorapproval') },
    @{ Tab='Evidence & Workflow'; SectionName='disposition_section'; SectionLabel='Disposition'; Fields=@('earnint_casedisposition','earnint_finaldetermination') },

    @{ Tab='Ai Insights'; SectionName='ai_summary_section'; SectionLabel='AI Summary'; Fields=@('earnfrau_aisummary','earnfrau_supportingevidencesummary','earnfrau_nextbestaction') },
    @{ Tab='Ai Insights'; SectionName='ai_explainability_section'; SectionLabel='AI Explainability'; Fields=@('earnfrau_risksignalbreakdown','earnfrau_evidencegaps','earnfrau_confidencerationale','earnfrau_humanreviewnote') },
    @{ Tab='Ai Insights'; SectionName='ai_raw_output_section'; SectionLabel='AI Raw Output'; Fields=@('earnfrau_airawjson') }
)

$fieldSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $layout) {
    foreach ($field in $entry.Fields) {
        [void]$fieldSet.Add($field)
    }
}

$fieldLabelMap = Get-FieldLabelMapFromPayloads -PayloadPaths @($CasePayloadPath, $AiPayloadPath)

$escaped = $CaseFormName.Replace("'", "''")
$form = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,formxml,type&`$filter=objecttypecode eq 'incident' and type eq 2 and name eq '$escaped'").value | Select-Object -First 1)
if ($form.Count -eq 0) {
    throw "Form '$CaseFormName' not found on incident."
}

[xml]$xml = $form[0].formxml

# Remove only targeted data fields from wherever they currently are; keep web resources and other controls.
$cells = @($xml.SelectNodes('//section/rows/row/cell'))
foreach ($cell in $cells) {
    $control = $cell.SelectSingleNode('./control')
    if ($null -eq $control) { continue }

    $fieldName = "$($control.GetAttribute('datafieldname'))"
    if ([string]::IsNullOrWhiteSpace($fieldName)) { continue }

    if ($fieldSet.Contains($fieldName)) {
        $row = $cell.ParentNode
        [void]$row.RemoveChild($cell)
        if ($null -eq $row.SelectSingleNode('./cell')) {
            [void]$row.ParentNode.RemoveChild($row)
        }
    }
}

foreach ($entry in $layout) {
    $tab = Find-TabByLabel -Xml $xml -TabLabel $entry.Tab
    if ($null -eq $tab) {
        throw "Tab '$($entry.Tab)' not found on form '$CaseFormName'."
    }

    $section = Ensure-Section -Xml $xml -Tab $tab -SectionName $entry.SectionName -SectionLabel $entry.SectionLabel
    Add-FieldRows -Xml $xml -Section $section -Fields $entry.Fields -FieldLabelMap $fieldLabelMap
}

$updatedXml = $xml.OuterXml
$patch = @{ formxml = $updatedXml } | ConvertTo-Json -Compress -Depth 50
Invoke-Dv -Method "Patch" -Path "systemforms($($form[0].formid))" -Body $patch | Out-Null
Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null

Write-Host "Updated and published form '$CaseFormName'" -ForegroundColor Green
Write-Host "  Form id: $($form[0].formid)"
