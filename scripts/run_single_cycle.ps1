# run_single_cycle.ps1
# Compila y simula el single-cycle con Icarus Verilog y reporta PASS/FAIL.
# Uso (desde cualquier carpeta):  powershell -ExecutionPolicy Bypass -File scripts\run_single_cycle.ps1
$ErrorActionPreference = "Stop"

# Localiza iverilog/vvp (en PATH o en la instalacion por defecto de winget)
$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue).Source
if (-not $iverilog) { $iverilog = "C:\iverilog\bin\iverilog.exe" }
$vvp = (Get-Command vvp -ErrorAction SilentlyContinue).Source
if (-not $vvp) { $vvp = "C:\iverilog\bin\vvp.exe" }

if (-not (Test-Path $iverilog)) { throw "No se encontro iverilog. Instala Icarus Verilog o ajusta la ruta." }

$root = Split-Path -Parent $PSScriptRoot
$sc = Join-Path $root "src\single_cycle"
Push-Location $sc
try {
    # $readmemh usa ruta relativa, por eso corremos desde src\single_cycle (ahi esta riscvtest.dat)
    $srcs = Get-ChildItem -Filter *.v | ForEach-Object { $_.Name }
    & $iverilog -g2001 -o build_single.vvp $srcs
    if ($LASTEXITCODE -ne 0) { throw "Error de compilacion" }

    # El testbench termina con $stop; le damos 'finish' por stdin para que vvp no quede interactivo.
    # (No usamos 2>&1: en Windows PowerShell fusionar el stderr de un .exe lanza NativeCommandError.)
    $out = "finish" | & $vvp build_single.vvp
    $out | Write-Host

    if ($out -match "Simulation succeeded") {
        Write-Host "`n==> PASS: el single-cycle escribio 25 en la direccion 100." -ForegroundColor Green
    } else {
        Write-Host "`n==> FAIL: no se detecto 'Simulation succeeded'." -ForegroundColor Red
        exit 1
    }
} finally {
    Remove-Item -Force build_single.vvp -ErrorAction SilentlyContinue
    Pop-Location
}
