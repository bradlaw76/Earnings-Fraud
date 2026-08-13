<#
.SYNOPSIS
    Rewrites three unrelated activities on the Patricia Nguyen EIR Case.

.DESCRIPTION
    Updates two Tasks and one Appointment with earnings-integrity content and
    upcoming dates. The script verifies every regarding link before writing and
    preserves owners and activity parties. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/108-remediate-case-activities.ps1 -WhatIf
    pwsh ./scripts/bootstrap/108-remediate-case-activities.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [guid]$CaseId = "22868d3c-6c8b-f111-ab10-000d3a189124",
    [guid]$EvidenceTaskId = "fe445da2-ab91-f111-8077-3833c5ed69ae",
    [guid]$StatementTaskId = "04455da2-ab91-f111-8077-3833c5ed69ae",
    [guid]$AppointmentId = "06455da2-ab91-f111-8077-3833c5ed69ae",
    [int]$ApplicationChoiceValue = 581180001,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envFile = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) ".env.ps1"
if ((Test-Path $envFile) -and [string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    . $envFile
    $EnvironmentUrl = $global:DV_ENVIRONMENT_URL
}

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "Environment URL required. Run 10-auth-connect.ps1 first."
}

$EnvironmentUrl = $EnvironmentUrl.TrimEnd("/")
$token = (az account get-access-token --resource $EnvironmentUrl --query accessToken -o tsv 2>$null)
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Could not get a Dataverse access token. Re-run 10-auth-connect.ps1."
}

$headers = @{
    Authorization      = "Bearer $($token.Trim())"
    "Content-Type"     = "application/json"
    "OData-Version"    = "4.0"
    "OData-MaxVersion" = "4.0"
    Prefer             = "return=representation"
}

function Invoke-Dv {
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )

    $uri = "$EnvironmentUrl/api/data/v9.2/$Path"
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
}

function Get-Activity {
    param(
        [Parameter(Mandatory)][string]$EntitySet,
        [Parameter(Mandatory)][guid]$ActivityId,
        [Parameter(Mandatory)][string]$Select
    )

    return Invoke-Dv -Method Get -Path "$EntitySet($ActivityId)?`$select=$Select"
}

function Test-TargetValues {
    param(
        [Parameter(Mandatory)]$Record,
        [Parameter(Mandatory)][hashtable]$Values
    )

    foreach ($entry in $Values.GetEnumerator()) {
        $actual = $Record.($entry.Key)
        $expected = $entry.Value
        if ($entry.Key -in @("scheduledstart", "scheduledend")) {
            $actualUtc = if ($actual -is [datetime]) {
                $actual.ToUniversalTime()
            } else {
                [datetimeoffset]::Parse([string]$actual).UtcDateTime
            }
            $expectedUtc = [datetimeoffset]::Parse([string]$expected).UtcDateTime
            if ($actualUtc -ne $expectedUtc) {
                Write-Verbose "Date mismatch for $($entry.Key): actual '$actualUtc', expected '$expectedUtc'"
                return $false
            }
        } elseif ([string]$actual -cne [string]$expected) {
            Write-Verbose "Value mismatch for $($entry.Key): actual '$actual', expected '$expected'"
            return $false
        }
    }
    return $true
}

$case = Invoke-Dv -Method Get -Path "incidents($CaseId)?`$select=incidentid,title,demo_datacustomerapplication"
if ($case.title -notlike "EIR-2025-0033*Nguyen, Patricia*") {
    throw "Case $CaseId is not the expected Patricia Nguyen EIR Case. No activities were changed."
}
if ($case.demo_datacustomerapplication -ne $ApplicationChoiceValue) {
    throw "The Patricia Nguyen Case is not scoped to application choice $ApplicationChoiceValue. No activities were changed."
}

$activities = @(
    @{
        Label = "IRS 1099 evidence Task"
        EntitySet = "tasks"
        Id = $EvidenceTaskId
        Select = "activityid,subject,description,scheduledstart,scheduledend,_regardingobjectid_value,statecode,statuscode"
        Values = @{
            subject = "Verify IRS 1099 self-employment income evidence"
            description = "Verify that Patricia Nguyen's 2024 IRS 1099-NEC reflects `$11,600 in self-employment income. Confirm the beneficiary identity, earnings period, payer information, and source authenticity, then add a concise verification summary to the Case timeline."
            scheduledstart = "2026-08-11T13:00:00Z"
            scheduledend = "2026-08-12T21:00:00Z"
        }
    },
    @{
        Label = "Beneficiary statement Task"
        EntitySet = "tasks"
        Id = $StatementTaskId
        Select = "activityid,subject,description,scheduledstart,scheduledend,_regardingobjectid_value,statecode,statuscode"
        Values = @{
            subject = "Reconcile beneficiary statement with IRS 1099"
            description = "Compare Patricia Nguyen's statement that the funds were a gift or loan with the 2024 IRS 1099 self-employment income record. Document the unresolved differences, identify supporting documents to request, and record a preliminary analysis for human review."
            scheduledstart = "2026-08-12T13:00:00Z"
            scheduledend = "2026-08-13T21:00:00Z"
        }
    },
    @{
        Label = "Beneficiary clarification Appointment"
        EntitySet = "appointments"
        Id = $AppointmentId
        Select = "activityid,subject,description,location,scheduledstart,scheduledend,_regardingobjectid_value,statecode,statuscode"
        Values = @{
            subject = "Beneficiary earnings clarification interview"
            description = "Meet with Patricia Nguyen to discuss the difference between her 2024 IRS 1099 self-employment income and beneficiary statement. Confirm the source and timing of the funds, request supporting documents, and record her responses. Do not make a final determination during the appointment."
            location = "Microsoft Teams / SSA Field Office"
            scheduledstart = "2026-08-14T18:00:00Z"
            scheduledend = "2026-08-14T18:30:00Z"
        }
    }
)

Write-Host ""
Write-Host "=== Remediate Patricia Nguyen Case Activities ===" -ForegroundColor Cyan
Write-Host "  Environment : $EnvironmentUrl"
Write-Host "  Case        : $($case.title)"
if ($WhatIf) { Write-Host "  Mode        : WhatIf (no writes)" -ForegroundColor Yellow }
Write-Host ""

$updated = 0
$skipped = 0
foreach ($activity in $activities) {
    $record = Get-Activity -EntitySet $activity.EntitySet -ActivityId $activity.Id -Select $activity.Select
    if ($record._regardingobjectid_value -ne $CaseId) {
        throw "$($activity.Label) does not regard the expected Case. No further activities were changed."
    }

    if (Test-TargetValues -Record $record -Values $activity.Values) {
        Write-Host "  [SKIPPED] $($activity.Label) already has the target values" -ForegroundColor DarkGray
        $skipped++
    } elseif ($WhatIf) {
        Write-Host "  [WHATIF] Would update $($activity.Label)" -ForegroundColor Yellow
    } else {
        Invoke-Dv -Method Patch -Path "$($activity.EntitySet)($($activity.Id))" -Body $activity.Values | Out-Null
        Write-Host "  [UPDATED] $($activity.Label)" -ForegroundColor Green
        $updated++
    }
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "Preview complete. No records changed." -ForegroundColor Cyan
    exit 0
}

$foreignPattern = "Obsidian|Bravo Talon|Ghost-6|Tactical|Extraction Plan|drone|Mission File|cyber"
$validationErrors = @()
foreach ($activity in $activities) {
    $record = Get-Activity -EntitySet $activity.EntitySet -ActivityId $activity.Id -Select $activity.Select
    if ($record._regardingobjectid_value -ne $CaseId) {
        $validationErrors += "$($activity.Label) has the wrong regarding Case."
    }
    if ($record.statecode -ne 0) {
        $validationErrors += "$($activity.Label) is not open."
    }
    if (-not (Test-TargetValues -Record $record -Values $activity.Values)) {
        $validationErrors += "$($activity.Label) does not match the target content or dates."
    }
    if ("$($record.subject)`n$($record.description)" -match $foreignPattern) {
        $validationErrors += "$($activity.Label) still contains unrelated tactical terminology."
    }
}

Write-Host ""
Write-Host "=== Activity Remediation Complete ===" -ForegroundColor Cyan
Write-Host "  Updated    : $updated"
Write-Host "  Skipped    : $skipped"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Activity validation failed with $($validationErrors.Count) error(s)."
}

Write-Host "  Validation : PASS" -ForegroundColor Green
Write-Host "  App URL    : $EnvironmentUrl/main.aspx" -ForegroundColor Cyan