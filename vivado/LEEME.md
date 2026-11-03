# Paquete Vivado — Configuración A (pipeline + Hazard Unit)

> ⚠️ **Verificado en Icarus Verilog, NO probado en Vivado desde el entorno de desarrollo.**
> Pruébalo en tu PC y reporta errores. No se entrega un `.xpr` a propósito: un `.xpr`
> trae rutas absolutas y depende de la versión de Vivado. El script `.tcl` reconstruye
> el proyecto en **cualquier versión** (por eso corre igual en las PCs de la universidad).

## Contenido
```
vivado/
├── crear_proyecto.tcl   # crea el proyecto, agrega fuentes, simula
├── LEEME.md             # este archivo
├── src/                 # 19 fuentes .v (pipeline + Hazard Unit)
├── tb/                  # 4 testbenches (nohazard, forward, stall, flush)
└── mem/                 # 4 programas .dat
```

## Cómo correrlo
1. Abre **Vivado**.
2. En la **consola Tcl** (abajo), ubícate en esta carpeta y corre el script:
   ```tcl
   cd C:/.../Proyecto2/vivado
   source crear_proyecto.tcl
   ```
   (usa `/` en las rutas de Tcl, aunque sea Windows). O sin GUI:
   ```
   vivado -mode batch -source crear_proyecto.tcl
   ```
3. Se crea el proyecto `pipeline_e1/`, se lanza la **simulación behavioral** y corre 2000 ns.
   En la consola verás el mensaje **PASS/FAIL** del testbench.

## Cambiar de programa / testbench
Por defecto corre el de **forwarding**. Para otro, define las variables **antes** del `source`:
```tcl
set PROG prog_stall.dat ; set TB tb_pipeline_stall ; source crear_proyecto.tcl
```
| Programa (`PROG`) | Testbench (`TB`) | Qué demuestra | Mem[100] |
|---|---|---|---|
| `prog_nohazard.dat` | `tb_pipeline_nohazard` | ISA sin dependencias | 25 |
| `prog_forward.dat`  | `tb_pipeline_forward`  | forwarding (dist. 1 y 2) | 28 |
| `prog_stall.dat`    | `tb_pipeline_stall`    | load-use (1 stall) | 14 |
| `prog_flush.dat`    | `tb_pipeline_flush`    | branch tomado (flush ×2) | 5 |

## Señales a mostrar por demostración (en la waveform)
El script ya intenta agregarlas; si no aparecen, arrástralas desde el panel *Scope*.
- **Resultado:** `MemWrite`, `DataAdr`, `WriteData` (la escritura a la dir. 100 con el valor esperado).
- **Etapas / PC:** `dut/PC`, `dut/Instr`.
- **Forwarding:** en `dut/rvsingle/dp` → `ForwardAE`, `ForwardBE`, `SrcAE`, `ALUResultM`, `ResultW`.
- **Stall (load-use):** `StallF`, `StallD`, `FlushE`, y el consumidor esperando 1 ciclo.
- **Flush (branch):** `PCSrcE`, `FlushD`, `FlushE`, `PCTargetE`, y las 2 instrucciones anuladas.

## Si tu Vivado es más viejo que el part elegido
El script usa el part **`xc7a35tcpg236-1`** (7 Series, Basys3), que existe desde ~2015.
Si tu versión no lo tuviera, cambia el part antes del `source`:
```tcl
set PART xc7a100tcsg324-1 ; source crear_proyecto.tcl
```
(cualquier part de 7 Series sirve; la simulación behavioral no depende del part real).

## Riesgos conocidos al pasar de Icarus a Vivado
- **Ruta de `$readmemh`:** `imem.v` lee `riscvtest.dat` con ruta relativa; el script copia el
  `.dat` elegido a la carpeta de ejecución de xsim (`pipeline_e1.sim/sim_1/behav/xsim/`).
  Si Vivado no lo encontrara, copia manualmente `mem/<prog>.dat` ahí como `riscvtest.dat`.
- **Valores `x`:** todos los registros tienen reset; `maindec` usa `default=0` (NOP seguro).
- **Tiempo de simulación:** el script lo fija en 2000 ns (el default de Vivado es 1000 ns).
- **Señales internas:** no se ven por defecto; el script intenta agregarlas a la waveform.
