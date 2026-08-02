$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

$formA='540b48bd-8087-f111-ab10-000d3a189124'
$formB='3b7d0ac5-8087-f111-ab10-000d3a189124'

$sol=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/solutions?`$select=solutionid&`$filter=uniquename eq 'EarningsIntegrity'" -Headers $h).value | Select-Object -First 1
$sid=$sol.solutionid

$inSolA=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $sid and componenttype eq 60 and objectid eq $formA&`$top=1" -Headers $h).value.Count -gt 0)
$inSolB=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $sid and componenttype eq 60 and objectid eq $formB&`$top=1" -Headers $h).value.Count -gt 0)

$appId='9262ce94-6187-f111-ab10-000d3a189124'
$au=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodules($appId)?`$select=appmoduleidunique" -Headers $h).appmoduleidunique

$inAppA=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodulecomponents?`$select=objectid&`$filter=_appmoduleidunique_value eq $au and componenttype eq 60 and objectid eq $formA&`$top=1" -Headers $h).value.Count -gt 0)
$inAppB=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodulecomponents?`$select=objectid&`$filter=_appmoduleidunique_value eq $au and componenttype eq 60 and objectid eq $formB&`$top=1" -Headers $h).value.Count -gt 0)

Write-Output "IN_SOL_A=$inSolA IN_SOL_B=$inSolB IN_APP_A=$inAppA IN_APP_B=$inAppB"