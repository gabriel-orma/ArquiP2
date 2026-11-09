# =====================================================================
# crear_proyecto_dual_e2.tcl -- Proyecto Vivado de la Configuracion B
#                               (procesador SUPERESCALAR dual-issue in-order)
#
# Genera el proyecto desde los fuentes .v (NO se entrega un .xpr, para que
# funcione en cualquier version de Vivado). Verificado en Icarus Verilog;
# NO probado en Vivado desde el entorno de desarrollo.
#
# ---------------------------------------------------------------------
# USO (consola Tcl de Vivado):
#     cd <ruta a esta carpeta vivado>
#     source crear_proyecto_dual_e2.tcl
#
#   o en batch (sin GUI):
#     vivado -mode batch -source crear_proyecto_dual_e2.tcl
#
# Para elegir OTRO programa de prueba, define PROG antes del source:
#     set PROG e2_test3_loaduse_mem.dat ; source crear_proyecto_dual_e2.tcl
#
#   Los 6 programas de la rubrica (todos con el MISMO testbench de traza):
#     e2_test1_dualalu.dat      -> 2 ALU independientes (emite 2)      Mem[100]=12
#     e2_test2_raw_fwd.dat      -> RAW + forwarding                    Mem[100]=40
#     e2_test3_loaduse_mem.dat  -> load-use (stall) + conflicto mem    Mem[100]=14
#     e2_test4_branch_flush.dat -> branch tomado + flush/anulacion     Mem[100]=42
#     e2_test5_2writes.dat      -> 2 escrituras (gana via 1)           Mem[100]=7
#     e2_test6_reagrupa.dat     -> reagrupamiento (emite 1 repetido)   Mem[100]=5
# =====================================================================

# ---------- parametros (editables antes del source) ----------
if {![info exists PART]} { set PART "xc7a35tcpg236-1" }       ;# 7 Series (Basys3). Cambia si tu Vivado no lo tiene.
if {![info exists PROG]} { set PROG "e2_test1_dualalu.dat" }  ;# programa a cargar en imem2
set TB   "tb_dual_trace"
set PROJ "dual_e2"

set origin  [file normalize [file dirname [info script]]]
set projdir [file join $origin $PROJ]

puts "== Config B (dual-issue): creando proyecto '$PROJ'  part=$PART  prog=$PROG =="

catch { close_sim -quiet }
catch { close_project }
if {[file exists $projdir]} { file delete -force $projdir }

create_project $PROJ $projdir -part $PART -force

# ---------- fuentes de diseno (dual-issue) ----------
add_files -norecurse [glob [file join $origin src_e2 *.v]]
set_property top top_dual [get_filesets sources_1]
update_compile_order -fileset sources_1

# ---------- fuentes de simulacion (testbench de traza) ----------
add_files -fileset sim_1 -norecurse [glob [file join $origin tb_e2 *.v]]
set_property top $TB [get_filesets sim_1]
update_compile_order -fileset sim_1

# tiempo de simulacion (el default de Vivado es 1000 ns; aqui 400 ns bastan)
set_property -name {xsim.simulate.runtime} -value {400ns} -objects [get_filesets sim_1]

# ---------- cargar el programa como riscvtest.dat ----------
# imem2.v hace $readmemh("riscvtest.dat") con ruta RELATIVA al dir donde corre
# xsim: <proj>.sim/sim_1/behav/xsim . Copiamos alli el .dat elegido.
set xsimdir [file join $projdir "$PROJ.sim" sim_1 behav xsim]
file mkdir $xsimdir
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

# ---------- lanzar simulacion behavioral ----------
launch_simulation
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

# ---------- waveform: SOLO senales relevantes, instrucciones en TEXTO ----------
catch { remove_wave [get_waves *] }

set tb /${TB}
set dp /${TB}/dut/dp

# 1) base
foreach s {clk reset} { catch { add_wave [get_objects $tb/$s] } }

# 2) decision de emision (cuantas instrucciones salen este ciclo) + banderas
foreach s {PCF issueCountOut stall flushDE annul1} {
  catch { add_wave [get_objects $dp/$s] }
}
catch { set_property RADIX unsigned [get_waves $dp/PCF] }
catch { set_property RADIX unsigned [get_waves $dp/issueCountOut] }

# 3) TRACE en TEXTO: instruccion (ASCII) en cada etapa de cada via.
#    via 0: t0F t0E t0M t0W   |   via 1: t1F t1E t1M t1W
#    radix ASCII = se lee el mnemonico (addi, lw, beq, bubble...) en vez de hex.
foreach s {t0F t0E t0M t0W t1F t1E t1M t1W} {
  catch {
    set w [add_wave [get_objects $tb/$s]]
    set_property RADIX ascii $w
  }
}

# 4) resultado final (acceso a memoria de datos)
foreach s {MemWrite DataAdr WriteData} { catch { add_wave [get_objects $tb/dut/$s] } }
catch { set_property RADIX unsigned [get_waves $tb/dut/DataAdr] }
catch { set_property RADIX unsigned [get_waves $tb/dut/WriteData] }

restart
run 400ns

puts "== Listo. En la consola veras la traza por ciclo y el estado final. =="
puts "== En la waveform, pon las senales t0*/t1* en radix ASCII si no quedaron. =="
