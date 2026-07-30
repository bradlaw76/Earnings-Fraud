<#
.SYNOPSIS
    Creates NEW fraud-specific forms on OOB Case (incident) and Contact.

.DESCRIPTION
    - Ensures fraud columns exist from payloads.
    - Creates new main forms by cloning OOB forms.
    - Adds fraud columns to the new forms if missing.
    - Optionally attempts to add the new forms to a model-driven app.
    - Publishes all customizations.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$AppId = "",
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
    throw "AccessToken not found. Run 10-auth-connect.ps1 or az login first."
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

    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    $attempt = 0
    $maxAttempts = 6

    while ($attempt -lt $maxAttempts) {
        $attempt++
        try {
            $h = @{
                "Authorization" = "Bearer $AccessToken"
                "Content-Type" = "application/json"
                "OData-Version" = "4.0"
                "OData-MaxVersion" = "4.0"
                "Accept" = "application/json"
            }

            if (-not [string]::IsNullOrWhiteSpace($Body)) {
                return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body
            }
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
        }
        catch {
            $status = $null
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                $status = [int]$_.Exception.Response.StatusCode
            }
            elseif ($_.Exception.Message -match "\b(401|429)\b") {
                $status = [int]$matches[1]
            }

            if ($status -eq 401 -and $attempt -lt $maxAttempts) {
                $freshToken = (& az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
                if (-not [string]::IsNullOrWhiteSpace($freshToken)) {
                    $AccessToken = $freshToken.Trim()
                    continue
                }
            }

            if ($status -eq 429 -and $attempt -lt $maxAttempts) {
                $waitSeconds = [Math]::Min(16, [Math]::Pow(2, $attempt - 1))
                [System.Threading.Thread]::Sleep([int]($waitSeconds * 1000))
                continue
            }

            throw
        }
    }
}

function Test-ColumnExists([string]$TableLogicalName, [string]$ColumnLogicalName) {
    try {
        Invoke-Dv -Method "Get" -Path "EntityDefinitions(LogicalName='$TableLogicalName')/Attributes(LogicalName='$ColumnLogicalName')?`$select=LogicalName" | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Ensure-ColumnsFromPayload([string]$PayloadFile) {
    $doc = Get-Content $PayloadFile -Raw | ConvertFrom-Json
    $table = ("$($doc.TableLogicalName)").ToLower()

    foreach ($col in $doc.Columns) {
        $logical = ("$($col.SchemaName)").ToLower()
        if (Test-ColumnExists -TableLogicalName $table -ColumnLogicalName $logical) {
            continue
        }
        $body = $col | ConvertTo-Json -Depth 20 -Compress
        Invoke-Dv -Method "Post" -Path "EntityDefinitions(LogicalName='$table')/Attributes" -Body $body | Out-Null
    }
}

function Get-FieldDefsFromPayload([string]$PayloadFile) {
    $doc = Get-Content $PayloadFile -Raw | ConvertFrom-Json
    $fields = New-Object System.Collections.Generic.List[object]
    foreach ($col in $doc.Columns) {
        $logical = ("$($col.SchemaName)").ToLower()
        if ([string]::IsNullOrWhiteSpace($logical)) {
            continue
        }

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

        [void]$fields.Add([pscustomobject]@{
            LogicalName = $logical
            Label = $label
        })
    }

    return @($fields | Sort-Object LogicalName -Unique)
}

function Add-FieldsToFormXml {
    param(
        [string]$FormXml,
        [object[]]$FieldDefs,
        [string]$SectionLabel
    )

    [xml]$xml = $FormXml
    $sectionsNode = $xml.SelectSingleNode("/form/tabs/tab/columns/column/sections")
    if ($null -eq $sectionsNode) {
        throw "Could not find sections node in formxml."
    }

    $existingControls = @{}
    $controlNodes = $xml.SelectNodes("//control")
    foreach ($c in $controlNodes) {
        $attr = $c.Attributes["datafieldname"]
        if ($null -ne $attr -and -not [string]::IsNullOrWhiteSpace($attr.Value)) {
            $existingControls[$attr.Value.ToLower()] = $true
        }
    }

    $newFields = @($FieldDefs | Where-Object { -not $existingControls.ContainsKey($_.LogicalName.ToLower()) })
    if ($newFields.Count -eq 0) {
        return $FormXml
    }

    $sectionNode = $xml.CreateElement("section")
    $sectionNode.SetAttribute("name", "fraud_section")
    $sectionNode.SetAttribute("showlabel", "true")
    $sectionNode.SetAttribute("showbar", "true")

    $labelsNode = $xml.CreateElement("labels")
    $labelNode = $xml.CreateElement("label")
    $labelNode.SetAttribute("description", $SectionLabel)
    $labelNode.SetAttribute("languagecode", "1033")
    [void]$labelsNode.AppendChild($labelNode)
    [void]$sectionNode.AppendChild($labelsNode)

    $rowsNode = $xml.CreateElement("rows")
    for ($i = 0; $i -lt $newFields.Count; $i += 2) {
        $row = $xml.CreateElement("row")
        for ($j = 0; $j -lt 2; $j++) {
            $idx = $i + $j
            if ($idx -ge $newFields.Count) { continue }

            $fieldLogical = "$($newFields[$idx].LogicalName)"
            $fieldLabel = "$($newFields[$idx].Label)"
            $cell = $xml.CreateElement("cell")
            $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
            $cell.SetAttribute("showlabel", "true")
            $cell.SetAttribute("locklevel", "0")

            $cellLabels = $xml.CreateElement("labels")
            $cellLabel = $xml.CreateElement("label")
            $cellLabel.SetAttribute("description", $fieldLabel)
            $cellLabel.SetAttribute("languagecode", "1033")
            [void]$cellLabels.AppendChild($cellLabel)
            [void]$cell.AppendChild($cellLabels)

            $control = $xml.CreateElement("control")
            $control.SetAttribute("id", $fieldLogical)
            $control.SetAttribute("classid", "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}")
            $control.SetAttribute("datafieldname", $fieldLogical)
            $control.SetAttribute("disabled", "false")
            [void]$cell.AppendChild($control)

            [void]$row.AppendChild($cell)
        }
        [void]$rowsNode.AppendChild($row)
    }

    [void]$sectionNode.AppendChild($rowsNode)
    [void]$sectionsNode.AppendChild($sectionNode)
    return $xml.OuterXml
}

function Ensure-NewForm {
    param(
        [string]$TableLogicalName,
        [string]$SourceFormName,
        [string]$NewFormName,
        [object[]]$FieldDefs,
        [string]$SectionLabel
    )

    $escapedNew = $NewFormName.Replace("'", "''")
    $existing = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$escapedNew'").value | Select-Object -First 1)
    if ($existing.Count -gt 0) {
        Write-Host "  Form '$NewFormName' already exists on '$TableLogicalName'" -ForegroundColor DarkGray
        return "$($existing[0].formid)"
    }

    $escapedSource = $SourceFormName.Replace("'", "''")
    $source = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,formxml,objecttypecode,type&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$escapedSource'").value | Select-Object -First 1)
    if ($source.Count -eq 0) {
        throw "Source form '$SourceFormName' not found on '$TableLogicalName'."
    }

    $newXml = Add-FieldsToFormXml -FormXml "$($source[0].formxml)" -FieldDefs $FieldDefs -SectionLabel $SectionLabel
    $create = @{
        name = $NewFormName
        objecttypecode = $TableLogicalName
        type = 2
        formxml = $newXml
    } | ConvertTo-Json -Compress -Depth 20

    Invoke-Dv -Method "Post" -Path "systemforms" -Body $create | Out-Null
    $created = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,objecttypecode,type&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$escapedNew'").value | Select-Object -First 1)
    if ($created.Count -eq 0) {
        throw "Created form '$NewFormName' was not found in verification query."
    }

    Write-Host "  Created form '$NewFormName' on '$TableLogicalName'" -ForegroundColor Green
    return "$($created[0].formid)"
}

function Add-FormsToApp {
    param(
        [string]$TargetAppId,
        [string[]]$FormIds
    )

    if ([string]::IsNullOrWhiteSpace($TargetAppId) -or $FormIds.Count -eq 0) {
        return
    }

    $components = @()
    foreach ($id in $FormIds) {
        $components += @{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $id }
    }

    $body = @{ AppId = $TargetAppId; Components = $components } | ConvertTo-Json -Compress -Depth 20
    try {
        Invoke-Dv -Method "Post" -Path "AddAppComponents" -Body $body | Out-Null
        Write-Host "  Submitted form add to app $TargetAppId" -ForegroundColor Green
    }
    catch {
        Write-Host "  WARN: App form add returned warning/error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Create New OOB Fraud Forms ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
if (-not [string]::IsNullOrWhiteSpace($AppId)) {
    Write-Host "  AppId:       $AppId"
}
Write-Host ""

Ensure-ColumnsFromPayload -PayloadFile $CasePayloadPath
Ensure-ColumnsFromPayload -PayloadFile $ContactPayloadPath

$caseFields = Get-FieldDefsFromPayload -PayloadFile $CasePayloadPath
$contactFields = Get-FieldDefsFromPayload -PayloadFile $ContactPayloadPath

$newCaseFormId = Ensure-NewForm -TableLogicalName "incident" -SourceFormName "Case" -NewFormName $CaseFormName -FieldDefs $caseFields -SectionLabel "Fraud Review"
$newContactFormId = Ensure-NewForm -TableLogicalName "contact" -SourceFormName "Information" -NewFormName $ContactFormName -FieldDefs $contactFields -SectionLabel "Fraud Profile"

Add-FormsToApp -TargetAppId $AppId -FormIds @($newCaseFormId, $newContactFormId)

Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  New incident form: $newCaseFormId"
Write-Host "  New contact form:  $newContactFormId"
