$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}
$appId='9262ce94-6187-f111-ab10-000d3a189124'

$au=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodules($appId)?`$select=appmoduleidunique" -Headers $h).appmoduleidunique
$ids=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodulecomponents?`$select=componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $au and componenttype eq 60&`$top=5000" -Headers $h).value | Select-Object -ExpandProperty objectid -Unique)

$forms=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms?`$select=formid,name,objecttypecode,type&`$filter=type eq 2&`$top=5000" -Headers $h).value |
  Where-Object { $ids -contains $_.formid -and $_.objecttypecode -in @('incident','contact') } |
  Sort-Object objecttypecode,name

if($forms.Count -eq 0){
  Write-Output 'NO_INCIDENT_CONTACT_FORMS_IN_APP_COMPONENTS'
} else {
  foreach($f in $forms){
    Write-Output ("APP_FORM=" + $f.objecttypecode + "::" + $f.name + "::" + $f.formid)
  }
}