$ErrorActionPreference='Stop'
$url='https://healthconnectcenter.crm.dynamics.com'
$token=az account get-access-token --resource $url --query accessToken -o tsv
$h=@{Authorization="Bearer $token"; 'Content-Type'='application/json'; Accept='application/json'; 'OData-Version'='4.0'; 'OData-MaxVersion'='4.0'}

Invoke-RestMethod -Method Patch -Uri "$url/api/data/v9.2/systemforms(540b48bd-8087-f111-ab10-000d3a189124)" -Headers $h -Body (@{name='Fraud Analyst Case Form (Standalone)'}|ConvertTo-Json -Compress)
Invoke-RestMethod -Method Patch -Uri "$url/api/data/v9.2/systemforms(3b7d0ac5-8087-f111-ab10-000d3a189124)" -Headers $h -Body (@{name='Supervisor Review Case Form (Standalone)'}|ConvertTo-Json -Compress)

Invoke-RestMethod -Method Patch -Uri "$url/api/data/v9.2/systemforms(227cc47e-cb86-f111-ab10-000d3a189124)" -Headers $h -Body (@{name='Fraud Analyst Case Form'}|ConvertTo-Json -Compress)
Invoke-RestMethod -Method Patch -Uri "$url/api/data/v9.2/systemforms(e801601c-a999-428f-bf86-26bc69c3d5d4)" -Headers $h -Body (@{name='Supervisor Review Case Form'}|ConvertTo-Json -Compress)

Invoke-RestMethod -Method Post -Uri "$url/api/data/v9.2/PublishAllXml" -Headers $h -Body '{}' | Out-Null
Write-Output 'RENAMED_AND_PUBLISHED'