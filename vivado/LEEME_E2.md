# Paquete Vivado — Configuración B (dual-issue in-order, E2)

> ⚠️ **Verificado en Icarus Verilog, NO probado en Vivado desde el entorno de desarrollo.**
> Pruébalo en tu PC y reporta errores. No se entrega un `.xpr` a propósito: un `.xpr`
> trae rutas absolutas y depende de la versión de Vivado. El script `.tcl` reconstruye
> el proyecto en **cualquier versión** (por eso corre igual en las PCs de la universidad).

## Contenido
```
vivado/
├── crear_proyecto_dual_e2.tcl   # crea el proyecto E2, agrega fuentes, simula
├── LEEME_E2.md                  # este archivo
├── src_e2/                      # fuentes del dual-issue (17 .v)
├── tb_e2/                       # testbench de traza (tb_dual_trace.v)
└── mem/                         # 6 programas e2_test*.dat
```

## Cómo correrlo
1. Abre **Vivado**.
2. En la **consola Tcl** (abajo), ubícate en esta carpeta y corre el script:
   ```tcl
   cd C:/.../Proyecto2/vivado
   source crear_proyecto_dual_e2.tcl
   ```
   (usa `/` en las rutas de Tcl, aunque sea Windows). O sin GUI:
   ```
   vivado -mode batch -source crear_proyecto_dual_e2.tcl
   ```
3. Se crea el proyecto `dual_e2/`, se lanza la **simulación behavioral** y corre 400 ns.
   En la **consola Tcl** verás la **traza por ciclo** (qué instrucción está en cada etapa
   de cada vía, en texto) y el estado final.

## Elegir otro programa de prueba
Define `PROG` **antes** del `source`:
```tcl
set PROG e2_test4_branch_flush.dat ; source crear_proyecto_dual_e2.tcl
```

| Programa | Qué demuestra | Esperado |
|---|---|---|
| `e2_test1_dualalu.dat`      | 2 ALU independientes (**emite 2**) | Mem[100]=12 |
| `e2_test2_raw_fwd.dat`      | RAW entre vías + **forwarding** | Mem[100]=40 |
| `e2_test3_loaduse_mem.dat`  | **load-use (stall)** + conflicto de memoria | Mem[100]=14 |
| `e2_test4_branch_flush.dat` | **branch tomado + flush/anulación** (x9=0) | Mem[100]=42 |
| `e2_test5_2writes.dat`      | **2 escrituras** al regfile (gana vía 1) | Mem[100]=7 |
| `e2_test6_reagrupa.dat`     | **reagrupamiento** (emite 1 repetido) | Mem[100]=5 |

## Señales en la waveform (ya las agrega el script)

Las instrucciones se muestran **en texto (radix ASCII)**, no en binario:

- **Emisión / control:** `issueCountOut` (cuántas emite: 2/1/0), `stall`, `flushDE`, `annul1`, `PCF`.
- **Vía 0 (texto ASCII):** `t0F t0E t0M t0W` — instrucción en Fetch/Decode, EX, MEM, WB.
- **Vía 1 (texto ASCII):** `t1F t1E t1M t1W`.
- **Resultado:** `MemWrite`, `DataAdr`, `WriteData`.

### Señales específicas por programa (el script las agrega solas)

Según el `PROG` elegido, el script añade las señales relevantes de ese escenario:

| Programa | Señales extra que agrega | Qué ves |
|---|---|---|
| `e2_test2_raw_fwd`      | `fwdA0act fwdB0act fwdA1act fwdB1act`, `SrcA_1D`, `RD1_1D` | el indicador de forwarding en 1 + el operando forwardeado distinto del valor del regfile |
| `e2_test3_loaduse_mem`  | `lwE0 lwE1`, `memOp0M memOp1M` | el `lw` en EX (causa del stall) y las operaciones de memoria por vía (conflicto) |
| `e2_test4_branch_flush` | `PCSrc0E PCSrc1E` | qué vía toma el salto (lo que dispara `flushDE`/`annul1`) |
| `e2_test5_2writes`      | `RegWrite0W Rd0W Result0W`, `RegWrite1W Rd1W Result1W` | los 2 puertos de escritura activos el mismo ciclo |
| `e2_test6_reagrupa`     | `issue1` | cuándo la vía 1 NO se emite (y se reagrupa) |

> Si alguna señal `t0*`/`t1*` queda en hexadecimal: selecciónala en la waveform →
> clic derecho → **Radix → ASCII**.

## Qué mirar en cada demostración

| Demostración | Señales clave | Qué buscar |
|---|---|---|
| **Emisión simultánea** | `issueCountOut`, `t0E`, `t1E` | ciclos con `issueCountOut=2` y dos instrucciones reales en EX |
| **Reagrupamiento** | `issueCountOut`, `t0F`, `t1F` | tras un `issueCountOut=1`, la instrucción de la vía 1 aparece como vía 0 el ciclo siguiente |
| **Load-use** | `stall`, `t0E` | `stall=1` con un `lw` en EX y su consumidora esperando |
| **Branch/flush** | `flushDE`, `annul1` | pulso de `flushDE` y las etapas limpiándose (`bubble`) |
| **2 escrituras** | `t0W`, `t1W` | dos instrucciones en WB el mismo ciclo |

## Nota de equivalencia
Los 6 programas dan el **mismo resultado** que el pipeline single-issue (configuración A)
y que el single-cycle original — verificado en Icarus. El dual-issue es más rápido (menos
ciclos) pero funcionalmente idéntico.
