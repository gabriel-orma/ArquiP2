# EF — Comparación A / B / C (preliminar)

Mediciones hechas con Icarus Verilog. Reproducible con:

```bash
bash scripts/run_abc.sh            # mide ef_prog1 y demo_profesor
```

- **A** = pipeline single-issue de 5 etapas (`src/pipeline`).
- **B** = dual-issue in-order (`src/dual_issue`).
- **C** = B + predictor de 2 bits + BTB (`src/dual_issue_opt`).
- **Instrucciones retiradas** = ciclos del single-cycle (1 instr/ciclo), que ejecuta
  exactamente la misma ruta dinámica; es idéntico para A, B y C.
- **Ciclos** = hasta que se escribe el resultado en `Mem[100]` (`tb/tb_count.v`).
- `CPI = ciclos / retiradas`, `IPC = retiradas / ciclos`, `speedup = ciclos_A / ciclos_cfg`.

## Equivalencia funcional

Las tres configuraciones producen el mismo resultado que el single-cycle:
`Mem[100] = 30` (programa 1) y `Mem[100] = 25` (programa del profesor). ✔

## Programa 1 — propio (arreglo + bucle de acumulación)

`asm/ef_prog1.s` — 45 instrucciones retiradas, `Mem[100] = 30`.
Ejercita ALU en 2 vías, forwarding (RAW), load-use (stall) y un bucle con branch
de retorno tomado 5 veces.

| Config | Ciclos | CPI | IPC | Speedup vs A |
|---|---|---|---|---|
| A (single-issue) | 66 | 1.47 | 0.68 | 1.00× |
| B (dual-issue) | 59 | 1.31 | 0.76 | 1.12× |
| **C (dual+pred+BTB)** | **51** | **1.13** | **0.88** | **1.29×** |

## Programa 2 — del profesor (riscvtest de Harris, sin modificar)

`mem/demo_profesor.dat` — 18 instrucciones retiradas, `Mem[100] = 25`.
Código muy dependiente (RAW) y con varios saltos, sin bucles repetidos.

| Config | Ciclos | CPI | IPC | Speedup vs A |
|---|---|---|---|---|
| A (single-issue) | 26 | 1.44 | 0.69 | 1.00× |
| B (dual-issue) | 32 | 1.78 | 0.56 | 0.81× |
| C (dual+pred+BTB) | 32 | 1.78 | 0.56 | 0.81× |

## Interpretación (para la defensa)

1. **El dual-issue no es gratis.** En el programa del profesor B (y C) quedan por
   debajo de A: hay poca ILP (muchas dependencias) y varios saltos, así que casi
   nunca se emiten 2 instrucciones y se paga la **burbuja de reagrupamiento** (1 ciclo
   por emisión parcial en el diseño de 5 etapas) más la penalización de branch. El
   dual-issue solo conviene cuando hay instrucciones independientes que emparejar.

2. **El predictor solo ayuda con bucles.** En el programa del profesor C = B porque no
   hay branches que se repitan: el BTB/predictor no tiene nada que reutilizar. En el
   programa 1, con un bucle que se toma 5 veces, C baja de 59 a 51 ciclos (1.29× vs A):
   la 1.ª vuelta falla (BTB vacío) y las siguientes se predicen bien, ahorrando ~2
   ciclos por salto.

3. **Esto motiva la limitación del dual-issue ingenuo.** La burbuja de reagrupamiento
   es la que hunde a B en código dependiente; un **Instruction Queue** (que conserve la
   instrucción no emitida en vez de re-buscarla) la eliminaría. Queda como línea de
   mejora futura además del predictor ya implementado.
