$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

$caseId='d58f439b-f189-f111-ab10-000d3a189124'
$contactId='910cc7a7-f189-f111-ab10-000d3a189124'

$caseXml=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms($caseId)?`$select=formxml" -Headers $h).formxml
$contactXml=(Invoke-RestMethod -Method Get -Uri "$url/api/data/v9.2/systemforms($contactId)?`$select=formxml" -Headers $h).formxml

# Validate human labels are present
Write-Output ("CASE_LABEL_DiscrepancyType=" + ($caseXml -match 'description="Discrepancy Type"'))
Write-Output ("CASE_LABEL_RiskRating=" + ($caseXml -match 'description="Risk Rating"'))
Write-Output ("CASE_LABEL_CaseDisposition=" + ($caseXml -match 'description="Case Disposition"'))
Write-Output ("CASE_LABEL_SupervisorApproval=" + ($caseXml -match 'description="Supervisor Approval"'))
Write-Output ("CONTACT_LABEL_SSN=" + ($contactXml -match 'description="SSN"'))

# Validate section labels are meaningful
Write-Output ("CASE_SECTION_LABEL_OK=" + ($caseXml -match 'description="Fraud Review"'))
Write-Output ("CONTACT_SECTION_LABEL_OK=" + ($contactXml -match 'description="Fraud Profile"'))

# Validate old schema-name labels are not used in labels
Write-Output ("CASE_SCHEMA_LABEL_PRESENT=" + ($caseXml -match 'description="earnint_discrepancytype"|description="earnint_riskrating"|description="earnint_casedisposition"|description="earnint_supervisorapproval"'))
Write-Output ("CONTACT_SCHEMA_LABEL_PRESENT=" + ($contactXml -match 'description="earnint_ssn"'))