<#
.SYNOPSIS
    Adds all custom tables (EntityDefinitions) to the target solution.
    Safe to rerun — adding an already-included component is a no-op.

.PARAMETER EnvironmentUrl     Defaults to $env:DV_ENVIRONMENT_URL.
.PARAMETER AccessToken        Defaults to $env:DV_TOKEN.
.PARAMETER SolutionUniqueName Defaults to $env:DV_SOLUTION_NAME.
.PARAMETER PublisherPrefix    Defaults to $env:DV_PUBLISHER_PREFIX.

.EXAMPLE
    pwsh ./scripts/bootstrap/50-add-to-solution.ps1
    pwsh ./scripts/bootstrap/50-add-to-solution.ps1 -SolutionUniqueName "MyApp"
#>

param(
    [string]$EnvironmentUrl     = $env:DV_ENVIRONMENT_URL,
    [string]$AccessToken        = $env:DV_TOKEN,
    [string]$SolutionUniqueName = $env:DV_SOLUTION_NAME,
    [string]$PublisherPrefix    = $env:DV_PUBLISHER_PREFIX
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl     = $global:DV_ENVIRONMENT_URL
    $AccessToken        = $global:DV_TOKEN
    $SolutionUniqueName = $SolutionUniqueName -ne "" ? $SolutionUniqueName : $global:DV_SOLUTION_NAME
    $PublisherPrefix    = $PublisherPrefix    -ne "" ? $PublisherPrefix    : $global:DV_PUBLISHER_PREFIX
}

foreach ($v in @($EnvironmentUrl, $AccessToken, $SolutionUniqueName, $PublisherPrefix)) {
    if ([string]::IsNullOrWhiteSpace($v)) {
        Write-Host "Missing required values. Run 10-auth-connect.ps1 first." -ForegroundColor Red
        exit 1
    }
}

function Invoke-Dv([string]$Method, [string]$Path, [string]$Body = "") {
    $h = @{ "Authorization"="Bearer $AccessToken"; "Content-Type"="application/json";
            "OData-Version"="4.0"; "OData-MaxVersion"="4.0"; "Accept"="application/json" }
    $uri = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2/$Path"
    if ($Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h
}

function Get-PayloadEntityNames([string]$Folder) {
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($file in @(Get-ChildItem -Path $Folder -Filter "table-*.json" -ErrorAction SilentlyContinue)) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $schema = if ($doc.PSObject.Properties.Name -contains 'EntityDefinition') { $doc.EntityDefinition.SchemaName } else { $doc.SchemaName }
        if (-not [string]::IsNullOrWhiteSpace($schema)) { [void]$names.Add($schema.ToLower()) }
    }

    foreach ($file in @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue)) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace($doc.TableLogicalName)) { [void]$names.Add($doc.TableLogicalName.ToLower()) }
    }

    foreach ($file in @(Get-ChildItem -Path $Folder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $rels = if ($doc -is [array]) { $doc } elseif ($doc.PSObject.Properties.Name -contains 'Relationships') { @($doc.Relationships) } else { @($doc) }
        foreach ($rel in $rels) {
            if (-not [string]::IsNullOrWhiteSpace($rel.ReferencedEntity)) { [void]$names.Add($rel.ReferencedEntity.ToLower()) }
            if (-not [string]::IsNullOrWhiteSpace($rel.ReferencingEntity)) { [void]$names.Add($rel.ReferencingEntity.ToLower()) }
        }
    }

    return @($names)
}

function Get-PayloadAttributes([string]$Folder) {
    $items = @()
    foreach ($file in @(Get-ChildItem -Path $Folder -Filter "columns-*.json" -ErrorAction SilentlyContinue)) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $tableName = $doc.TableLogicalName
        if ([string]::IsNullOrWhiteSpace($tableName)) { continue }
        foreach ($col in $doc.Columns) {
            if (-not [string]::IsNullOrWhiteSpace($col.SchemaName)) {
                $items += [PSCustomObject]@{
                    TableLogicalName = $tableName.ToLower()
                    AttributeLogicalName = $col.SchemaName.ToLower()
                }
            }
        }
    }
    return $items
}

function Get-PayloadRelationships([string]$Folder) {
    $items = @()
    foreach ($file in @(Get-ChildItem -Path $Folder -Filter "relationships-*.json" -ErrorAction SilentlyContinue)) {
        $doc = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $rels = if ($doc -is [array]) { $doc } elseif ($doc.PSObject.Properties.Name -contains 'Relationships') { @($doc.Relationships) } else { @($doc) }
        foreach ($rel in $rels) {
            if (-not [string]::IsNullOrWhiteSpace($rel.SchemaName)) {
                $items += $rel.SchemaName
            }
        }
    }
    return @($items | ForEach-Object { $_.ToLower() } | Sort-Object -Unique)
}

function Add-SolutionComponent([Guid]$ComponentId, [int]$ComponentType, [string]$SolutionName) {
    $body = @{ ComponentId = $ComponentId; ComponentType = $ComponentType; SolutionUniqueName = $SolutionName; AddRequiredComponents = $false } | ConvertTo-Json -Compress
    Invoke-Dv "Post" "AddSolutionComponent" $body | Out-Null
}

Write-Host ""
Write-Host "=== Add to Solution ===" -ForegroundColor Cyan
Write-Host "  Environment: $EnvironmentUrl"
Write-Host "  Solution:    $SolutionUniqueName"
Write-Host "  Prefix:      $PublisherPrefix"
Write-Host ""

# Verify solution exists
$sol = (Invoke-Dv "Get" "solutions?`$filter=uniquename eq '$SolutionUniqueName'&`$select=solutionid,uniquename").value | Select-Object -First 1
if ($null -eq $sol) {
    Write-Host "Solution '$SolutionUniqueName' not found in this environment." -ForegroundColor Red
    Write-Host "Create it first in the Power Platform Maker portal or with: pac solution create"
    exit 1
}
Write-Host "  Solution ID: $($sol.solutionid)" -ForegroundColor DarkGray

$payloadsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "payloads"
$entityNames = @(Get-PayloadEntityNames $payloadsFolder)
$attributeRefs = @(Get-PayloadAttributes $payloadsFolder)
$relationshipNames = @(Get-PayloadRelationships $payloadsFolder)
$tables = @()
foreach ($entityName in $entityNames) {
    try {
        $entity = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$entityName')?`$select=LogicalName,MetadataId"
        if ($null -ne $entity -and -not [string]::IsNullOrWhiteSpace($entity.LogicalName)) {
            $tables += $entity
        }
    } catch {
        Write-Host "  WARN  could not resolve entity '$entityName' from payloads" -ForegroundColor Yellow
    }
}
Write-Host "  Entities found in payloads: $($tables.Count)"
Write-Host "  Attributes found in payloads: $($attributeRefs.Count)"
Write-Host "  Relationships found in payloads: $($relationshipNames.Count)"
Write-Host ""

$added = 0; $skipped = 0; $failed = 0
# ComponentType 1 = Entity
foreach ($t in $tables | Sort-Object LogicalName -Unique) {
    Write-Host "  $($t.LogicalName) " -NoNewline
    try {
        Add-SolutionComponent -ComponentId $t.MetadataId -ComponentType 1 -SolutionName $SolutionUniqueName
        Write-Host "(added)" -ForegroundColor Green
        $added++
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
            Write-Host "(already in solution)" -ForegroundColor DarkGray; $skipped++
        } else {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red; $failed++
        }
    }
}

# ComponentType 2 = Attribute
foreach ($attr in $attributeRefs | Sort-Object TableLogicalName, AttributeLogicalName -Unique) {
    Write-Host "  $($attr.TableLogicalName).$($attr.AttributeLogicalName) " -NoNewline
    try {
        $attribute = Invoke-Dv "Get" "EntityDefinitions(LogicalName='$($attr.TableLogicalName)')/Attributes(LogicalName='$($attr.AttributeLogicalName)')?`$select=MetadataId,LogicalName"
        Add-SolutionComponent -ComponentId $attribute.MetadataId -ComponentType 2 -SolutionName $SolutionUniqueName
        Write-Host "(added)" -ForegroundColor Green
        $added++
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
            Write-Host "(already in solution)" -ForegroundColor DarkGray; $skipped++
        } else {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red; $failed++
        }
    }
}

# ComponentType 10 = Relationship
foreach ($relationshipName in $relationshipNames) {
    Write-Host "  $relationshipName " -NoNewline
    try {
        $relationship = (Invoke-Dv "Get" "RelationshipDefinitions?`$filter=SchemaName eq '$relationshipName'&`$select=MetadataId,SchemaName").value | Select-Object -First 1
        if ($null -eq $relationship) {
            Write-Host "(warning: relationship metadata lookup not resolved)" -ForegroundColor Yellow
            $skipped++
            continue
        }
        Add-SolutionComponent -ComponentId $relationship.MetadataId -ComponentType 10 -SolutionName $SolutionUniqueName
        Write-Host "(added)" -ForegroundColor Green
        $added++
    } catch {
        if ($_.Exception.Message -like "*already*" -or $_.Exception.Message -like "*duplicate*") {
            Write-Host "(already in solution)" -ForegroundColor DarkGray; $skipped++
        } else {
            Write-Host "(FAILED: $($_.Exception.Message))" -ForegroundColor Red; $failed++
        }
    }
}

Write-Host ""
Write-Host "Solution components — added: $added  skipped: $skipped  failed: $failed"
if ($failed -gt 0) { exit 1 }
Write-Host ""
Write-Host "Next step: pwsh ./scripts/bootstrap/60-build-forms-views.ps1"

