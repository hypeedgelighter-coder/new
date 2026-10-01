$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot 'build\synth'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Push-Location $buildDir
try {
    & vivado -mode batch -nojournal -nolog -source (Join-Path $projectRoot 'syn\synth.tcl')
    if ($LASTEXITCODE -ne 0) { throw 'Vivado synthesis failed' }
    Write-Host "PASS: synthesis reports are in $buildDir" -ForegroundColor Green
} finally {
    Pop-Location
}
