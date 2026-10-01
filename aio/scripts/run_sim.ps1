$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot 'build\sim'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$sources = @(
    (Join-Path $projectRoot 'rtl\ecc\secded_ecc_32.sv'),
    (Join-Path $projectRoot 'rtl\aio_nand_dma_ctrl.sv'),
    (Join-Path $projectRoot 'testbench\tb_secded_ecc_32.sv'),
    (Join-Path $projectRoot 'testbench\tb_aio_nand_dma_ctrl.sv')
)

Push-Location $buildDir
try {
    & xvlog -sv @sources
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }

    & xelab tb_secded_ecc_32 -s tb_secded_ecc_32_sim
    if ($LASTEXITCODE -ne 0) { throw 'ECC xelab failed' }

    & xsim tb_secded_ecc_32_sim -runall -log ecc_simulation.log
    if ($LASTEXITCODE -ne 0) { throw 'ECC xsim failed' }

    $eccResult = Get-Content -LiteralPath (Join-Path $buildDir 'ecc_simulation.log') -Raw
    if ($eccResult -notmatch 'PASS: ECC RTL exhaustive single-bit regression') {
        throw 'ECC simulation ended without the expected PASS signature'
    }

    & xelab tb_aio_nand_dma_ctrl -s tb_aio_nand_dma_ctrl_sim
    if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }

    & xsim tb_aio_nand_dma_ctrl_sim -runall -log simulation.log
    if ($LASTEXITCODE -ne 0) { throw 'xsim failed' }

    $result = Get-Content -LiteralPath (Join-Path $buildDir 'simulation.log') -Raw
    if ($result -notmatch 'PASS: 8 end-to-end scenarios completed') {
        throw 'simulation ended without the expected PASS signature'
    }
    Write-Host 'PASS: RTL regression completed.' -ForegroundColor Green
} finally {
    Pop-Location
}
