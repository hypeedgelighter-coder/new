$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot 'build\impl'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Push-Location $buildDir
try {
    & vivado -mode batch -nojournal -log impl.log -source (Join-Path $projectRoot 'syn\impl_fpga.tcl')
    if ($LASTEXITCODE -ne 0) { throw 'Vivado implementation failed' }
    Select-String -Path (Join-Path $buildDir 'impl.log') -Pattern '^IMPL_RESULT' | ForEach-Object { $_.Line }
    Write-Host "PASS: implementation reports are in $buildDir" -ForegroundColor Green
} finally {
    Pop-Location
}
