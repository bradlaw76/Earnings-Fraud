<#
.SYNOPSIS
    Creates three open Tasks for each of the newest Earnings Fraud Cases.

.DESCRIPTION
    Selects the 20 most recently created Cases scoped to DATA-Customer-Application
    value 581180001. Creates intake/risk, evidence, and follow-up/disposition Tasks
    with deterministic subjects and Case-tailored descriptions. Safe to rerun.

.EXAMPLE
    pwsh ./scripts/bootstrap/109-seed-recent-case-tasks.ps1 -WhatIf
    pwsh ./scripts/bootstrap/109-seed-recent-case-tasks.ps1
#>

param(
    [string]$EnvironmentUrl = $env:DV_ENVIRONMENT_URL,
    [ValidateRange(1, 100)]
    [int]$CaseCount = 20,
    [int]$ApplicationChoiceValue = 581180001,
    [datetime]$BaseDueDate = "2026-08-17T21:00:00Z",
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
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if ($null -eq $Body) {
                return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
            }
            return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
        } catch {
            $statusCode = [int]$_.Exception.Response.StatusCode
            if ($attempt -eq 5 -or $statusCode -notin @(429, 502, 503, 504)) {
                throw
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
        }
    }
}

function Get-DvRows {
    param([Parameter(Mandatory)][string]$Path)

    $rows = @()
    $nextPath = $Path
    while ($nextPath) {
        $response = if ($nextPath -like "http*") {
            Invoke-RestMethod -Method Get -Uri $nextPath -Headers $headers
        } else {
            Invoke-Dv -Method Get -Path $nextPath
        }
        $rows += @($response.value)
        $nextLinkProperty = $response.PSObject.Properties["@odata.nextLink"]
        $nextPath = if ($null -ne $nextLinkProperty) { $nextLinkProperty.Value } else { $null }
    }
    return @($rows)
}

function Escape-ODataString {
    param([Parameter(Mandatory)][string]$Value)
    return $Value.Replace("'", "''")
}

function Get-ReviewProfile {
    param([Parameter(Mandatory)][int]$ReviewType)

    switch ($ReviewType) {
        100000001 {
            return @{
                Label = "Unreported earnings"
                Intake = "Confirm the wage-match referral, review period, beneficiary identity, and high-risk indicators for this unreported earnings Case. Record any missing intake details before evidence analysis begins."
                Evidence = "Compare reported earnings with the authoritative wage record. Verify employer, period, amount, and source authenticity, then summarize the confirmed variance and any evidence gaps."
                FollowUp = "Prepare the human-review package for the proposed overpayment review. Confirm that the beneficiary response and supporting evidence are documented before routing the recommendation."
            }
        }
        100000002 {
            return @{
                Label = "Multiple employer"
                Intake = "Validate the employer-report referral, affected review period, and separate wage sources for this multiple-employer Case. Confirm that each employer is represented in the intake record."
                Evidence = "Review wage evidence for each employer, reconcile the combined authoritative earnings, and identify any missing beneficiary statement or identity-linkage documentation."
                FollowUp = "Prepare a focused information request covering unresolved employer amounts and beneficiary explanations. Record the response deadline and the evidence needed for a human determination."
            }
        }
        100000004 {
            return @{
                Label = "Late reporting"
                Intake = "Confirm the late-reporting period, referral source, corrected wage information, and impacted months. Distinguish timing issues from intentional misrepresentation indicators."
                Evidence = "Verify the corrected wage report against authoritative records and confirm that earnings now reconcile. Document whether the evidence supports an administrative correction."
                FollowUp = "Prepare the corrected-data disposition for human review, including monitoring notes and any remaining benefit-adjustment actions. Do not close the Case automatically."
            }
        }
        100000005 {
            return @{
                Label = "Employer mismatch"
                Intake = "Validate the employer-mismatch referral, beneficiary identity, employer details, and review period. Record the specific fields that differ between the Case and wage source."
                Evidence = "Compare the employer wage record with available beneficiary and Case information. Verify the employer response status and document unresolved discrepancies."
                FollowUp = "Prepare employer-contact follow-up with the exact wage, period, and identity questions requiring confirmation. Record the response deadline for human review."
            }
        }
        default {
            return @{
                Label = "Earnings integrity"
                Intake = "Validate the intake source, beneficiary identity, review period, and risk indicators. Document missing Case information before evidence analysis."
                Evidence = "Review the available wage and beneficiary evidence, reconcile known amounts, and document evidence gaps requiring follow-up."
                FollowUp = "Prepare the next human-review action based on the Case evidence and proposed disposition. Do not make or automate a final determination."
            }
        }
    }
}

$cases = @(Get-DvRows -Path "incidents?`$select=incidentid,title,createdon,_customerid_value,earnint_reviewtype,earnint_riskrating,earnint_evidencestatus,earnint_casedisposition&`$filter=demo_datacustomerapplication eq $ApplicationChoiceValue&`$orderby=createdon desc&`$top=$CaseCount")
if ($cases.Count -ne $CaseCount) {
    throw "Expected $CaseCount scoped Cases but found $($cases.Count). No Tasks were changed."
}
if (@($cases | Where-Object { $null -eq $_._customerid_value -or $null -eq $_.earnint_reviewtype }).Count -gt 0) {
    throw "One or more target Cases is missing a Contact or review type. No Tasks were changed."
}

$taskTypes = @(
    @{ Number = 1; Key = "Intake"; Category = "Intake and Risk"; Subject = "Validate intake and risk profile"; DueOffset = 0 },
    @{ Number = 2; Key = "Evidence"; Category = "Evidence Review"; Subject = "Review earnings evidence and gaps"; DueOffset = 2 },
    @{ Number = 3; Key = "FollowUp"; Category = "Follow-Up and Disposition"; Subject = "Prepare follow-up and disposition package"; DueOffset = 4 }
)

Write-Host ""
Write-Host "=== Seed Tasks for Recent Earnings Fraud Cases ===" -ForegroundColor Cyan
Write-Host "  Environment       : $EnvironmentUrl"
Write-Host "  Target Cases      : $CaseCount"
Write-Host "  Tasks per Case    : $($taskTypes.Count)"
Write-Host "  Planned Task total: $($CaseCount * $taskTypes.Count)"
if ($WhatIf) { Write-Host "  Mode              : WhatIf (no writes)" -ForegroundColor Yellow }
Write-Host ""

$created = 0
$skipped = 0
$expectedSubjects = @{}
$targetCaseIds = @{}

for ($caseIndex = 0; $caseIndex -lt $cases.Count; $caseIndex++) {
    $case = $cases[$caseIndex]
    $targetCaseIds[$case.incidentid.ToString()] = $true
    $profile = Get-ReviewProfile -ReviewType $case.earnint_reviewtype
    $caseNumberMatch = [regex]::Match($case.title, "BULK-(\d{3})")
    $caseNumber = if ($caseNumberMatch.Success) { $caseNumberMatch.Groups[1].Value } else { ($caseIndex + 1).ToString("000") }
    $waveOffset = [math]::Floor($caseIndex / 5) * 7
    $priority = if ($case.earnint_riskrating -ge 100000002) { 2 } else { 1 }

    Write-Host "Case $caseNumber - $($profile.Label): $($case.title)" -ForegroundColor Yellow
    foreach ($taskType in $taskTypes) {
        $subject = "EIR Work Item $caseNumber-$($taskType.Number) - $($taskType.Subject)"
        $expectedSubjects[$subject] = $case.incidentid.ToString()
        $safeSubject = Escape-ODataString -Value $subject
        $existing = @(Get-DvRows -Path "tasks?`$select=activityid,subject,_regardingobjectid_value&`$filter=subject eq '$safeSubject'&`$top=1")

        if ($existing.Count -eq 1) {
            if ($existing[0]._regardingobjectid_value -ne $case.incidentid) {
                throw "Task '$subject' already exists but regards a different record."
            }
            Write-Host "  [SKIPPED] $subject" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $dueDate = $BaseDueDate.ToUniversalTime().AddDays($waveOffset + $taskType.DueOffset)
        $startDate = $dueDate.AddDays(-1).Date.AddHours(13)
        if ($WhatIf) {
            Write-Host "  [WHATIF] $subject - due $($dueDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
            continue
        }

        $body = @{
            subject = $subject
            description = "$($profile[$taskType.Key])`n`nRegarding Case: $($case.title)"
            category = $taskType.Category
            subcategory = $profile.Label
            prioritycode = $priority
            scheduledstart = $startDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            scheduledend = $dueDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            "regardingobjectid_incident@odata.bind" = "/incidents($($case.incidentid))"
        }
        Invoke-Dv -Method Post -Path "tasks" -Body $body | Out-Null
        Write-Host "  [CREATED] $subject" -ForegroundColor Green
        $created++
    }
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "Preview complete. No records changed." -ForegroundColor Cyan
    Write-Host "  Planned Tasks: $($CaseCount * $taskTypes.Count)"
    exit 0
}

$allGeneratedTasks = @(Get-DvRows -Path "tasks?`$select=activityid,subject,category,subcategory,scheduledstart,scheduledend,statecode,_regardingobjectid_value&`$filter=startswith(subject,'EIR Work Item ')")
$generatedTasks = @($allGeneratedTasks | Where-Object {
    $_._regardingobjectid_value -and $targetCaseIds.ContainsKey($_._regardingobjectid_value.ToString()) -and $expectedSubjects.ContainsKey($_.subject)
})

$validationErrors = @()
$expectedTotal = $CaseCount * $taskTypes.Count
if ($generatedTasks.Count -ne $expectedTotal) {
    $validationErrors += "Expected $expectedTotal generated Tasks; found $($generatedTasks.Count)."
}
if (@($generatedTasks | Group-Object subject | Where-Object Count -gt 1).Count -gt 0) {
    $validationErrors += "Duplicate generated Task subjects were found."
}
if (@($generatedTasks | Where-Object statecode -ne 0).Count -gt 0) {
    $validationErrors += "One or more generated Tasks is not open."
}
if (@($generatedTasks | Where-Object { -not $_._regardingobjectid_value -or -not $targetCaseIds.ContainsKey($_._regardingobjectid_value.ToString()) }).Count -gt 0) {
    $validationErrors += "One or more generated Tasks has the wrong regarding Case."
}

foreach ($case in $cases) {
    $caseTasks = @($generatedTasks | Where-Object { $_._regardingobjectid_value -eq $case.incidentid })
    if ($caseTasks.Count -ne $taskTypes.Count) {
        $validationErrors += "Case '$($case.title)' has $($caseTasks.Count) generated Tasks instead of $($taskTypes.Count)."
    }
    foreach ($taskType in $taskTypes) {
        if (@($caseTasks | Where-Object category -eq $taskType.Category).Count -ne 1) {
            $validationErrors += "Case '$($case.title)' does not have exactly one '$($taskType.Category)' Task."
        }
    }
}

Write-Host ""
Write-Host "=== Recent Case Task Seed Complete ===" -ForegroundColor Cyan
Write-Host "  Created    : $created"
Write-Host "  Skipped    : $skipped"
Write-Host "  Validated  : $($generatedTasks.Count)"
if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Host "  [FAIL] $_" -ForegroundColor Red }
    throw "Recent Case Task validation failed with $($validationErrors.Count) error(s)."
}

Write-Host "  Validation : PASS" -ForegroundColor Green
Write-Host "  App URL    : $EnvironmentUrl/main.aspx" -ForegroundColor Cyan