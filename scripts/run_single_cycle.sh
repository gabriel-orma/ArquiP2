#!/usr/bin/env bash
# Compila y simula el single-cycle con Icarus Verilog y reporta PASS/FAIL.
# Uso (Git Bash):  bash scripts/run_single_cycle.sh
set -e

export PATH="/c/iverilog/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/src/single_cycle"   # riscvtest.dat se lee por ruta relativa

iverilog -g2001 -o build_single.vvp *.v
OUT="$(printf 'finish\n' | vvp build_single.vvp 2>&1)"
echo "$OUT"
rm -f build_single.vvp

if echo "$OUT" | grep -q "Simulation succeeded"; then
  echo ""
  echo "==> PASS: el single-cycle escribio 25 en la direccion 100."
else
  echo ""
  echo "==> FAIL: no se detecto 'Simulation succeeded'."
  exit 1
fi
