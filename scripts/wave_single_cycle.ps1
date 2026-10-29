# wave_single_cycle.ps1
# Compila el single-cycle con el testbench de ondas, genera single_cycle.vcd y abre GTKWave.
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\wave_single_cycle.ps1
$ErrorActionPreference = "Stop"

$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue).Source
if (-not $iverilog) { $iverilog = "C:\iverilog\bin\iverilog.exe" }
$vvp = (Get-Command vvp -ErrorAction SilentlyContinue).Source
if (-not $vvp) { $vvp = "C:\iverilog\bin\vvp.exe" }
$gtkwave = (Get-Command gtkwave -ErrorAction SilentlyContinue).Source
if (-not $gtkwave) { $gtkwave = "C:\iverilog\gtkwave\bin\gtkwave.exe" }

$root  = Split-Path -Parent $PSScriptRoot
$sc    = Join-Path $root "src\single_cycle"
$tb    = Join-Path $root "tb\tb_single_cycle_wave.v"
$build = Join-Path $root "build"

# Carpeta de build aislada (no ensucia src\single_cycle). riscvtest.dat debe estar junto
# al ejecutable porque imem lo lee con ruta relativa ($readmemh).
New-Item -ItemType Directory -Force -Path $build | Out-Null
Copy-Item (Join-Path $sc "riscvtest.dat") $build -Force

Push-Location $build
try {
    # Fuentes de diseno, EXCLUYENDO el testbench original (usamos el de ondas).
    $design = Get-ChildItem $sc -Filter *.v |
              Where-Object { $_.Name -ne "testbench.v" } |
              ForEach-Object { $_.FullName }

    & $iverilog -g2001 -o wave.vvp $design $tb
    if ($LASTEXITCODE -ne 0) { throw "Error de compilacion" }

    $out = & $vvp wave.vvp
    $out | Write-Host

    if (-not (Test-Path "single_cycle.vcd")) { throw "No se genero el VCD" }
    Write-Host "`nVCD generado: $build\single_cycle.vcd" -ForegroundColor Green

    # Abre GTKWave con el layout de senales si existe el .gtkw.
    $gtkw = Join-Path $root "scripts\single_cycle.gtkw"
    if (Test-Path $gtkw) {
        Copy-Item $gtkw $build -Force
        & $gtkwave "single_cycle.vcd" "single_cycle.gtkw"
    } else {
        & $gtkwave "single_cycle.vcd"
    }
} finally {
    Pop-Location
}
