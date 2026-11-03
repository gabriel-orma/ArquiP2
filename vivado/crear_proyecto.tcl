# =====================================================================
# crear_proyecto.tcl -- Proyecto Vivado de la Configuracion A
#                       (pipeline RV32I de 5 etapas + Hazard Unit)
#
# Genera el proyecto desde los fuentes .v (NO se entrega un .xpr, para que
# funcione en cualquier version de Vivado). Verificado en Icarus Verilog;
# NO probado en Vivado desde el entorno de desarrollo.
#
# ---------------------------------------------------------------------
# USO (consola Tcl de Vivado):
#     cd <ruta a esta carpeta vivado>
#     source crear_proyecto.tcl
#
#   o en batch (sin GUI):
#     vivado -mode batch -source crear_proyecto.tcl
#
# Para elegir OTRO programa/testbench, define las variables ANTES del source:
#     set PROG prog_stall.dat ; set TB tb_pipeline_stall ; source crear_proyecto.tcl
#
#   Combinaciones validas (programa  ->  testbench):
#     prog_nohazard.dat  ->  tb_pipeline_nohazard   (ISA sin dependencias, Mem[100]=25)
#     prog_forward.dat   ->  tb_pipeline_forward    (forwarding,            Mem[100]=28)
#     prog_stall.dat     ->  tb_pipeline_stall      (load-use,              Mem[100]=14)
#     prog_flush.dat     ->  tb_pipeline_flush      (branch flush,          Mem[100]=5)
#
#   DEMO VISUAL del flujo por etapas (muestra la instruccion en texto en F/D/E/M/W):
#     prog_stall.dat     ->  tb_pipeline_trace      (se ve la burbuja del load-use)
#     (sirve con cualquier prog_*.dat; usa radix ASCII en txtF..txtW)
# =====================================================================

# ---------- parametros (editables antes del source) ----------
if {![info exists PART]} { set PART "xc7a35tcpg236-1" }    ;# 7 Series (Basys3). Cambia si tu Vivado no lo tiene.
if {![info exists PROG]} { set PROG "prog_forward.dat" }    ;# programa a cargar en la imem
if {![info exists TB]}   { set TB   "tb_pipeline_forward" } ;# modulo top de simulacion
set PROJ "pipeline_e1"

set origin  [file normalize [file dirname [info script]]]
set projdir [file join $origin $PROJ]

puts "== Config A: creando proyecto '$PROJ'  part=$PART  prog=$PROG  tb=$TB =="

# cierra simulacion/proyecto abiertos (para poder re-correr este script sin error)
catch { close_sim -quiet }
catch { close_project }

# borra un proyecto previo con el mismo nombre
if {[file exists $projdir]} { file delete -force $projdir }

create_project $PROJ $projdir -part $PART -force

# ---------- fuentes de diseno ----------
add_files -norecurse [glob [file join $origin src *.v]]
set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1

# ---------- fuentes de simulacion (los 4 testbenches) ----------
add_files -fileset sim_1 -norecurse [glob [file join $origin tb *.v]]
set_property top $TB [get_filesets sim_1]
update_compile_order -fileset sim_1

# tiempo de simulacion por defecto (el default de Vivado es 1000 ns, aqui 2000 ns)
set_property -name {xsim.simulate.runtime} -value {2000ns} -objects [get_filesets sim_1]

# ---------- cargar el programa como riscvtest.dat ----------
# imem.v hace $readmemh("riscvtest.dat") con ruta RELATIVA al directorio donde
# corre xsim: <proj>.sim/sim_1/behav/xsim . Copiamos alli el .dat elegido.
set xsimdir [file join $projdir "$PROJ.sim" sim_1 behav xsim]
file mkdir $xsimdir
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

# ---------- lanzar simulacion behavioral ----------
launch_simulation

# por si el launch regenero la carpeta, re-copiamos el .dat y reiniciamos
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

# ---------- waveform: deja SOLO las senales relevantes ----------
# 1) limpia TODO lo que Vivado auto-agrego (duplicados, senales de mas)
catch { remove_wave [get_waves *] }

set tb /${TB}
set dp /${TB}/dut/rvsingle/dp

# 2) senales base (siempre)
foreach s {clk reset}  { catch { add_wave [get_objects $tb/$s] } }
foreach s {PC Instr}   { catch { add_wave [get_objects $tb/dut/$s] } }

# 3) senales ESPECIFICAS segun el hazard que prueba este testbench
if {$TB eq "tb_pipeline_forward"} {
  set hz {ForwardAE ForwardBE SrcAE ALUResultM ResultW StallF}
} elseif {$TB eq "tb_pipeline_stall"} {
  set hz {StallF StallD FlushE ForwardAE ForwardBE}
} elseif {$TB eq "tb_pipeline_flush"} {
  set hz {PCSrcE FlushD FlushE PCTargetE}
} else {
  set hz {}
}
foreach s $hz { catch { add_wave [get_objects $dp/$s] } }

# 3b) TRACE: instruccion (en TEXTO) presente en cada etapa F/D/E/M/W,
#     mas las senales que explican las burbujas. radix ASCII = se lee el mnemonico.
if {$TB eq "tb_pipeline_trace"} {
  foreach s {txtF txtD txtE txtM txtW} {
    catch {
      set w [add_wave [get_objects $tb/$s]]   ;# captura el objeto wave creado
      set_property RADIX ascii $w              ;# ASCII = se lee el mnemonico
    }
  }
  foreach s {StallF StallD FlushD FlushE PCSrcE} { catch { add_wave [get_objects $dp/$s] } }
}

# 4) resultado final (siempre)
foreach s {MemWrite DataAdr WriteData} { catch { add_wave [get_objects $tb/dut/$s] } }

# 5) radix decimal en las senales de datos (best-effort; si falla, se hace por GUI)
foreach s "$tb/dut/PC $tb/dut/WriteData $tb/dut/DataAdr $dp/SrcAE $dp/ALUResultM $dp/ResultW $dp/PCTargetE" {
  catch { set_property RADIX unsigned [get_waves $s] }
}

restart
run 2000ns

puts "== Listo. Revisa la consola (PASS/FAIL) y la waveform. =="
