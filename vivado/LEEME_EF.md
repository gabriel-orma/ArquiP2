# Paquete Vivado — EF (Configuración C: dual-issue + predictor 2 bits + BTB)

Genera el proyecto Vivado desde los fuentes `.v` (no se entrega `.xpr`, para que
funcione en cualquier versión). **Verificado en Icarus Verilog; NO probado en
Vivado desde el entorno de desarrollo** — puede requerir ajustes menores de ruta
o de parte FPGA.

## Uso

Desde la consola Tcl de Vivado, parado en esta carpeta `vivado/`:

```tcl
source crear_proyecto_dual_ef.tcl
```

o en batch (sin GUI):

```
vivado -mode batch -source crear_proyecto_dual_ef.tcl
```

Para elegir otro programa, define `PROG` antes del `source`:

```tcl
set PROG ef_prog1.dat ; source crear_proyecto_dual_ef.tcl
```

Si tu Vivado no tiene la parte por defecto, cámbiala:

```tcl
set PART xc7a100tcsg324-1 ; source crear_proyecto_dual_ef.tcl
```

## Programas (en `mem/`, mismo testbench `tb_dual_opt_trace`)

| PROG | Qué muestra | Mem[100] |
|---|---|---|
| `ef_loop.dat` (default) | bucle: el predictor **brilla** (PREDICE vs MISPRED) | 24 |
| `ef_prog1.dat` | propio: arreglo + bucle (ALU dual, load-use, forwarding) | 30 |
| `demo_profesor.dat` | riscvtest de Harris, sin modificar | 25 |

## Qué mirar en la waveform

La traza imprime por ciclo la instrucción en cada etapa/vía (en texto) y la bandera
del ciclo. En el waveform, lo clave de la config C:

| Señal | Significado |
|---|---|
| `PCF` | puntero de fetch (en `ef_loop` oscila 16↔20 sin flush cuando predice bien) |
| `predTakenPkt` | IF predijo un salto tomado → **redirige el fetch** sin esperar a EX |
| `btb_hit0` / `btb_hit1` | el PC ya estaba en el BTB (branch visto antes) |
| `mispred0` / `mispred1` | la predicción falló → **único caso que hace flush** |
| `flushDE` | ahora = mala predicción (en B era "todo salto tomado") |
| `issueCountOut` | cuántas instrucciones se emiten este ciclo (2/1/0) |
| `t0*` / `t1*` | instrucción por etapa/vía (poner **radix ASCII**) |

En la consola, la bandera por ciclo resume el estado:
`PREDICE` (salto predicho en IF), `MISPRED` (predicción fallida), `STALL`, `ANNUL`.

En `ef_loop` se ve el patrón del predictor: la **1.ª** vez que pasa el branch de
retorno → `MISPRED` (BTB vacío); las **siguientes** → `PREDICE` sin flush (ahí está
el ahorro); al **salir** del bucle → `MISPRED` (corrige y sigue).

## Comparación A/B/C (ciclos / IPC / speedup)

La medición cuantitativa (configuraciones A, B y C sobre dos programas) está fuera
de este paquete, en el repositorio:

```bash
bash scripts/run_abc.sh
```

y los resultados tabulados en `docs/ef_resultados_abc.md`.

## Contenido

- `crear_proyecto_dual_ef.tcl` — script que crea el proyecto y arma la waveform.
- `src_ef/` — fuentes de la config C (incluye `bpredictor.v`, `btb.v`,
  `datapath_dual_opt.v`, `top_dual_opt.v`).
- `tb_ef/` — `tb_dual_opt_trace.v` (testbench de traza con señales de predicción).
- `mem/` — los programas `.dat`.
