$ErrorActionPreference = 'Stop'
$required = @('APP_DOMAIN', 'POSTGRES_PASSWORD', 'JWT_SECRET')
$envPath = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path -LiteralPath $envPath)) { throw '缺少 .env，请从 .env.example 创建并填写。' }
$values = @{}
Get-Content -LiteralPath $envPath | ForEach-Object { if ($_ -match '^([^#=]+)=(.*)$') { $values[$matches[1].Trim()] = $matches[2].Trim() } }
foreach ($name in $required) { if (-not $values.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($values[$name]) -or $values[$name] -like 'replace-*') { throw "环境变量 $name 尚未安全配置。" } }
if ($values['ALLOW_DEV_LOGIN'] -ne 'false') { throw '正式部署必须设置 ALLOW_DEV_LOGIN=false。' }
if ($values['JWT_SECRET'].Length -lt 32) { throw 'JWT_SECRET 至少需要 32 个字符。' }
docker compose -f compose.yaml -f compose.production.yaml config --quiet
Write-Host '部署前检查通过。'

