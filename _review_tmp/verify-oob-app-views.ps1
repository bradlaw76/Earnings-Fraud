$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}
$appId='9262ce94-6187-f111-ab10-000d3a189124'
$au=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodules($appId)?`$select=appmoduleidunique" -Headers $h).appmoduleidunique
$viewIds=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodulecomponents?`$select=componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $au and componenttype eq 26&`$top=5000" -Headers $h).value | Select-Object -ExpandProperty objectid -Unique)
$views=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/savedqueries?`$select=savedqueryid,name,returnedtypecode,querytype&`$filter=querytype eq 0&`$top=5000" -Headers $h).value |
  Where-Object { $viewIds -contains $_.savedqueryid -and $_.returnedtypecode -in @('incident','contact') } |
  Sort-Object returnedtypecode,name
if($views.Count -eq 0){ Write-Output 'NO_INCIDENT_CONTACT_VIEWS_IN_APP_COMPONENTS' }
else { foreach($v in $views){ Write-Output ("APP_VIEW=" + $v.returnedtypecode + "::" + $v.name + "::" + $v.savedqueryid) } }