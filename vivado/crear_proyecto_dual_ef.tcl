# =====================================================================
# crear_proyecto_dual_ef.tcl -- Proyecto Vivado de la Configuracion C
#   (dual-issue in-order + PREDICTOR DE 2 BITS + BTB)
#
# Genera el proyecto desde los fuentes .v (NO se entrega un .xpr, para que
# funcione en cualquier version de Vivado). Verificado en Icarus Verilog;
# NO probado en Vivado desde el entorno de desarrollo.
#
# ---------------------------------------------------------------------
# USO (consola Tcl de Vivado):
#     cd <ruta a esta carpeta vivado>
#     source crear_proyecto_dual_ef.tcl
#
#   o en batch (sin GUI):
#     vivado -mode batch -source crear_proyecto_dual_ef.tcl
#
# Para elegir OTRO programa, define PROG antes del source:
#     set PROG ef_prog1.dat ; source crear_proyecto_dual_ef.tcl
#
#   Programas disponibles (mismo testbench de traza):
#     ef_loop.dat       -> bucle: el predictor BRILLA (PREDICE vs MISPRED)   Mem[100]=24
#     ef_prog1.dat      -> propio: arreglo + bucle (ALU dual, load-use)      Mem[100]=30
#     demo_profesor.dat -> riscvtest de Harris (sin modificar)              Mem[100]=25
# =====================================================================

# ---------- parametros (editables antes del source) ----------
if {![info exists PART]} { set PART "xc7a35tcpg236-1" }   ;# 7 Series (Basys3). Cambia si tu Vivado no lo tiene.
if {![info exists PROG]} { set PROG "ef_loop.dat" }       ;# programa a cargar en imem2
set TB   "tb_dual_opt_trace"
if {![info exists PROJ]} { set PROJ "dual_ef" }

set origin  [file normalize [file dirname [info script]]]
set projdir [file join $origin $PROJ]

puts "== Config C (dual + predictor 2b + BTB): creando '$PROJ'  part=$PART  prog=$PROG =="

# cierra proyecto/simulacion solo si hay alguno abierto (evita error en batch)
if {[llength [get_projects -quiet]] > 0} {
  catch { close_sim -quiet }
  catch { close_project }
}
if {[file exists $projdir]} { file delete -force $projdir }

create_project $PROJ $projdir -part $PART -force

# ---------- fuentes de diseno (config C) ----------
add_files -norecurse [glob [file join $origin src_ef *.v]]
set_property top top_dual_opt [get_filesets sources_1]
update_compile_order -fileset sources_1

# ---------- fuentes de simulacion (testbench de traza) ----------
add_files -fileset sim_1 -norecurse [glob [file join $origin tb_ef *.v]]
set_property top $TB [get_filesets sim_1]
update_compile_order -fileset sim_1

# tiempo de simulacion (el default de Vivado es 1000 ns; aqui 600 ns bastan)
set_property -name {xsim.simulate.runtime} -value {600ns} -objects [get_filesets sim_1]

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

# 2) emision + banderas (flushDE ahora = mala prediccion)
foreach s {PCF issueCountOut stall flushDE annul1} {
  catch { add_wave [get_objects $dp/$s] }
}
catch { set_property RADIX unsigned [get_waves $dp/PCF] }
catch { set_property RADIX unsigned [get_waves $dp/issueCountOut] }

# 3) PREDICCION: la estrella de la config C
#    predTakenPkt = IF predijo salto tomado (redirige el fetch)
#    btb_hit0/1   = el PC estaba en el BTB (ya se vio ese branch)
#    mispred0/1   = la prediccion fallo (unico flush real)
foreach s {predTakenPkt predAnnul1 btb_hit0 btb_hit1 mispred0 mispred1} {
  catch { add_wave [get_objects $dp/$s] }
}

# 4) TRACE en TEXTO: instruccion (ASCII) en cada etapa de cada via.
#    radix ASCII = se lee el mnemonico (addi, lw, beq, bubble...) en vez de hex.
foreach s {t0F t0E t0M t0W t1F t1E t1M t1W} {
  catch {
    set w [add_wave [get_objects $tb/$s]]
    set_property RADIX ascii $w
  }
}

# 5) resultado final (acceso a memoria de datos)
foreach s {MemWrite DataAdr WriteData} { catch { add_wave [get_objects $tb/dut/$s] } }
catch { set_property RADIX unsigned [get_waves $tb/dut/DataAdr] }
catch { set_property RADIX unsigned [get_waves $tb/dut/WriteData] }

restart
run 600ns

puts "== Listo. En la consola veras la traza por ciclo (PREDICE / MISPRED) y el estado final. =="
puts "== En la waveform, pon t0*/t1* en radix ASCII si no quedaron. =="
