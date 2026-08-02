$ErrorActionPreference='Stop'
$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; 'Content-Type'='application/json'; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

$formA='540b48bd-8087-f111-ab10-000d3a189124'
$formB='3b7d0ac5-8087-f111-ab10-000d3a189124'
$solName='EarningsIntegrity'
$appId='9262ce94-6187-f111-ab10-000d3a189124'

foreach($fid in @($formA,$formB)){
  $solBody=@{ ComponentId=$fid; ComponentType=60; SolutionUniqueName=$solName; AddRequiredComponents=$false } | ConvertTo-Json -Compress
  try {
    Invoke-RestMethod -Method Post -Uri "$url/api/data/v9.2/AddSolutionComponent" -Headers $h -Body $solBody | Out-Null
    Write-Output "ADD_SOLUTION_OK=$fid"
  } catch {
    if($_.ErrorDetails.Message){ Write-Output "ADD_SOLUTION_MSG=$fid :: $($_.ErrorDetails.Message)" }
    else { Write-Output "ADD_SOLUTION_MSG=$fid :: $($_.Exception.Message)" }
  }
}

$appBody=@{ AppId=$appId; Components=@(
  @{ '@odata.type'='Microsoft.Dynamics.CRM.systemform'; formid=$formA },
  @{ '@odata.type'='Microsoft.Dynamics.CRM.systemform'; formid=$formB }
) } | ConvertTo-Json -Depth 10

try {
  Invoke-RestMethod -Method Post -Uri "$url/api/data/v9.2/AddAppComponents" -Headers $h -Body $appBody | Out-Null
  Write-Output 'ADD_APP_OK'
} catch {
  if($_.ErrorDetails.Message){ Write-Output "ADD_APP_MSG=$($_.ErrorDetails.Message)" }
  else { Write-Output "ADD_APP_MSG=$($_.Exception.Message)" }
}

Invoke-RestMethod -Method Post -Uri "$url/api/data/v9.2/PublishAllXml" -Headers $h -Body '{}' | Out-Null
Write-Output 'PUBLISH_OK'