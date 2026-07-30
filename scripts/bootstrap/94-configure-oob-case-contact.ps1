<#
.SYNOPSIS
    Configures OOB Case (incident) and Contact for the fraud use case.

.DESCRIPTION
    - Creates missing fraud fields on incident/contact from payload files.
    - Updates existing OOB forms (Case and Contact Information) to include those fields.
    - Adds those OOB forms/views to a model-driven app (optional).
    - Publishes all customizations.
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken = $env:DV_TOKEN,
    [string]$AppId = "",
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

if (-not (Test-Path $CasePayloadPath)) {
    throw "Case payload not found: $CasePayloadPath"
}
if (-not (Test-Path $ContactPayloadPath)) {
    throw "Contact payload not found: $ContactPayloadPath"
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
    $created = 0
    $skipped = 0

    Write-Host "  Table: $table" -ForegroundColor Cyan

    foreach ($col in $doc.Columns) {
        $logical = ("$($col.SchemaName)").ToLower()
        Write-Host "    $logical " -NoNewline
        if (Test-ColumnExists -TableLogicalName $table -ColumnLogicalName $logical) {
            Write-Host "(exists)" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $body = $col | ConvertTo-Json -Depth 20 -Compress
        Invoke-Dv -Method "Post" -Path "EntityDefinitions(LogicalName='$table')/Attributes" -Body $body | Out-Null
        Write-Host "(created)" -ForegroundColor Green
        $created++
    }

    return [pscustomobject]@{ Table = $table; Created = $created; Skipped = $skipped }
}

function Get-FieldListFromPayload([string]$PayloadFile) {
    $doc = Get-Content $PayloadFile -Raw | ConvertFrom-Json
    $fields = @()
    foreach ($col in $doc.Columns) {
        $logical = ("$($col.SchemaName)").ToLower()
        if (-not [string]::IsNullOrWhiteSpace($logical)) {
            $fields += $logical
        }
    }
    return @($fields | Select-Object -Unique)
}

function Add-FieldsToFormXml {
    param(
        [string]$FormXml,
        [string[]]$FieldLogicalNames,
        [string]$SectionLabel
    )

    [xml]$xml = $FormXml
    $rowsNode = $xml.SelectSingleNode("/form/tabs/tab/columns/column/sections/section/rows")
    if ($null -eq $rowsNode) {
        throw "Could not find form rows node in formxml."
    }

    $existingControls = @{}
    $controlNodes = $xml.SelectNodes("//control")
    foreach ($c in $controlNodes) {
        $attr = $c.Attributes["datafieldname"]
        if ($null -ne $attr -and -not [string]::IsNullOrWhiteSpace($attr.Value)) {
            $existingControls[$attr.Value.ToLower()] = $true
        }
    }

    $newFields = @($FieldLogicalNames | Where-Object { -not $existingControls.ContainsKey($_.ToLower()) })
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

    $sectionRows = $xml.CreateElement("rows")

    for ($i = 0; $i -lt $newFields.Count; $i += 2) {
        $row = $xml.CreateElement("row")

        for ($j = 0; $j -lt 2; $j++) {
            $idx = $i + $j
            if ($idx -ge $newFields.Count) { continue }

            $field = $newFields[$idx]
            $cell = $xml.CreateElement("cell")
            $cell.SetAttribute("id", "{$([guid]::NewGuid().ToString())}")
            $cell.SetAttribute("showlabel", "true")
            $cell.SetAttribute("locklevel", "0")

            $cellLabels = $xml.CreateElement("labels")
            $cellLabel = $xml.CreateElement("label")
            $cellLabel.SetAttribute("description", $field)
            $cellLabel.SetAttribute("languagecode", "1033")
            [void]$cellLabels.AppendChild($cellLabel)
            [void]$cell.AppendChild($cellLabels)

            $control = $xml.CreateElement("control")
            $control.SetAttribute("id", $field)
            $control.SetAttribute("classid", "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}")
            $control.SetAttribute("datafieldname", $field)
            $control.SetAttribute("disabled", "false")
            [void]$cell.AppendChild($control)

            [void]$row.AppendChild($cell)
        }

        [void]$sectionRows.AppendChild($row)
    }

    [void]$sectionNode.AppendChild($sectionRows)

    $sectionsNode = $xml.SelectSingleNode("/form/tabs/tab/columns/column/sections")
    [void]$sectionsNode.AppendChild($sectionNode)

    return $xml.OuterXml
}

function Update-FormWithFields {
    param(
        [string]$TableLogicalName,
        [string]$FormName,
        [string[]]$FieldLogicalNames,
        [string]$SectionLabel
    )

    $escapedFormName = $FormName.Replace("'", "''")
    $form = @((Invoke-Dv -Method "Get" -Path "systemforms?`$select=formid,name,formxml,type,objecttypecode&`$filter=objecttypecode eq '$TableLogicalName' and type eq 2 and name eq '$escapedFormName'").value | Select-Object -First 1)
    if ($form.Count -eq 0) {
        throw "Form '$FormName' not found on table '$TableLogicalName'."
    }

    $newXml = Add-FieldsToFormXml -FormXml "$($form[0].formxml)" -FieldLogicalNames $FieldLogicalNames -SectionLabel $SectionLabel
    $patch = @{ formxml = $newXml } | ConvertTo-Json -Compress -Depth 20
    Invoke-Dv -Method "Patch" -Path "systemforms($($form[0].formid))" -Body $patch | Out-Null

    Write-Host "  Updated form '$FormName' on '$TableLogicalName'" -ForegroundColor Green
    return "$($form[0].formid)"
}

function Ensure-AppArtifacts {
    param(
        [string]$TargetAppId,
        [string]$CaseFormId,
        [string]$ContactFormId
    )

    if ([string]::IsNullOrWhiteSpace($TargetAppId)) {
        return
    }

    $views = (Invoke-Dv -Method "Get" -Path "savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype&`$filter=querytype eq 0&`$top=5000").value
    $wanted = New-Object System.Collections.Generic.List[object]

    [void]$wanted.Add(@{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $CaseFormId })
    [void]$wanted.Add(@{ "@odata.type" = "Microsoft.Dynamics.CRM.systemform"; formid = $ContactFormId })

    foreach ($v in $views) {
        if (($v.returnedtypecode -eq "incident" -and $v.name -in @("Active Cases", "My Active Cases", "Inactive Cases")) -or
            ($v.returnedtypecode -eq "contact" -and $v.name -in @("Active Contacts", "My Active Contacts", "Inactive Contacts"))) {
            [void]$wanted.Add(@{ "@odata.type" = "Microsoft.Dynamics.CRM.savedquery"; savedqueryid = $v.savedqueryid })
        }
    }

    $componentArray = $wanted.ToArray()
    $body = @{ AppId = $TargetAppId; Components = $componentArray } | ConvertTo-Json -Compress -Depth 20
    Invoke-Dv -Method "Post" -Path "AddAppComponents" -Body $body | Out-Null
    Write-Host "  Added OOB forms/views to app $TargetAppId" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Configure OOB Case/Contact For Fraud Use Case ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
if (-not [string]::IsNullOrWhiteSpace($AppId)) {
    Write-Host "  AppId:       $AppId"
}
Write-Host ""

$caseResult = Ensure-ColumnsFromPayload -PayloadFile $CasePayloadPath
$contactResult = Ensure-ColumnsFromPayload -PayloadFile $ContactPayloadPath

$caseFields = Get-FieldListFromPayload -PayloadFile $CasePayloadPath
$contactFields = Get-FieldListFromPayload -PayloadFile $ContactPayloadPath

$caseFormId = Update-FormWithFields -TableLogicalName "incident" -FormName "Case" -FieldLogicalNames $caseFields -SectionLabel "Fraud Review"
$contactFormId = Update-FormWithFields -TableLogicalName "contact" -FormName "Information" -FieldLogicalNames $contactFields -SectionLabel "Fraud Profile"

Ensure-AppArtifacts -TargetAppId $AppId -CaseFormId $caseFormId -ContactFormId $contactFormId

Invoke-Dv -Method "Post" -Path "PublishAllXml" -Body "{}" | Out-Null

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  incident fields: created $($caseResult.Created), existing $($caseResult.Skipped)"
Write-Host "  contact fields:  created $($contactResult.Created), existing $($contactResult.Skipped)"
Write-Host "  Updated form IDs:"
Write-Host "    Case:    $caseFormId"
Write-Host "    Contact: $contactFormId"
