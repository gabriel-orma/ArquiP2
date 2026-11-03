# =====================================================================
# crear_proyecto_dual.tcl -- Proyecto Vivado del FRONT-END DUAL (evidencia 5.4)
# Dual Fetch + Dual Decode preliminar. Muestra en waveform las 2 vias
# decodificando 2 instrucciones en el mismo ciclo.
#
# USO (consola Tcl de Vivado):
#     cd <ruta a esta carpeta vivado>
#     source crear_proyecto_dual.tcl
# =====================================================================

if {![info exists PART]} { set PART "xc7a35tcpg236-1" }
set PROG "prog_forward.dat"
set TB   "tb_dual_fetch_decode"
set PROJ "dual_e1"

set origin  [file normalize [file dirname [info script]]]
set projdir [file join $origin $PROJ]

puts "== Dual preliminar: creando proyecto '$PROJ' =="
catch { close_sim -quiet }
catch { close_project }
if {[file exists $projdir]} { file delete -force $projdir }

create_project $PROJ $projdir -part $PART -force

# fuentes: modulos reusados del pipeline (src) + especificos del dual (dual)
add_files -norecurse [glob [file join $origin src *.v]]
add_files -norecurse [glob [file join $origin dual *.v]]
update_compile_order -fileset sources_1

# simulacion: SOLO el testbench dual
add_files -fileset sim_1 -norecurse [file join $origin tb tb_dual_fetch_decode.v]
set_property top $TB [get_filesets sim_1]
update_compile_order -fileset sim_1
set_property -name {xsim.simulate.runtime} -value {150ns} -objects [get_filesets sim_1]

# programa (imem2 lee riscvtest.dat)
set xsimdir [file join $projdir "$PROJ.sim" sim_1 behav xsim]
file mkdir $xsimdir
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

launch_simulation
file copy -force [file join $origin mem $PROG] [file join $xsimdir riscvtest.dat]

# ---------- waveform: SOLO las senales del dual decode ----------
catch { remove_wave [get_waves *] }
set tb /${TB}
catch { add_wave [get_objects $tb/clk] }
catch { add_wave [get_objects $tb/reset] }
catch { add_wave [get_objects $tb/PCF] }
# via 0
catch { add_wave [get_objects $tb/dut/Instr0D] }
catch { add_wave [get_objects $tb/dut/Rd0D] }
catch { add_wave [get_objects $tb/dut/RegWrite0D] }
# via 1
catch { add_wave [get_objects $tb/dut/Instr1D] }
catch { add_wave [get_objects $tb/dut/Rd1D] }
catch { add_wave [get_objects $tb/dut/RegWrite1D] }
# radix (PCF y Rd en decimal; las Instr quedan en hex)
foreach s "$tb/PCF $tb/dut/Rd0D $tb/dut/Rd1D" {
  catch { set_property RADIX unsigned [get_waves $s] }
}

restart
run 150ns
puts "== EVIDENCIA: en PC=8, Instr0D=addi x1 (Rd0D=1, RegWrite0D=1) y a la vez Instr1D=addi x2 (Rd1D=2, RegWrite1D=1). =="
