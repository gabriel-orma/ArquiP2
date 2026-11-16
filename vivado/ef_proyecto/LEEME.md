# Proyecto Vivado UNICO — EF (3 modelos + varios testbenches)

Un solo proyecto con los **tres modelos** y **varios testbenches**. Se configura
**una vez** y luego solo eliges el testbench y le das *Run Simulation*. No hay que
cambiar de proyecto ni re-ejecutar scripts.

## 1. Crear el proyecto (una sola vez)

Desde la consola Tcl de Vivado, parado en esta carpeta:
```tcl
source crear_proyecto.tcl
```
o en batch:
```
vivado -mode batch -source crear_proyecto.tcl
```
Si tu Vivado no tiene la parte por defecto: `set PART xc7a100tcsg324-1 ; source crear_proyecto.tcl`

## 2. Simular (las veces que quieras, sin tocar scripts)

1. **Flow Navigator → SIMULATION → Simulation Sources** (set `sim_1`).
2. Click derecho en el testbench que quieras → **Set as Top**.
3. **Run Simulation → Run Behavioral Simulation**.

La consola imprime los ciclos (`fin en N ciclos`) y el estado de memoria para
verificar. En el waveform aparece la señal **`done`** (la señal de comprobación:
se alcanzó `fin`) y las señales de cada modelo.

## 3. Testbenches disponibles

| Testbench | Modelo | Programa | Qué verifica |
|---|---|---|---|
| `tb_A_prof`  | A pipeline       | profesor | ciclos + estado `M[x1+..]` (ref) |
| `tb_B_prof`  | B dual-issue     | profesor | + traza por via (t0*/t1*) |
| `tb_C_prof`  | C dual+pred+BTB  | profesor | + predicción (predTakenPkt, flushDE) |
| `tb_A_prog1` | A pipeline       | propio   | Mem[100]=30 |
| `tb_B_prog1` | B dual-issue     | propio   | Mem[100]=30 |
| `tb_C_prog1` | C dual+pred+BTB  | propio   | Mem[100]=30 |
| `tb_C_loop`  | C dual+pred+BTB  | bucle    | demo predictor: PREDICE/MISPRED |

Cada testbench **ya trae fijado su modelo y su programa** (vía el parámetro
`MEMFILE` del top). No hay que configurar nada más.

## 4. Qué mirar en el waveform

- **`done`** — señal de comprobación (1 cuando se alcanzó `fin`). Marca el cierre.
- **`PCnow`** — PC de fetch; su valor final = dirección de `fin`.
- **A:** `dut.rvsingle` — PC, hazards, forwarding, stalls.
- **B/C:** `t0F..t0W` / `t1F..t1W` (instrucción por etapa/vía, radix **ASCII**),
  `issueCountOut` (2/1/0), `stallS`, `flushS`/`mispS`, `annulS`.
- **C (predicción):** `predS` (predTakenPkt = predijo salto), `mispS` (flushDE =
  mala predicción), `hit0S`/`hit1S` (BTB hit). En `tb_C_loop` se ve el patrón
  MISPRED→PREDICE→MISPRED del bucle.

## 5. Resultados de referencia

- **Programa del profesor:** `M[x1+0..52]` (x1=1536) =
  `11 5 12 7 16 23 24 18 24 74 4 0 1 1`. Ciclos: A=456, B=478, C=406.
- **Programa propio:** `Mem[100]=30`. Ciclos: A=64, B=57, C=49.
- **Bucle (tb_C_loop):** `Mem[100]=24`.

## Notas

- **Verificado en Icarus; NO probado en Vivado** desde el entorno de desarrollo.
- Si un testbench reporta que **no encuentra su `.dat`**, copia los archivos de
  `mem/*.dat` a `ef_dual/ef_dual.sim/sim_1/behav/xsim/` (el script ya lo intenta).
- Para añadir otro programa: ponlo en `mem/`, crea un testbench en `tb/` con
  `#(.MEMFILE("tu_programa.dat"))` y su dirección de `fin`, y re-ejecuta el script.
