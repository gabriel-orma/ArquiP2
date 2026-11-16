# =====================================================================
# crear_proyecto.tcl -- Proyecto Vivado UNICO para la EF.
# Contiene los TRES modelos (A pipeline, B dual-issue, C dual+predictor+BTB)
# y VARIOS testbenches. Se ejecuta UNA SOLA VEZ.
#
# Despues, en Vivado NO hace falta re-ejecutar nada: en "Simulation Sources"
# eliges el testbench que quieras (click derecho -> Set as Top) y le das
# Run Simulation. Cada testbench ya trae fijado su modelo y su programa.
#
# USO (una vez):
#   vivado -mode batch -source crear_proyecto.tcl
#   o en la consola Tcl de Vivado:  cd <esta carpeta> ; source crear_proyecto.tcl
#
# Verificado en Icarus Verilog; NO probado en Vivado desde el entorno de
# desarrollo (puede requerir ajustar la parte FPGA).
# =====================================================================

if {![info exists PART]} { set PART "xc7a35tcpg236-1" }   ;# Basys3. Cambia si no la tienes.
if {![info exists PROJ]} { set PROJ "ef_dual" }

set origin  [file normalize [file dirname [info script]]]
set projdir [file join $origin $PROJ]

if {[llength [get_projects -quiet]] > 0} { catch { close_sim -quiet }; catch { close_project } }
if {[file exists $projdir]} { file delete -force $projdir }
create_project $PROJ $projdir -part $PART -force

# ---------- diseno: los 3 modelos (deduplicado, sin colisiones) ----------
add_files -norecurse [glob [file join $origin src *.v]]
update_compile_order -fileset sources_1

# ---------- simulacion: todos los testbenches + los programas ----------
add_files -fileset sim_1 -norecurse [glob [file join $origin tb *.v]]
add_files -fileset sim_1 -norecurse [glob [file join $origin mem *.dat]]
set_property top tb_C_prof [get_filesets sim_1]       ;# top por defecto (cambialo en la GUI)
update_compile_order -fileset sim_1
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# ---------- copia los .dat al dir de simulacion (por si Vivado no los copia) ----------
set xsimdir [file join $projdir "$PROJ.sim" sim_1 behav xsim]
file mkdir $xsimdir
foreach f [glob [file join $origin mem *.dat]] { catch { file copy -force $f $xsimdir } }

puts "==================================================================="
puts " Proyecto '$PROJ' creado: 3 modelos (A/B/C) + 7 testbenches."
puts ""
puts " Para simular (sin re-ejecutar este script):"
puts "   1. Flow Navigator -> SIMULATION -> Simulation Sources."
puts "   2. Click derecho en el testbench que quieras -> Set as Top."
puts "   3. Run Simulation -> Run Behavioral Simulation."
puts ""
puts " Testbenches disponibles (modelo + programa):"
puts "   tb_A_prof / tb_B_prof / tb_C_prof   -> programa del profesor"
puts "   tb_A_prog1 / tb_B_prog1 / tb_C_prog1 -> programa propio"
puts "   tb_C_loop                           -> demo del predictor (bucle)"
puts "==================================================================="
