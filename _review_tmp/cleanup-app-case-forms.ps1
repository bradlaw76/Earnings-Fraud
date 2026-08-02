$ErrorActionPreference='Stop'
$url='https://healthconnectcenter.crm.dynamics.com'
$appId='9262ce94-6187-f111-ab10-000d3a189124'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; 'Content-Type'='application/json'; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

# App-linked main forms for earnfrd2_case
$au=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodules($appId)?`$select=appmoduleidunique" -Headers $h).appmoduleidunique
$appFormIds=((Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/appmodulecomponents?`$select=componenttype,objectid,_appmoduleidunique_value&`$filter=_appmoduleidunique_value eq $au and componenttype eq 60&`$top=5000" -Headers $h).value | Select-Object -ExpandProperty objectid -Unique)

$allCaseForms=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms?`$select=formid,name,objecttypecode,type,formactivationstate&`$filter=objecttypecode eq 'earnfrd2_case' and type eq 2&`$top=5000" -Headers $h).value
$appCaseForms=@($allCaseForms | Where-Object { $appFormIds -contains $_.formid })
$nonAppCaseForms=@($allCaseForms | Where-Object { $appFormIds -notcontains $_.formid })

Write-Output "APP_FORMS_COUNT=$($appCaseForms.Count)"
$appCaseForms | Sort-Object name | ForEach-Object { Write-Output ("APP_FORM={0}::{1}" -f $_.name,$_.formid) }

# Archive/rename non-app forms so makers don't accidentally use them.
foreach($f in $nonAppCaseForms){
  $newName = $f.name
  if($newName -notlike 'ARCHIVE - *'){
    $newName = "ARCHIVE - " + $newName
    $body = @{ name = $newName } | ConvertTo-Json -Compress
    Invoke-RestMethod -Method Patch -Uri "$url/api/data/v9.2/systemforms($($f.formid))" -Headers $h -Body $body | Out-Null
    Write-Output "ARCHIVED_FORM=$newName::$($f.formid)"
  } else {
    Write-Output "ALREADY_ARCHIVED=$($f.name)::$($f.formid)"
  }
}

Invoke-RestMethod -Method Post -Uri "$url/api/data/v9.2/PublishAllXml" -Headers $h -Body '{}' | Out-Null
Write-Output 'PUBLISHED_OK'

# Final display list
$final=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms?`$select=formid,name,objecttypecode,type&`$filter=objecttypecode eq 'earnfrd2_case' and type eq 2&`$top=5000" -Headers $h).value | Sort-Object name
$final | ForEach-Object { Write-Output ("FINAL_FORM={0}::{1}" -f $_.name,$_.formid) }