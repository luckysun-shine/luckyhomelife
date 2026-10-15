param([Parameter(Mandatory = $true)][string]$BaseUrl)
$ErrorActionPreference = 'Stop'
$health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get
if ($health.status -ne 'ok') { throw '健康检查未返回 ok。' }
Write-Host "API 健康检查通过：$($health.timestamp)"
