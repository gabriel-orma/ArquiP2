# run_pipeline.ps1
# Compila el pipeline con un programa (.dat de mem/) y un testbench (de tb/),
# y reporta PASS/FAIL. El .dat se copia como riscvtest.dat a la carpeta build.
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\run_pipeline.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\run_pipeline.ps1 -Prog prog_x.dat -Tb tb_x.v
param(
  [string]$Prog = "prog_nohazard.dat",
  [string]$Tb   = "tb_pipeline_nohazard.v"
)
$ErrorActionPreference = "Stop"

$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue).Source
if (-not $iverilog) { $iverilog = "C:\iverilog\bin\iverilog.exe" }
$vvp = (Get-Command vvp -ErrorAction SilentlyContinue).Source
if (-not $vvp) { $vvp = "C:\iverilog\bin\vvp.exe" }

$root  = Split-Path -Parent $PSScriptRoot
$pl    = Join-Path $root "src\pipeline"
$build = Join-Path $root "build"

New-Item -ItemType Directory -Force -Path $build | Out-Null
Copy-Item (Join-Path $root "mem\$Prog") (Join-Path $build "riscvtest.dat") -Force

Push-Location $build
try {
    # fuentes de diseno del pipeline (sin testbench suelto)
    $design = Get-ChildItem $pl -Filter *.v |
              Where-Object { $_.Name -ne "testbench.v" } |
              ForEach-Object { $_.FullName }

    & $iverilog -g2001 -o pipe.vvp $design (Join-Path $root "tb\$Tb")
    if ($LASTEXITCODE -ne 0) { throw "Error de compilacion" }

    $out = & $vvp pipe.vvp
    $out | Write-Host

    if ($out -match "PASS") {
        Write-Host "`n==> PASS" -ForegroundColor Green
    } else {
        Write-Host "`n==> FAIL" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
