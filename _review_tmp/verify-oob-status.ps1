$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

# Check OOB forms by known IDs used in update script
$caseFormId='4a63c8d1-6c1e-48ec-9db4-3e6c7155334c'
$contactFormId='894cc46a-b0cb-4ab0-8bf6-200544e46a2d'

$caseForm=Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms($caseFormId)?`$select=formid,name,objecttypecode,type,formxml" -Headers $h
$contactForm=Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms($contactFormId)?`$select=formid,name,objecttypecode,type,formxml" -Headers $h

Write-Output ("CASE_FORM=" + $caseForm.name + "::" + $caseForm.objecttypecode + "::" + $caseForm.formid)
Write-Output ("CONTACT_FORM=" + $contactForm.name + "::" + $contactForm.objecttypecode + "::" + $contactForm.formid)

# Check OOB columns existence
$checks=@(
  @{Table='incident'; Column='earnint_discrepancytype'},
  @{Table='incident'; Column='earnint_riskrating'},
  @{Table='incident'; Column='earnint_casedisposition'},
  @{Table='incident'; Column='earnint_supervisorapproval'},
  @{Table='contact'; Column='earnint_ssn'}
)

foreach($c in $checks){
  try {
    Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/EntityDefinitions(LogicalName='$($c.Table)')/Attributes(LogicalName='$($c.Column)')?`$select=LogicalName" -Headers $h | Out-Null
    Write-Output ("COLUMN_EXISTS=" + $c.Table + "::" + $c.Column + "::True")
  } catch {
    Write-Output ("COLUMN_EXISTS=" + $c.Table + "::" + $c.Column + "::False")
  }
}

# Quick check that these OOB forms contain the fraud fields in form XML
Write-Output ("CASE_FORM_HAS_DISCREPANCYTYPE=" + ($caseForm.formxml -match 'earnint_discrepancytype'))
Write-Output ("CASE_FORM_HAS_RISKRATING=" + ($caseForm.formxml -match 'earnint_riskrating'))
Write-Output ("CASE_FORM_HAS_CASEDISPOSITION=" + ($caseForm.formxml -match 'earnint_casedisposition'))
Write-Output ("CASE_FORM_HAS_SUPERVISORAPPROVAL=" + ($caseForm.formxml -match 'earnint_supervisorapproval'))
Write-Output ("CONTACT_FORM_HAS_SSN=" + ($contactForm.formxml -match 'earnint_ssn'))