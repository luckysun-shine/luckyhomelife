$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

Write-Host '1/5 服务端类型检查'
Push-Location (Join-Path $root 'server')
try { npm run typecheck } finally { Pop-Location }

Write-Host '2/5 服务端单元测试'
Push-Location (Join-Path $root 'server')
try { npm test } finally { Pop-Location }

Write-Host '3/5 移动端静态检查与测试'
Push-Location (Join-Path $root 'mobile')
try {
  flutter analyze
  flutter test
} finally { Pop-Location }

Write-Host '4/5 部署配置检查'
& (Join-Path $PSScriptRoot 'preflight.ps1')

Write-Host '5/5 运行中服务冒烟检查'
& (Join-Path $PSScriptRoot 'smoke-test.ps1')

Write-Host 'P0 自动验收通过。请继续按 docs/P0_ACCEPTANCE_CHECKLIST.md 完成人工场景。'
