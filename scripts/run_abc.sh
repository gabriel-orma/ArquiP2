#!/usr/bin/env bash
# run_abc.sh: mide ciclos de las configuraciones A, B y C (y el single-cycle como
# oraculo de instrucciones retiradas) sobre los programas indicados, con Icarus.
# Uso:  bash scripts/run_abc.sh [prog1 prog2 ...]   (nombres de mem/<prog>.dat)
# Por defecto mide ef_prog1 (propio) y demo_profesor (del profesor).
set -e
cd "$(dirname "$0")/.."                 # raiz del repo
ROOT="$(pwd)"
IV="${IVERILOG:-iverilog}"             # exporta IVERILOG si no esta en PATH
VVP="${VVP:-vvp}"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

PROGS=("${@:-}")
[ -z "${PROGS[*]}" ] && PROGS=(ef_prog1 demo_profesor)

PIPE="$ROOT/src/pipeline/controller.v $ROOT/src/pipeline/maindec.v $ROOT/src/pipeline/aludec.v $ROOT/src/pipeline/alu.v $ROOT/src/pipeline/extend.v $ROOT/src/pipeline/flopr.v $ROOT/src/pipeline/floprc.v $ROOT/src/pipeline/flopenrc.v $ROOT/src/pipeline/flopenr.v $ROOT/src/pipeline/mux2.v $ROOT/src/pipeline/mux3.v $ROOT/src/pipeline/dmem.v $ROOT/src/pipeline/adder.v"
DUAL="$ROOT/src/dual_issue/issueunit.v $ROOT/src/dual_issue/regfile2w.v $ROOT/src/dual_issue/imem2.v"
OPT="$ROOT/src/dual_issue_opt/bpredictor.v $ROOT/src/dual_issue_opt/btb.v $ROOT/src/dual_issue_opt/top_dual_opt.v $ROOT/src/dual_issue_opt/datapath_dual_opt.v"
SC=$(ls "$ROOT"/src/single_cycle/*.v | grep -v testbench.v | tr '\n' ' ')
TB="$ROOT/tb/tb_count.v"

cd "$BUILD"
$IV -g2001 -DSINGLE -o sc.out "$TB" $SC
$IV -g2001 -DSINGLE -o a.out  "$TB" $PIPE "$ROOT/src/pipeline/imem.v" "$ROOT/src/pipeline/regfile.v" "$ROOT/src/pipeline/datapath.v" "$ROOT/src/pipeline/riscvsingle.v" "$ROOT/src/pipeline/hazardunit.v" "$ROOT/src/pipeline/top.v"
$IV -g2001        -o b.out "$TB" $PIPE $DUAL "$ROOT/src/dual_issue/top_dual.v" "$ROOT/src/dual_issue/datapath_dual.v"
$IV -g2001 -DOPT  -o c.out "$TB" $PIPE $DUAL $OPT

cyc(){ $VVP "$1" 2>/dev/null | grep RESULTADO | sed -E 's/.*Mem\[100\]=([0-9]+)  CICLOS=([0-9]+)/\1 \2/'; }

for prog in "${PROGS[@]}"; do
  cp "$ROOT/mem/${prog}.dat" riscvtest.dat
  read RET_R RET <<< "$(cyc sc.out)"
  read AR AC    <<< "$(cyc a.out)"          # ciclos de A = referencia del speedup
  echo "==================== $prog  (Mem[100]=$RET_R, retiradas=$RET) ===================="
  printf "%-18s %8s %8s %8s %8s\n" "config" "ciclos" "CPI" "IPC" "spdup"
  for cfg in "A a.out" "B b.out" "C c.out"; do
    set -- $cfg; name=$1; out=$2
    read R C <<< "$(cyc $out)"
    [ "$R" != "$RET_R" ] && name="${name}(!=)"      # marca si el resultado difiere
    cpi=$(awk "BEGIN{printf \"%.2f\", $C/$RET}")
    ipc=$(awk "BEGIN{printf \"%.2f\", $RET/$C}")
    sp=$(awk "BEGIN{printf \"%.2f\", $AC/$C}")
    printf "%-18s %8s %8s %8s %7sx\n" "$name" "$C" "$cpi" "$ipc" "$sp"
  done
done
